// Copyright (c) 2023 WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
//
// WSO2 Inc. licenses this file to you under the Apache License,
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
import ballerina/io;

class ListStream {
    private Stream[] currentEntries = [];
    private int index = 0;
    private final http:Client httpClient;
    private final string accessKeyId;
    private final string secretAccessKey;
    private final string region;
    private final string awsHost;
    private final string uri = SLASH;
    private string? lastEvaluatedStreamArn;
    private ListStreamsInput listStreamInput;

    isolated function init(http:Client httpClient, string host, string accessKey, string secretKey, string region, ListStreamsInput streamInput)
                           returns error? {
        self.httpClient = httpClient;
        self.accessKeyId = accessKey;
        self.secretAccessKey = secretKey;
        self.region = region;
        self.awsHost = AWS_STREAMS_SERVICE + DOT + self.region + DOT + AWS_HOST;
        self.lastEvaluatedStreamArn = null;
        self.listStreamInput = streamInput;
        self.currentEntries = check self.fetchStreams();
    }

    public isolated function next() returns record {| Stream value; |}|error? {
        if (self.index < self.currentEntries.length()) {
            record {| Stream value; |} 'stream = {value: self.currentEntries[self.index]};
            self.index += 1;
            return 'stream;
        }
        if (self.lastEvaluatedStreamArn is string) {
            self.index = 0;
            self.currentEntries = check self.fetchStreams();
            record {| Stream value; |} streamName = {value: self.currentEntries[self.index]};
            self.index += 1;
            return streamName;
        }
    }

    isolated function fetchStreams() returns Stream[]|error {
        string target = STREAMS_VERSION + DOT +"ListStreams";
        ListStreamsInput request = {
            tableName: self.listStreamInput.tableName,
            exclusiveStartStreamArn: self.lastEvaluatedStreamArn,
            'limit: self.listStreamInput.'limit
        };
        json payload = check request.cloneWithType(json);
        convertJsonKeysToUpperCase(payload);
        io:println(payload);
        map<string> signedRequestHeaders = check getSignedRequestHeaders(self.awsHost, self.accessKeyId,
                                                                         self.secretAccessKey, self.region,
                                                                         POST, self.uri, target, payload);                                 
        json tableListResp = check self.httpClient->post(self.uri, payload, signedRequestHeaders);
        convertJsonKeysToCamelCase(tableListResp);
        ListStreamsOutput response = check tableListResp.cloneWithType(ListStreamsOutput);
        self.lastEvaluatedStreamArn = response?.lastEvaluatedStreamArn;
        Stream[]? streamList = response?.streams;
        if streamList is Stream[] {
            return streamList;
        }
        return [];
    }
}

class RecordsStream {
    private Record[] currentEntries = [];
    private int index = 0;
    private final http:Client httpClient;
    private final string accessKeyId;
    private final string secretAccessKey;
    private final string region;
    private final string awsHost;
    private final string uri = SLASH;
    private string? nextShardIterator;
    private GetRecordsInput getRecordsInput;

    isolated function init(http:Client httpClient, string host, string accessKey, string secretKey, string region, GetRecordsInput getRecordsInput)
                           returns error? {
        self.httpClient = httpClient;
        self.accessKeyId = accessKey;
        self.secretAccessKey = secretKey;
        self.region = region;
        self.awsHost = AWS_STREAMS_SERVICE + DOT + self.region + DOT + AWS_HOST;
        self.nextShardIterator = null;
        self.getRecordsInput = getRecordsInput;
        self.currentEntries = check self.fetchRecords();
    }

    public isolated function next() returns record {| Record value; |}|error? {
        if (self.index < self.currentEntries.length()) {
            record {| Record value; |} 'record = {value: self.currentEntries[self.index]};
            self.index += 1;
            return 'record;
        }
        if (self.nextShardIterator is string) {
            self.index = 0;
            Record[]|error fetchRecordsResult = self.fetchRecords();
            if fetchRecordsResult is Record[] && fetchRecordsResult.length() > 0 {
                self.currentEntries = fetchRecordsResult;
            } else {
                return ();
            }
            record {| Record value; |} 'record = {value: self.currentEntries[self.index]};
            self.index += 1;
            return 'record;
        }
    }

    isolated function fetchRecords() returns Record[]|error {
        io:println("called fetch records");
        string target = STREAMS_VERSION + DOT +"GetRecords";
        GetRecordsInput request = self.getRecordsInput;
        json payload = check request.cloneWithType(json);
        convertJsonKeysToUpperCase(payload);
        map<string> signedRequestHeaders = check getSignedRequestHeaders(self.awsHost, self.accessKeyId,
                                                                         self.secretAccessKey, self.region,
                                                                         POST, self.uri, target, payload);                                                        
        json response = check self.httpClient->post(self.uri, payload, signedRequestHeaders);
        convertJsonKeysToCamelCase(response);
        GetRecordsOutput records = check response.cloneWithType(GetRecordsOutput);
        self.nextShardIterator = records?.nextShardIterator;
        if self.nextShardIterator is string {
            self.getRecordsInput.shardIterator = <string>self.nextShardIterator;
        }
        Record[]? recordList = records?.'records;
        if recordList is Record[] && recordList.length() > 0 {
            return recordList;
        } else if records.hasKey("nextShardIterator") && self.nextShardIterator is string {
            return self.fetchRecords();
        }
        return [];
    }
}

