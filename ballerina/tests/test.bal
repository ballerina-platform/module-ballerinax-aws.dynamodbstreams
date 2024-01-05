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

import ballerina/test;
import ballerina/os;
import ballerinax/aws.dynamodb;
import ballerina/io;

configurable string accessKeyId = os:getEnv("ACCESS_KEY_ID");
configurable string secretAccessKey = os:getEnv("SECRET_ACCESS_KEY");
configurable string region = os:getEnv("REGION");

final string mainTable = "TestStreamTable";

ConnectionConfig config = {
    awsCredentials: {accessKeyId: accessKeyId, secretAccessKey: secretAccessKey},
    region: region
};

Client dynamoDBStreamClient = check new (config);

@test:Config{}
function testStreamsList() returns error? {
    ListStreamsInput listStreamsInput = {
        tableName: mainTable,
        'limit: 1
    };
    stream<Stream,error?> response = check dynamoDBStreamClient->listStreams(listStreamsInput);
    check response.forEach(function(Stream resp) {
        test:assertEquals(resp.tableName, mainTable);
    });                     
}

@test:Config{}
function testDescribeStreams() returns error? {
    DescribeStreamInput describeStream = {
        streamArn: "arn:aws:dynamodb:us-east-1:134633749276:table/TestStreamTable/stream/2024-01-04T04:43:13.919"
    };
    StreamDescription response = check dynamoDBStreamClient->describeStream(describeStream);
    test:assertEquals(response.tableName, mainTable);
    test:assertEquals(response.streamStatus, "ENABLED");
}

@test:Config{}
function testGetRecords() returns error? {
    dynamodb:Client dynamodbClient = check new(config);
    dynamodb:ItemCreateInput request = {
        tableName: mainTable,
        item: {
            "LastPostDateTime": {
                "S": "201303190422"
            },
            "Tags": {
                "SS": [
                    "Update",
                    "Multiple Items",
                    "HelpMe"
                ]
            },
            "ForumName": {
                "S": "Amazon DynamoDB"
            },
            "Message": {
                "S": "I want to update multiple items in a single call. What's the best way to do that?"
            },
            "Subject": {
                "S": "How do I update multiple items?"
            },
            "LastPostedBy": {
                "S": "fred@example.com"
            }
        },
        conditionExpression: "ForumName <> :f and Subject <> :s",
        returnValues: dynamodb:ALL_OLD,
        returnItemCollectionMetrics: dynamodb:SIZE,
        returnConsumedCapacity: dynamodb:TOTAL,
        expressionAttributeValues: {
            ":f": {
                "S": "Amazon DynamoDB"
            },
            ":s": {
                "S": "How do I update multiple items?"
            }
        }
    };
    _ = check dynamodbClient->createItem(request);

    DescribeStreamInput describeStream = {
        streamArn: "arn:aws:dynamodb:us-east-1:134633749276:table/TestTable/stream/2023-11-17T09:36:43.853"
    };
    StreamDescription response = check dynamoDBStreamClient->describeStream(describeStream);
    io:println("describe stream: " + response.toString());
    string shardId = "";
    Shard[]? shards = response.shards;
    test:assertTrue(shards is Shard[]);
    if shards is Shard[] {
        shardId = <string>shards[0].shardId;
    }
    GetShardsIteratorInput shardIteratorReq = {
        shardIteratorType: TRIM_HORIZON, 
        shardId: shardId, 
        streamArn: "arn:aws:dynamodb:us-east-1:134633749276:table/TestTable/stream/2023-11-17T09:36:43.853"
    };
    GetShardsIteratorOutput shardIterator = check dynamoDBStreamClient->getShardIterator(shardIteratorReq);
    GetRecordsInput getRecordsInput = {
        shardIterator: shardIterator.shardIterator
    };
    io:println("getRecordsInput: " + getRecordsInput.toString());
    stream<Record, error?> streamResult = check dynamoDBStreamClient->getRecords(getRecordsInput);
    check streamResult.forEach(function(Record srecord) {
        io:println("record: " + srecord.toString());
    });
    dynamodb:ItemDeleteInput delRequest = {
        tableName: mainTable,
        'key: {
            "ForumName": {
                "S": "Amazon DynamoDB"
            },
            "Subject": {
                "S": "How do I update multiple items?"
            }
        },
        returnConsumedCapacity: dynamodb:TOTAL,
        returnItemCollectionMetrics: dynamodb:SIZE,
        returnValues: dynamodb:ALL_OLD
    };
    _= check dynamodbClient->deleteItem(delRequest);
}
