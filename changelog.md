# Change Log
This file contains all the notable changes done to the Ballerina AWS DynamoDB Streams package through the releases.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

This release revamps the connector's authentication and region configuration to use the shared
[`ballerinax/aws`](https://github.com/ballerina-platform/module-ballerinax-aws) package, so that all AWS
connectors share a single, consistent credential model. It also corrects the change-data record shapes,
which previously made stream records unusable as typed data.
([Revamp Connector Authentication Flow](https://github.com/wso2-enterprise/integration-engineering/issues/2105))

It contains breaking changes. See the "Migrating from 1.x" section below.

### Changed

- **[Breaking]** Credentials are now supplied through a single `ConnectionConfig.auth` field of type
  `auth:AuthConfig`, sourced from `ballerinax/aws.auth` instead of being defined locally by this package.
  In 1.x, credentials were passed as `awsCredentials`, which accepted static keys only. Every 1.x
  credential source remains supported, with six new ones added.
- **[Breaking]** `ConnectionConfig` no longer includes `ballerinax/client.config:ConnectionConfig`. The
  HTTP configuration fields are now declared directly on the record, which additionally makes
  `socketConfig`, `validation` and `laxDataBinding` available.
- **[Breaking]** The `ConnectionConfig.region` field type changed from `string` to `aws:Region|string`.
  This is a widening — plain region strings continue to work, so regions that are not yet present in the
  `aws:Region` enum can still be supplied directly.
- **[Breaking]** `getRecords` now returns `GetRecordsOutput` instead of `stream<Record, error?>`. The
  response carries both the records and the `nextShardIterator`, which 1.x discarded; surfacing it is what
  allows a consumer to continue reading a shard from a known position. The stream-returning form is
  available as `pollRecords`.
- **[Breaking]** `getShardIterator` now returns the shard iterator `string` directly, rather than a
  single-field `GetShardsIteratorOutput` record.
- **[Breaking]** `GetShardsIteratorInput` is renamed `GetShardIteratorInput`, matching the name of the
  `GetShardIterator` operation. Its `shardIteratorType` field is now typed `ShardIteratorType` rather than
  `string`, so an invalid iterator type is a compile-time error.
- **[Breaking]** `StreamRecord.keys`, `.newImage` and `.oldImage` are now typed `map<AttributeValue>`,
  keyed by attribute name, matching the API. In 1.x they were typed as a single `AttributeValue`, so item
  data landed in the open record's rest fields and could not be read as typed data.
- **[Breaking]** `StreamRecord.sizeBytes` is now typed `int`, matching the API's Long. It was `float`.
- **[Breaking]** The fields of `AttributeValue` are now optional and non-nilable (`string s?`). They were
  both optional and nilable (`string? s?`).
- **[Breaking]** The `eventName` enum is renamed `OperationType`, following Ballerina naming conventions.
  The field on `Record` is still called `eventName`.
- **[Breaking]** `listStreams` now returns `stream<Stream, Error?>` rather than
  `stream<Stream, error?>|error`, and its `request` parameter defaults to `{}`. The first page is fetched
  on the first iteration rather than eagerly, so callers no longer need `check` on the call itself.
- **[Breaking]** Operations now return the module's own `Error` type instead of the generic `error`.
- Temporary credentials (STS assume-role, SSO, container and instance profiles) are now refreshed
  transparently by the credential provider, instead of the connector holding a single set of keys
  resolved at initialization time.
- The package now requires Ballerina distribution `2201.12.0` (was `2201.11.0`).

### Removed

- **[Breaking]** The `ConnectionConfig.awsCredentials` field, and the `AwsCredentials` and
  `AwsTemporaryCredentials` records it accepted, have been removed in favour of `ConnectionConfig.auth`.
- **[Breaking]** The `GetShardsIteratorOutput` record has been removed; `getShardIterator` returns the
  iterator `string` directly.

### Added

- Support for six additional AWS credential sources, available through `auth:AuthConfig`:
  - `auth:ProfileAuthConfig` — credentials read from a named profile in the shared credentials file.
  - `auth:AssumeRoleConfig` — temporary credentials obtained by assuming an IAM role via AWS STS.
  - `auth:WebIdentityConfig` — web identity (OIDC) federation, including IAM Roles for Service Accounts (IRSA).
  - `auth:SsoAuthConfig` — AWS IAM Identity Center (SSO).
  - `auth:ProcessAuthConfig` — credentials sourced from an external credential process.
  - `auth:DEFAULT_CREDENTIALS` — the AWS default credential provider chain.
- A new optional `ConnectionConfig.endpoint` field of type `aws:EndpointConfig`, for selecting FIPS or
  dualstack endpoint variants and for overriding the endpoint entirely (for example, LocalStack or VPC
  interface endpoints).
- A `Client.close()` method that releases the resources held by the credential provider (background
  refresh threads and any HTTP connections opened for STS/SSO). It is a normal method rather than a
  remote method, since closing the client does not send a request to DynamoDB Streams.
- A `pollRecords` operation, which polls a single shard and emits its records as a Ballerina stream. It is
  the `getRecords` loop written for the caller, with exponential backoff between empty polls and an
  optional `maxIdlePolls` bound. Like the 1.x `getRecords` stream, it completes when the shard is closed
  and fully read, and does not follow the child shards.
- The `GetRecordsOutput` and `PollRecordsInput` records, and the `OperationType` enum.
- A `RequestGenerationError` and a `ResponseHandlingError`, distinct subtypes of `Error`, which mark the
  failures that occur either side of the service call: credentials that cannot be resolved or a request
  that cannot be signed, and a response that cannot be read or bound.

### Fixed

- Item attribute names are no longer corrupted. 1.x applied a blanket first-letter case conversion to every
  key of every request and response, including the user-defined attribute names inside `Keys`, `NewImage`,
  `OldImage` and nested maps — so an attribute named `ForumName` was returned as `forumName`. Wire names are
  now declared per field, and attribute names pass through verbatim.
- A valid empty page from `ListStreams` no longer causes an index-out-of-range panic. The response may be
  empty while still carrying a continuation token, which 1.x indexed into unconditionally.
- Polling a shard with no new records no longer recurses without bound. 1.x refetched immediately and
  recursively on an empty response, so a live shard with no writes — the normal case with the `LATEST`
  iterator type — busy-polled the service with no backoff and grew the stack. `pollRecords` iterates, backs
  off exponentially, and can be bounded with `maxIdlePolls`.
- Requests are now sent with the `application/x-amz-json-1.0` content type. 1.x sent `application/json`,
  which is not the protocol DynamoDB Streams speaks.
- Service failures are now reported with their status code, request id and response body, rather than
  surfacing as a raw `http:ClientError` whose message was only the HTTP reason phrase.

### Migrating from 1.x

Add an `import ballerinax/aws;` alongside the existing DynamoDB Streams import, and move the credential
fields under `auth`:

```ballerina
// 1.x
import ballerinax/aws.dynamodbstreams;

dynamodbstreams:ConnectionConfig config = {
    awsCredentials: {accessKeyId, secretAccessKey},
    region: "us-east-1"
};
```

```ballerina
// 2.0.0
import ballerinax/aws;
import ballerinax/aws.dynamodbstreams;

dynamodbstreams:ConnectionConfig config = {
    auth: {accessKeyId, secretAccessKey},
    region: aws:US_EAST_1
};
```

Temporary credentials move from `securityToken` to `sessionToken` inside `auth`:

```ballerina
// 1.x
dynamodbstreams:ConnectionConfig config = {
    awsCredentials: {accessKeyId, secretAccessKey, securityToken},
    region: "us-east-1"
};
```

```ballerina
// 2.0.0
dynamodbstreams:ConnectionConfig config = {
    auth: {accessKeyId, secretAccessKey, sessionToken},
    region: aws:US_EAST_1
};
```

Deployments that should resolve credentials from the environment rather than from hardcoded keys can now
use the default credential provider chain:

```ballerina
// 2.0.0
import ballerinax/aws;
import ballerinax/aws.auth;

dynamodbstreams:ConnectionConfig config = {
    auth: auth:DEFAULT_CREDENTIALS,
    region: aws:US_EAST_1
};
```

`getShardIterator` returns the iterator directly, and its input record is renamed:

```ballerina
// 1.x
dynamodbstreams:GetShardsIteratorOutput output = check dynamodbStreams->getShardIterator({
    streamArn,
    shardId,
    shardIteratorType: dynamodbstreams:TRIM_HORIZON
});
string shardIterator = output.shardIterator;
```

```ballerina
// 2.0.0
string shardIterator = check dynamodbStreams->getShardIterator({
    streamArn,
    shardId,
    shardIteratorType: dynamodbstreams:TRIM_HORIZON
});
```

Code that iterated the `getRecords` stream can move to `pollRecords` unchanged in shape:

```ballerina
// 1.x
stream<dynamodbstreams:Record, error?> records = check dynamodbStreams->getRecords({shardIterator});
check records.forEach(function(dynamodbstreams:Record 'record) {
    io:println('record.eventName);
});
```

```ballerina
// 2.0.0
stream<dynamodbstreams:Record, dynamodbstreams:Error?> records =
    dynamodbStreams->pollRecords({shardIterator});
check from dynamodbstreams:Record 'record in records
    do {
        io:println('record.eventName);
    };
```

Consumers that need to record their position in a shard should call `getRecords` and drive the loop
themselves, which 1.x did not allow. Persist each record's `sequenceNumber` and resume with an
`AFTER_SEQUENCE_NUMBER` iterator — a sequence number stays valid for the stream's whole 24-hour retention
window, whereas a shard iterator expires after 15 minutes:

```ballerina
// 2.0.0
string? shardIterator = check dynamodbStreams->getShardIterator({
    streamArn,
    shardId,
    shardIteratorType: dynamodbstreams:AFTER_SEQUENCE_NUMBER,
    sequenceNumber: savedSequenceNumber
});
while shardIterator is string {
    dynamodbstreams:GetRecordsOutput result = check dynamodbStreams->getRecords({shardIterator});
    foreach dynamodbstreams:Record 'record in result.records {
        dynamodbstreams:StreamRecord streamRecord = check 'record.dynamodb.ensureType();
        check saveCheckpoint(streamRecord.sequenceNumber);
    }
    shardIterator = result.nextShardIterator;
}
```

Item images and keys are now attribute-name keyed maps, so change data can be read as typed values:

```ballerina
// 1.x — `keys` was a single `AttributeValue`, so item data was only reachable
// through the open record's rest fields
dynamodbstreams:AttributeValue keys = <dynamodbstreams:AttributeValue>streamRecord.keys;
```

```ballerina
// 2.0.0
map<dynamodbstreams:AttributeValue> keys = check streamRecord.keys.ensureType();
string? orderId = keys["OrderId"]?.s;
```

## [1.1.0] - 2025-01-31

### Changed
- Migrated to Java 21.

## [1.0.0] - 2024-05-21

### Added
- Initial release of the AWS DynamoDB Streams connector.
