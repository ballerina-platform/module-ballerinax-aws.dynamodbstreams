## Package overview

The `ballerinax/aws.dynamodbstreams` is a [Ballerina](https://ballerina.io/) connector for AWS DynamoDB. It is comprised of the following capabilities.
* Perform AWS DynamoDB Streams related operations programmatically. The `ballerinax/aws.dynamodbstreams` module provides this capability.

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

## Report issues
To report bugs, request new features, start new discussions, view project boards, etc., go to the [Ballerina Extended Library repository](https://github.com/ballerina-platform/ballerina-extended-library)

## Useful links
- Discuss code changes of the Ballerina project via [ballerina-dev@googlegroups.com](mailto:ballerina-dev@googlegroups.com).
- Chat live with us via our [Discord server](https://discord.gg/ballerinalang).
- Post all technical questions on Stack Overflow with the [#ballerina](https://stackoverflow.com/questions/tagged/ballerina) tag
