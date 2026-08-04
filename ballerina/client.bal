// Copyright (c) 2024, WSO2 LLC. (http://www.wso2.com).
//
// WSO2 LLC. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

import ballerina/data.jsondata;
import ballerina/http;
import ballerinax/aws;
import ballerinax/aws.auth;

# The Ballerina AWS DynamoDB Streams connector provides the capability to capture and process item-level changes
# made to Amazon DynamoDB tables in near real time.
@display {label: "Amazon DynamoDB Streams", iconPath: "icon.png"}
public isolated client class Client {
    private final http:Client streamClient;
    private final auth:CredentialProvider credentialProvider;
    private final aws:Region|string region;
    private final string host;

    # Initializes the connector.
    # ```ballerina
    # dynamodbstreams:Client dynamodbStreams = check new ({
    #     auth: {
    #         accessKeyId: "<AWS_ACCESS_KEY_ID>",
    #         secretAccessKey: "<AWS_SECRET_ACCESS_KEY>"
    #     },
    #     region: aws:US_EAST_1
    # });
    # ```
    #
    # + config - Configuration required to initialize the client
    # + return - An `error` on failure of initialization, or else `()`
    public isolated function init(ConnectionConfig config) returns error? {
        http:ClientConfiguration httpClientConfig = {httpVersion: config.httpVersion, http1Settings: config.http1Settings, http2Settings: config.http2Settings, timeout: config.timeout, forwarded: config.forwarded, followRedirects: config.followRedirects, poolConfig: config.poolConfig, cache: config.cache, compression: config.compression, circuitBreaker: config.circuitBreaker, retryConfig: config.retryConfig, cookieConfig: config.cookieConfig, responseLimits: config.responseLimits, secureSocket: config.secureSocket, proxy: config.proxy, socketConfig: config.socketConfig, validation: config.validation, laxDataBinding: config.laxDataBinding};
        self.region = config.region;
        aws:EndpointConfig? endpointConfig = config.endpoint;
        string baseURL;
        if endpointConfig is aws:EndpointConfig {
            self.host = aws:resolveEndpointHost(SERVICE_NAME, config.region, endpointConfig);
            baseURL = aws:resolveEndpoint(SERVICE_NAME, config.region, endpointConfig);
        } else {
            self.host = aws:resolveEndpointHost(SERVICE_NAME, config.region);
            baseURL = aws:resolveEndpoint(SERVICE_NAME, config.region);
        }
        self.streamClient = check new (baseURL, httpClientConfig);
        self.credentialProvider = check new (config.auth);
    }

    # Returns the stream ARNs associated with the current account and endpoint. If `tableName` is given, only the
    # stream ARNs for that table are returned.
    # ```ballerina
    # stream<dynamodbstreams:Stream, dynamodbstreams:Error?> streams =
    #     dynamodbStreams->listStreams({tableName: "Orders"});
    # ```
    #
    # + request - The details of the streams to list
    # + return - A stream of `Stream` values, which completes once every page has been consumed
    remote isolated function listStreams(ListStreamsInput request = {}) returns stream<Stream, Error?> {
        StreamIterator iterator = new (request, self.listStreamsPage);
        return new (iterator);
    }

    # Returns information about a stream, including its current status, its Amazon Resource Name (ARN), the
    # composition of its shards, and its corresponding DynamoDB table. A stream can have more shards than fit in a
    # single response; when `lastEvaluatedShardId` is set on the result, pass it back as `exclusiveStartShardId` to
    # read the next page of shards.
    # ```ballerina
    # dynamodbstreams:StreamDescription description = check dynamodbStreams->describeStream({streamArn});
    # ```
    #
    # + request - The details of the stream to describe
    # + return - A `StreamDescription`, or an `Error` on failure
    remote isolated function describeStream(DescribeStreamInput request) returns StreamDescription|Error {
        http:Request httpRequest = check generateRequest(self.credentialProvider, self.host, self.region,
                TARGET_DESCRIBE_STREAM, jsondata:toJson(request));
        json response = check sendRequest(self.streamClient, httpRequest);
        do {
            json description = check response.StreamDescription;
            return check jsondata:parseAsType(description);
        } on fail error e {
            return error ResponseHandlingError(string `Error occurred while processing the DescribeStream response: ${
                    e.message()}`, e);
        }
    }

    # Returns a shard iterator, which describes a position within a shard. Use the iterator in a subsequent
    # `getRecords` call to read the stream records from the shard. Shard iterators expire 15
    # minutes after they are returned.
    # ```ballerina
    # string shardIterator = check dynamodbStreams->getShardIterator({
    #     streamArn,
    #     shardId,
    #     shardIteratorType: dynamodbstreams:TRIM_HORIZON
    # });
    # ```
    #
    # + request - The details of the shard iterator to obtain
    # + return - The shard iterator, or an `Error` on failure
    remote isolated function getShardIterator(GetShardIteratorInput request) returns string|Error {
        http:Request httpRequest = check generateRequest(self.credentialProvider, self.host, self.region,
                TARGET_GET_SHARD_ITERATOR, jsondata:toJson(request));
        json response = check sendRequest(self.streamClient, httpRequest);
        do {
            json shardIterator = check response.ShardIterator;
            string iterator = check shardIterator.ensureType();
            return iterator;
        } on fail error e {
            return error ResponseHandlingError(string `Error occurred while processing the GetShardIterator response: ${
                    e.message()}`, e);
        }
    }

    # Retrieves the stream records currently available at the shard iterator's position — at most `limit` of them
    # and never more than 1000. An empty `records` array does not mean the shard is
    # exhausted; the shard is fully read only once `nextShardIterator` is absent.
    # ```ballerina
    # dynamodbstreams:GetRecordsOutput result = check dynamodbStreams->getRecords({shardIterator});
    # ```
    #
    # + request - The details of the records to retrieve
    # + return - A `GetRecordsOutput` carrying the records and the next shard iterator, or an `Error` on failure
    remote isolated function getRecords(GetRecordsInput request) returns GetRecordsOutput|Error {
        return self.getRecordsPage(request);
    }

    # Polls a single shard and emits its stream records as a Ballerina stream. Consecutive empty polls back off
    # exponentially from `pollInterval` up to `maxPollInterval`. The stream **stops at the shard boundary**: it
    # completes once the shard is closed and fully read.
    # ```ballerina
    # stream<dynamodbstreams:Record, dynamodbstreams:Error?> records =
    #     dynamodbStreams->pollRecords({shardIterator, maxIdlePolls: 3});    
    # ```
    #
    # + request - The details of the shard to poll
    # + return - A stream of `Record` values, which completes when the shard is closed and fully read
    remote isolated function pollRecords(PollRecordsInput request) returns stream<Record, Error?> {
        RecordIterator iterator = new (request, self.getRecordsPage);
        return new (iterator);
    }

    # Releases the resources held by the credential provider: its background refresh threads, and the HTTP
    # connections it keeps open to reach STS/SSO.
    # ```ballerina
    # check dynamodbStreams.close();
    # ```
    #
    # + return - An `Error` if releasing the resources fails, or else `()`
    public isolated function close() returns Error? {
        auth:Error? result = self.credentialProvider.close();
        if result is auth:Error {
            return error Error(string `Error occurred while closing the AWS credential provider: ${
                    result.message()}`, result);
        }
    }

    private isolated function getRecordsPage(GetRecordsInput request) returns GetRecordsOutput|Error {
        http:Request httpRequest = check generateRequest(self.credentialProvider, self.host, self.region,
                TARGET_GET_RECORDS, jsondata:toJson(request));
        json response = check sendRequest(self.streamClient, httpRequest);
        GetRecordsOutput|jsondata:Error result = jsondata:parseAsType(response);
        if result is jsondata:Error {
            return error ResponseHandlingError(string `Error occurred while processing the GetRecords response: ${
                    result.message()}`, result);
        }
        return result;
    }

    private isolated function listStreamsPage(ListStreamsInput request) returns ListStreamsOutput|Error {
        http:Request httpRequest = check generateRequest(self.credentialProvider, self.host, self.region,
                TARGET_LIST_STREAMS, jsondata:toJson(request));
        json response = check sendRequest(self.streamClient, httpRequest);
        ListStreamsOutput|jsondata:Error result = jsondata:parseAsType(response);
        if result is jsondata:Error {
            return error ResponseHandlingError(string `Error occurred while processing the ListStreams response: ${
                    result.message()}`, result);
        }
        return result;
    }
}
