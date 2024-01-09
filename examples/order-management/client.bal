// Copyright (c) 2024 WSO2 LLC. (http://www.wso2.org) All Rights Reserved.
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

import ballerina/io;
import ballerina/os;
import ballerinax/aws.dynamodbstreams;

public function main() returns error? {
    dynamodbstreams:ConnectionConfig amazonDynamodbConfig = {
        awsCredentials: {
            accessKeyId: os:getEnv("ACCESS_KEY_ID"),
            secretAccessKey: os:getEnv("SECRET_ACCESS_KEY")
        },
        region: os:getEnv("REGION")
    };

    dynamodbstreams:Client dynamodbStreamsClient = check new(amazonDynamodbConfig);

    dynamodbstreams:DescribeStreamInput describeStream = {
        streamArn: "arn:aws:dynamodb:us-east-1:134633749276:table/TestTable/stream/2023-11-17T09:36:43.853"
    };

    dynamodbstreams:StreamDescription describeStreamResult = check dynamodbStreamsClient->describeStream(describeStream);
    string shardId = "";
    dynamodbstreams:Shard[]? shards = describeStreamResult.shards;

    if shards is dynamodbstreams:Shard[] {
        shardId = <string>shards[0].shardId;
    }

    dynamodbstreams:GetShardsIteratorInput shardIteratorReq = {
        shardIteratorType: dynamodbstreams:TRIM_HORIZON, 
        shardId: shardId, 
        streamArn: "arn:aws:dynamodb:us-east-1:134633749276:table/TestTable/stream/2023-11-17T09:36:43.853"
    };
    dynamodbstreams:GetShardsIteratorOutput shardIterator = check dynamodbStreamsClient->getShardIterator(shardIteratorReq);
    dynamodbstreams:GetRecordsInput getRecordsInput = {
        shardIterator: shardIterator.shardIterator
    };  
    while true {
        stream<dynamodbstreams:Record, error?> result = check dynamodbStreamsClient->getRecords(getRecordsInput);
        check result.forEach(function(dynamodbstreams:Record srecord) {
            io:println(result);
        });
    }
}
