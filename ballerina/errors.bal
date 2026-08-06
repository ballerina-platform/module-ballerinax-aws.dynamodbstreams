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

# Represents the generic error type for the `aws.dynamodbstreams` module. For a failure reported by the DynamoDB
# Streams service, the error detail carries the `httpStatusCode`, the `requestId`, and the response body as
# `errorResponse` — verbatim, so it names the exception, for example `ExpiredIteratorException`. When the body could
# not be read at all, `errorResponse` is absent and the read failure is the error's `cause`.
public type Error distinct error;

# Represents an error that occurs while generating an API request, before anything is sent: the AWS credentials
# cannot be resolved, or the request cannot be signed.
public type RequestGenerationError distinct Error;

# Represents an error that occurs when the API response cannot be handled: the payload cannot be read, or it does
# not match the expected shape.
public type ResponseHandlingError distinct Error;
