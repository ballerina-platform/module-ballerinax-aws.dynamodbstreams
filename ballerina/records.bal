// Copyright (c) 2021, WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
//
// WSO2 Inc. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

import ballerinax/'client.config;

# Represents the AWS DynamoDB Connector configurations.
@display {label: "Connection Config"}
public type ConnectionConfig record {|
    *config:ConnectionConfig;
    never auth?;
    # AWS credentials
    AwsCredentials|AwsTemporaryCredentials awsCredentials;
    # AWS Region
    string region;
|};

# Represents AWS credentials.
#
# + accessKeyId - AWS access key  
# + secretAccessKey - AWS secret key
public type AwsCredentials record {
    string accessKeyId;
    @display {
        label: "",
        kind: "password"
    }
    string secretAccessKey;
};

# Represents AWS temporary credentials.
#
# + accessKeyId - AWS access key  
# + secretAccessKey - AWS secret key  
# + securityToken - AWS secret token
public type AwsTemporaryCredentials record {
    string accessKeyId;
    @display {
        label: "",
        kind: "password"
    }
    string secretAccessKey;
    @display {
        label: "",
        kind: "password"
    }
    string securityToken;   
};

# Record containing the fields required for describeStream request.
# 
# + streamArn - The Amazon Resource Name (ARN) for the stream
# + exclusiveStartShardId - The shard ID of the first item that this operation will evaluate. Use the value that was returned for LastEvaluatedShardId in the previous operation
# + limit - The maximum number of shard objects to return. The upper limit is 100
public type DescribeStreamInput record {
    string streamArn;
    string exclusiveStartShardId?;
    int 'limit?;
};

# Represents a single element of a key schema. A key schema speciﬁes the attributes that make up the primary key of a
# table, or the key attributes of an index.
#
# + attributeName - The name of a key attribute
# + keyType - The role that this key attribute will assume: HASH - partition key, RANGE - sort key
public type KeySchemaElement record {
    string attributeName;
    KeyType keyType;
};

# Represents all of the data describing a particular stream.
#
# + creationRequestDateTime - The date and time when the request to create this stream was issued
# + keySchema - The key attribute(s) of the stream's DynamoDB table  
# + lastEvaluatedShardId - The shard ID of the item where the operation stopped, inclusive of the previous result set. Use this value to start a new operation, excluding this value in the new request
# + shards - The shards that comprise the stream 
# + streamArn - The Amazon Resource Name (ARN) for the stream
# + streamLabel - A timestamp, in ISO 8601 format, for this stream
# + streamStatus - Indicates the current status of the stream
# + streamViewType - Indicates the format of the records within this stream 
# + tableName - The DynamoDB table with which the stream is associated
public type StreamDescription record {
    decimal creationRequestDateTime?;
    KeySchemaElement[] keySchema?;
    string lastEvaluatedShardId?;
    Shard[] shards?;
    string streamArn?;
    string streamLabel?;
    StreamStatus streamStatus?;
    StreamViewType streamViewType?;
    string tableName?;
};

# A uniquely identified group of stream records within a stream.
#
# + parentShardId - The shard ID of the current shard's parent  
# + sequenceNumberRange - The range of possible sequence numbers for the shard
# + shardId - The system-generated identifier for this shard
public type Shard record {
    string parentShardId?;
    SequenceNumberRange sequenceNumberRange?;
    string shardId?;
};

# The beginning and ending sequence numbers for the stream records contained within a shard.
#
# + endingSequenceNumber - The last sequence number for the stream records contained within a shard. String contains numeric characters only 
# + startingSequenceNumber - The first sequence number for the stream records contained within a shard. String contains numeric characters only
public type SequenceNumberRange record {
    string endingSequenceNumber?;
    string startingSequenceNumber?;
};

# Retrieves the stream records from a given shard.
#
# + shardIterator - A shard iterator that was retrieved from a previous GetShardIterator operation. This iterator can be used to access the stream records in this shard
# + 'limit - The maximum number of records to return from the shard. The upper limit is 1000
public type GetRecordsInput record {
    string shardIterator;
    int 'limit?;
};

# Response for the getRecords.
#
# + nextShardIterator - The next position in the shard from which to start sequentially reading stream records. If set to null, the shard has been closed and the requested iterator will not return any more data
# + records - The stream records from the shard, which were retrieved using the shard iterator
public type GetRecordsOutput record {
    string nextShardIterator?;
    Record[] records?;
};

