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
import ballerina/io;
import ballerinax/aws.dynamodb;

configurable string accessKeyId = os:getEnv("ACCESS_KEY_ID");
configurable string secretAccessKey = os:getEnv("SECRET_ACCESS_KEY");
configurable string region = os:getEnv("REGION");

final string mainTable = "TestStreamTable";
final string streamArn = "arn:aws:dynamodb:us-east-1:134633749276:table/TestStreamTable/stream/2024-01-19T11:15:31.697";
final dynamodb:Client dynamodbClient = check new(config);

ConnectionConfig config = {
    awsCredentials: {accessKeyId: accessKeyId, secretAccessKey: secretAccessKey},
    region: region
};

Client dynamoDBStreamClient = check new (config);

@test:BeforeSuite
function updateItem() returns error? {
    io:println("------region-------");
    io:println(region);
    io:println("------region-------");
    dynamodb:ItemCreateInput request = {
        TableName: mainTable,
        Item: {
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
        ConditionExpression: "ForumName <> :f and Subject <> :s",
        ReturnValues: dynamodb:ALL_OLD,
        ReturnItemCollectionMetrics: dynamodb:SIZE,
        ReturnConsumedCapacity: dynamodb:TOTAL,
        ExpressionAttributeValues: {
            ":f": {
                "S": "Amazon DynamoDB"
            },
            ":s": {
                "S": "How do I update multiple items?"
            }
        }
    };
    _ = check dynamodbClient->createItem(request);
}

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
        streamArn: streamArn
    };
    StreamDescription response = check dynamoDBStreamClient->describeStream(describeStream);
    test:assertEquals(response.tableName, mainTable);
    test:assertEquals(response.streamStatus, "ENABLED");
}

@test:Config{}
function testGetRecords() returns error? {
    DescribeStreamInput describeStream = {
        streamArn: streamArn
    };
    StreamDescription response = check dynamoDBStreamClient->describeStream(describeStream);
    test:assertEquals(response.tableName, mainTable);
    string shardId = "";
    Shard[]? shards = response.shards;
    test:assertTrue(shards is Shard[]);
    if shards is Shard[] {
        shardId = <string>shards[0].shardId;
    }
    GetShardsIteratorInput shardIteratorReq = {
        shardIteratorType: TRIM_HORIZON, 
        shardId: shardId, 
        streamArn: streamArn
    };
    GetShardsIteratorOutput shardIterator = check dynamoDBStreamClient->getShardIterator(shardIteratorReq);
    test:assertFalse(shardIterator.shardIterator is "");
    GetRecordsInput getRecordsInput = {
        shardIterator: shardIterator.shardIterator
    };
    stream<Record, error?> streamResult = check dynamoDBStreamClient->getRecords(getRecordsInput);
    check streamResult.forEach(function(Record srecord) {
        test:assertEquals(srecord.eventSource, "aws:dynamodb");
    });
}

@test:AfterSuite
function deleteUpdatedItem() returns error? {
    dynamodb:ItemDeleteInput delRequest = {
        TableName: mainTable,
        Key: {
            "ForumName": {
                "S": "Amazon DynamoDB"
            },
            "Subject": {
                "S": "How do I update multiple items?"
            }
        },
        ReturnConsumedCapacity: dynamodb:TOTAL,
        ReturnItemCollectionMetrics: dynamodb:SIZE,
        ReturnValues: dynamodb:ALL_OLD
    };
    _= check dynamodbClient->deleteItem(delRequest);
}
