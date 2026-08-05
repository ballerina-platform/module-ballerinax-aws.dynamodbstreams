# Checkpointed Shard Consumer

This use case shows how the AWS DynamoDB Streams API can be used to build a stream consumer that survives restarts —
neither replaying a whole shard nor silently skipping records it never handled.

The position to persist is each record's **`sequenceNumber`**, not the `nextShardIterator`. A shard iterator expires 15
minutes after it is issued, so a persisted one is almost always dead by the next run; a sequence number stays valid for
the stream's whole 24-hour retention window and is resumed with an `AFTER_SEQUENCE_NUMBER` iterator. The example
commits the sequence number of a batch's last record only *after* the whole batch has been handled, so a crash
part-way through replays that batch rather than losing it.

It runs on the AWS default credential provider chain, so the same code works unchanged on a workstation, on EC2, on
ECS, and on EKS.

## Prerequisites

### 1. Setup AWS account

Refer to the [Setup guide](https://github.com/ballerina-platform/module-ballerinax-aws.dynamodbstreams/blob/main/README.md#setup-guide)
to obtain the necessary credentials and to enable a stream on the table. Note the resulting **Latest stream ARN** — it
is the `streamArn` this example reads.

Because the example uses `auth:DEFAULT_CREDENTIALS`, credentials come from the environment rather than from
`Config.toml`: environment variables or `~/.aws/credentials` locally, an instance profile on EC2, a task role on ECS,
or Pod Identity/IRSA on EKS.

### 2. Configuration

Create a `Config.toml` file in the example's root directory and provide the region and stream as follows:

```toml
region = "<region>"
streamArn = "<stream-arn>"
```

## Run the example

Execute the following command to run the example:

```bash
bal run
```

Write to the table, then run it again: the second run picks up only the records added since the first, which is the
checkpoint doing its job.

> **Note:** checkpoints are kept in `./checkpoints` to keep the example self-contained. A production consumer would
> store them wherever it already keeps durable state. A `TrimmedDataAccessException` means the checkpointed record has
> aged past the 24-hour retention window, so the shard restarts from the trim horizon — that is the only position
> failure a sequence-number checkpoint can hit.
