// Copyright (c) 2026, WSO2 LLC. (http://www.wso2.com).
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

import ballerina/data.jsondata;
import ballerina/http;
import ballerinax/aws;
import ballerinax/aws.auth;

# Provides a set of configurations for controlling the behaviours when communicating with the
# Amazon DynamoDB Streams endpoint.
@display {label: "Connection Config"}
public type ConnectionConfig record {|
    # Authentication configuration: any standard credential source supported by
    # AWS — static credentials, an AWS profile, STS assume-role,
    # web identity (OIDC), IAM Identity Center (SSO), an external credential
    # process, or the default credential provider chain
    auth:AuthConfig auth;
    # AWS region: an `aws:Region` enum member or a plain region
    # string (e.g., `"us-east-1"`) for regions not yet in the enum
    aws:Region|string region;
    # Optional endpoint options: FIPS/dualstack variants, or a custom
    # endpoint override (e.g. LocalStack, VPC interface endpoints)
    aws:EndpointConfig endpoint?;
    # The HTTP version understood by the client
    http:HttpVersion httpVersion = http:HTTP_2_0;
    # Configurations related to HTTP/1.x protocol
    http:ClientHttp1Settings http1Settings = {};
    # Configurations related to HTTP/2 protocol
    http:ClientHttp2Settings http2Settings = {};
    # The maximum time to wait (in seconds) for a response before closing the connection
    decimal timeout = 30;
    # The choice of setting `forwarded`/`x-forwarded` header
    string forwarded = "disable";
    # Configurations associated with Redirection
    http:FollowRedirects followRedirects?;
    # Configurations associated with request pooling
    http:PoolConfiguration poolConfig?;
    # HTTP caching related configurations
    http:CacheConfig cache = {};
    # Specifies the way of handling compression (`accept-encoding`) header
    http:Compression compression = http:COMPRESSION_AUTO;
    # Configurations associated with the behaviour of the Circuit Breaker
    http:CircuitBreakerConfig circuitBreaker?;
    # Configurations associated with retrying
    http:RetryConfig retryConfig?;
    # Configurations associated with cookies
    http:CookieConfig cookieConfig?;
    # Configurations associated with inbound response size limits
    http:ResponseLimitConfigs responseLimits = {};
    # SSL/TLS-related options
    http:ClientSecureSocket secureSocket?;
    # Proxy server related options
    http:ProxyConfig proxy?;
    # Provides settings related to client socket configuration
    http:ClientSocketConfig socketConfig = {};
    # Enables the inbound payload validation functionality which provided by the constraint package. Enabled by default
    boolean validation = true;
    # Enables relaxed data binding on the client side. When enabled, `nil` values are treated as optional,
    # and absent fields are handled as `nilable` types. Enabled by default
    boolean laxDataBinding = true;
|};

# The role that a key attribute assumes in a key schema.
public enum KeyType {
    # The partition key
    HASH,
    # The sort key
    RANGE
}

# The format of the records within a stream.
public enum StreamViewType {
    # The entire item, as it appeared after it was modified
    NEW_IMAGE,
    # The entire item, as it appeared before it was modified
    OLD_IMAGE,
    # Both the new and the old item images of the item
    NEW_AND_OLD_IMAGES,
    # Only the key attributes of the modified item
    KEYS_ONLY
}

# The current state of a stream.
public enum StreamStatus {
    # The stream is being created
    ENABLING,
    # The stream is enabled
    ENABLED,
    # The stream is being deleted
    DISABLING,
    # The stream is disabled
    DISABLED
}

# The type of data modification that was performed on a DynamoDB table item.
public enum OperationType {
    # A new item was added to the table
    INSERT,
    # An item was modified
    MODIFY,
    # An item was deleted from the table
    REMOVE
}

