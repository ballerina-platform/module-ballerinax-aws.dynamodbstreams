# Ballerina Amazon DynamoDB Streams Connector 
[![Build Status](https://github.com/ballerina-platform/module-ballerinax-aws.dynamodbstreams/workflows/CI/badge.svg)](https://github.com/ballerina-platform/module-ballerinax-aws.dynamodbstreams/actions?query=workflow%3ACI)
[![codecov](https://codecov.io/gh/ballerina-platform/module-ballerinax-aws.dynamodbstreams/branch/main/graph/badge.svg)](https://codecov.io/gh/ballerina-platform/module-ballerinax-aws.dynamodbstreams)
[![GitHub Last Commit](https://img.shields.io/github/last-commit/ballerina-platform/module-ballerinax-aws.dynamodbstreams.svg)](https://github.com/ballerina-platform/module-ballerinax-aws.dynamodbstreams./commits/master)
[![GraalVM Check](https://github.com/ballerina-platform/module-ballerinax-aws.dynamodbstreams/actions/workflows/build-with-bal-test-native.yml/badge.svg)](https://github.com/ballerina-platform/module-ballerinax-aws.dynamodbstreams/actions/workflows/build-with-bal-test-native.yml)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

[Amazon DynamoDB](https://aws.amazon.com/dynamodb/) is a fully managed, serverless, key-value NoSQL database designed to run high-performance applications at any scale. DynamoDB offers built-in security, continuous backups, automated multi-region replication, in-memory caching, and data export tools.

The connector provides the capability to programmatically handle AWS DynamoDB Streams related operations.

For more information, go to the module(s).
- [aws.dynamodbstreams](./Module.md)

## Set up DynamoDB credentials

To invoke the DynamoDB REST API, you need AWS credentials. Below is a step-by-step guide on how to obtain these credentials:

1. Create an AWS Account:
* If you don't already have an AWS account, you need to create one. Go to the AWS Management Console, click on "Create an AWS Account," and follow the instructions.

2. Access the AWS Identity and Access Management (IAM) Console:

* Once logged into the [AWS Management Console](https://aws.amazon.com/), go to the IAM console by selecting "Services" and then choosing "IAM" under the "Security, Identity, & Compliance" section.

3. Create an IAM User:

* In the IAM console, navigate to "Users" and click on "Add user."
* Enter a username, and under "Select AWS access type," choose "Programmatic access."
* Click through the permissions setup, attaching policies that grant access to DynamoDB if you have specific requirements.
* Review the details and click "Create user."

4. Access Key ID and Secret Access Key:

* Once the user is created, you will see a success message. Take note of the "Access key ID" and "Secret access key" displayed on the confirmation screen. These credentials are needed to authenticate your requests.

5. Securely Store Credentials:

* Download the CSV file containing the credentials, or copy the "Access key ID" and "Secret access key" to a secure location. This information is sensitive and should be handled with care.

6. Use the Credentials in Your Application:

* In your application, use the obtained "Access key ID" and "Secret access key" to authenticate requests to the DynamoDB REST API.

## Quickstart

**Note**: Ensure you follow the [prerequisites](https://github.com/ballerina-platform/module-ballerinax-aws.dynamodbstreams#set-up-dynamodb-credentials) to get the credentials to be used.

To use the `dynamodbstreams` connector in your Ballerina application, modify the `.bal` file as follows:

### Step 1: Import the connector
Import the `ballerinax/aws.dynamodbstreams` package into your Ballerina project.
```ballerina
import ballerinax/aws.dynamodbstreams;
```

### Step 2: Instantiate a new connector
Create a `dynamodbstreams:ConnectionConfig` with the obtained access key id and secret access key to initialize the connector with it.
```ballerina
dynamodbstreams:ConnectionConfig amazonDynamodbConfig = {
    awsCredentials: {
        accessKeyId: "ACCESS_KEY_ID",
        secretAccessKey: "SECRET_ACCESS_KEY"
    },
    region: "REGION"
};

dynamodbstreams:Client amazonDynamodbClient = check new(amazonDynamodbConfig);
```

### Step 3: Invoke connector operation
1. Now you can use the operations available within the connector. Note that they are in the form of remote operations.  
Following is an example of how to describe a stream in DynamoDB streams using the connector.

```ballerina
public function main() returns error? {
   dynamodbstreams:DescribeStreamInput describeStreamInput = {
      streamArn: "arn:aws:dynamodb:us-east-1:134633749276:table/TestStreamTable/stream/2024-01-04T04:43:13.919"
   };
   dynamodbstreams:StreamDescription response = check dynamoDBStreamClient->describeStream(describeStreamInput);
}
```
2. Use `bal run` command to compile and run the Ballerina program.


## Examples

The `dynamodbstreams` connector provides practical examples illustrating usage in various scenarios. Explore these [examples](https://github.com/ballerina-platform/module-ballerinax-aws.dynamodbstreams/tree/master/examples).

1. [Real-time order processing](https://github.com/ballerina-platform/module-ballerinax-aws.dynamodbstreams/tree/master/examples/order-management/client.bal)
    A real-time order processing system.

For comprehensive information about the connector's functionality, configuration, and usage in Ballerina programs, refer to the `dynamodbstreams` connector's reference guide in [Ballerina Central](https://central.ballerina.io/ballerinax/aws.dynamodbstreams/latest).

## Building from the source
### Setting up the prerequisites
1. Download and install Java SE Development Kit (JDK) version 11. You can install either [OpenJDK](https://adoptopenjdk.net/) or [Oracle JDK](https://www.oracle.com/java/technologies/javase-jdk11-downloads.html).
 
   > **Note:** Set the JAVA_HOME environment variable to the path name of the directory into which you installed JDK.
 
2. Download and install [Ballerina Swan Lake](https://ballerina.io/)

### Building the source
 
Execute the commands below to build from the source:
* To build the package:
   ```   
   bal build ./ballerina
   ```
* To run tests after build:
   ```
   bal test ./ballerina
   ```
## Contributing to Ballerina
 
As an open source project, Ballerina welcomes contributions from the community.
 
For more information, see [contribution guidelines](https://github.com/ballerina-platform/ballerina-lang/blob/master/CONTRIBUTING.md).
 
## Code of conduct
 
All contributors are encouraged to read the [Ballerina Code of Conduct](https://ballerina.io/code-of-conduct).
 
## Useful links
 
* Discuss code changes of the Ballerina project via [ballerina-dev@googlegroups.com](mailto:ballerina-dev@googlegroups.com).
* Chat live with us via our [Discord server](https://discord.gg/ballerinalang).
* Post all technical questions on Stack Overflow with the [#ballerina](https://stackoverflow.com/questions/tagged/ballerina) tag.
 