# A description of a unique event within a stream.
#
# + awsRegion - The region in which the GetRecords request was received
# + dynamodb - The main body of the stream record, containing all of the DynamoDB-specific fields
# + eventID - A globally unique identifier for the event that was recorded in this stream record
# + eventName - The type of data modification that was performed on the DynamoDB table
# + eventSource - The AWS service from which the stream record originated. For DynamoDB Streams, this is aws:dynamodb 
# + eventVersion - The version number of the stream record format. This number is updated whenever the structure of Record is modified
# + userIdentity - Items that are deleted by the Time to Live process after expiration
public type Record record {
    string awsRegion?;
    StreamRecord dynamodb?;
    string eventID?;
    eventName eventName?;
    string eventSource?;
    string eventVersion?;
    Identity userIdentity?;
};

# Represents the data for an attribute. Each attribute value is described as a name-value pair. The name is the data
# type, and the value is the data itself.
#
# + b - An attribute of type Binary
# + bool - An attribute of type Boolean
# + bs - An attribute of type Binary Set
# + l - An attribute of type List
# + m - An attribute of type Map
# + n - An attribute of type Number
# + ns - An attribute of type Number Set
# + null - An attribute of type Null
# + s - An attribute of type String
# + ss - An attribute of type String Set
public type AttributeValue record {
    // Data types of Binary and Binary Set may be need to revise.
    string? b? ;
    boolean? bool?;
    string[]? bs?;
    AttributeValue[]? l?;
    map<AttributeValue>? m?;
    string? n?;
    string[]? ns?;
    boolean? 'null?;
    string? s?;
    string[]? ss?;
};

# A description of a single data modification that was performed on an item in a DynamoDB table.
#
# + approximateCreationDateTime - The approximate date and time when the stream record was created, in UNIX epoch time format and rounded down to the closest second
# + keys - The primary key attribute(s) for the DynamoDB item that was modified
# + newImage - The item in the DynamoDB table as it appeared after it was modified
# + oldImage - The item in the DynamoDB table as it appeared before it was modified
# + sequenceNumber - The sequence number of the stream record
# + sizeBytes - The size of the stream record, in bytes
# + streamViewType - The type of data from the modified DynamoDB item that was captured in this stream record
public type StreamRecord record {
    decimal approximateCreationDateTime?;
    AttributeValue keys?;
    AttributeValue newImage?;
    AttributeValue oldImage?;
    string sequenceNumber?;
    float sizeBytes?;
    StreamViewType streamViewType?;
};

# Contains details about the type of identity that made the request.
#
# + principalId - A unique identifier for the entity that made the call. For Time To Live, the principalId is "dynamodb.amazonaws.com"
# + type - The type of the identity. For Time To Live, the type is "Service"
public type Identity record {
    string principalId;
    string 'type;
};

# The request to perform getShardIterator.
#
# + shardId - The identifier of the shard. The iterator will be returned for this shard ID
# + streamArn - The Amazon Resource Name (ARN) for the stream
# + shardIteratorType -Determines how the shard iterator is used to start reading stream records from the shard
# + sequenceNumber - The sequence number of a stream record in the shard from which to start reading
public type GetShardsIteratorInput record {
    string shardId;
    string shardIteratorType;
    string streamArn;
    string sequenceNumber?;
};

# The response of getShardIterator.
#
# + shardIterator - The position in the shard from which to start reading stream records sequentially. A shard iterator specifies this position using the sequence number of a stream record in a shard
public type GetShardsIteratorOutput record {
    string shardIterator;
};

# Record containing the fields required for listStreams request.
#
# + exclusiveStartStreamArn - Field Description  
# + limit - Field Description  
# + tableName - Field Description
public type ListStreamsInput record {
    string exclusiveStartStreamArn?;
    int 'limit?;
    string tableName?;
};

# Response associated with the listStreams request.
#
# + lastEvaluatedStreamArn - The stream ARN of the item where the operation stopped, inclusive of the previous result set
# + streams - A list of stream descriptors associated with the current account and endpoint
public type ListStreamsOutput record {
    string lastEvaluatedStreamArn?;
    Stream[] streams;
};

# Represents all of the data describing a particular stream.
#
# + streamArn - The Amazon Resource Name (ARN) for the stream  
# + streamLabel - A timestamp, in ISO 8601 format, for this stream
# + tableName - The DynamoDB table with which the stream is associated
public type Stream record {
    string streamArn?;
    string streamLabel?;
    string tableName?; 
};
