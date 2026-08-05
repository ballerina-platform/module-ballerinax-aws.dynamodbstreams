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

import ballerina/data.jsondata;
import ballerina/test;
import ballerinax/aws.auth;

@test:Config {
    groups: ["init"]
}
isolated function testInitUsingStaticAuthAndClose() returns error? {
    Client streamsClient = isLiveTestEnabled
        ? check new ({region: awsRegion, auth: staticAuth})
        : check newMockClient();
    check streamsClient.close();
}

@test:Config {
    groups: ["init"]
}
isolated function testUnresolvableCredentialsFailInit() {
    Client|error result = new ({
        region: awsRegion,
        auth: {profileName: "no-such-profile", credentialsFilePath: "./tests/resources/no-such-credentials"},
        endpoint: mockEndpoint
    });
    if result is Client {
        test:assertFail("expected an error when the credentials cannot be resolved");
    }
    test:assertTrue(result is auth:CredentialResolutionError, "unexpected error: " + result.message());
}

@test:Config {
    groups: ["operations", "listStreams"]
}
isolated function testListStreams() returns error? {
    resetMockState();
    stream<Stream, Error?> streams = dynamodbStreams->listStreams({tableName: testTableName});
    int count = 0;
    check from Stream 'stream in streams
        do {
            test:assertEquals('stream.tableName, testTableName);
            test:assertTrue('stream?.streamArn is string);
            count += 1;
        };
    test:assertTrue(count > 0, "expected at least one stream for the test table");
}

@test:Config {
    groups: ["operations", "describeStream"]
}
isolated function testDescribeStream() returns error? {
    resetMockState();
    StreamDescription description = check dynamodbStreams->describeStream({streamArn: testStreamArn});
    test:assertEquals(description.streamArn, testStreamArn);
    test:assertEquals(description.tableName, testTableName);
    test:assertEquals(description.streamStatus, ENABLED);
    Shard[] shards = check description.shards.ensureType();
    test:assertTrue(shards.length() > 0, "expected the stream to have at least one shard");
    test:assertTrue(shards[0]?.shardId is string);
}

@test:Config {
    groups: ["operations", "getShardIterator"]
}
isolated function testGetShardIterator() returns error? {
    resetMockState();
    string shardIterator = check getFirstShardIterator();
    test:assertNotEquals(shardIterator, "");
}

@test:Config {
    groups: ["operations", "getRecords"]
}
isolated function testGetRecordsSurfacesNextShardIterator() returns error? {
    resetMockState();
    string shardIterator = check getFirstShardIterator();
    GetRecordsOutput result = check dynamodbStreams->getRecords({shardIterator});

    // The next shard iterator must be surfaced so that a consumer can checkpoint the shard position; an open
    // shard returns one even when the page carried no records.
    test:assertTrue(result?.nextShardIterator is string, "expected a next shard iterator for an open shard");
    check assertWellFormed(result.records);
}

@test:Config {
    groups: ["operations", "getRecords"]
}
isolated function testGetRecordsResumesFromCheckpoint() returns error? {
    resetMockState();
    string shardIterator = check getFirstShardIterator();
    GetRecordsOutput first = check dynamodbStreams->getRecords({shardIterator, 'limit: 1});
    string checkpoint = check first?.nextShardIterator.ensureType();

    // Resuming from the checkpoint must be accepted and hand back a usable position again.
    GetRecordsOutput second = check dynamodbStreams->getRecords({shardIterator: checkpoint, 'limit: 1});
    test:assertTrue(second?.nextShardIterator is string);
    check assertWellFormed(second.records);
}

@test:Config {
    groups: ["operations", "pollRecords"]
}
isolated function testPollRecordsCompletesWhenIdle() returns error? {
    resetMockState();
    string shardIterator = check getFirstShardIterator();
    // `maxIdlePolls` bounds the loop, so this terminates against a shard that is receiving no writes.
    stream<Record, Error?> records = dynamodbStreams->pollRecords({
        shardIterator,
        pollInterval: 0.1,
        maxPollInterval: 0.2,
        maxIdlePolls: 3
    });
    Record[] collected = [];
    check from Record 'record in records
        do {
            collected.push('record);
        };
    check assertWellFormed(collected);
}

@test:Config {
    groups: ["operations", "errors"]
}
isolated function testInvalidShardIteratorFails() returns error? {
    resetMockState();
    GetRecordsOutput|Error result = dynamodbStreams->getRecords({shardIterator: "not-a-valid-shard-iterator"});
    if result is GetRecordsOutput {
        test:assertFail("expected an Error for an invalid shard iterator");
    }
    test:assertTrue(result.detail()["httpStatusCode"] is int);
    string errorResponse = check result.detail()["errorResponse"].ensureType();
    test:assertTrue(errorResponse.includes("Exception"), "unexpected error response: " + errorResponse);
}

// ---------------------------------------------------------------------------------------------------------------
// Mock-only — the request as it went out, exact call counts, and fixed fixtures
// ---------------------------------------------------------------------------------------------------------------

@test:Config {
    enable: !isLiveTestEnabled,
    groups: ["mock"]
}
isolated function testRequestIsSignedAndTargeted() returns error? {
    resetMockState();
    _ = check dynamodbStreams->describeStream({streamArn: testStreamArn});
    string authorization = lastAuthorizationHeader();
    test:assertTrue(authorization.startsWith("AWS4-HMAC-SHA256 Credential=MOCKACCESSKEYID/"),
            "the request must carry a SigV4 authorization header");
    // DynamoDB Streams signs under the `dynamodb` signing name, not its `streams.dynamodb` endpoint prefix.
    test:assertTrue(authorization.includes("/us-east-1/dynamodb/aws4_request"),
            "the credential scope must use the dynamodb signing name");
    test:assertEquals(lastContentTypeHeader(), JSON_CONTENT_TYPE);
}

@test:Config {
    enable: !isLiveTestEnabled,
    groups: ["mock"]
}
isolated function testRequestPayloadUsesWireFieldNames() returns error? {
    resetMockState();
    _ = check dynamodbStreams->getShardIterator({
        streamArn: testStreamArn,
        shardId: MOCK_SHARD_ID,
        shardIteratorType: LATEST
    });
    test:assertEquals(lastRequestPayload(), {
        "StreamArn": testStreamArn,
        "ShardId": MOCK_SHARD_ID,
        "ShardIteratorType": "LATEST"
    });
}

@test:Config {
    enable: !isLiveTestEnabled,
    groups: ["mock"]
}
isolated function testListStreamsWalksEmptyIntermediatePage() returns error? {
    resetMockState();
    stream<Stream, Error?> streams = dynamodbStreams->listStreams({tableName: testTableName});
    Stream[] collected = [];
    check from Stream 'stream in streams
        do {
            collected.push('stream);
        };

    // Three requests: page 1 (one stream), page 2 (empty but not final), page 3 (final, one stream).
    test:assertEquals(collected.length(), 2);
    test:assertEquals(listStreamsCallCount(), 3);
}

@test:Config {
    enable: !isLiveTestEnabled,
    groups: ["mock"]
}
isolated function testListStreamsSendsContinuationToken() returns error? {
    resetMockState();
    stream<Stream, Error?> streams = dynamodbStreams->listStreams({tableName: testTableName, 'limit: 1});
    check from Stream _ in streams
        do {
        };
    // The last request of the walk must have carried the continuation token from the preceding page.
    test:assertEquals(lastRequestPayload(), {
        "TableName": testTableName,
        "Limit": 1,
        "ExclusiveStartStreamArn": testStreamArn
    });
}

@test:Config {
    enable: !isLiveTestEnabled,
    groups: ["mock"]
}
isolated function testGetRecordsWalksShardToCompletion() returns error? {
    resetMockState();

    // The loop a consumer writes: read a page, hand the returned iterator back, stop when none comes back.
    Record[] collected = [];
    string? shardIterator = MOCK_ITERATOR_PREFIX + "-0";
    while shardIterator is string {
        GetRecordsOutput result = check dynamodbStreams->getRecords({shardIterator});
        collected.push(...result.records);
        shardIterator = result.nextShardIterator;
    }

    // Page 1 is empty with an open iterator, page 2 carries the record, page 3 closes the shard.
    test:assertEquals(collected.length(), 1);
    test:assertEquals(collected[0].eventName, INSERT);
    test:assertEquals(getRecordsCallCount(), 3);
}

@test:Config {
    enable: !isLiveTestEnabled,
    groups: ["mock"]
}
isolated function testPollRecordsBacksOffAndCompletesOnClosedShard() returns error? {
    resetMockState();
    stream<Record, Error?> records = dynamodbStreams->pollRecords({
        shardIterator: MOCK_ITERATOR_PREFIX + "-0",
        pollInterval: 0.1,
        maxPollInterval: 0.2
    });
    Record[] collected = [];
    check from Record 'record in records
        do {
            collected.push('record);
        };

    // Poll 1 is empty with an open iterator, poll 2 yields the record, poll 3 closes the shard and ends the stream.
    test:assertEquals(collected.length(), 1);
    StreamRecord streamRecord = check collected[0].dynamodb.ensureType();
    map<AttributeValue> keys = check streamRecord.keys.ensureType();
    test:assertEquals(keys.get("OrderId").s, "ORD-1");
    test:assertEquals(getRecordsCallCount(), 3);
}

@test:Config {
    enable: !isLiveTestEnabled,
    groups: ["mock"]
}
isolated function testPollRecordsHonoursMaxIdlePolls() returns error? {
    resetMockState();
    // The first poll comes back empty, which is one idle poll, so the stream completes without a second request.
    stream<Record, Error?> records = dynamodbStreams->pollRecords({
        shardIterator: MOCK_ITERATOR_PREFIX + "-0",
        pollInterval: 0.1,
        maxPollInterval: 0.1,
        maxIdlePolls: 1
    });
    int count = 0;
    check from Record _ in records
        do {
            count += 1;
        };
    test:assertEquals(count, 0);
    test:assertEquals(getRecordsCallCount(), 1);
}

@test:Config {
    enable: !isLiveTestEnabled,
    groups: ["mock"]
}
isolated function testServiceErrorReportsTheErrorResponse() returns error? {
    resetMockState();
    GetRecordsOutput|Error result = dynamodbStreams->getRecords({shardIterator: "trigger-error"});
    if result is GetRecordsOutput {
        test:assertFail("expected an Error for the mocked failure response");
    }
    // The message is generic and names the status; the service's error response is reported as it is in the detail,
    // alongside the status code and the request id.
    test:assertEquals(result.message(), "The DynamoDB Streams operation failed with status 400");
    test:assertEquals(result.detail()["httpStatusCode"], 400);
    test:assertEquals(result.detail()["requestId"], MOCK_REQUEST_ID);
    // The body is reported as it was received, so the exception name is there to match on.
    string errorResponse = check result.detail()["errorResponse"].ensureType();
    test:assertTrue(errorResponse.includes("ExpiredIteratorException"), "unexpected body: " + errorResponse);
    test:assertTrue(errorResponse.includes("The shard iterator has expired"), "unexpected body: " + errorResponse);
}

@test:Config {
    enable: !isLiveTestEnabled,
    groups: ["mock", "errors"]
}
isolated function testNonJsonFailureBodyIsReportedVerbatim() returns error? {
    resetMockState();
    GetRecordsOutput|Error result = dynamodbStreams->getRecords({shardIterator: TRIGGER_NON_JSON_ERROR});
    if result is GetRecordsOutput {
        test:assertFail("expected an Error for the mocked gateway failure");
    }
    test:assertEquals(result.message(), "The DynamoDB Streams operation failed with status 502");
    test:assertEquals(result.detail()["httpStatusCode"], 502);
    string errorResponse = check result.detail()["errorResponse"].ensureType();
    test:assertEquals(errorResponse, "<html><body>502 Bad Gateway</body></html>");
}

@test:Config {
    groups: ["mock", "errors"]
}
isolated function testConnectionFailureLeavesErrorDetailsUnset() returns error? {
    // Nothing is listening on this port, so the failure happens before any response is received.
    Client streamsClient = check new ({
        region: awsRegion,
        auth: {accessKeyId: "MOCKACCESSKEYID", secretAccessKey: "mock-secret-access-key"},
        endpoint: {customEndpoint: "http://localhost:21098"}
    });
    StreamDescription|Error result = streamsClient->describeStream({streamArn: testStreamArn});
    if result is StreamDescription {
        test:assertFail("expected an Error when the endpoint is unreachable");
    }
    // The message names the step and appends the transport failure's own wording, which varies by environment.
    test:assertTrue(result.message().startsWith("Error occurred while invoking the REST API: "),
            "unexpected message: " + result.message());
    // Nothing came back from the service, so there are no response details to report.
    test:assertEquals(result.detail(), {});
    check streamsClient.close();
}

// ---------------------------------------------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------------------------------------------

isolated function getFirstShardIterator() returns string|error {
    StreamDescription description = check dynamodbStreams->describeStream({streamArn: testStreamArn});
    Shard[] shards = check description.shards.ensureType();
    string shardId = check shards[0].shardId.ensureType();
    return dynamodbStreams->getShardIterator({
        streamArn: testStreamArn,
        shardId,
        shardIteratorType: TRIM_HORIZON
    });
}

// Records arrive in whatever quantity the backend has, so assert their shape rather than their count.
isolated function assertWellFormed(Record[] records) returns error? {
    foreach Record 'record in records {
        test:assertEquals('record.eventSource, "aws:dynamodb");
        StreamRecord streamRecord = check 'record.dynamodb.ensureType();
        map<AttributeValue> keys = check streamRecord.keys.ensureType();
        test:assertTrue(keys.length() > 0, "expected the record to carry its item keys");
    }
}

// ---------------------------------------------------------------------------------------------------------------
// Data binding tests — no backend needed
// ---------------------------------------------------------------------------------------------------------------

@test:Config {
    groups: ["dataBinding"]
}
isolated function testListStreamsRequestSerialization() returns error? {
    ListStreamsInput request = {tableName: "Orders", exclusiveStartStreamArn: "arn:start", 'limit: 10};
    json expected = {"TableName": "Orders", "ExclusiveStartStreamArn": "arn:start", "Limit": 10};
    test:assertEquals(jsondata:toJson(request), expected);
}

@test:Config {
    groups: ["dataBinding"]
}
isolated function testEmptyListStreamsRequestSerialization() returns error? {
    ListStreamsInput request = {};
    test:assertEquals(jsondata:toJson(request), {});
}

@test:Config {
    groups: ["dataBinding"]
}
isolated function testDescribeStreamRequestSerialization() returns error? {
    DescribeStreamInput request = {streamArn: "arn:stream", exclusiveStartShardId: "shard-1", 'limit: 100};
    json expected = {"StreamArn": "arn:stream", "ExclusiveStartShardId": "shard-1", "Limit": 100};
    test:assertEquals(jsondata:toJson(request), expected);
}

@test:Config {
    groups: ["dataBinding"]
}
isolated function testGetShardIteratorRequestSerialization() returns error? {
    GetShardIteratorInput request = {
        streamArn: "arn:stream",
        shardId: "shard-1",
        shardIteratorType: AFTER_SEQUENCE_NUMBER,
        sequenceNumber: "100000000000000000001"
    };
    json expected = {
        "StreamArn": "arn:stream",
        "ShardId": "shard-1",
        "ShardIteratorType": "AFTER_SEQUENCE_NUMBER",
        "SequenceNumber": "100000000000000000001"
    };
    test:assertEquals(jsondata:toJson(request), expected);
}

@test:Config {
    groups: ["dataBinding"]
}
isolated function testGetRecordsRequestSerialization() returns error? {
    GetRecordsInput request = {shardIterator: "iterator-token", 'limit: 1000};
    test:assertEquals(jsondata:toJson(request), {"ShardIterator": "iterator-token", "Limit": 1000});
}

@test:Config {
    groups: ["dataBinding"]
}
isolated function testListStreamsResponseBinding() returns error? {
    json wireResponse = {
        "Streams": [
            {
                "StreamArn": "arn:aws:dynamodb:us-east-1:123456789012:table/Orders/stream/2026-01-01T00:00:00.000",
                "StreamLabel": "2026-01-01T00:00:00.000",
                "TableName": "Orders"
            }
        ],
        "LastEvaluatedStreamArn": "arn:aws:dynamodb:us-east-1:123456789012:table/Orders/stream/2026-01-01T00:00:00.000"
    };
    ListStreamsOutput response = check jsondata:parseAsType(wireResponse);
    test:assertEquals(response.streams.length(), 1);
    test:assertEquals(response.streams[0].tableName, "Orders");
    test:assertEquals(response.streams[0].streamLabel, "2026-01-01T00:00:00.000");
    test:assertTrue(response?.lastEvaluatedStreamArn is string);
}

@test:Config {
    groups: ["dataBinding"]
}
isolated function testFinalListStreamsPageBinding() returns error? {
    // The final page carries no `LastEvaluatedStreamArn`, and a page can be empty while still being valid.
    ListStreamsOutput response = check jsondata:parseAsType(<json>{"Streams": []});
    test:assertEquals(response.streams.length(), 0);
    test:assertTrue(response?.lastEvaluatedStreamArn is ());
}

@test:Config {
    groups: ["dataBinding"]
}
isolated function testStreamDescriptionBinding() returns error? {
    json wireResponse = {
        "StreamArn": "arn:aws:dynamodb:us-east-1:123456789012:table/Orders/stream/2026-01-01T00:00:00.000",
        "StreamLabel": "2026-01-01T00:00:00.000",
        "StreamStatus": "ENABLED",
        "StreamViewType": "NEW_AND_OLD_IMAGES",
        "CreationRequestDateTime": 1767225600,
        "TableName": "Orders",
        "KeySchema": [
            {"AttributeName": "OrderId", "KeyType": "HASH"},
            {"AttributeName": "CreatedAt", "KeyType": "RANGE"}
        ],
        "Shards": [
            {
                "ShardId": "shardId-00000001700000000000-abcdef01",
                "ParentShardId": "shardId-00000001600000000000-12345678",
                "SequenceNumberRange": {
                    "StartingSequenceNumber": "100000000000000000001",
                    "EndingSequenceNumber": "100000000000000000099"
                }
            }
        ],
        "LastEvaluatedShardId": "shardId-00000001700000000000-abcdef01"
    };
    StreamDescription description = check jsondata:parseAsType(wireResponse);
    test:assertEquals(description.streamStatus, ENABLED);
    test:assertEquals(description.streamViewType, NEW_AND_OLD_IMAGES);
    test:assertEquals(description.tableName, "Orders");
    test:assertEquals(description.creationRequestDateTime, <decimal>1767225600);

    KeySchemaElement[] keySchema = check description.keySchema.ensureType();
    test:assertEquals(keySchema[0].attributeName, "OrderId");
    test:assertEquals(keySchema[0].keyType, HASH);
    test:assertEquals(keySchema[1].keyType, RANGE);

    Shard[] shards = check description.shards.ensureType();
    test:assertEquals(shards[0].shardId, "shardId-00000001700000000000-abcdef01");
    test:assertEquals(shards[0].parentShardId, "shardId-00000001600000000000-12345678");
    SequenceNumberRange range = check shards[0].sequenceNumberRange.ensureType();
    test:assertEquals(range.startingSequenceNumber, "100000000000000000001");
    test:assertEquals(range.endingSequenceNumber, "100000000000000000099");
    test:assertEquals(description.lastEvaluatedShardId, "shardId-00000001700000000000-abcdef01");
}

@test:Config {
    groups: ["dataBinding"]
}
isolated function testOpenShardHasNoEndingSequenceNumber() returns error? {
    Shard shard = check jsondata:parseAsType(<json>{
        "ShardId": "shardId-00000001700000000000-abcdef01",
        "SequenceNumberRange": {"StartingSequenceNumber": "100000000000000000001"}
    });
    SequenceNumberRange range = check shard.sequenceNumberRange.ensureType();
    test:assertTrue(range?.endingSequenceNumber is ());
    test:assertTrue(shard?.parentShardId is ());
}

@test:Config {
    groups: ["dataBinding"]
}
isolated function testGetRecordsResponseBinding() returns error? {
    json wireResponse = {
        "NextShardIterator": "next-iterator-token",
        "Records": [
            {
                "eventID": "9e1b3c5a7f",
                "eventName": "MODIFY",
                "eventVersion": "1.1",
                "eventSource": "aws:dynamodb",
                "awsRegion": "us-east-1",
                "dynamodb": {
                    "SequenceNumber": "100000000000000000001",
                    "Keys": {"OrderId": {"S": "ORD-1"}},
                    "OldImage": {"OrderId": {"S": "ORD-1"}, "Status": {"S": "PENDING"}},
                    "NewImage": {"OrderId": {"S": "ORD-1"}, "Status": {"S": "SHIPPED"}},
                    "StreamViewType": "NEW_AND_OLD_IMAGES",
                    "ApproximateCreationDateTime": 1767225600,
                    "SizeBytes": 112
                }
            }
        ]
    };
    GetRecordsOutput response = check jsondata:parseAsType(wireResponse);
    test:assertEquals(response.nextShardIterator, "next-iterator-token");
    test:assertEquals(response.records.length(), 1);

    Record 'record = response.records[0];
    test:assertEquals('record.eventName, MODIFY);
    test:assertEquals('record.eventID, "9e1b3c5a7f");
    test:assertEquals('record.eventSource, "aws:dynamodb");
    test:assertEquals('record.awsRegion, "us-east-1");

    StreamRecord streamRecord = check 'record.dynamodb.ensureType();
    test:assertEquals(streamRecord.sequenceNumber, "100000000000000000001");
    test:assertEquals(streamRecord.streamViewType, NEW_AND_OLD_IMAGES);
    // `SizeBytes` is a Long on the wire, so it must bind to `int` rather than `float`.
    test:assertEquals(streamRecord.sizeBytes, 112);
    test:assertTrue(streamRecord.sizeBytes is int);

    // `Keys`/`NewImage`/`OldImage` are attribute-name keyed maps, not single attribute values.
    map<AttributeValue> keys = check streamRecord.keys.ensureType();
    test:assertEquals(keys.length(), 1);
    test:assertEquals(keys.get("OrderId").s, "ORD-1");

    map<AttributeValue> newImage = check streamRecord.newImage.ensureType();
    test:assertEquals(newImage.get("Status").s, "SHIPPED");
    map<AttributeValue> oldImage = check streamRecord.oldImage.ensureType();
    test:assertEquals(oldImage.get("Status").s, "PENDING");
}

@test:Config {
    groups: ["dataBinding"]
}
isolated function testEmptyRecordsPageBinding() returns error? {
    // A shard with no new writes returns an empty page together with a next iterator; that is not the end of
    // the shard.
    GetRecordsOutput response = check jsondata:parseAsType(<json>{
        "Records": [],
        "NextShardIterator": "still-open"
    });
    test:assertEquals(response.records.length(), 0);
    test:assertEquals(response.nextShardIterator, "still-open");
}

@test:Config {
    groups: ["dataBinding"]
}
isolated function testClosedShardPageBinding() returns error? {
    // A closed and fully-read shard omits `NextShardIterator`.
    GetRecordsOutput response = check jsondata:parseAsType(<json>{"Records": []});
    test:assertTrue(response?.nextShardIterator is ());
}

@test:Config {
    groups: ["dataBinding"]
}
isolated function testAllAttributeValueTypesBinding() returns error? {
    json wireImage = {
        "Title": {"S": "Ballerina"},
        "Count": {"N": "42"},
        "Thumbnail": {"B": "dGhpcyB0ZXh0IGlzIGJhc2U2NA=="},
        "InStock": {"BOOL": true},
        "Discontinued": {"NULL": true},
        "Tags": {"SS": ["new", "featured"]},
        "Ratings": {"NS": ["4", "5"]},
        "Blobs": {"BS": ["dGhpcw==", "dGhhdA=="]},
        "History": {"L": [{"S": "created"}, {"N": "1"}]},
        "Address": {"M": {"City": {"S": "Colombo"}, "Zip": {"N": "00100"}}}
    };
    map<AttributeValue> image = check jsondata:parseAsType(wireImage);
    test:assertEquals(image.get("Title").s, "Ballerina");
    test:assertEquals(image.get("Count").n, "42");
    test:assertEquals(image.get("Thumbnail").b, "dGhpcyB0ZXh0IGlzIGJhc2U2NA==");
    test:assertEquals(image.get("InStock").bool, true);
    test:assertEquals(image.get("Discontinued").'null, true);
    test:assertEquals(image.get("Tags").ss, ["new", "featured"]);
    test:assertEquals(image.get("Ratings").ns, ["4", "5"]);
    test:assertEquals(image.get("Blobs").bs, ["dGhpcw==", "dGhhdA=="]);

    AttributeValue[] history = check image.get("History").l.ensureType();
    test:assertEquals(history[0].s, "created");
    test:assertEquals(history[1].n, "1");

    map<AttributeValue> address = check image.get("Address").m.ensureType();
    test:assertEquals(address.get("City").s, "Colombo");
    test:assertEquals(address.get("Zip").n, "00100");
}

@test:Config {
    groups: ["dataBinding"]
}
isolated function testAttributeNamesArePreservedVerbatim() returns error? {
    // Attribute names are user data and must never be case-converted. These names would all be corrupted by a
    // blanket first-letter conversion over the response JSON, and the last one collides with a type tag.
    json wireImage = {
        "OrderId": {"S": "ORD-1"},
        "customerName": {"S": "Alice"},
        "SKU": {"S": "SKU-9"},
        "Nested": {"M": {"InnerKey": {"N": "7"}, "BOOL": {"S": "an attribute literally named BOOL"}}}
    };
    map<AttributeValue> image = check jsondata:parseAsType(wireImage);
    test:assertTrue(image.hasKey("OrderId"));
    test:assertTrue(image.hasKey("customerName"));
    test:assertTrue(image.hasKey("SKU"));
    test:assertFalse(image.hasKey("orderId"));
    test:assertFalse(image.hasKey("CustomerName"));
    test:assertFalse(image.hasKey("sKU"));

    map<AttributeValue> nested = check image.get("Nested").m.ensureType();
    test:assertTrue(nested.hasKey("InnerKey"));
    test:assertEquals(nested.get("InnerKey").n, "7");
    test:assertEquals(nested.get("BOOL").s, "an attribute literally named BOOL");
}

@test:Config {
    groups: ["dataBinding"]
}
isolated function testTimeToLiveDeletionIdentityBinding() returns error? {
    Record 'record = check jsondata:parseAsType(<json>{
        "eventID": "1",
        "eventName": "REMOVE",
        "eventSource": "aws:dynamodb",
        "userIdentity": {"PrincipalId": "dynamodb.amazonaws.com", "Type": "Service"}
    });
    test:assertEquals('record.eventName, REMOVE);
    Identity identity = check 'record.userIdentity.ensureType();
    test:assertEquals(identity.principalId, "dynamodb.amazonaws.com");
    test:assertEquals(identity.'type, "Service");
}
