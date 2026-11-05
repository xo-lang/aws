# Service customizations

The other AWS SDKs add hand-written behavior that the Smithy models do
not describe. This page lists every one in aws-sdk-go-v2 (its
`service/*/internal/customizations`, the hand-written files next to the
generated ones, `service/internal/*`, and the codegen's
`customization` package), checked against botocore's and the Java v2
SDK's lists, and says what this SDK does about each.

Status:

- **Yes**: handled, with the test named.
- **Rules**: needs nothing beyond the model; the endpoint rules or a
  trait already carry it.
- **No**: not handled yet. The next step names the fix.

The audit was made against aws-sdk-go-v2 at commit 0dedb8162
(2026-11-04).

## Signing, auth and transport

| Customization | Services | Status | Test or next step |
|---|---|---|---|
| SigV4, and S3's variant (no path normalization, `X-Amz-Content-Sha256`) | all; S3, S3 Control | Yes | `sigv4/sigv4_test.xo` (the suite); `integration/s3control_test.xo` |
| SigV4a when the endpoint rules choose it (Multi-Region Access Points, EventBridge global endpoints, CloudFront KeyValueStore, SESv2) | S3, EventBridge, CloudFront KVS, SESv2 and others | Yes (Rules) | `sigv4a/sigv4a_test.xo`; `transport/transport_test.xo`; real AWS step 13 |
| No auth (`smithy.api#auth: []`) and optional auth: sent unsigned | STS AssumeRoleWithWebIdentity and AssumeRoleWithSAML, Cognito Identity and Identity Provider, SSO, SSO OIDC, Sign-In | Yes | `integration/auth_test.xo`; `transport/transport_test.xo` "auth None and Optional" |
| Bearer token auth (`smithy.api#httpBearerAuth`; Bedrock API keys from `AWS_BEARER_TOKEN_BEDROCK`) | Bedrock, Bedrock Runtime, CodeCatalyst | No | a `token` provider in `Options` and `Signing.auth = Bearer`, sending `Authorization: Bearer` |
| S3 Express One Zone session auth (CreateSession credentials, `sigv4-s3express`) | S3 directory buckets | No | a session cache keyed by bucket, signing with `x-amz-s3session-token` |
| Retry: IDPCommunicationError retryable | STS | Yes | `retry/retry_test.xo` |
| Clock skew correction | all | Yes | `transport/transport_test.xo` "clock skew" |
| Long polling operations keep retrying when the retry quota is empty | SQS ReceiveMessage and similar | No | a `long_poll` flag on the request that bypasses the quota |
| `Accept-Encoding: identity` (bodies as stored) | all (S3 needs it) | Yes | `transport/transport_test.xo` "gzip bodies" |
| `Expect: 100-continue` for large S3 uploads | S3 PutObject, UploadPart | No | not needed for correctness; an optimization once std/http supports it |
| Request compression (`requestCompression`, gzip) | CloudWatch PutMetricData | Yes | protocol tests (`internal/protocoltest`) |
| Idempotency tokens filled in | all with `idempotencyToken` | Yes | protocol tests |
| Lambda recursion detection (`X-Amzn-Trace-Id` from `_X_AMZN_TRACE_ID` inside Lambda) | all | No | read the variable in `from_config` and add the header |
| User agent features and metrics | all | No (only a plain user agent) | not needed for correctness |

## Checksums and integrity

| Customization | Services | Status | Test or next step |
|---|---|---|---|
| Flexible checksums: CRC32 when the operation requires one, the caller's algorithm otherwise (`aws.protocols#httpChecksum`) | S3 (DeleteObjects and 24 other operations require one) | Yes | `checksum/checksum_test.xo`; `integration/checksum_test.xo` |
| `Content-MD5` for `httpChecksumRequired` | S3 Control | Yes | generated serializers |
| Response checksum validation (`ChecksumMode: ENABLED`) | S3 GetObject, HeadObject | No (`checksum.validate` exists) | wrap the streamed body to check at its end |
| Trailing checksums with aws-chunked encoding for streamed uploads | S3 | No | needed only for unsized streams |
| DynamoDB response CRC32 (`X-Amz-Crc32`) | DynamoDB | No | check the header against the body before decoding |
| SQS message MD5 checks (SendMessage, SendMessageBatch, ReceiveMessage) | SQS | No | compare `MD5OfMessageBody` and the attributes' MD5 |
| Glacier tree hash and `X-Amz-Content-Sha256` | Glacier | Yes | `checksum/checksum_test.xo` "tree hash"; `integration/customize_test.xo` |

