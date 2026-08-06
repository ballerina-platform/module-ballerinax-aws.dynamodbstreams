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

import ballerina/file;
import ballerina/io;
import ballerinax/aws;
import ballerinax/aws.auth;
import ballerinax/aws.dynamodbstreams;

configurable string region = ?;
configurable string streamArn = ?;

// Where the last committed sequence number of each shard is stored.
const string CHECKPOINT_DIR = "./checkpoints";

// Stored in place of a sequence number once a shard has been closed and fully read.
const string SHARD_COMPLETED = "COMPLETED";

public function main() returns error? {
    // `DEFAULT_CREDENTIALS` resolves credentials from the environment.
    dynamodbstreams:Client dynamodbStreams = check new ({
        auth: auth:DEFAULT_CREDENTIALS,
        region: region is "" ? aws:US_EAST_1 : region
    });

    dynamodbstreams:Shard[] shards = check collectShards(dynamodbStreams, streamArn);
    io:println(string `Stream ${streamArn} has ${shards.length()} shard(s)`);

    foreach dynamodbstreams:Shard shard in shards {
        check consumeShard(dynamodbStreams, shard);
    }

    check dynamodbStreams.close();
}

isolated function consumeShard(dynamodbstreams:Client dynamodbStreams, dynamodbstreams:Shard shard) returns error? {
    string shardId = check shard.shardId.ensureType();

    // The checkpoint is the sequence number of the last record handled — not a shard iterator.
    string? checkpoint = check loadCheckpoint(shardId);
    if checkpoint == SHARD_COMPLETED {
        io:println(string `Shard ${shardId}: already completed, skipping`);
        return;
    }

    string? shardIterator;
    if checkpoint is string {
        io:println(string `Shard ${shardId}: resuming after sequence number ${checkpoint}`);
        shardIterator = check dynamodbStreams->getShardIterator({
            streamArn,
            shardId,
            shardIteratorType: dynamodbstreams:AFTER_SEQUENCE_NUMBER,
            sequenceNumber: checkpoint
        });
    } else {
        io:println(string `Shard ${shardId}: no checkpoint, starting from the trim horizon`);
        shardIterator = check dynamodbStreams->getShardIterator({
            streamArn,
            shardId,
            shardIteratorType: dynamodbstreams:TRIM_HORIZON
        });
    }

    int processed = 0;
    while shardIterator is string {
        dynamodbstreams:GetRecordsOutput|dynamodbstreams:Error result =
            dynamodbStreams->getRecords({shardIterator, 'limit: 100});

        if result is dynamodbstreams:Error {
            // The only position failure a sequence-number checkpoint can hit: the record it names has aged past
            // the 24-hour retention window, so there is nothing to resume from.
            string errorResponse = check result.detail()["errorResponse"].ensureType();
            if errorResponse.includes("TrimmedDataAccessException") {
                io:println(string `Shard ${shardId}: checkpoint aged out, restarting from the trim horizon`);
                check file:remove(check checkpointPath(shardId), file:RECURSIVE);
                return;
            }
            return result;
        }

        string? lastSequenceNumber = ();
        foreach dynamodbstreams:Record 'record in result.records {
            dynamodbstreams:StreamRecord streamRecord = check 'record.dynamodb.ensureType();
            map<dynamodbstreams:AttributeValue> keys = check streamRecord.keys.ensureType();
            io:println(string `  ${'record.eventName ?: "UNKNOWN"} seq=${
                streamRecord.sequenceNumber ?: "-"} keys=${keys.toString()}`);
            lastSequenceNumber = streamRecord.sequenceNumber;
            processed += 1;
        }

        // Commit only after the whole page has been handled, so a crash mid-page replays that page rather than
        // skipping it. Stream records are delivered at least once, so downstream handling must be idempotent.
        if lastSequenceNumber is string {
            check saveCheckpoint(shardId, lastSequenceNumber);
        }

        shardIterator = result.nextShardIterator;

        // An empty page means the shard has nothing new right now; stop here and let the next run resume from the
        // committed sequence number.
        if result.records.length() == 0 {
            break;
        }
    }

    if shardIterator is () {
        // No next iterator means the shard is closed and fully read; its children carry on from here.
        io:println(string `Shard ${shardId}: closed and fully read (${processed} record(s))`);
        check saveCheckpoint(shardId, SHARD_COMPLETED);
    } else {
        io:println(string `Shard ${shardId}: ${processed} record(s) processed, position committed`);
    }
}

isolated function checkpointPath(string shardId) returns string|error =>
    file:joinPath(CHECKPOINT_DIR, shardId + ".checkpoint");

isolated function loadCheckpoint(string shardId) returns string?|error {
    string path = check checkpointPath(shardId);
    if !check file:test(path, file:EXISTS) {
        return ();
    }
    return (check io:fileReadString(path)).trim();
}

isolated function saveCheckpoint(string shardId, string state) returns error? {
    if !check file:test(CHECKPOINT_DIR, file:EXISTS) {
        check file:createDir(CHECKPOINT_DIR, file:RECURSIVE);
    }
    check io:fileWriteString(check checkpointPath(shardId), state);
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
