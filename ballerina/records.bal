// Copyright (c) 2024, WSO2 LLC. (http://www.wso2.org) All Rights Reserved.
//
// WSO2 LLC. licenses this file to you under the Apache License,
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

# Represents the AWS DynamoDB Streams Connector configurations.
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
public type AwsCredentials record {
    # AWS access key
    string accessKeyId;
    # AWS secret key
    @display {
        label: "",
        kind: "password"
    }
    string secretAccessKey;
};

# Represents AWS temporary credentials.
public type AwsTemporaryCredentials record {
    # AWS access key
    string accessKeyId;
    # AWS secret key
    @display {
        label: "",
        kind: "password"
    }
    string secretAccessKey;
    # AWS secret token
    @display {
        label: "",
        kind: "password"
    }
    string securityToken;   
};

# Record containing the fields required for describeStream request.
public type DescribeStreamInput record {|
    # The Amazon Resource Name (ARN) for the stream
    string streamArn;
    # The shard ID of the first item that this operation will evaluate. Use the value that was returned for LastEvaluatedShardId in the previous operation
    string exclusiveStartShardId?;
    # The maximum number of shard objects to return. The upper limit is 100
    int 'limit?;
|};

# Represents a single element of a key schema. A key schema speciﬁes the attributes that make up the primary key of a
# table, or the key attributes of an index.
public type KeySchemaElement record {
    # The name of a key attribute
    string attributeName;
    # The role that this key attribute will assume: HASH - partition key, RANGE - sort key
    KeyType keyType;
};

# Represents all of the data describing a particular stream.
public type StreamDescription record {
    # The date and time when the request to create this stream was issued
    decimal creationRequestDateTime?;
    # The key attribute(s) of the stream's DynamoDB table
    KeySchemaElement[] keySchema?;
    # The shard ID of the item where the operation stopped, inclusive of the previous result set. Use this value to start a new operation, excluding this value in the new request
    string lastEvaluatedShardId?;
    # The shards that comprise the stream
    Shard[] shards?;
    # The Amazon Resource Name (ARN) for the stream
    string streamArn?;
    # A timestamp, in ISO 8601 format, for this stream
    string streamLabel?;
    # Indicates the current status of the stream
    StreamStatus streamStatus?;
    # Indicates the format of the records within this stream
    StreamViewType streamViewType?;
    # The DynamoDB table with which the stream is associated
    string tableName?;
};

# A uniquely identified group of stream records within a stream.
public type Shard record {
    # The shard ID of the current shard's parent
    string parentShardId?;
    # The range of possible sequence numbers for the shard
    SequenceNumberRange sequenceNumberRange?;
    # The system-generated identifier for this shard
    string shardId?;
};

# The beginning and ending sequence numbers for the stream records contained within a shard.
public type SequenceNumberRange record {
    # The last sequence number for the stream records contained within a shard. String contains numeric characters only
    string endingSequenceNumber?;
    # The first sequence number for the stream records contained within a shard. String contains numeric characters only
    string startingSequenceNumber?;
};

# Retrieves the stream records from a given shard.
public type GetRecordsInput record {|
    # A shard iterator that was retrieved from a previous GetShardIterator operation. This iterator can be used to access the stream records in this shard
    string shardIterator;
    # The maximum number of records to return from the shard. The upper limit is 1000
    int 'limit?;
|};

# Response for the getRecords.
public type GetRecordsOutput record {
    # The next position in the shard from which to start sequentially reading stream records. If set to null, the shard has been closed and the requested iterator will not return any more data
    string nextShardIterator?;
    # The stream records from the shard, which were retrieved using the shard iterator
    Record[] records?;
};