# Determines how a shard iterator is used to start reading stream records from a shard.
public enum ShardIteratorType {
    # Start reading at the last untrimmed record in the shard, which is the oldest data record in the shard
    TRIM_HORIZON,
    # Start reading just after the most recent record in the shard, so that you always read the most recent data
    LATEST,
    # Start reading exactly from the position denoted by a specific sequence number
    AT_SEQUENCE_NUMBER,
    # Start reading right after the position denoted by a specific sequence number
    AFTER_SEQUENCE_NUMBER
}

# Represents the fields of a `listStreams` request.
public type ListStreamsInput record {|
    # If provided, only the streams associated with this table name are returned
    @jsondata:Name {value: "TableName"}
    string tableName?;
    # The Amazon Resource Name (ARN) of the first item that this operation will evaluate. Use the value that was
    # returned for `lastEvaluatedStreamArn` in the previous operation
    @jsondata:Name {value: "ExclusiveStartStreamArn"}
    string exclusiveStartStreamArn?;
    # The maximum number of streams to return per request. The upper limit is 100
    @jsondata:Name {value: "Limit"}
    int 'limit?;
|};

# Represents the response of a single `ListStreams` request.
public type ListStreamsOutput record {
    # A list of stream descriptors associated with the current account and endpoint
    @jsondata:Name {value: "Streams"}
    Stream[] streams = [];
    # The stream ARN of the item where the operation stopped, inclusive of the previous result set. Use this value to
    # start a new operation, excluding this value in the new request
    @jsondata:Name {value: "LastEvaluatedStreamArn"}
    string lastEvaluatedStreamArn?;
};

# Represents a summary of a stream returned by `listStreams`.
public type Stream record {
    # The Amazon Resource Name (ARN) for the stream
    @jsondata:Name {value: "StreamArn"}
    string streamArn?;
    # A timestamp, in ISO 8601 format, for this stream
    @jsondata:Name {value: "StreamLabel"}
    string streamLabel?;
    # The DynamoDB table with which the stream is associated
    @jsondata:Name {value: "TableName"}
    string tableName?;
};

# Represents the fields of a `describeStream` request.
public type DescribeStreamInput record {|
    # The Amazon Resource Name (ARN) for the stream
    @jsondata:Name {value: "StreamArn"}
    string streamArn;
    # The shard ID of the first item that this operation will evaluate. Use the value that was returned for
    # `lastEvaluatedShardId` in the previous operation
    @jsondata:Name {value: "ExclusiveStartShardId"}
    string exclusiveStartShardId?;
    # The maximum number of shard objects to return. The upper limit is 100
    @jsondata:Name {value: "Limit"}
    int 'limit?;
|};

# Represents all of the data describing a particular stream.
public type StreamDescription record {
    # The Amazon Resource Name (ARN) for the stream
    @jsondata:Name {value: "StreamArn"}
    string streamArn?;
    # A timestamp, in ISO 8601 format, for this stream
    @jsondata:Name {value: "StreamLabel"}
    string streamLabel?;
    # Indicates the current status of the stream
    @jsondata:Name {value: "StreamStatus"}
    StreamStatus streamStatus?;
    # Indicates the format of the records within this stream
    @jsondata:Name {value: "StreamViewType"}
    StreamViewType streamViewType?;
    # The date and time when the request to create this stream was issued, in UNIX epoch time format
    @jsondata:Name {value: "CreationRequestDateTime"}
    decimal creationRequestDateTime?;
    # The DynamoDB table with which the stream is associated
    @jsondata:Name {value: "TableName"}
    string tableName?;
    # The key attribute(s) of the stream's DynamoDB table
    @jsondata:Name {value: "KeySchema"}
    KeySchemaElement[] keySchema?;
    # The shards that comprise the stream
    @jsondata:Name {value: "Shards"}
    Shard[] shards?;
    # The shard ID of the item where the operation stopped, inclusive of the previous result set. Pass this value as
    # `exclusiveStartShardId` in a new `describeStream` request to read the next page of shards
    @jsondata:Name {value: "LastEvaluatedShardId"}
    string lastEvaluatedShardId?;
};

