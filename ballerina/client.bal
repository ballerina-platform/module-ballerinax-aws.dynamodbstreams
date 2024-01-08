// Copyright (c) 2024, WSO2 LLC. (http://www.wso2.org) All Rights Reserved.
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

import ballerina/http;
import ballerinax/'client.config;

# The Ballerina AWS DynamoDB Streams connector provides the capability to access AWS DynamoDB Streams related operations.
@display {label: "Amazon DynamoDB Streams", iconPath: "icon.png"}
public isolated client class Client {
    private final http:Client awsDynamoDb;
    private final string accessKeyId;
    private final string secretAccessKey;
    private final string? securityToken;
    private final string region;
    private final string awsHost;
    private final string uri = SLASH;

    # Initializes the connector. During initialization you have to pass access key id, secret access key, and region.
    # Create an AWS account and obtain tokens following
    # [this guide](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_access-keys.html).
    #
    # + config - Configuration required to initialize the client
    # + return - An error on failure of initialization or else `()`
    public isolated function init(ConnectionConfig config) returns error? {
        self.accessKeyId = config.awsCredentials.accessKeyId;
        self.secretAccessKey = config.awsCredentials.secretAccessKey;
        self.securityToken = config.awsCredentials?.securityToken;
        self.region = config.region;
        self.awsHost = AWS_STREAMS_SERVICE + DOT + self.region + DOT + AWS_HOST;
        string endpoint = HTTPS + self.awsHost;

        http:ClientConfiguration httpClientConfig = check config:constructHTTPClientConfig(config);
        self.awsDynamoDb = check new (endpoint, httpClientConfig);
    }

    # Returns an array of stream ARNs associated with the current account and endpoint. If the TableName parameter is present, then ListStreams will return only the streams ARNs for that table.
    #
    # + request - The required details to list the streams
    # + return - If success, `stream<Stream, error?>` or else an error
    remote isolated function listStreams(ListStreamsInput request) returns stream<Stream, error?>|error {
        ListStream listStream = check new ListStream(self.awsDynamoDb, self.awsHost, self.accessKeyId,
                                                        self.secretAccessKey, self.region, request);
        return new stream<Stream, error?>(listStream);
    }

    # Returns information about a stream, including the current status of the stream, its Amazon Resource Name (ARN), the composition of its shards, and its corresponding DynamoDB table.
    #
    # + request - The required details to describe the stream
    # + return - If success, dynamodb:StreamDescription record, else an error
    remote isolated function describeStream(DescribeStreamInput request) returns StreamDescription|error {
        string target = STREAMS_VERSION + DOT + "DescribeStream";
        json payload = check request.cloneWithType(json);
        convertJsonKeysToUpperCase(payload);
        map<string> signedRequestHeaders = check getSignedRequestHeaders(self.awsHost, self.accessKeyId,
                                                                    self.secretAccessKey, self.region,
                                                                    POST, self.uri, target, payload);
        json response = check self.awsDynamoDb->post(self.uri, payload, signedRequestHeaders);
        convertJsonKeysToCamelCase(response);
        json streamDescription = check response.streamDescription;
        return check streamDescription.cloneWithType(StreamDescription);
    }

    # Returns a shard iterator. A shard iterator provides information about how to retrieve the stream records from within a shard. Use the shard iterator in a subsequent GetRecords request to read the stream records from the shard.
    #
    # + request - The required details to get the shard iterator
    # + return - If success, ShardIterator, else an error
    remote isolated function getShardIterator(GetShardsIteratorInput request) returns GetShardsIteratorOutput|error {
        string target = STREAMS_VERSION + DOT + "GetShardIterator";
        json payload = check request.cloneWithType(json);
        convertJsonKeysToUpperCase(payload);
        map<string> signedRequestHeaders = check getSignedRequestHeaders(self.awsHost, self.accessKeyId,
                                                            self.secretAccessKey, self.region,
                                                            POST, self.uri, target, payload);
        json response = check self.awsDynamoDb->post(self.uri, payload, signedRequestHeaders);
        convertJsonKeysToCamelCase(response);
        return check response.cloneWithType(GetShardsIteratorOutput);
    }

    # Retrieves the stream records from a given shard.
    #
    # + request - The required details to get the records from a shard
    # + return - If success, ShardIterator, else an error
    remote isolated function getRecords(GetRecordsInput request) returns stream<Record, error?>|error {
        RecordsStream recordStream = check new RecordsStream(self.awsDynamoDb, self.awsHost, self.accessKeyId,
                                                        self.secretAccessKey, self.region, request);
        return new stream<Record, error?>(recordStream);
    }
}
