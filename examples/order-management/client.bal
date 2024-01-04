import ballerina/io;
import ballerina/os;
import ballerinax/aws.dynamodbstreams;

public function main() returns error? {
    dynamodbstreams:ConnectionConfig amazonDynamodbConfig = {
        awsCredentials: {
            accessKeyId: os:getEnv("ACCESS_KEY_ID"),
            secretAccessKey: os:getEnv("SECRET_ACCESS_KEY")
        },
        region: os:getEnv("REGION")
    };

    dynamodbstreams:Client dynamodbStreamsClient = check new(amazonDynamodbConfig);

    dynamodbstreams:DescribeStreamInput describeStream = {
        streamArn: "arn:aws:dynamodb:us-east-1:134633749276:table/TestTable/stream/2023-11-17T09:36:43.853"
    };

    dynamodbstreams:StreamDescription describeStreamResult = check dynamodbStreamsClient->describeStream(describeStream);
    string shardId = "";
    dynamodbstreams:Shard[]? shards = describeStreamResult.shards;

    if shards is dynamodbstreams:Shard[] {
        shardId = <string>shards[0].shardId;
    }

    dynamodbstreams:GetShardsIteratorInput shardIteratorReq = {
        shardIteratorType: dynamodbstreams:TRIM_HORIZON, 
        shardId: shardId, 
        streamArn: "arn:aws:dynamodb:us-east-1:134633749276:table/TestTable/stream/2023-11-17T09:36:43.853"
    };
    dynamodbstreams:GetShardsIteratorOutput shardIterator = check dynamodbStreamsClient->getShardIterator(shardIteratorReq);
    dynamodbstreams:GetRecordsInput getRecordsInput = {
        shardIterator: shardIterator.shardIterator
    };  
    while true {
        stream<dynamodbstreams:Record, error?> result = check dynamodbStreamsClient->getRecords(getRecordsInput);
        io:println(result);
    }
}
