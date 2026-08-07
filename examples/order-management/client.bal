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

import ballerina/io;
import ballerinax/aws;
import ballerinax/aws.dynamodbstreams;

configurable string accessKeyId = ?;
configurable string secretAccessKey = ?;
configurable string region = ?;
configurable string tableName = ?;

const int MAX_IDLE_POLLS = 3;
const decimal MAX_POLL_INTERVAL = 5;

public function main() returns error? {
    dynamodbstreams:Client dynamodbStreams = check new ({
        auth: {accessKeyId, secretAccessKey},
        region: region is "" ? aws:US_EAST_1 : region
    });

    // Find the active stream of the orders table. `listStreams` pages through the result set on its own.
    string? streamArn = ();
    stream<dynamodbstreams:Stream, dynamodbstreams:Error?> streams =
        dynamodbStreams->listStreams({tableName});
    check from dynamodbstreams:Stream 'stream in streams
        do {
            streamArn = 'stream.streamArn;
        };
    if streamArn !is string {
        return error(string `No stream is enabled on the '${tableName}' table`);
    }
    io:println("Reading order changes from ", streamArn);

    dynamodbstreams:Shard[] shards = check collectShards(dynamodbStreams, streamArn);

    foreach dynamodbstreams:Shard shard in shards {
        string shardId = check shard.shardId.ensureType();

        // `TRIM_HORIZON` starts at the oldest record still held by the shard; use `LATEST` to only see changes
        // made from now on.
        string shardIterator = check dynamodbStreams->getShardIterator({
            streamArn,
            shardId,
            shardIteratorType: dynamodbstreams:TRIM_HORIZON
        });

        // Tail the shard. Consecutive empty polls back off up to `maxPollInterval`, and `maxIdlePolls` bounds the
        // wait so this example terminates instead of tailing forever. `pollRecords` stops at the shard boundary,
        // so a long-running consumer would re-describe the stream and pick up the child shards from here.
        stream<dynamodbstreams:Record, dynamodbstreams:Error?> records = dynamodbStreams->pollRecords({
            shardIterator,
            pollInterval: 1,
            maxPollInterval: MAX_POLL_INTERVAL,
            maxIdlePolls: MAX_IDLE_POLLS
        });
        check from dynamodbstreams:Record 'record in records
            do {
                check processOrderChange('record);
            };
    }

    check dynamodbStreams.close();
}

isolated function processOrderChange(dynamodbstreams:Record 'record) returns error? {
    dynamodbstreams:StreamRecord streamRecord = check 'record.dynamodb.ensureType();
    map<dynamodbstreams:AttributeValue> keys = check streamRecord.keys.ensureType();
    string orderId = keys.get("OrderId").s ?: "<unknown>";

    match 'record.eventName {
        dynamodbstreams:INSERT => {
            map<dynamodbstreams:AttributeValue> newImage = check streamRecord.newImage.ensureType();
            io:println(string `New order ${orderId} placed with status ${statusOf(newImage)}`);
        }
        dynamodbstreams:MODIFY => {
            map<dynamodbstreams:AttributeValue> oldImage = check streamRecord.oldImage.ensureType();
            map<dynamodbstreams:AttributeValue> newImage = check streamRecord.newImage.ensureType();
            io:println(string `Order ${orderId} moved from ${statusOf(oldImage)} to ${statusOf(newImage)}`);
        }
        dynamodbstreams:REMOVE => {
            // Time-to-live expiry is reported as a removal by the DynamoDB service itself.
            boolean expired = 'record.userIdentity?.principalId == "dynamodb.amazonaws.com";
            io:println(string `Order ${orderId} ${expired ? "expired" : "was deleted"}`);
        }
    }
}

isolated function statusOf(map<dynamodbstreams:AttributeValue> image) returns string {
    dynamodbstreams:AttributeValue? status = image["Status"];
    return status?.s ?: "<unset>";
}

# `describeStream` returns at most 100 shards per call. A `lastEvaluatedShardId` on the result means there are more,
# so a consumer that wants the whole stream has to page through them.
#
# + dynamodbStreams - The client to read through
# + streamArn - The stream whose shards are collected
# + return - Every shard of the stream, or an `error` if a page cannot be read
isolated function collectShards(dynamodbstreams:Client dynamodbStreams, string streamArn)
        returns dynamodbstreams:Shard[]|error {
    dynamodbstreams:Shard[] shards = [];
    string? exclusiveStartShardId = ();
    while true {
        dynamodbstreams:DescribeStreamInput request = {streamArn};
        if exclusiveStartShardId is string {
            request.exclusiveStartShardId = exclusiveStartShardId;
        }
        dynamodbstreams:StreamDescription description = check dynamodbStreams->describeStream(request);
        dynamodbstreams:Shard[]? page = description?.shards;
        if page is dynamodbstreams:Shard[] {
            shards.push(...page);
        }
        exclusiveStartShardId = description?.lastEvaluatedShardId;
        if exclusiveStartShardId !is string {
            break;
        }
    }
    return shards;
}
