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

const string AWS_HOST = "amazonaws.com";
const string AWS_SERVICE = "dynamodb";
const string AWS_STREAMS_SERVICE = "streams.dynamodb";
const string STREAMS_VERSION = "DynamoDBStreams_20120810";

const string UTF_8 = "UTF-8";
const string HOST = "host";
const string CONTENT_TYPE = "content-type";
const string APPLICATION_JSON = "application/json";
const string X_AMZ_DATE = "x-amz-date";
const string X_AMZ_TARGET = "x-amz-target";
const string AWS4_REQUEST = "aws4_request";
const string AWS4_HMAC_SHA256 = "AWS4-HMAC-SHA256";
const string CREDENTIAL = "Credential";
const string SIGNED_HEADER = "SignedHeaders";
const string SIGNATURE = "Signature";
const string AWS4 = "AWS4";
const string ISO8601_BASIC_DATE_FORMAT = "yyyyMMdd'T'HHmmss'Z'";
const string SHORT_DATE_FORMAT = "yyyyMMdd";
const string ENCODED_SLASH = "%2F";
const string SLASH = "/";
const string EMPTY_STRING = "";
const string NEW_LINE = "\n";
const string COLON = ":";
const string SEMICOLON = ";";
const string EQUAL = "=";
const string SPACE = " ";
const string COMMA = ",";
const string DOT = ".";
const string Z = "Z";

// HTTP.
const string POST = "POST";
const string HTTPS = "https://";

// Constants to refer the headers.
const string HEADER_CONTENT_TYPE = "Content-Type";
const string HEADER_X_AMZ_CONTENT_SHA256 = "X-Amz-Content-Sha256";
const string HEADER_X_AMZ_DATE = "X-Amz-Date";
const string HEADER_X_AMZ_TARGET = "X-Amz-Target";
const string HEADER_HOST = "Host";
const string HEADER_AUTHORIZATION = "Authorization";

const string GENERATE_SIGNED_REQUEST_HEADERS_FAILED_MSG = "Error occurred while generating signed request headers.";

public enum AttributeType {
    S, N, B
}

public enum KeyType {
    HASH, RANGE
}

public enum SSEType {
    AES256, KMS
}

public enum StreamViewType {
    NEW_IMAGE, OLD_IMAGE, NEW_AND_OLD_IMAGES, KEYS_ONLY
}

public enum StreamStatus {
    ENABLING, ENABLED, DISABLING, DISABLED
}

public enum eventName {
    INSERT, MODIFY, REMOVE
}

public enum ShardIteratorType {
    TRIM_HORIZON, LATEST, AT_SEQUENCE_NUMBER, AFTER_SEQUENCE_NUMBER
}
