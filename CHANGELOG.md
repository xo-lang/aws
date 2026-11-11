# Changes

Changes to the core module and the generator, newest first. Each module
is versioned and tagged on its own (README, Versioning and
compatibility); a generator fix lists the service modules it touches.

## Unreleased

JSON numbers (`protocol/jsonv`): a body's integer `-0` reads as +0 and
`"nan"`, `"INFINITY"` and the like as NaN and the infinities, as
smithy-go's JSON decoder reads them (its integer fast path and
`strings.EqualFold`); `-0.0` stays -0. The float32 integration test
expected this and failed since std/json reads `-0` as `-0.0`. Tests:
the Route 53 InvalidChangeBatch test registered `.../rrset/` for a
client that sends `.../rrset` (the model's URI), which only the native
FakeNet's old slash leniency matched, and the transport wire test
records its request in Router middleware, since the Router answers a
`//` path with a 307 to the cleaned path (xo v0.46.0, as Go's
ServeMux).

Release fix (`scripts/tag-modules.sh`): each changed service now
requires the root version tagged with it. Before, a service tag kept
`require github.com/xo-lang/aws v0.1.0`, so an app with no workspace
selected a core without the functions the service calls (a dry run in a
scratch clone of the release after v0.1.0 tagged 435 services that
way). The script now checks every changed service against the planned
root (`scripts/check-core-requires.sh --typecheck`: each core name a
service uses must exist at that version, then a type check against
that version's tree, offline), tags the root, raises each changed
service's require to it in one commit, and then tags the services. The
same dry run with the fix tags root v0.2.0, the services requiring it,
and an app with no workspace that gets s3vectors and acm type checks.

**Breaking:** Smithy `float` members are `Float32`, as aws-sdk-go-v2's
`float32` (decision 0010, accepted by the owner on 2026-11-06). A field,
list item or map value of a Smithy `float` that was `Float` is now
`Float32` in 54 service modules, each of them a minor version at its
next tag. Code that does arithmetic on one converts it (`Float(x)`).
Smithy `double` members stay `Float`.

- Reads round as Go's: a header once (`strconv.ParseFloat(v, 32)`, with
  Go's errors), a JSON, XML or query body twice (to float64, then
  `float32(f64)`), so `3.4028235677973366e38` is the largest float32 in
  a header and +Inf in a body.
- Writes are Go's shortest float32 text: `strconv.FormatFloat(v, 'f',
  -1, 32)` in a label, query string or header (`0.0000001`), and
  smithy-go's `encoding.EncodeFloat(v, 32)` in a JSON or XML body
  (`1e-7`, `1e+21`). Before, a float was written with its float64 digits
  (`1.100000023841858` for a value read as `1.1`).
- NaN and the infinities are Smithy's names everywhere. In an XML body
  Go's EncodeFloat panics on them; Xo writes the names.
- `protocol/rest`: `shortest32`, `float32_text`, `encode_float32` and
  `encode_float`; `jsonv.float32` and `jsonv.read_float32`;
  `xmlv.read_float32`. Checked against go1.26 on about 3,500 float32 bit
  patterns and 2,200 float64 to float32 roundings
  (`float32vectors_test.xo`), and end to end against s3vectors v1.17.3
  and cloudfront v1.75.4 (`integration/float32_test.xo`).
- The services with `Float32` members:
  amplifyuibuilder, appconfig, arcregionswitch, arczonalshift, b2bi,
  batch, bedrock, bedrockagent, bedrockagentcore,
  bedrockagentcorecontrol, bedrockagentruntime, bedrockruntime,
  chimesdkvoice, cleanrooms, cloudfront, cloudtrail, comprehend,
  comprehendmedical, connect, datazone, deadline, ec2, emr,
  frauddetector, gamelift, geomaps, globalaccelerator, iotsitewise,
  iotwireless, ivsrealtime, kendra, kendraranking, lightsail,
  location, lookoutequipment, machinelearning, mediapackagev2, mgn,
  odb, opensearchserverless, outposts, personalizeevents, qconnect,
  rdsdata, rekognition, rtbfabric, s3vectors, sagemaker,
  sagemakergeospatial, securityhub, sfn, textract, timestreaminfluxdb,
  transcribe.

An XML body writes a double as smithy-go's `encoding.EncodeFloat(v, 64)`
(behavior fix): `1e-7` and `1e+21` where Xo wrote `0.0000001` and
`1000000000000000000000`. It changes, besides the services above:
  autoscaling, cloudformation, cloudsearch, cloudwatch, docdb,
  elasticache, elasticbeanstalk, elasticloadbalancingv2, neptune, rds,
  redshift, route53, s3control, ses.

`scripts/changed-modules.sh` makes a member added, removed or changed (an
indented `pub` line) a minor bump; before, a field's new type was a
patch.

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
  A float header was left to decision 0010 (the Float32 entry above).
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
