// Copyright (c) 2026, WSO2 LLC. (http://www.wso2.com).
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

// A local stand-in for the DynamoDB Streams endpoint, reached through `endpoint.customEndpoint`. It speaks the AWS
// JSON 1.0 protocol, echoes back the table and stream named in `test_init.bal`, and records what it was sent so the
// tests can assert on signing and on the request payloads.
//
// The `listStreams` and `getRecords` fixtures are sequenced across calls to reproduce the response shapes that a
// single request cannot show: a page that is empty but still carries a continuation token, a shard with nothing new
// yet, and a shard that has closed. Tests that depend on that sequence call `resetMockState()` first.

import ballerina/http;
import ballerinax/aws;

const int MOCK_PORT = 21099;
const string MOCK_ENDPOINT = "http://localhost:21099";

// Every iterator the mock hands out carries this prefix, so anything else is rejected the way the service rejects
// an invalid or expired iterator.
const string MOCK_ITERATOR_PREFIX = "mock-iterator";
const string MOCK_REQUEST_ID = "MOCKREQUESTID123";
const string MOCK_SHARD_ID = "shard-1";

final readonly & aws:EndpointConfig mockEndpoint = {customEndpoint: MOCK_ENDPOINT};

// A single isolated variable, since a `lock` statement may access only one restricted variable.
type MockState record {|
    int listStreamsCallCount = 0;
    int getRecordsCallCount = 0;
    string authorizationHeader = "";
    string contentTypeHeader = "";
    json requestPayload = ();
|};

isolated MockState mockState = {};

listener http:Listener mockListener = new (MOCK_PORT);

service / on mockListener {
    isolated resource function post .(http:Request request) returns http:Response|error {
        string target = check request.getHeader(TARGET_HEADER);
        json payload = check request.getJsonPayload();
        string authorization = check request.getHeader("authorization");
        string contentType = check request.getHeader(CONTENT_TYPE_HEADER);
        lock {
            mockState.authorizationHeader = authorization;
            mockState.contentTypeHeader = contentType;
            mockState.requestPayload = payload.clone();
        }

        match target {
            TARGET_LIST_STREAMS => {
                return okResponse(listStreamsPage());
            }
            TARGET_DESCRIBE_STREAM => {
                return okResponse(describeStreamResponse());
            }
            TARGET_GET_SHARD_ITERATOR => {
                return okResponse({"ShardIterator": MOCK_ITERATOR_PREFIX + "-0"});
            }
            TARGET_GET_RECORDS => {
                json shardIterator = (<map<json>>payload)["ShardIterator"];
                if shardIterator is string && shardIterator.startsWith(MOCK_ITERATOR_PREFIX) {
                    return okResponse(getRecordsPage());
                }
                return errorResponse();
            }
        }
        return errorResponse();
    }
}

isolated function describeStreamResponse() returns json => {
    "StreamDescription": {
        "StreamArn": testStreamArn,
        "StreamLabel": "2026-01-01T00:00:00.000",
        "StreamStatus": "ENABLED",
        "StreamViewType": "NEW_AND_OLD_IMAGES",
        "TableName": testTableName,
        "KeySchema": [{"AttributeName": "OrderId", "KeyType": "HASH"}],
        "Shards": [
            {
                "ShardId": MOCK_SHARD_ID,
                "SequenceNumberRange": {"StartingSequenceNumber": "100000000000000000001"}
            }
        ]
    }
};

// Page 1 carries a stream and a continuation token; page 2 is empty yet still carries a token — a valid response
// the service does return, and the shape that used to panic the iterator; page 3 closes the result set.
isolated function listStreamsPage() returns json {
    int call;
    lock {
        mockState.listStreamsCallCount += 1;
        call = mockState.listStreamsCallCount;
    }
    if call == 1 {
        return {
            "Streams": [{"StreamArn": testStreamArn, "StreamLabel": "label-1", "TableName": testTableName}],
            "LastEvaluatedStreamArn": testStreamArn
        };
    }
    if call == 2 {
        return {"Streams": [], "LastEvaluatedStreamArn": testStreamArn};
    }
    return {"Streams": [{"StreamArn": testStreamArn + "-2", "StreamLabel": "label-2", "TableName": testTableName}]};
}

// An empty first page with an open iterator (the quiet-shard case), then a record, then a closed shard.
isolated function getRecordsPage() returns json {
    int call;
    lock {
        mockState.getRecordsCallCount += 1;
        call = mockState.getRecordsCallCount;
    }
    if call == 1 {
        return {"Records": [], "NextShardIterator": MOCK_ITERATOR_PREFIX + "-1"};
    }
    if call == 2 {
        return {
            "Records": [
                {
                    "eventID": "1",
                    "eventName": "INSERT",
                    "eventSource": "aws:dynamodb",
                    "awsRegion": "us-east-1",
                    "dynamodb": {
                        "SequenceNumber": "100000000000000000001",
                        "Keys": {"OrderId": {"S": "ORD-1"}},
                        "NewImage": {"OrderId": {"S": "ORD-1"}, "Status": {"S": "NEW"}},
                        "StreamViewType": "NEW_AND_OLD_IMAGES",
                        "SizeBytes": 64
                    }
                }
            ],
            "NextShardIterator": MOCK_ITERATOR_PREFIX + "-2"
        };
    }
    return {"Records": []};
}

isolated function okResponse(json payload) returns http:Response {
    http:Response response = new;
    response.statusCode = http:STATUS_OK;
    response.setJsonPayload(payload);
    return response;
}

isolated function errorResponse() returns http:Response {
    http:Response response = new;
    response.statusCode = http:STATUS_BAD_REQUEST;
    response.setHeader(REQUEST_ID_HEADER, MOCK_REQUEST_ID);
    response.setJsonPayload({
        "__type": "com.amazonaws.dynamodb.v20120810#ExpiredIteratorException",
        "message": "The shard iterator has expired"
    });
    return response;
}

isolated function newMockClient() returns Client|error =>
    new ({
        region: awsRegion,
        auth: {accessKeyId: "MOCKACCESSKEYID", secretAccessKey: "mock-secret-access-key"},
        endpoint: mockEndpoint
    });

isolated function resetMockState() {
    lock {
        mockState = {};
    }
}

isolated function lastRequestPayload() returns json {
    lock {
        return mockState.requestPayload.clone();
    }
}

isolated function listStreamsCallCount() returns int {
    lock {
        return mockState.listStreamsCallCount;
    }
}

isolated function getRecordsCallCount() returns int {
    lock {
        return mockState.getRecordsCallCount;
    }
}

isolated function lastAuthorizationHeader() returns string {
    lock {
        return mockState.authorizationHeader;
    }
}

isolated function lastContentTypeHeader() returns string {
    lock {
        return mockState.contentTypeHeader;
    }
}