# Represents a single element of a key schema. A key schema specifies the attributes that make up the primary key of
# a table, or the key attributes of an index.
public type KeySchemaElement record {
    # The name of a key attribute
    @jsondata:Name {value: "AttributeName"}
    string attributeName?;
    # The role that this key attribute assumes: `HASH` - partition key, `RANGE` - sort key
    @jsondata:Name {value: "KeyType"}
    KeyType keyType?;
};

# A uniquely identified group of stream records within a stream.
public type Shard record {
    # The system-generated identifier for this shard
    @jsondata:Name {value: "ShardId"}
    string shardId?;
    # The shard ID of the current shard's parent
    @jsondata:Name {value: "ParentShardId"}
    string parentShardId?;
    # The range of possible sequence numbers for the shard
    @jsondata:Name {value: "SequenceNumberRange"}
    SequenceNumberRange sequenceNumberRange?;
};

# The beginning and ending sequence numbers for the stream records contained within a shard.
public type SequenceNumberRange record {
    # The first sequence number for the stream records contained within a shard. Contains numeric characters only
    @jsondata:Name {value: "StartingSequenceNumber"}
    string startingSequenceNumber?;
    # The last sequence number for the stream records contained within a shard. Contains numeric characters only.
    # Absent while the shard is still open for writes
    @jsondata:Name {value: "EndingSequenceNumber"}
    string endingSequenceNumber?;
};

# Represents the fields of a `getShardIterator` request.
public type GetShardIteratorInput record {|
    # The Amazon Resource Name (ARN) for the stream
    @jsondata:Name {value: "StreamArn"}
    string streamArn;
    # The identifier of the shard. The iterator will be returned for this shard ID
    @jsondata:Name {value: "ShardId"}
    string shardId;
    # Determines how the shard iterator is used to start reading stream records from the shard
    @jsondata:Name {value: "ShardIteratorType"}
    ShardIteratorType shardIteratorType;
    # The sequence number of a stream record in the shard from which to start reading. Required for the
    # `AT_SEQUENCE_NUMBER` and `AFTER_SEQUENCE_NUMBER` iterator types, and must be omitted for the others
    @jsondata:Name {value: "SequenceNumber"}
    string sequenceNumber?;
|};

# Represents the fields of a `getRecords` request.
public type GetRecordsInput record {|
    # A shard iterator obtained from `getShardIterator`, or the `nextShardIterator` of a previous `getRecords`
    # response. Shard iterators expire 15 minutes after they are returned
    @jsondata:Name {value: "ShardIterator"}
    string shardIterator;
    # The maximum number of records to return from the shard. The upper limit is 1000
    @jsondata:Name {value: "Limit"}
    int 'limit?;
|};

# Represents the response of a single `GetRecords` request.
public type GetRecordsOutput record {
    # The stream records read from the shard, at most `limit` of them and never more than 1000. Empty when the
    # shard has no new records yet — which does not mean the shard is exhausted; that is signalled by an absent
    # `nextShardIterator`
    @jsondata:Name {value: "Records"}
    Record[] records = [];
    # The position in the shard from which to continue reading. Pass this value as the `shardIterator` of the next
    # `getRecords` request to resume where this one stopped. Absent once the shard has been closed and fully read,
    # at which point the consumer should move on to the child shards
    @jsondata:Name {value: "NextShardIterator"}
    string nextShardIterator?;
};

# Represents the fields of a `pollRecords` request. These are not `GetRecords` parameters — apart from the shard
# iterator and the limit, they configure how the connector paces its own polling.
public type PollRecordsInput record {|
    # A shard iterator obtained from `getShardIterator`, or the `nextShardIterator` of a previous `getRecords`
    # response
    string shardIterator;
    # The maximum number of records to return per underlying `GetRecords` call. The upper limit is 1000
    int 'limit?;
    # The time to wait, in seconds, before re-polling a shard that returned no records. Doubles on each consecutive
    # empty poll, up to `maxPollInterval`, and resets as soon as records arrive
    decimal pollInterval = 1;
    # The upper bound, in seconds, for the wait between polls of a shard that keeps returning no records
    decimal maxPollInterval = 20;
    # The number of consecutive empty polls after which the stream completes. When not set, the stream keeps polling
    # an open shard indefinitely, and completes only once the shard is closed and fully read
    int maxIdlePolls?;
|};