# A description of a unique event within a stream.
public type Record record {
    # The region in which the GetRecords request was received
    string awsRegion?;
    # The main body of the stream record, containing all of the DynamoDB-specific fields
    StreamRecord dynamodb?;
    # A globally unique identifier for the event that was recorded in this stream record
    string eventID?;
    # The type of data modification that was performed on the DynamoDB table
    eventName eventName?;
    # The AWS service from which the stream record originated. For DynamoDB Streams, this is aws:dynamodb
    string eventSource?;
    # The version number of the stream record format. This number is updated whenever the structure of Record is modified
    string eventVersion?;
    # Items that are deleted by the Time to Live process after expiration
    Identity userIdentity?;
};

# Represents the data for an attribute. Each attribute value is described as a name-value pair. The name is the data
# type, and the value is the data itself.
public type AttributeValue record {
    # An attribute of type Binary
    string? b? ;
    # An attribute of type Boolean
    boolean? bool?;
    # An attribute of type Binary Set
    string[]? bs?;
    # An attribute of type List
    AttributeValue[]? l?;
    # An attribute of type Map
    map<AttributeValue>? m?;
    # An attribute of type Number
    string? n?;
    # An attribute of type Number Set
    string[]? ns?;
    # An attribute of type Null
    boolean? 'null?;
    # An attribute of type String
    string? s?;
    # An attribute of type String Set
    string[]? ss?;
};

# A description of a single data modification that was performed on an item in a DynamoDB table.
public type StreamRecord record {
    # The approximate date and time when the stream record was created, in UNIX epoch time format and rounded down to the closest second
    decimal approximateCreationDateTime?;
    # The primary key attribute(s) for the DynamoDB item that was modified
    AttributeValue keys?;
    # The item in the DynamoDB table as it appeared after it was modified
    AttributeValue newImage?;
    # The item in the DynamoDB table as it appeared before it was modified
    AttributeValue oldImage?;
    # The sequence number of the stream record
    string sequenceNumber?;
    # The size of the stream record, in bytes
    float sizeBytes?;
    # The type of data from the modified DynamoDB item that was captured in this stream record
    StreamViewType streamViewType?;
};

# Contains details about the type of identity that made the request.
public type Identity record {
    # A unique identifier for the entity that made the call. For Time To Live, the principalId is "dynamodb.amazonaws.com"
    string principalId;
    # The type of the identity. For Time To Live, the type is "Service"
    string 'type;
};

# The request to perform getShardIterator.
public type GetShardsIteratorInput record {|
    # The identifier of the shard. The iterator will be returned for this shard ID
    string shardId;
    # Determines how the shard iterator is used to start reading stream records from the shard
    string shardIteratorType;
    # The Amazon Resource Name (ARN) for the stream
    string streamArn;
    # The sequence number of a stream record in the shard from which to start reading
    string sequenceNumber?;
|};

# The response of getShardIterator.
public type GetShardsIteratorOutput record {
    # The position in the shard from which to start reading stream records sequentially. A shard iterator specifies this position using the sequence number of a stream record in a shard
    string shardIterator;
};

# Record containing the fields required for listStreams request.
public type ListStreamsInput record {|
    # The Amazon Resource Name (ARN) of the first item that this operation will evaluate. Use the value that was returned for LastEvaluatedStreamArn in the previous operation
    string exclusiveStartStreamArn?;
    # The maximum number of streams to return. The upper limit is 100
    int 'limit?;
    # If this parameter is provided, then only the streams associated with this table name are returned
    string tableName?;
|};

# Response associated with the listStreams request.
public type ListStreamsOutput record {
    # The stream ARN of the item where the operation stopped, inclusive of the previous result set. Use this value to start a new operation, excluding this value in the new request
    string lastEvaluatedStreamArn?;
    # A list of stream descriptors associated with the current account and endpoint
    Stream[] streams;
};

# Represents all of the data describing a particular stream.
public type Stream record {
    # The Amazon Resource Name (ARN) for the stream
    string streamArn?;
    # A timestamp, in ISO 8601 format, for this stream
    string streamLabel?;
    # The DynamoDB table with which the stream is associated
    string tableName?; 
};