## Endpoints and request shape

| Customization | Services | Status | Test or next step |
|---|---|---|---|
| Endpoint rules: virtual host and path style buckets, ARNs, access points, Outposts, Object Lambda, dual stack, FIPS, accelerate | S3, S3 Control | Rules | the endpoint tests in each model (`scripts/check-endpoints.sh`) |
| S3 Control: no host prefix on top of the rules' account host | S3 Control | Yes | `integration/s3control_test.xo` |
| Account ID endpoints (`AWS::Auth::AccountId`, filled from the credentials) | DynamoDB, DynamoDB Streams, Kinesis, EventBridge | Partly: an `account_id` option, not filled from credentials | fill it from the credentials' account when the mode allows |
| Endpoint discovery (`aws.api#clientEndpointDiscovery`) | Timestream Write and Query (required), DynamoDB (optional, off as in aws-sdk-go-v2) | Yes for required; a configured endpoint skips it | `discovery/discovery_test.xo`; `integration/discovery_test.xo`. Next: forget the address on InvalidEndpointException |
| Errors in a 200 response | S3 (every operation with a structured XML response) | Yes | `integration/s3_200_error_test.xo` |
| Route 53: `/hostedzone/`, `/change/` and `/delegationset/` prefixes trimmed from ids | Route 53 (34 members) | Yes | `integration/customize_test.xo` |
| Route 53: InvalidChangeBatch error body | Route 53 ChangeResourceRecordSets | Yes | `integration/customize_test.xo` "Route 53 errors" |
| XML error members matched without case (`message` modeled, `<Message>` sent) | Route 53 and other XML services | Yes | `integration/customize_test.xo` "Route 53 errors"; protocol tests |
| Glacier: account id `-` by default, `x-amz-glacier-version` | Glacier | Yes | `integration/customize_test.xo` |
| API Gateway: `Accept: application/json` | API Gateway | Yes | `integration/customize_test.xo` |
| Machine Learning: Predict goes to the PredictEndpoint input | Machine Learning | Yes | `integration/customize_test.xo` |
| Cross-region presigned URL (SourceRegion, then PreSignedUrl filled) | RDS, DocumentDB, Neptune (CopyDBSnapshot, CreateDBCluster, ...), EC2 CopySnapshot | No | a `source_region` input that presigns the same call in that region |
| S3 GetBucketLocation's unwrapped root element | S3 | No test yet | a test with an empty and a set constraint |
| S3 `Expires`: an unparseable date does not fail the response | S3 GetObject, HeadObject | No test yet | a test with a bad date |
| Presigned URLs | S3 (GetObject, PutObject, ...), STS GetCallerIdentity | Yes | `transport/transport_test.xo`, LocalStack, real AWS steps 1 and 2 |
| Polly SynthesizeSpeech presigned URL | Polly | No | add it to the presign list |
| S3 presigned POST | S3 | No | a form policy signer |
| Event streams (signed input streams, output streams) | S3 Select, Kinesis, Transcribe Streaming, Lambda, Bedrock Runtime and others | Yes | `eventstream/`, real AWS steps 3, 9, 10, 11, 12 |

## Model fixes

| Customization | Services | Status | Test or next step |
|---|---|---|---|
| EC2's unboxed members treated as optional | EC2 | Yes (every member is optional, decision 0004) | protocol tests |
| Defaults not filled in, required members optional | all | Yes (decision 0004) | protocol tests (skips listed in `codegen/gen/gen.xo`) |
| Paginators and waiters the models leave out (S3 ListObjectVersions, Route 53, DynamoDB, Kinesis) | those services | No | hand-written paginators where aws-sdk-go-v2 has them |
