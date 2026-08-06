// Copyright (c) 2024, WSO2 LLC. (http://www.wso2.com).
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

// The endpoint prefix of the DynamoDB Streams service, used to resolve the
// endpoint URL (e.g. `streams.dynamodb.us-east-1.amazonaws.com`).
const string SERVICE_NAME = "streams.dynamodb";

// The SigV4 signing name of the DynamoDB Streams service.
const string SIGNING_SERVICE_NAME = "dynamodb";

// The DynamoDB Streams API version, used as the `x-amz-target` prefix.
const string API_VERSION = "DynamoDBStreams_20120810";

const string TARGET_DESCRIBE_STREAM = API_VERSION + ".DescribeStream";
const string TARGET_GET_RECORDS = API_VERSION + ".GetRecords";
const string TARGET_GET_SHARD_ITERATOR = API_VERSION + ".GetShardIterator";
const string TARGET_LIST_STREAMS = API_VERSION + ".ListStreams";

const string ROOT_PATH = "/";
const string HTTP_POST = "POST";

// DynamoDB and DynamoDB Streams speak the AWS JSON 1.0 protocol.
const string JSON_CONTENT_TYPE = "application/x-amz-json-1.0";

const string CONTENT_TYPE_HEADER = "content-type";
const string TARGET_HEADER = "x-amz-target";
const string REQUEST_ID_HEADER = "x-amzn-RequestId";

// Default pacing for `pollRecords`, also used as the fallback when a non-positive interval is supplied.
const decimal DEFAULT_POLL_INTERVAL = 1;
const decimal DEFAULT_MAX_POLL_INTERVAL = 20;

