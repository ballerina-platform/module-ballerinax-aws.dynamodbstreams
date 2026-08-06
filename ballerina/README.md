## Overview

[Amazon DynamoDB Streams](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/Streams.html) captures a time-ordered sequence of item-level modifications made to an [Amazon DynamoDB](https://aws.amazon.com/dynamodb/) table and stores them for up to 24 hours, so applications can react to data changes in near real time. Each modification produces one stream record, and the records of a stream are distributed across shards that a consumer reads through shard iterators.

The Amazon DynamoDB Streams connector offers APIs to connect and interact with the [AWS DynamoDB Streams API](https://docs.aws.amazon.com/amazondynamodb/latest/APIReference/API_Operations_Amazon_DynamoDB_Streams.html) endpoints.

### Key features

- Complete coverage of the DynamoDB Streams API: `ListStreams`, `DescribeStream`, `GetShardIterator`, and `GetRecords`
- Checkpointable shard reads — `getRecords` surfaces the next shard iterator, and every record carries its sequence number, so a restarted consumer can resume exactly where it stopped
- One remote method per AWS operation, plus `pollRecords` to tail a shard and an auto-paginating Ballerina stream for `listStreams`
- Typed change data: item images and keys are attribute-name keyed maps of `AttributeValue`
- Flexible credential configuration: static keys, AWS credentials file profiles, STS assume-role, web identity (OIDC), IAM Identity Center (SSO), an external credential process, or the default AWS credential provider chain (EKS Pod Identity, ECS task roles, EC2 instance profiles, environment variables)
- Automatic refresh of expiring temporary credentials
- FIPS, dualstack, and custom endpoint support

## Setup guide

### Enable a stream on your DynamoDB table

A table only produces stream records once a stream is enabled on it. In the [DynamoDB console](https://console.aws.amazon.com/dynamodbv2), open your table, go to **Exports and streams** > **DynamoDB stream details** and choose **Turn on**. Pick the view type that carries the data your application needs:

| View type | What each record carries |
|---|---|
| `KEYS_ONLY` | Only the key attributes of the modified item |
| `NEW_IMAGE` | The whole item as it looked after the change |
| `OLD_IMAGE` | The whole item as it looked before the change |
| `NEW_AND_OLD_IMAGES` | Both images |

Take note of the resulting **Latest stream ARN** — it is the `streamArn` this connector operates on.

### Obtain IAM user credentials

To create an IAM user and generate an access key, follow the [obtaining IAM user credentials](https://central.ballerina.io/ballerinax/aws/latest#obtaining-iam-user-credentials) guide.

Attach the DynamoDB Streams permissions your application needs to the user. Reading a stream requires the four stream actions, which are separate from the table's data-plane actions:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "dynamodb:ListStreams",
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "dynamodb:DescribeStream",
                "dynamodb:GetShardIterator",
                "dynamodb:GetRecords"
            ],
            "Resource": "arn:aws:dynamodb:<REGION>:<ACCOUNT_ID>:table/<TABLE_NAME>/stream/*"
        }
    ]
}
```

> **Note:** `dynamodb:ListStreams` is in a statement of its own because it cannot be scoped to a stream ARN — AWS
> denies it when the resource is anything other than `*`. Omit that statement entirely if your application never
> calls `listStreams`.

## Quickstart

To use the `aws.dynamodbstreams` connector in your Ballerina project, modify the `.bal` file as follows:

### Step 1: Import the connector

Import the `ballerinax/aws.dynamodbstreams` package into your Ballerina project.

```ballerina
import ballerinax/aws;
import ballerinax/aws.dynamodbstreams;
```

### Step 2: Instantiate a new connector

The `dynamodbstreams:Client` accepts a `ConnectionConfig` with an `auth` field that supports every standard AWS credential source.

#### Option 1: Static credentials

Use explicit AWS credentials. Suitable for local development and environments where credentials are managed directly.

```ballerina
dynamodbstreams:Client dynamodbStreams = check new ({
    auth: {
        accessKeyId: "<AWS_ACCESS_KEY_ID>",
        secretAccessKey: "<AWS_SECRET_ACCESS_KEY>"
    },
    region: aws:US_EAST_1
});
```

#### Option 2: AWS credentials file profile

Use a named profile from your `~/.aws/credentials` file. Suitable for developer workstations with multiple AWS accounts.

```ballerina
dynamodbstreams:Client dynamodbStreams = check new ({
    auth: {
        profileName: "<PROFILE_NAME>",
        credentialsFilePath: "~/.aws/credentials"
    },
    region: aws:US_EAST_1
});
```

#### Option 3: Default credential provider chain

Use `auth:DEFAULT_CREDENTIALS` to let the connector resolve credentials from the environment. This is the recommended approach for AWS-managed environments, and the only supported one where long-term access keys are unavailable (EC2 instance roles, ECS task roles, EKS Pod Identity/IRSA).

```ballerina
import ballerinax/aws.auth;

