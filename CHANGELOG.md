# Changes

Changes to the core module and the generator, newest first. Each module
is versioned and tagged on its own (README, Versioning and
compatibility); a generator fix lists the service modules it touches.

## Unreleased

Header numbers and booleans are parsed as aws-sdk-go-v2 parses them
(behavior fix, 54 service modules regenerated):

- An integer header is Go's `strconv.ParseInt(v, 0, bits)` for its
  size (8, 16, 32 or 64 bits): base prefixes (`0x`, `0o`, `0b`, and
  `0` for octal), underscores between digits, and Go's errors
  (`strconv.ParseInt: parsing "128": value out of range`). Before, only
  decimal text read, with no range check.
- A boolean header is Go's `strconv.ParseBool` (`1`, `t`, `T`, `TRUE`,
  `true`, `True` and the false forms). Any other text is Go's error.
  Before, anything but `true` read as false.
- A double header is Go's `strconv.ParseFloat(v, 64)`, errors included.
  A float header is unchanged until decision 0010 (Proposed) settles
  how Smithy `float` members are typed.
- DynamoDB's `X-Amz-Crc32` is Go's `strconv.ParseUint(v, 10, 32)`: one
  that does not parse fails with Go's text (`unable to parse checksum
  header abc, strconv.ParseUint: parsing "abc": invalid syntax`). A
  mismatch fails with Go's words (`response did not match expected
  checksum, <want>, <got>`). Go itself lets that call succeed, a
  deliberate difference (README).
- `protocol/rest`: `go_parse_bool`, `go_parse_int`, `go_parse_uint` and
  `go_parse_float` (32 or 64 bits, the 32-bit result rounded once to
  the nearest float32), checked against go1.26 strconv on 407 inputs
  (`strconvvectors_test.xo`).

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
