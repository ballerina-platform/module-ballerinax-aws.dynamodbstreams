# Ballerina Amazon DynamoDB Streams Connector

[![Build](https://github.com/ballerina-platform/module-ballerinax-aws.dynamodbstreams/actions/workflows/ci.yml/badge.svg)](https://github.com/ballerina-platform/module-ballerinax-aws.dynamodbstreams/actions/workflows/ci.yml)
[![codecov](https://codecov.io/gh/ballerina-platform/module-ballerinax-aws.dynamodbstreams/branch/main/graph/badge.svg)](https://codecov.io/gh/ballerina-platform/module-ballerinax-aws.dynamodbstreams)
[![GitHub Last Commit](https://img.shields.io/github/last-commit/ballerina-platform/module-ballerinax-aws.dynamodbstreams.svg)](https://github.com/ballerina-platform/module-ballerinax-aws.dynamodbstreams/commits/main)
[![GitHub Issues](https://img.shields.io/github/issues/ballerina-platform/ballerina-library/module/aws.dynamodbstreams.svg?label=Open%20Issues)](https://github.com/ballerina-platform/ballerina-library/labels/module%2Faws.dynamodbstreams)


## Overview

The `ballerinax/aws.dynamodbstreams` package offers APIs to connect and interact with the [AWS DynamoDB Streams API](https://docs.aws.amazon.com/amazondynamodb/latest/APIReference/API_Operations_Amazon_DynamoDB_Streams.html) endpoints, covering all four of its operations: `ListStreams`, `DescribeStream`, `GetShardIterator`, and `GetRecords`.

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

Use `auth:DEFAULT_CREDENTIALS` in `aws.auth` module to let the connector resolve credentials from the environment. This is the recommended approach for AWS-managed environments, and the only supported one where long-term access keys are unavailable (EC2 instance roles, ECS task roles, EKS Pod Identity/IRSA).

```ballerina
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

> **Note:** Beyond the three options above, the `credentials` field also accepts `auth:AssumeRoleConfig` (STS assume-role), `auth:WebIdentityConfig` (web identity / OIDC), `auth:SsoAuthConfig` (IAM Identity Center), and `auth:ProcessAuthConfig` (external credential process). See the [`Ballerina AWS`](https://central.ballerina.io/ballerinax/aws/latest) documentation for details.

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

## Build from the source

### Prerequisites

1. Download and install Java SE Development Kit (JDK) version 21. You can download it from either of the following sources:

    * [Oracle JDK](https://www.oracle.com/java/technologies/downloads/)
    * [OpenJDK](https://adoptium.net/)

   > **Note:** After installation, remember to set the `JAVA_HOME` environment variable to the directory where JDK was installed.

2. Download and install [Ballerina Swan Lake](https://ballerina.io/).

3. Download and install [Docker](https://www.docker.com/get-started).

   > **Note**: Ensure that the Docker daemon is running before executing any tests.

### Build options

Execute the commands below to build from the source.

1. To build the package:
   ```bash
   ./gradlew clean build
   ```

2. To run the tests:
   ```bash
   ./gradlew clean test
   ```

3. To build the without the tests:
   ```bash
   ./gradlew clean build -x test
   ```

4. To debug package with a remote debugger:
   ```bash
   ./gradlew clean build -Pdebug=<port>
   ```

5. To debug with the Ballerina language:
   ```bash
   ./gradlew clean build -PbalJavaDebug=<port>
   ```

6. Publish the generated artifacts to the local Ballerina Central repository:
    ```bash
    ./gradlew clean build -PpublishToLocalCentral=true
    ```

7. Publish the generated artifacts to the Ballerina Central repository:
   ```bash
   ./gradlew clean build -PpublishToCentral=true
   ```

## Contribute to Ballerina

As an open-source project, Ballerina welcomes contributions from the community.

For more information, go to the [contribution guidelines](https://github.com/ballerina-platform/ballerina-lang/blob/master/CONTRIBUTING.md).

## Code of conduct

All the contributors are encouraged to read the [Ballerina Code of Conduct](https://ballerina.io/code-of-conduct).

## Useful links

* For more information go to the [`aws.dynamodbstreams` package](https://central.ballerina.io/ballerinax/aws.dynamodbstreams/latest).
* For example demonstrations of the usage, go to [Ballerina By Examples](https://ballerina.io/learn/by-example/).
* Chat live with us via our [Discord server](https://discord.gg/ballerinalang).
* Post all technical questions on Stack Overflow with the [#ballerina](https://stackoverflow.com/questions/tagged/ballerina) tag.
