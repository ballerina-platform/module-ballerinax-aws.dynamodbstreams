# Real-time Order Processing

This use case shows how the AWS DynamoDB Streams API can be used to react to changes in an `Orders` table as they
happen, instead of polling the table itself. Every insert, update, and delete produces one stream record, which the
example dispatches on: a new order reports its status, an update compares the before and after images, and a removal
distinguishes a genuine delete from a time-to-live expiry.

It uses `pollRecords` to tail each shard, which is the convenience form of the `getRecords` loop for consumers that do
not need to checkpoint.

## Prerequisites

### 1. Setup AWS account

Refer to the [Setup guide](https://github.com/ballerina-platform/module-ballerinax-aws.dynamodbstreams/blob/main/README.md#setup-guide)
to obtain the necessary credentials (access key ID, secret access key, region) and to enable a stream on the table.

This example expects an `Orders` table whose partition key is `OrderId` (String) and which carries a `Status`
attribute, with a stream enabled using the `NEW_AND_OLD_IMAGES` view type so that each record carries both images.

### 2. Configuration

Create a `Config.toml` file in the example's root directory and provide your AWS account related configurations as
follows:

```toml
accessKeyId = "<access-key-id>"
secretAccessKey = "<secret-access-key>"
region = "<region>"
tableName = "Orders"
```

## Run the example

Execute the following command to run the example:

```bash
bal run
```

While it runs, add or update items in the `Orders` table and the changes are printed as their stream records arrive.

> **Note:** `pollRecords` completes when a shard is closed and fully read — it does not follow the child shards that
> replace it. Shards close routinely as the table repartitions, so a long-running consumer should re-`describeStream`
> and pick up the children. To survive restarts without re-reading records, persist each record's `sequenceNumber` and
> resume with an `AFTER_SEQUENCE_NUMBER` iterator — see the [shard checkpointing](../shard-checkpointing) example.
