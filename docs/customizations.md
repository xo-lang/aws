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
| Bearer token auth (`smithy.api#httpBearerAuth`; Bedrock API keys from `AWS_BEARER_TOKEN_BEDROCK`; CodeCatalyst's token from the profile's `sso_session`, refreshed through SSO OIDC, as aws-sdk-go-v2's BearerAuthTokenProvider) | Bedrock, Bedrock Runtime (used when a token is set), CodeCatalyst (always) | Yes | `integration/bearer_test.xo` (CodeCatalyst from an SSO session); `config/config_test.xo` "bearer tokens", "SSO settings" |
| S3 Express One Zone session auth (CreateSession credentials, `sigv4-s3express`): sessions cached by the base credentials' HMAC and the bucket, refreshed a minute before expiry; the token sent as `x-amz-s3session-token` (and in a presigned query) | S3 directory buckets | Yes | `integration/s3express_test.xo`; `credentials/credentials_test.xo` "session cache". Next: a real directory bucket in the real AWS steps |
| Retry: IDPCommunicationError retryable | STS | Yes | `retry/retry_test.xo` |
| Clock skew correction | all | Yes | `transport/transport_test.xo` "clock skew" |
| Long polling: when the retry quota stops a retry, back off before returning (aws-sdk-go-v2 behind `AWS_NEW_RETRIES_2026`; on here) | SQS ReceiveMessage, Step Functions GetActivityTask, SWF PollForActivityTask and PollForDecisionTask | Yes | `retry/retry_test.xo` "long poll" |
| `Accept-Encoding: identity` (bodies as stored) | all (S3 needs it) | Yes | `transport/transport_test.xo` "gzip bodies" |
| `Expect: 100-continue` for large S3 uploads | S3 PutObject, UploadPart | No | not needed for correctness; an optimization once std/http supports it |
| Request compression (`requestCompression`, gzip) | CloudWatch PutMetricData | Yes | protocol tests (`internal/protocoltest`) |
| Idempotency tokens filled in | all with `idempotencyToken` | Yes | protocol tests |
| Lambda recursion detection (`X-Amzn-Trace-Id` from `_X_AMZN_TRACE_ID` inside Lambda) | all | Yes | `config/config_test.xo`; `integration/bearer_test.xo` "trace id" |
| User agent features and metrics (UA 2.1: `api/<service>`, `app/<AWS_SDK_UA_APP_ID>`, and `m/` with aws-sdk-go-v2's codes: E retry mode, B waiter, C paginator, U to Y the request checksum, Z/a and b/c the checksum settings, P/Q/R the account ID mode, J an S3 Express session, L gzip, and the credential sources e, g, h, i, k, n, o, p, q, r, s, t, u, v, w, z, 0) | all | Yes, without versions (modules are tagged one by one) | `integration/useragent_test.xo`; `config/config_test.xo` (credential codes). Next: per module versions written at tag time |

## Checksums and integrity

| Customization | Services | Status | Test or next step |
|---|---|---|---|
| Flexible checksums (`aws.protocols#httpChecksum`): the caller's algorithm; else CRC32 when the operation requires one, and also when it only supports one unless `calculate_request_checksums` is false or the call carries a checksum ("when supported", the aws-sdk-go-v2 default) | S3 (DeleteObjects and 24 others require one; PutObject, UploadPart and 4 others support one) | Yes | `checksum/checksum_test.xo`; `integration/checksum_test.xo` "CRC32 by default"; `AWS_REQUEST_CHECKSUM_CALCULATION` or the profile's `request_checksum_calculation` = `when_required` turns the default off (`config/config_test.xo` "checksum settings", `integration/checksum_test.xo` "checksum settings reach") |
| `Content-MD5` for `httpChecksumRequired` | S3 Control | Yes | generated serializers |
| Response checksum validation: the mode sent and the body checked unless `validate_response_checksums` is false ("when supported", the aws-sdk-go-v2 default); multipart checksums skipped | S3 GetObject, GetObjectAnnotation | Yes | `integration/checksum_test.xo` "GetObject asks"; `AWS_RESPONSE_CHECKSUM_VALIDATION` or the profile's `response_checksum_validation` = `when_required` turns it off (same tests) |
| Trailing checksums with aws-chunked encoding for streamed uploads | S3 | No | needed only for unsized streams |
| DynamoDB response CRC32 (`X-Amz-Crc32`) | DynamoDB | Yes | `integration/integrity_test.xo` |
| SQS message MD5 checks (SendMessage, SendMessageBatch, ReceiveMessage) | SQS | Yes (bodies, as aws-sdk-go-v2) | `integration/integrity_test.xo` |
| Glacier tree hash and `X-Amz-Content-Sha256` | Glacier | Yes | `checksum/checksum_test.xo` "tree hash"; `integration/customize_test.xo` |

## Endpoints and request shape

| Customization | Services | Status | Test or next step |
|---|---|---|---|
| Endpoint rules: virtual host and path style buckets, ARNs, access points, Outposts, Object Lambda, dual stack, FIPS, accelerate | S3, S3 Control | Rules | the endpoint tests in each model (`scripts/check-endpoints.sh`) |
| S3 Control: no host prefix on top of the rules' account host | S3 Control | Yes | `integration/s3control_test.xo` |
| Account ID endpoints (`AWS::Auth::AccountId` from the credentials' account: `AWS_ACCOUNT_ID`, a profile's `aws_account_id`, an assumed role's ARN; mode "preferred" by default, `AWS_ACCOUNT_ID_ENDPOINT_MODE`) | DynamoDB, DynamoDB Streams, Kinesis, EventBridge | Yes | `integration/integrity_test.xo` "account endpoint"; `config/config_test.xo` "the account comes". Next: the account from SSO and process credentials |
| Endpoint discovery (`aws.api#clientEndpointDiscovery`), the address dropped on InvalidEndpointException | Timestream Write and Query (required), DynamoDB (optional, off as in aws-sdk-go-v2) | Yes for required; a configured endpoint skips it | `discovery/discovery_test.xo`; `integration/discovery_test.xo` |
| Errors in a 200 response | S3 (every operation with a structured XML response) | Yes | `integration/s3_200_error_test.xo` |
| Route 53: `/hostedzone/`, `/change/` and `/delegationset/` prefixes trimmed from ids | Route 53 (34 members) | Yes | `integration/customize_test.xo` |
| Route 53: InvalidChangeBatch error body | Route 53 ChangeResourceRecordSets | Yes | `integration/customize_test.xo` "Route 53 errors" |
| XML error members matched without case (`message` modeled, `<Message>` sent) | Route 53 and other XML services | Yes | `integration/customize_test.xo` "Route 53 errors"; protocol tests |
| Glacier: account id `-` by default, `x-amz-glacier-version` | Glacier | Yes | `integration/customize_test.xo` |
| API Gateway: `Accept: application/json` | API Gateway | Yes | `integration/customize_test.xo` |
| Machine Learning: Predict goes to the PredictEndpoint input | Machine Learning | Yes | `integration/customize_test.xo` |
| Cross-region presigned URL (SourceRegion, then PreSignedUrl filled) | RDS (4 operations), DocumentDB and Neptune (2 each), EC2 CopySnapshot | Yes: a `source_region` input field (modeled by EC2) | `integration/presign_autofill_test.xo` |
| S3 GetBucketLocation's unwrapped root element | S3 | Yes | `integration/s3_200_error_test.xo` "GetBucketLocation" |
| S3 `Expires`: an unparseable date does not fail the response | S3 GetObject, HeadObject | Rules: the pinned model types it as a string | none needed |
| Presigned URLs | S3 (GetObject, PutObject, ...), STS GetCallerIdentity | Yes | `transport/transport_test.xo`, LocalStack, real AWS steps 1 and 2 |
| Polly SynthesizeSpeech presigned URL (a GET with the input in the query) | Polly | Yes | `integration/polly_presign_test.xo` |
| S3 presigned POST (a signed policy with the bucket, the key unless a condition checks it, and the caller's conditions; field names in lower case as botocore sends them, since LocalStack looks for those) | S3 | Yes (`presign_post_object`, `sigv4.post_policy`) | `integration/presign_post_test.xo`; the LocalStack S3 round trip uploads a file through the form with signature checking on. Next: a real AWS upload in step 2 |
| Event streams (signed input streams, output streams) | S3 Select, Kinesis, Transcribe Streaming, Lambda, Bedrock Runtime and others | Yes | `eventstream/`, real AWS steps 3, 9, 10, 11, 12 |

## Model fixes

| Customization | Services | Status | Test or next step |
|---|---|---|---|
| EC2's unboxed members treated as optional | EC2 | Yes (every member is optional, decision 0004) | protocol tests |
| Defaults not filled in, required members optional | all | Yes (decision 0004) | protocol tests (skips listed in `codegen/gen/gen.xo`) |
| Paginators aws-sdk-go-v2 writes by hand (several markers, a truncation flag, or a token from the items) | S3 ListObjectVersions and ListMultipartUploads, Route 53 ListResourceRecordSets, DynamoDB BatchGetItem, Kinesis DescribeStream, Amplify Backend ListBackendJobs | Yes (`HAND_PAGERS` in codegen/gen/customize.xo) | `integration/paginators_test.xo` (all but Amplify Backend, which type checks) |
