# Checkpointed shard consumer

## Overview

A stream consumer that restarts must not replay the whole shard, nor silently skip records it never handled. The position to persist is each record's **`sequenceNumber`** — not the `nextShardIterator`. A shard iterator expires 15 minutes after it is issued, so a persisted one is almost always dead by the next run; a sequence number stays valid for the stream's whole 24-hour retention window and is resumed with an `AFTER_SEQUENCE_NUMBER` iterator. This example shows that loop, running on the default AWS credential provider chain so the same code works locally and on EC2, ECS, or EKS without any credential-handling changes.

## Implementation

1. The client is created with `auth:DEFAULT_CREDENTIALS`, so credentials come from the environment — environment variables or `~/.aws/credentials` locally, an instance profile on EC2, a task role on ECS, Pod Identity or IRSA on EKS. Temporary credentials from any of those sources are refreshed automatically before they expire.

2. `describeStream` lists the shards. For each shard, the consumer looks for a stored sequence number: if one exists, `getShardIterator` with `AFTER_SEQUENCE_NUMBER` resumes just past that record, otherwise `TRIM_HORIZON` starts from the oldest retained one.

3. `getRecords` reads a batch at a time. The sequence number of the batch's **last** record is committed *after* the whole batch has been processed, so a crash part-way through replays that batch rather than losing it. Stream records are delivered at least once, so downstream handling has to be idempotent either way.

4. Two terminal conditions are handled explicitly:
    - An absent `nextShardIterator` means the shard is closed and fully read; the checkpoint is discarded and the shard's children take over.
    - A `TrimmedDataAccessException` means the checkpointed record has aged past the 24-hour retention window, so there is nothing to resume from and the shard restarts from the trim horizon. This is the only position failure a sequence-number checkpoint can hit — it cannot go stale the way a shard iterator does.

Checkpoints are kept in `./checkpoints` here to keep the example self-contained; a production consumer would store them wherever it already keeps durable state.

## Run the example

1. Set the region and the stream ARN. No credentials are configured explicitly — the default chain finds them:

    ```sh
    export AWS_REGION="us-east-1"
    export STREAM_ARN="arn:aws:dynamodb:us-east-1:123456789012:table/Orders/stream/2026-01-01T00:00:00.000"
    ```

2. Run the example:

    ```sh
    cd examples/shard-checkpointing
    bal run
    ```

3. Write to the table, then run it again. The second run picks up only the records added since the first, which is the checkpoint doing its job.
