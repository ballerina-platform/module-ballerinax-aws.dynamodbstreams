## Overview
The Ballerina AWS DynamoDB streams connector provides the capability to programatically handle [AWS DynamoDB streams](https://aws.amazon.com/dynamodb/) related operations.

This module supports [Amazon DynamoDB REST API 20120810](https://docs.aws.amazon.com/amazondynamodb/latest/APIReference/Welcome.html).

## Overview

The connector provides the capability to programatically handle AWS DynamoDB Streams related operations.

This module supports [Amazon DynamoDB REST API 20120810](https://docs.aws.amazon.com/amazondynamodb/latest/APIReference/Welcome.html).

## Setup guide

### Step 1: Create an AWS account
* If you don't already have an AWS account, you need to create one. Go to the [AWS Management Console](https://console.aws.amazon.com/console/home), click on "Create a new AWS Account," and follow the instructions.

### Step 2: Get the access key ID and the secret access key

Once you log in to your AWS account, you need to create a user group and a user with the necessary permissions to access DynamoDB. To do this, follow the steps below:

1. Create an AWS user group
* Navigate to the Identity and Access Management (IAM) service. Click on "Groups" and then "Create New Group."

<img src=https://raw.githubusercontent.com/ballerina-platform/module-ballerinax-aws.dynamodbstreams/main/ballerina/resources/create-group.png alt="Create user group" width="50%">

* Enter a group name and attach the necessary policies to the group. For example, you can attach the "AmazonDynamoDBFullAccess" policy to provide full access to DynamoDB.

<img src=https://raw.githubusercontent.com/ballerina-platform/module-ballerinax-aws.dynamodbstreams/main/ballerina/resources/create-group-policies.png alt="Attach policy" width="50%">

2. Create an IAM user

* In the IAM console, navigate to "Users" and click on "Add user."

<img src=https://raw.githubusercontent.com/ballerina-platform/module-ballerinax-aws.dynamodbstreams/main/ballerina/resources/create-user.png alt="Add user" width="50%">

* Enter a username, tick the "Provide user access to the AWS Management Console - optional" checkbox, and click "I want to create an IAM user". This will enable programmatic access through access keys.

<img src=https://raw.githubusercontent.com/ballerina-platform/module-ballerinax-aws.dynamodbstreams/main/ballerina/resources/create-group-policies.png alt="Create IAM user" width="50%">

* Click through the permissions setup, and add the user to the user group we previously created.

<img src=https://raw.githubusercontent.com/ballerina-platform/module-ballerinax-aws.dynamodbstreams/main/ballerina/resources/create-user-set-permission.png alt="Attach user group" width="50%">

* Review the details and click "Create user."

<img src=https://raw.githubusercontent.com/ballerina-platform/module-ballerinax-aws.dynamodbstreams/main/ballerina/resources/create-user-review.png alt="Review user" width="50%">

3. Generate access key ID and secret access key

* Once the user is created, you will see a success message. Navigate to the "Users" tab, and select the user you created.

<img src=https://raw.githubusercontent.com/ballerina-platform/module-ballerinax-aws.dynamodbstreams/main/ballerina/resources/view-user.png alt="View User" width="50%">

* Click on the "Create access key" button to generate the access key ID and secret access key.

<img src=https://raw.githubusercontent.com/ballerina-platform/module-ballerinax-aws.dynamodbstreams/main/ballerina/resources/create-access-key.png alt="Create access key" width="50%">

* Follow the steps and download the CSV file containing the credentials.

<img src=https://raw.githubusercontent.com/ballerina-platform/module-ballerinax-aws.dynamodbstreams/main/ballerina/resources/download-access-key.png alt="Download credentials" width="50%">

## Quickstart

To use the `dynamodbstreams` connector in your Ballerina application, modify the `.bal` file as follows:

### Step 1: Import the connector
Import the `ballerinax/aws.dynamodbstreams` package into your Ballerina project.
```ballerina
import ballerinax/aws.dynamodbstreams;
```

### Step 2: Instantiate a new connector
Create a `dynamodbstreams:ConnectionConfig` with the obtained access key ID and secret access key to initialize the connector with it.
```ballerina
dynamodbstreams:Client dynamoDb = check new({
    awsCredentials: {
        accessKeyId: "ACCESS_KEY_ID",
        secretAccessKey: "SECRET_ACCESS_KEY"
    },
    region: "REGION"
});
```

### Step 3: Invoke the connector operation
Now, utilize the available connector operations.

```ballerina
public function main() returns error? {
   dynamodbstreams:DescribeStreamInput describeStreamInput = {
      streamArn: "arn:aws:dynamodb:us-east-1:134633749276:table/TestStreamTable/stream/2024-01-04T04:43:13.919"
   };
   dynamodbstreams:StreamDescription response = check dynamoDb->describeStream(describeStreamInput);
}
```

### Step 4: Run the Ballerina application

Use the following command to compile and run the Ballerina program.

```bash
bal run
```

## Examples

The `dynamodbstreams` connector provides practical examples illustrating usage in various scenarios. Explore these [examples](https://github.com/ballerina-platform/module-ballerinax-aws.dynamodbstreams/tree/master/examples).

1. [Real-time order processing](https://github.com/ballerina-platform/module-ballerinax-aws.dynamodbstreams/tree/master/examples/order-management/client.bal)
   This example shows how to use DynamoDB Streams API to implement a real-time order processing system.
