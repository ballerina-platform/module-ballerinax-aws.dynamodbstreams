# Real-time Order Processing

## Overview

Consider a scenario you want to do real-time order processing. You can simply do this by using DynamoDB streams. In the context of DynamoDB Streams, you can use DynamoDB Streams to capture changes to your order data and react to those changes in near real-time. This example demonstrates how the basic operations of real-time order processing actions can be done using Ballerina DynamoDB streams API.

## Implementation

1. Assume you have a DynamoDB table named 'Orders' with the following schema:
   a. Partition key: OrderId (String)

2. You can log into the AWS account and enable the streams.

3. Polling to get the new orders and order updates.

In this example, we'll use a basic long-polling approach to continuously check the DynamoDB Stream for new records. You can use the `getRecords` API for this. 

## Run the Example

First, clone this repository, and then run the following commands to run this example in your local machine.

```sh
// Run the dynamoDB client
$ cd examples/game/client
$ bal run
```