# A description of a unique event within a stream.
public type Record record {
    # A globally unique identifier for the event that was recorded in this stream record
    string eventID?;
    # The type of data modification that was performed on the DynamoDB table
    OperationType eventName?;
    # The version number of the stream record format. This number is updated whenever the structure of `Record`
    # is modified
    string eventVersion?;
    # The AWS service from which the stream record originated. For DynamoDB Streams, this is `aws:dynamodb`
    string eventSource?;
    # The region in which the `GetRecords` request was received
    string awsRegion?;
    # The main body of the stream record, containing all of the DynamoDB-specific fields
    StreamRecord dynamodb?;
    # The identity of the principal behind the modification. Populated for items deleted by the Time to Live
    # process, where the principal is the DynamoDB service itself
    Identity userIdentity?;
};

# A description of a single data modification that was performed on an item in a DynamoDB table.
public type StreamRecord record {
    # The sequence number of the stream record
    @jsondata:Name {value: "SequenceNumber"}
    string sequenceNumber?;
    # The primary key attribute(s) of the DynamoDB item that was modified, keyed by attribute name
    @jsondata:Name {value: "Keys"}
    map<AttributeValue> keys?;
    # The item in the DynamoDB table as it appeared after it was modified, keyed by attribute name. Present only
    # when the stream view type includes new images
    @jsondata:Name {value: "NewImage"}
    map<AttributeValue> newImage?;
    # The item in the DynamoDB table as it appeared before it was modified, keyed by attribute name. Present only
    # when the stream view type includes old images
    @jsondata:Name {value: "OldImage"}
    map<AttributeValue> oldImage?;
    # The type of data from the modified DynamoDB item that was captured in this stream record
    @jsondata:Name {value: "StreamViewType"}
    StreamViewType streamViewType?;
    # The approximate date and time when the stream record was created, in UNIX epoch time format and rounded down
    # to the closest second
    @jsondata:Name {value: "ApproximateCreationDateTime"}
    decimal approximateCreationDateTime?;
    # The size of the stream record, in bytes
    @jsondata:Name {value: "SizeBytes"}
    int sizeBytes?;
};

# Represents the data for an attribute. Each attribute value is described as a name-value pair: the name is the
# data type, and the value is the data itself. Exactly one field is set on any given value.
public type AttributeValue record {
    # An attribute of type String
    @jsondata:Name {value: "S"}
    string s?;
    # An attribute of type Number. Numbers are sent across the network as strings to preserve full precision
    @jsondata:Name {value: "N"}
    string n?;
    # An attribute of type Binary, as a base64-encoded string
    @jsondata:Name {value: "B"}
    string b?;
    # An attribute of type Boolean
    @jsondata:Name {value: "BOOL"}
    boolean bool?;
    # An attribute of type Null. Always `true` when present
    @jsondata:Name {value: "NULL"}
    boolean 'null?;
    # An attribute of type String Set
    @jsondata:Name {value: "SS"}
    string[] ss?;
    # An attribute of type Number Set
    @jsondata:Name {value: "NS"}
    string[] ns?;
    # An attribute of type Binary Set, as base64-encoded strings
    @jsondata:Name {value: "BS"}
    string[] bs?;
    # An attribute of type List
    @jsondata:Name {value: "L"}
    AttributeValue[] l?;
    # An attribute of type Map, keyed by attribute name
    @jsondata:Name {value: "M"}
    map<AttributeValue> m?;
};

# Contains details about the type of identity that made a request.
public type Identity record {
    # A unique identifier for the entity that made the call. For Time To Live, the principal ID is
    # `dynamodb.amazonaws.com`
    @jsondata:Name {value: "PrincipalId"}
    string principalId?;
    # The type of the identity. For Time To Live, the type is `Service`
    @jsondata:Name {value: "Type"}
    string 'type?;
};
