# 0003: The hand written core

Status: Proposed (Xo AWS 1, 2026-11-04)

## Context

The owner decided (2026-11-04) the core is written by hand: SigV4 (SigV4a
later), the credentials chain, retries and backoff, the endpoint rules
engine, the protocols, event streams, paginators and waiters. Each piece
has a reference behavior in aws-sdk-go-v2 and, where AWS publishes one, a
cross SDK specification and test suite. Xo's std already has what most of
it needs (spec/std.md: http client with streaming bodies and HTTP/2,
json, xml, crypto hashes and HMAC, ECDSA P-256, crc32 IEEE and Castagnoli,
time formats, url, base64, binary, backoff).

## Decision

Each item names its reference and its test source (0005).

### Signing (`sigv4`, `sigv4a`)

- SigV4 per AWS's specification: canonical request (URI encoding once
  for S3, twice for other services; sorted, encoded query; lower cased,
  trimmed, sorted signed headers), string to sign, signing key derived
  by `crypto.hmac(Sha256, ...)` and cached per (secret, date, region,
  service), `Authorization` header or presigned query.
- Payload: `X-Amz-Content-Sha256` with the body's hash, `UNSIGNED-PAYLOAD`
  (presign, and S3 over TLS when the user opts in), or
  `STREAMING-AWS4-HMAC-SHA256-PAYLOAD` / `STREAMING-UNSIGNED-PAYLOAD-TRAILER`
  for aws-chunked uploads with a trailing checksum.
- The signer gets the time from the `Clock` capability, never a global, so
  tests sign at a fixed time.
- SigV4a after the first services: the ECDSA P-256 key is derived from
  the secret with AWS's fixed counter KDF (HMAC-SHA256), then built as a
  SEC 1 DER key and loaded with `crypto.parse_private_key`; signatures
  with `crypto.sign`. A std way to build a key from a raw scalar would be
  cleaner (0006 item 5).
- Tested against the AWS signing test suite (v4 and v4a cases) shipped in
  awslabs/aws-c-auth (Apache-2.0) and the `get-vanilla`, `post-x-www-form`,
  ... cases, and S3's documented examples.

### Credentials (`credentials`, `config`)

- `Credentials { access_key_id: Str, secret_access_key: Secret[Str],
  session_token: Secret[Str]?, expires: Time?, source: Str }`. Secrets use
  Xo's `Secret[T]`, which renders as `<redacted>` in Debug and logs.
- Providers, each a value implementing `CredentialsProvider`
  (`fn retrieve(self) -> Credentials ! CredentialsErr uses (net.dial,
  clock)`): static; environment (`AWS_ACCESS_KEY_ID`, ...); shared config
  and credentials files (profiles, `source_profile` chains with cycle
  detection, `role_arn` assume role through STS, `credential_process`,
  `sso_session`); SSO (the token cache file and the portal's
  GetRoleCredentials, refreshing the token through SSO OIDC); web identity
  (STS AssumeRoleWithWebIdentity from a token file); ECS container
  (`AWS_CONTAINER_CREDENTIALS_RELATIVE_URI` and `_FULL_URI` with the
  authorization token and its file); EC2 instance metadata (IMDSv2 token
  then role credentials, with IMDSv1 fallback off by default).
- `credential_process` runs a command, so it needs the `Proc` capability;
  `load_default_config` takes an optional `proc: Proc?`, and without one a
  profile that names a process fails with an error saying so (no silent
  skip). This keeps `uses proc` out of every program that never asked for
  it.
- The default chain is aws-sdk-go-v2's order. A caching wrapper refreshes
  before expiry (a window with jitter) and lets one task refresh while
  others wait (`Mutex`), as Go's `CredentialsCache`.
- The STS and SSO calls the providers make use small hand written
  clients inside the core (two operations each), so the core never imports
  a generated service module (no cycle).
- Loading reads files and environment through the `Fs` and `Env`
  capabilities passed in; tests pass `MemFs` and `FakeEnv` (0005). The
  file parser follows the shared config file specification of the AWS
  SDKs and tools reference guide, tested with the cross SDK config file
  test cases.

### Configuration (`config`)

