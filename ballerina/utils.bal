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

import ballerina/http;
import ballerinax/aws;
import ballerinax/aws.auth;

# Builds the request for an operation, signed with AWS Signature Version 4.
#
# + credentialProvider - Provider that resolves (and refreshes) the signing credentials
# + host - The endpoint host to sign against
# + region - The signing region
# + target - The `x-amz-target` value identifying the operation
# + payload - The request body
# + return - The signed request, or an `Error` if the credentials cannot be resolved or the request cannot be signed
isolated function generateRequest(auth:CredentialProvider credentialProvider, string host, aws:Region|string region,
        string target, json payload) returns http:Request|Error {
    string body = payload.toJsonString();
    auth:Credentials|auth:CredentialResolutionError credentials = credentialProvider.getCredentials();
    if credentials is auth:CredentialResolutionError {
        return error RequestGenerationError(
                string `Error occurred while resolving the AWS credentials: ${credentials.message()}`, credentials);
    }

    map<string>|auth:SigningError signedHeaders = auth:getSignedHeaders({
        method: HTTP_POST,
        host: host,
        path: ROOT_PATH,
        headers: {[CONTENT_TYPE_HEADER]: JSON_CONTENT_TYPE, [TARGET_HEADER]: target},
        payload: body.toBytes()
    }, credentials, region, SIGNING_SERVICE_NAME);
    if signedHeaders is auth:SigningError {
        return error RequestGenerationError(
                string `Error occurred while signing the request: ${signedHeaders.message()}`, signedHeaders);
    }

    http:Request request = new;
    request.setTextPayload(body, JSON_CONTENT_TYPE);
    foreach [string, string] [name, value] in signedHeaders.entries() {
        request.setHeader(name, value);
    }
    return request;
}

# Sends a signed request to the DynamoDB Streams endpoint.
#
# + streamClient - The HTTP client pointing at the resolved Streams endpoint
# + request - The signed request to send
# + return - The JSON response payload, or an `Error`
isolated function sendRequest(http:Client streamClient, http:Request request) returns json|Error {
    http:Response|http:ClientError response = streamClient->post(ROOT_PATH, request);
    if response is http:ClientError {
        return error Error(string `Error occurred while invoking the REST API: ${response.message()}`, response);
    }
    return handleResponse(response);
}

# Reads the response payload, turning a service failure into an `Error`. The error detail carries the status code, the
# request id, and the response body as `errorResponse` — verbatim, since a failure body is not always the service's
# JSON 1.0 error document. When the body cannot be read at all, `errorResponse` is absent and the read failure is the
# error's cause.
#
# + response - The response received from the service
# + return - The JSON response payload, or an `Error`
isolated function handleResponse(http:Response response) returns json|Error {
    // DynamoDB Streams answers every successful operation with 200; there is no other success status.
    if response.statusCode == http:STATUS_OK {
        json|error payload = response.getJsonPayload();
        if payload is error {
            return error ResponseHandlingError(
                    string `Error occurred while reading the response payload: ${payload.message()}`, payload);
        }
        return payload;
    }

    string|error requestId = response.getHeader(REQUEST_ID_HEADER);
    string message = string `The DynamoDB Streams operation failed with status ${response.statusCode}`;
    string|error body = response.getTextPayload();
    if body is error {
        return error Error(message, body, httpStatusCode = response.statusCode,
            requestId = requestId is string ? requestId : "");
    }
    return error Error(message, httpStatusCode = response.statusCode, requestId = requestId is string ? requestId : "",
        errorResponse = body);
}
