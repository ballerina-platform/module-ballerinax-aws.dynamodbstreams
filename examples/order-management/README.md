# Real-time order processing

## Overview

Order state changes — a new order arriving, a status moving from `PENDING` to `SHIPPED`, an abandoned cart expiring — are exactly the kind of event a downstream system needs to react to promptly. Rather than polling the table itself, this example reads the table's DynamoDB stream, which delivers each item-level change once, in order, as it happens.

## Implementation

1. An `Orders` table with `OrderId` (String) as its partition key and a `Status` attribute, with a stream enabled using the `NEW_AND_OLD_IMAGES` view type so that each record carries both the before and after images.

2. `listStreams` finds the table's stream ARN, and `describeStream` lists the shards that make up the stream.

3. For each shard, `getShardIterator` with `TRIM_HORIZON` positions the reader at the oldest record still retained, and `pollRecords` tails the shard from there. It handles the two conditions a hand-written loop would have to distinguish: an **empty `records` array** means nothing new has arrived yet, so it backs off from 1 up to 5 seconds rather than spinning; an **absent `nextShardIterator`** means the shard is closed and fully read, which completes the stream. `maxIdlePolls` stops it after three quiet polls so that this example terminates.

4. Each record is dispatched on its `eventName`: an `INSERT` reports the new order's status, a `MODIFY` compares the old and new images, and a `REMOVE` distinguishes a genuine delete from a time-to-live expiry by checking whether the DynamoDB service itself was the acting principal.

Two limits worth knowing before building on this. `pollRecords` **completes at the shard boundary** — it does not follow the child shards a closed shard is replaced by, so a long-running consumer has to re-`describeStream` and pick them up. And to survive restarts without re-reading records, persist each record's `sequenceNumber` and resume with an `AFTER_SEQUENCE_NUMBER` iterator — see the [checkpointed shard consumer](../shard-checkpointing) example.

## Run the example

1. Set the credentials, region, and table name:

    ```sh
    export AWS_ACCESS_KEY_ID="<AWS_ACCESS_KEY_ID>"
    export AWS_SECRET_ACCESS_KEY="<AWS_SECRET_ACCESS_KEY>"
    export AWS_REGION="us-east-1"
    export ORDERS_TABLE_NAME="Orders"
    ```

2. Run the example:

    ```sh
    cd examples/order-management
    bal run
    ```

While it runs, add or update items in the `Orders` table and the changes are printed as their stream records arrive.
