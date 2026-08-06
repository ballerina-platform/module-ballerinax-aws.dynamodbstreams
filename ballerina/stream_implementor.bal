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

import ballerina/lang.runtime;

# Fetches a single page of streams.
type ListStreamsPageFetcher isolated function (ListStreamsInput request) returns ListStreamsOutput|Error;

# Fetches a single page of stream records.
type GetRecordsPageFetcher isolated function (GetRecordsInput request) returns GetRecordsOutput|Error;

# Iterates over every stream of the result set, fetching the next page only once the current one is exhausted.
class StreamIterator {
    private final ListStreamsPageFetcher fetchPage;
    private final ListStreamsInput request;
    private Stream[] currentPage = [];
    private int index = 0;
    private string? nextStartStreamArn = ();
    private boolean exhausted = false;

    isolated function init(ListStreamsInput request, ListStreamsPageFetcher fetchPage) {
        self.request = request.clone();
        self.fetchPage = fetchPage;
    }

    public isolated function next() returns record {|Stream value;|}|Error? {
        // Keep fetching until a page yields a value or the result set is exhausted. A page can legitimately come
        // back empty while still carrying a continuation token, so the emptiness of one page must not be mistaken
        // for the end of the result set — nor may an empty page be indexed into.
        while self.index >= self.currentPage.length() {
            if self.exhausted {
                return;
            }
            check self.fetchNextPage();
        }
        record {|Stream value;|} next = {value: self.currentPage[self.index]};
        self.index += 1;
        return next;
    }

    private isolated function fetchNextPage() returns Error? {
        ListStreamsInput request = self.request.clone();
        string? startStreamArn = self.nextStartStreamArn;
        if startStreamArn is string {
            request.exclusiveStartStreamArn = startStreamArn;
        }

        ListStreamsOutput page = check self.fetchPage(request);
        self.currentPage = page.streams;
        self.index = 0;
        self.nextStartStreamArn = page?.lastEvaluatedStreamArn;
        // Absent `lastEvaluatedStreamArn` means this was the final page.
        self.exhausted = self.nextStartStreamArn !is string;
    }
}

# Polls a single shard and iterates over the stream records it yields, backing off between empty polls.
#
# This iterator never crosses a shard boundary: it completes once the shard is closed and fully read, leaving the
# child shards to the caller.
class RecordIterator {
    private final GetRecordsPageFetcher fetchPage;
    private final int? recordLimit;
    private final decimal initialPollInterval;
    private final decimal maxPollInterval;
    private final int? maxIdlePolls;
    private Record[] currentPage = [];
    private int index = 0;
    private string? shardIterator;
    private decimal pollInterval;
    private int idlePolls = 0;

    isolated function init(PollRecordsInput request, GetRecordsPageFetcher fetchPage) {
        self.fetchPage = fetchPage;
        self.shardIterator = request.shardIterator;
        self.recordLimit = request?.'limit;
        self.maxIdlePolls = request?.maxIdlePolls;
        decimal maxInterval = request.maxPollInterval > 0d ? request.maxPollInterval : DEFAULT_MAX_POLL_INTERVAL;
        decimal interval = request.pollInterval > 0d ? request.pollInterval : DEFAULT_POLL_INTERVAL;
        if interval > maxInterval {
            interval = maxInterval;
        }
        self.maxPollInterval = maxInterval;
        self.initialPollInterval = interval;
        self.pollInterval = interval;
    }

    public isolated function next() returns record {|Record value;|}|Error? {
        while self.index >= self.currentPage.length() {
            string? shardIterator = self.shardIterator;
            // An absent next shard iterator means the shard has been closed and fully read.
            if shardIterator !is string {
                return;
            }
            if self.idlePolls > 0 {
                int? maxIdlePolls = self.maxIdlePolls;
                if maxIdlePolls is int && self.idlePolls >= maxIdlePolls {
                    return;
                }
                // Back off before re-polling a shard that returned nothing, so that tailing a quiet shard (the
                // common case with the `LATEST` iterator type) does not spin against the service.
                runtime:sleep(self.pollInterval);
                decimal nextInterval = self.pollInterval * 2;
                self.pollInterval = nextInterval > self.maxPollInterval ? self.maxPollInterval : nextInterval;
            }
            check self.fetchNextPage(shardIterator);
        }
        record {|Record value;|} next = {value: self.currentPage[self.index]};
        self.index += 1;
        return next;
    }

    private isolated function fetchNextPage(string shardIterator) returns Error? {
        GetRecordsInput request = {shardIterator: shardIterator};
        int? recordLimit = self.recordLimit;
        if recordLimit is int {
            request.'limit = recordLimit;
        }

        GetRecordsOutput page = check self.fetchPage(request);
        self.currentPage = page.records;
        self.index = 0;
        self.shardIterator = page?.nextShardIterator;

        if self.currentPage.length() == 0 {
            self.idlePolls += 1;
        } else {
            self.idlePolls = 0;
            self.pollInterval = self.initialPollInterval;
        }
    }
}
