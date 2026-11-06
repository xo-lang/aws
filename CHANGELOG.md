# Changes

Changes to the core module and the generator, newest first. Each module
is versioned and tagged on its own (README, Versioning and
compatibility); a generator fix lists the service modules it touches.

## Unreleased

Response headers that repeat are read as aws-sdk-go-v2 reads them
(behavior fix, every service module regenerated):

- A header bound to a scalar member is its first field, trimmed, as Go's
  generated deserializers read `Header.Values(name)[0]` with
  `strings.TrimSpace`. Before, the fields were joined with `, `, so a
  repeated `ETag` read as `"e1", "e2"` and a repeated number or date did
  not parse.
- A header bound to a list takes every field, each split on its own as
  smithy-go's `SplitHeaderListValues` and
  `SplitHTTPDateTimestampHeaderListValues` split it, and each item
  trimmed. smithy-go's errors are kept: an unclosed quote, text after a
  quoted item, a quoted item `strconv.Unquote` refuses, or an even number
  of commas (above one) in an HTTP-date list fails the call. An empty
  field is one empty item.
- A prefix-header map (S3's `x-amz-meta-*`) holds each matching name's
  first field, trimmed, under the rest of the name lower-cased, as Go's.
- The core module's own reads take the first field, as Go's
  `Header.Get`: `Date` for clock skew, `X-Amzn-ErrorType` and the
  request ID headers in error responses (restJson1, awsQuery, restXml),
  the SSO portal's error type, and the IMDS token TTL. DynamoDB's
  `X-Amz-Crc32` check reads the first field too.
- `protocol/rest`: `first_header`, `split_header_values`,
  `split_http_date_values` and `go_trim_space` replace
  `split_header_list` and `split_http_dates`, checked against smithy-go
  v1.28.8 on 48 header field lists (`headervectors_test.xo`).
