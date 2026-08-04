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
import ballerina/os;
import ballerinax/aws;
import ballerinax/aws.auth;
import ballerinax/aws.dynamodbstreams;

configurable string region = os:getEnv("AWS_REGION");
configurable string streamArn = os:getEnv("STREAM_ARN");

// Where the last committed sequence number of each shard is stored. A real consumer would keep this in DynamoDB, Redis,
// or whatever store it already treats as durable.
const string CHECKPOINT_DIR = "./checkpoints";

public function main() returns error? {
    // `DEFAULT_CREDENTIALS` resolves credentials from the environment, so this runs unchanged locally (environment
    // variables or `~/.aws/credentials`), on EC2 (instance profile), on ECS (task role), and on EKS (Pod Identity
    // or IRSA) — and any temporary credentials it finds are refreshed before they expire.
    dynamodbstreams:Client dynamodbStreams = check new ({
        auth: auth:DEFAULT_CREDENTIALS,
        region: region is "" ? aws:US_EAST_1 : region
    });

    dynamodbstreams:StreamDescription description = check dynamodbStreams->describeStream({streamArn});
    dynamodbstreams:Shard[] shards = check description.shards.ensureType();
    io:println(string `Stream ${streamArn} has ${shards.length()} shard(s)`);

    foreach dynamodbstreams:Shard shard in shards {
        check consumeShard(dynamodbStreams, shard);
    }

    check dynamodbStreams.close();
}

isolated function consumeShard(dynamodbstreams:Client dynamodbStreams, dynamodbstreams:Shard shard) returns error? {
    string shardId = check shard.shardId.ensureType();

    // The checkpoint is the sequence number of the last record handled — not a shard iterator. Iterators expire
    // after 15 minutes, so a persisted one is almost always dead by the next run; a sequence number stays usable
    // for the stream's whole 24-hour retention window.
    string? checkpoint = check loadCheckpoint(shardId);
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
            json errorResponse = check result.detail()["errorResponse"].ensureType();
            if errorResponse.toJsonString().includes("TrimmedDataAccessException") {
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
        check file:remove(check checkpointPath(shardId), file:RECURSIVE);
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

isolated function saveCheckpoint(string shardId, string sequenceNumber) returns error? {
    if !check file:test(CHECKPOINT_DIR, file:EXISTS) {
        check file:createDir(CHECKPOINT_DIR, file:RECURSIVE);
    }
    check io:fileWriteString(check checkpointPath(shardId), sequenceNumber);
}