`config.load_default_config(env, fs, opts...)` gives an `aws.Config`:
region (env, profile, IMDS optional), credentials provider (chain),
retry strategy, retry mode and max attempts, `use_fips`, `use_dualstack`,
custom endpoint URL (`AWS_ENDPOINT_URL`, per service
`AWS_ENDPOINT_URL_<SERVICE>`, and the profile's `services` section), app
id, account id endpoint mode, request checksum calculation and response
validation settings, and the HTTP client. Every setting has the precedence
the SDKs and tools reference guide defines.

### Retries (`retry`)

- Standard mode: max 3 attempts, exponential backoff with full jitter
  capped at 20 s, a retry quota token bucket (500 tokens, 5 per retry, 10
  per timeout, refunded on success); retryable: throttling and transient
  error codes, 5xx except 501, `ClientErr.Connect` (always safe),
  `ClientErr.Timeout` for idempotent operations, and the model's
  `@retryable` errors.
- Adaptive mode (client side rate limiting) later, as Go's.
- Clock skew: on a skew error the client records the offset from the
  `Date` response header and signs later attempts with the corrected time.
- Jitter comes from the `Rand` capability, sleeps from `Clock`, so retry
  tests run on Xo's fake clock with no real waiting.

### Endpoints (`endpoints`)

The rules engine's standard library: `isSet`, `not`, `booleanEquals`,
`stringEquals`, `getAttr`, `substring`, `uriEncode`, `parseURL`,
`isValidHostLabel`, and the AWS functions `aws.partition`, `aws.parseArn`,
`aws.isVirtualHostableS3Bucket`; the partitions table embedded. Generated
code (0002) calls these. An `EndpointResolver` option lets a user replace
the generated resolver (for emulators, the custom endpoint URL is enough).

### Protocols (`protocol/...`)

restJson1, restXml, awsJson1_0, awsJson1_1, awsQuery, ec2Query: shared
helpers for HTTP bindings (labels with greedy labels, query lists,
headers with list and timestamp formats, prefix headers, payload members,
`@httpResponseCode`), the body codecs, and error parsing per protocol
(`__type` with its namespace and URI forms, `X-Amzn-Errortype`, XML
`Error/Code`, query's `ErrorResponse`, EC2's `Response/Errors/Error`, S3's
200 response with an error body). Later, Smithy RPC v2 CBOR (a CBOR codec;
AWS has begun moving services to it): see 0006 item 6.

### Event streams (`eventstream`)

The `application/vnd.amazon.eventstream` framing (prelude, header types,
CRC32 of prelude and message with std/crc32), a decoder fed by the
response body's reads, signed event messages for input streams (each
message signed with the previous signature, the chunk signing chain), and
generated per operation union types for the events. Output streams
(S3 SelectObjectContent, Lambda InvokeWithResponseStream, Bedrock) come
first; input and duplex streams (Transcribe streaming) need HTTP/2 full
duplex, which std/http has (decision 0433 of Xo).

### Checksums (`checksum`)

Flexible checksums for S3 and others: CRC32 and CRC32C (std/crc32), SHA1
and SHA256 (std/crypto), CRC64NVME (written here in Xo until std has
it, 0006 item 4), the `aws-chunked` content encoding with a trailing
checksum, and response validation, with the request and response
settings defaulting to `when_supported` as current AWS SDKs do.

### Paginators and waiters

- Paginators from the `smithy.api#paginated` trait: a generated
  `<Op>Paginator` holding the client and the input with
  `has_more_pages()` and `next_page() -> Output ! Err`, stopping when the
  token is absent or repeats (Go's duplicate token check). Optional
  `limit` per page.
- Waiters from `smithy.waiters#waitable`: a generated `<Name>Waiter` with
  `wait(input, max_wait)`, acceptors evaluated by a small JMESPath subset
  evaluator in the core (the subset AWS waiters use: fields, indexes,
  projections, flatten, filters, comparisons, `length`, `contains`), with
  exponential delay between min and max delay and jitter from `Rand`.

## Consequences

- No generated code is needed to test the core: signing, credentials,
  retries and endpoints all have published test vectors.
- The core holds about the same set of packages as aws-sdk-go-v2's root
  module plus smithy-go, in one module.
- Capabilities make the SDK deterministic under test: fixed time, scripted
  random numbers, fake files, fake environment, and a fake network.

## Alternatives

- Wrap aws-sdk-go-v2 through `use go`: fast to ship, but it is the Go SDK
  in Xo clothing, only on the Go backend's terms, not a native SDK, and
  not what the owner decided.
- Interpret every request from the model at run time (as boto does from
  JSON): smaller binaries, no compile time types for inputs and outputs.
  Rejected: typed Input and Output structs are an owner decision.
