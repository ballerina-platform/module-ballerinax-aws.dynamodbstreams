# Specification: Ballerina DynamoDB Streams Library

_Owners_: @bhashinee  
_Reviewers_: @daneshk  
_Created_: 2023/11/09  
_Updated_: 2022/11/10  
_Edition_: Swan Lake  

## Introduction

This is the specification for the DynamoDB streams connector of [Ballerina language](https://ballerina.io/), which allows you to access the Amazon DynamoDB REST API.

The DynamoDB streams connector specification has evolved and may continue to evolve in the future. The released versions of the specification can be found under the relevant GitHub tag.

If you have any feedback or suggestions about the library, start a discussion via a [GitHub issue](https://github.com/ballerina-platform/ballerina-standard-library/issues) or in the [Discord server](https://discord.gg/ballerinalang). Based on the outcome of the discussion, the specification and implementation can be updated. Community feedback is always welcome. Any accepted proposal, which affects the specification is stored under `/docs/proposals`. Proposals under discussion can be found with the label `type/proposal` in GitHub.

The conforming implementation of the specification is released and included in the distribution. Any deviation from the specification is considered a bug.

## Contents
1. [Overview](#1-overview)
2. [Client](#2-client)
    1. [Client Configurations](#21-client-configurations)
    2. [Initialization](#22-initialization)
    3. [APIs](#23-apis)
        1. [listStreams](#listStreams)
        2. [describeStream](#describeStream)
        3. [getShardIterator](#getShardIterator)
        4. [getRecords](#getRecords)
        
## 1. [Overview](#1-overview)

The Ballerina `dynamodbstreams` library facilitates APIs to allow you to access the Amazon DynamoDB REST API specifically to work with DynamoDB streams. 
DynamoDB Streams is a feature provided by Amazon DynamoDB, a fully managed NoSQL database service. DynamoDB Streams enables you to capture and track changes made to items in a DynamoDB table in real-time. It's a mechanism for creating a time-ordered sequence of item-level modifications within a table.

## 2. [Client](#2-client)

`dynamodbstreams:Client` can be used to access the Amazon DynamoDB Streams REST API. 

### 2.1. [Client Configurations](#21-client-configurations)

When initializing the client, following configurations can be provided,

```ballerina
public type ConnectionConfig record {|
    *config:ConnectionConfig;
    never auth?;
    # AWS credentials
    AwsCredentials|AwsTemporaryCredentials awsCredentials;
    # AWS Region
    string region;
|};
```

### 2.2. [Initialization](#22-initialization)

A client can be initialized by providing the AwsCredentials and optionally the other configurations in `ClientConfiguration`.

```ballerina
ConnectionConfig config = {
    awsCredentials: {accessKeyId: "ACCESS_KEY_ID", secretAccessKey: "SECRET_ACCESS_KEY"},
    region: "ap-south-1"
};

Client dynamoDBClient = check new (config);
```

### 2.3 [APIs](#23-apis)

#### [listStreams](#listStreams)

This API can be used to list streams in DynamoDB account.

```ballerina
# Returns an array of stream ARNs associated with the current account and endpoint. If the TableName parameter is present, then ListStreams will return only the streams ARNs for that table.
#
# + request - The required details to list the streams
# + return - If success, `stream<Stream, error?>` or else an error
remote isolated function listStreams(ListStreamsInput request) returns stream<Stream, error?>|error {
```

#### [describeStream](#describeStream)

This API can be used to get information about a stream.

```ballerina
# Returns information about a stream, including the current status of the stream, its Amazon Resource Name (ARN), the composition of its shards, and its corresponding DynamoDB table.
#
# + request - The required details to describe the stream
# + return - If success, dynamodb:StreamDescription record, else an error
remote isolated function describeStream(DescribeStreamInput request) returns StreamDescription|error {
```

#### [getShardIterator](#getShardIterator)

This API can be used to get a shard iterator.

```ballerina
# Returns a shard iterator. A shard iterator provides information about how to retrieve the stream records from within a shard. Use the shard iterator in a subsequent GetRecords request to read the stream records from the shard.
#
# + request - The required details to get the shard iterator
# + return - If success, ShardIterator, else an error
remote isolated function getShardIterator(GetShardsIteratorInput request) returns GetShardsIteratorOutput|error {
```

#### [getRecords](#getRecords)

This API can be used to get the stream records from a given shard.

```ballerina
# Retrieves the stream records from a given shard.
#
# + request - The required details to get the records from a shard
# + return - If success, ShardIterator, else an error
remote isolated function getRecords(GetRecordsInput request) returns stream<Record, error?>|error {
```
