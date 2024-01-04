## Overview
The Ballerina AWS DynamoDB streams connector provides the capability to programatically handle [AWS DynamoDB streams](https://aws.amazon.com/dynamodb/) related operations.

This module supports [Amazon DynamoDB REST API 20120810](https://docs.aws.amazon.com/amazondynamodb/latest/APIReference/Welcome.html).
 
## Prerequisites
Before using this connector in your Ballerina application, complete the following:
1. Create an [AWS account](https://portal.aws.amazon.com/billing/signup?nc2=h_ct&src=default&redirect_url=https%3A%2F%2Faws.amazon.com%2Fregistration-confirmation#/start)
2. [Obtain tokens](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_access-keys.html)

## Quickstart
To use the AWS DynamoDB streams connector in your Ballerina application, update the .bal file as follows:

### Step 1: Import connector
Import the `ballerinax/aws.dynamodbstreams` module into the Ballerina project.
```ballerina
import ballerinax/aws.dynamodbstreams;
```

### Step 2: Create a new connector instance
Create an `dynamodbstreams:ConnectionConfig` with the tokens obtained, and initialize the connector with it.
```ballerina
dynamodbstreams:ConnectionConfig amazonDynamodbConfig = {
    awsCredentials: {
        accessKeyId: "<ACCESS_KEY_ID>",
        secretAccessKey: "<SECRET_ACCESS_KEY>"

    },
    region: "<REGION>"
};

dynamodbstreams:Client amazonDynamoDBClient = check new(amazonDynamodbConfig);
```

### Step 3: Invoke connector operation
1. Now you can use the operations available within the connector. Note that they are in the form of remote operations.  
Following is an example on how to describe a stream in DynamoDB streams using the connector.

    ```ballerina
    public function main() returns error? {
        dynamodbstreams:DescribeStreamInput describeStreamInput = {
            streamArn: "arn:aws:dynamodb:us-east-1:134633749276:table/TestStreamTable/stream/2024-01-04T04:43:13.919"
        };
        dynamodbstreams:StreamDescription response = check dynamoDBStreamClient->describeStream(describeStreamInput);
    }
    ```
2. Use `bal run` command to compile and run the Ballerina program.
