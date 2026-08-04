# Specification: Ballerina DynamoDB Streams Library

_Authors_: @bhashinee  
_Reviewers_: @daneshk  
_Created_: 2023/11/09  
_Updated_: 2026/08/04  
_Edition_: Swan Lake  

## Introduction

This is the specification for the DynamoDB Streams connector of [Ballerina language](https://ballerina.io/), which allows you to access the Amazon DynamoDB Streams API.

The DynamoDB Streams connector specification has evolved and may continue to evolve in the future. The released versions of the specification can be found under the relevant GitHub tag.

If you have any feedback or suggestions about the library, start a discussion via a [GitHub issue](https://github.com/ballerina-platform/ballerina-library/issues) or in the [Discord server](https://discord.gg/ballerinalang). Based on the outcome of the discussion, the specification and implementation can be updated. Community feedback is always welcome. Any accepted proposal, which affects the specification is stored under `/docs/proposals`. Proposals under discussion can be found with the label `type/proposal` in GitHub.

The conforming implementation of the specification is released and included in the distribution. Any deviation from the specification is considered a bug.

## Contents

1. [Overview](#1-overview)
2. [Client](#2-client)
    1. [Client configurations](#21-client-configurations)
    2. [Initialization](#22-initialization)
    3. [APIs](#23-apis)
        1. [listStreams](#231-liststreams)
        2. [describeStream](#232-describestream)
        3. [getShardIterator](#233-getsharditerator)
        4. [getRecords](#234-getrecords)
        5. [pollRecords](#235-pollrecords)
    4. [Closing the client](#24-closing-the-client)
3. [Change data](#3-change-data)
4. [Errors](#4-errors)
5. [Migrating from 1.x](#5-migrating-from-1x)

## 1. Overview

The Ballerina `aws.dynamodbstreams` library facilitates APIs to access the Amazon DynamoDB Streams API.

DynamoDB Streams is a feature of Amazon DynamoDB that captures a time-ordered sequence of item-level modifications made to a table and retains them for 24 hours. Each modification produces one *stream record*. Records are distributed across *shards*, and a consumer reads a shard by obtaining a *shard iterator* — a cursor into the shard — and advancing it.

The library covers all four operations of the DynamoDB Streams API: `ListStreams`, `DescribeStream`, `GetShardIterator`, and `GetRecords`, and maps one remote method to each. It adds one convenience on top, `pollRecords`, which wraps the `getRecords` loop for consumers that only want to tail a shard; `getRecords` remains the operation to use when the shard position has to be checkpointed.

Transport, request signing, credential resolution, and endpoint resolution are delegated to the shared [`ballerinax/aws`](https://central.ballerina.io/ballerinax/aws/latest) package: requests are signed with AWS Signature Version 4 by `aws.auth`, credentials are resolved (and expiring temporary credentials refreshed) by `auth:CredentialProvider`, and the endpoint URL is resolved from the AWS SDK's endpoint metadata by `aws:resolveEndpoint`.

## 2. Client

`dynamodbstreams:Client` is used to access the Amazon DynamoDB Streams API.

### 2.1 Client configurations

```ballerina
public type ConnectionConfig record {|
    # Authentication configuration: any standard credential source supported by AWS
    auth:AuthConfig auth;
    # AWS region: an `aws:Region` enum member or a plain region string
    aws:Region|string region;
    # Optional endpoint options: FIPS/dualstack variants, or a custom endpoint override
    aws:EndpointConfig endpoint?;
    # ... standard `ballerina/http` client configurations
|};
```

`auth` accepts any member of `auth:AuthConfig`, which covers every standard AWS credential source:

| Configuration | Credential source |
|---|---|
| `auth:StaticAuthConfig` | Explicit access key/secret, optionally with a session token |
| `auth:ProfileAuthConfig` | A named profile in a local AWS credentials file |
| `auth:AssumeRoleConfig` | Temporary credentials from an STS `AssumeRole` call |
| `auth:WebIdentityConfig` | Temporary credentials from an STS `AssumeRoleWithWebIdentity` call (OIDC) |
| `auth:SsoAuthConfig` | An AWS IAM Identity Center (SSO) session |
| `auth:ProcessAuthConfig` | An external process implementing the AWS `credential_process` contract |
| `auth:DEFAULT_CREDENTIALS` | The AWS default credential provider chain |

Temporary credentials obtained from STS, SSO, a container credential endpoint, or an instance profile are cached and refreshed automatically before they expire; a long-running consumer therefore does not need to re-create its client.

`region` accepts an `aws:Region` enum member, or a plain string for regions newer than the enum.

`endpoint` selects a non-default endpoint: `fips` and `dualstack` choose the corresponding endpoint variant, and `customEndpoint` overrides the resolved URL entirely (for a VPC interface endpoint, or a local LocalStack instance).

### 2.2 Initialization

A client is initialized with a credential source and a region.

```ballerina
Client dynamodbStreams = check new ({
    auth: {accessKeyId: "ACCESS_KEY_ID", secretAccessKey: "SECRET_ACCESS_KEY"},
    region: aws:AP_SOUTH_1
});
```

### 2.3 APIs

#### 2.3.1 listStreams

Lists the streams associated with the account and endpoint, or — when `tableName` is given — only the streams of that table. The returned Ballerina stream pages through the result set automatically using the service's `LastEvaluatedStreamArn`, and completes once the final page has been consumed. A page that is empty but still carries a continuation token is a valid intermediate response and does not end the walk.

```ballerina
remote isolated function listStreams(ListStreamsInput request = {}) returns stream<Stream, Error?>;
```

#### 2.3.2 describeStream

Returns information about a stream, including its current status, ARN, the composition of its shards, and its corresponding DynamoDB table. A stream can hold more shards than fit in one response; when `lastEvaluatedShardId` is set on the result, pass it back as `exclusiveStartShardId` to read the next page of shards.

```ballerina
remote isolated function describeStream(DescribeStreamInput request) returns StreamDescription|Error;
```

#### 2.3.3 getShardIterator

Returns a shard iterator, which describes a position within a shard. `shardIteratorType` selects the position: `TRIM_HORIZON` (the oldest retained record), `LATEST` (just after the most recent record), or `AT_SEQUENCE_NUMBER`/`AFTER_SEQUENCE_NUMBER` together with a `sequenceNumber`. Shard iterators expire 15 minutes after they are returned.

```ballerina
remote isolated function getShardIterator(GetShardIteratorInput request) returns string|Error;
```

#### 2.3.4 getRecords

Retrieves the stream records currently available at the shard iterator's position — at most `limit` of them and never more than 1000 — and surfaces the position to continue from.

`nextShardIterator` is the position to continue from: pass it as the `shardIterator` of the next call to keep reading. Two response shapes are significant and distinct:

- `records` empty, `nextShardIterator` present: the shard has no new records right now but remains open. This is the normal state of a shard being tailed and does not mean the shard is exhausted.
- `nextShardIterator` absent: the shard has been closed and fully read. The consumer should move on to its child shards.

```ballerina
remote isolated function getRecords(GetRecordsInput request) returns GetRecordsOutput|Error;
```

To checkpoint across restarts, persist the `sequenceNumber` of the last record handled rather than the iterator, and
resume with an `AFTER_SEQUENCE_NUMBER` shard iterator: iterators expire 15 minutes after they are issued, whereas a
sequence number stays valid for the stream's whole 24-hour retention window.

#### 2.3.5 pollRecords

Polls a single shard and emits its records as a Ballerina stream — the `getRecords` loop written for you, for
consumers that do not need to checkpoint. Consecutive empty polls back off exponentially from `pollInterval` up to
`maxPollInterval`, and the interval resets as soon as records arrive, so tailing a quiet shard does not spin against
the service. Setting `maxIdlePolls` bounds the wait, completing the stream after that many consecutive empty polls.

This is the one method that is not a DynamoDB Streams operation; it is a convenience over `GetRecords`.

**It stops at the shard boundary.** The stream completes once the shard is closed and fully read, which looks to the
caller exactly like "no more records". Shards close routinely as the table repartitions, so a long-running consumer
must re-`describeStream` and move on to the child shards rather than treating completion as the end of the data.

**It can still be checkpointed.** The intermediate shard iterators are not surfaced, but every record carries its
`sequenceNumber`, and a saved sequence number is resumed with an `AFTER_SEQUENCE_NUMBER` shard iterator:

```ballerina
check from Record 'record in dynamodbStreams->pollRecords({shardIterator})
    do {
        StreamRecord streamRecord = check 'record.dynamodb.ensureType();
        check saveCheckpoint(shardId, streamRecord.sequenceNumber);
    };

// ... and on the next run
string resumed = check dynamodbStreams->getShardIterator({
    streamArn,
    shardId,
    shardIteratorType: AFTER_SEQUENCE_NUMBER,
    sequenceNumber: savedSequenceNumber
});
```

A sequence number is in fact the more durable of the two checkpoints: it stays valid for the stream's whole 24-hour
retention window, whereas a shard iterator expires after 15 minutes. Use `getRecords` instead to control the reads
directly — committing once per batch of records rather than per record, or deciding when to stop.

```ballerina
remote isolated function pollRecords(PollRecordsInput request) returns stream<Record, Error?>;
```

### 2.4 Closing the client

Releases the resources held by the client: the credential provider's background refresh threads and the HTTP connections it uses to reach STS/SSO. It is not a remote method, since it interacts with no remote system — nothing is sent to DynamoDB Streams.

```ballerina
public isolated function close() returns Error?;
```

## 3. Change data

A `Record` describes one item-level modification. Its `eventName` is an `OperationType` (`INSERT`, `MODIFY`, or `REMOVE`), and its `dynamodb` field holds the `StreamRecord` carrying the item data.

Within a `StreamRecord`, `keys`, `newImage`, and `oldImage` are `map<AttributeValue>` — keyed by **attribute name**, mirroring the DynamoDB wire format:

```ballerina
StreamRecord streamRecord = check 'record.dynamodb.ensureType();
map<AttributeValue> newImage = check streamRecord.newImage.ensureType();
string? status = newImage["Status"]?.s;
```

`newImage` and `oldImage` are present only when the stream's view type includes them (see `StreamViewType`). Which images a stream carries is fixed when the stream is enabled on the table and cannot be changed per request.

An `AttributeValue` sets exactly one field, naming the DynamoDB type of the value: `s` (String), `n` (Number, carried as a string to preserve precision), `b` (Binary, base64-encoded), `bool`, `null`, `ss`/`ns`/`bs` (the corresponding sets), `l` (List), and `m` (Map, again keyed by attribute name).

Attribute names are user data and are never case-converted, so an item attribute called `customerName` stays `customerName` and one called `OrderId` stays `OrderId`.

Every record also carries its `sequenceNumber`, which is what a consumer should persist as its checkpoint —
`AT_SEQUENCE_NUMBER`/`AFTER_SEQUENCE_NUMBER` resume from it, and unlike a shard iterator it does not expire after
15 minutes.

Records are delivered **at least once**, so a consumer's handling of them must be idempotent. Ordering is guaranteed per shard, and — since a given primary key maps to one shard — per item.

## 4. Errors

Every operation returns `dynamodbstreams:Error`, the module's generic error type. Two distinct subtypes mark the
failures that happen either side of the call, so a caller can tell them apart from a failure the service reported:

```ballerina
public type Error distinct error;

public type RequestGenerationError distinct Error;
public type ResponseHandlingError distinct Error;
```

| Error | Raised when |
|---|---|
| `RequestGenerationError` | The credentials cannot be resolved, or the request cannot be signed — nothing was sent |
| `ResponseHandlingError` | The response payload cannot be read, or does not match the expected shape |
| `Error` | The service reported a failure, or the endpoint could not be reached |

When the service reports a failure, the message names the status code and the detail carries three fields:

| Detail field | Value |
|---|---|
| `httpStatusCode` | The HTTP status of the response |
| `requestId` | The `x-amzn-RequestId` header, or `""` when absent — quote it when raising an AWS support ticket |
| `errorResponse` | The service's error response as it is, or `()` when the body was not JSON |

DynamoDB Streams speaks the AWS JSON 1.0 protocol, so `errorResponse` names the exception in a `__type` field of the
form `<namespace>#<ExceptionName>` and carries the service's own wording in `message`:

```ballerina
GetRecordsOutput|Error result = dynamodbStreams->getRecords({shardIterator});
if result is Error {
    // message() -> "The DynamoDB Streams operation failed with status 400"
    json errorResponse = check result.detail()["errorResponse"].ensureType();
    // {"__type": "com.amazonaws.dynamodb.v20120810#ExpiredIteratorException",
    //  "message": "The shard iterator has expired"}
    if errorResponse.toJsonString().includes("ExpiredIteratorException") {
        // The iterator is older than 15 minutes; re-open the shard.
    }
}
```

For failures that happen before a response is received — an unresolvable credential source, an unsignable request,
an unreachable endpoint — the message names the step that failed, the underlying failure is the error's `cause`, and
the detail is empty.

The two service exceptions a stream consumer is expected to handle are `ExpiredIteratorException` (a shard iterator
older than 15 minutes; re-open the shard) and `TrimmedDataAccessException` (the requested position has aged past the
24-hour retention window; restart from `TRIM_HORIZON`).

## 5. Migrating from 1.x

Version 2.0.0 moves credential handling, request signing, and endpoint resolution onto the shared `ballerinax/aws` package, and corrects the change-data record shapes. Both are breaking.

**Configuration.** `awsCredentials` is replaced by `auth`, which accepts every standard AWS credential source rather than static keys alone, and `region` accepts the `aws:Region` enum alongside a plain string. A new optional `endpoint` field selects FIPS/dualstack variants or a custom endpoint.

```ballerina
// 1.x
ConnectionConfig config = {
    awsCredentials: {accessKeyId: "ACCESS_KEY_ID", secretAccessKey: "SECRET_ACCESS_KEY"},
    region: "ap-south-1"
};

// 2.x
ConnectionConfig config = {
    auth: {accessKeyId: "ACCESS_KEY_ID", secretAccessKey: "SECRET_ACCESS_KEY"},
    region: aws:AP_SOUTH_1
};
```

**Operations.**

| 1.x | 2.x |
|---|---|
| `getRecords(GetRecordsInput)` returned `stream<Record, error?>`, discarding every shard iterator | `getRecords(GetRecordsInput)` returns `GetRecordsOutput`, surfacing `nextShardIterator`, which is what makes checkpointing possible. The stream-returning form moved to `pollRecords`, now with backoff and an optional idle bound |
| `getShardIterator` returned `GetShardsIteratorOutput` | `getShardIterator` returns the iterator `string` directly |
| `GetShardsIteratorInput` | `GetShardIteratorInput` (the operation is `GetShardIterator`) |
| `shardIteratorType` was typed `string` | `shardIteratorType` is typed `ShardIteratorType` |
| `listStreams` returned `stream<Stream, error?>\|error`, fetching the first page eagerly | returns `stream<Stream, Error?>`; the first page is fetched on the first iteration, so drop the `check` |
| `listStreams` required a request argument | `request` defaults to `{}` |
| — | `close()` releases the credential provider (a normal method, not remote) |

**Change data.**

| 1.x | 2.x |
|---|---|
| `StreamRecord.keys`, `.newImage`, `.oldImage` were typed `AttributeValue`, so item data landed in the open-record rest fields | typed `map<AttributeValue>`, keyed by attribute name |
| `StreamRecord.sizeBytes` was typed `float` | typed `int`, matching the API's Long |
| Response keys were case-converted in bulk, which rewrote item attribute names | attribute names are preserved verbatim |
| `AttributeValue` fields were nilable (`string? s?`) | fields are optional and non-nilable (`string s?`) |
| enum `eventName` | enum `OperationType` |

**Errors.** Failures were raised as untyped `error` values, with a service failure surfacing as a raw `http:ClientError` whose message was just the HTTP reason phrase and whose error body sat unparsed in the `http` module's own detail record. They are now `dynamodbstreams:Error` — with `RequestGenerationError` and `ResponseHandlingError` marking the failures either side of the call — and a service failure carries `httpStatusCode`, `requestId`, and the service's `errorResponse` in the error detail.