dynamodbstreams:Client dynamodbStreams = check new ({
    auth: auth:DEFAULT_CREDENTIALS,
    region: aws:US_EAST_1
});
```

The standard default credential provider chain tries each of the following in order and takes the first source that yields credentials:

1. Environment variables (`AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY`, and `AWS_WEB_IDENTITY_TOKEN_FILE` if set)
2. The shared config/credentials file's active profile (`AWS_PROFILE`, or `default` if unset) — which may itself resolve via SSO, an external process, or a chained `AssumeRole` call, depending on that profile's configuration
3. Container credentials (ECS/EKS)
4. EC2 instance profile (IMDS)

### Step 3: Invoke the connector operation

Reading a stream is a three-step walk: describe the stream to find its shards, get an iterator for a shard, then read records from that position.

```ballerina
public function main() returns error? {
    string streamArn = "arn:aws:dynamodb:us-east-1:123456789012:table/Orders/stream/2026-01-01T00:00:00.000";

    dynamodbstreams:StreamDescription description = check dynamodbStreams->describeStream({streamArn});
    dynamodbstreams:Shard[] shards = check description.shards.ensureType();
    string shardId = check shards[0].shardId.ensureType();

    string shardIterator = check dynamodbStreams->getShardIterator({
        streamArn,
        shardId,
        shardIteratorType: dynamodbstreams:TRIM_HORIZON
    });

    dynamodbstreams:GetRecordsOutput result = check dynamodbStreams->getRecords({shardIterator});
    foreach dynamodbstreams:Record 'record in result.records {
        dynamodbstreams:StreamRecord streamRecord = check 'record.dynamodb.ensureType();
        io:println('record.eventName, " ", streamRecord.keys);
    }

    // Persist this to resume the shard later, from this process or another one.
    string? checkpoint = result.nextShardIterator;
}
```

### Step 4: Run the Ballerina application

Use the following command to compile and run the Ballerina program.

```bash
bal run
```

## Examples

The `aws.dynamodbstreams` connector provides practical examples illustrating usage in various scenarios. Explore these [examples](https://github.com/ballerina-platform/module-ballerinax-aws.dynamodbstreams/tree/main/examples).

1. [Real-time order processing](https://github.com/ballerina-platform/module-ballerinax-aws.dynamodbstreams/tree/main/examples/order-management)
   This example shows how to tail a DynamoDB stream with `pollRecords` to react to order changes as they happen.

2. [Checkpointed shard consumer](https://github.com/ballerina-platform/module-ballerinax-aws.dynamodbstreams/tree/main/examples/shard-checkpointing)
   This example shows how to read a stream with `getRecords`, persisting each record's sequence number so that a restarted consumer resumes where it stopped. It runs on the default credential provider chain, so it works unchanged on EC2, ECS, and EKS.
