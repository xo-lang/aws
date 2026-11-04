# 0005: Testing without real AWS

Status: Proposed (Xo AWS 1, 2026-11-04)

## Context

The owner decided (2026-11-04) that testing uses AWS's Smithy protocol
compliance tests, the SigV4 test suite, MinIO and LocalStack in Docker,
and never real AWS. Real AWS testing needs the owner's explicit
permission, asked through the lead. This repository becomes public, so
fixtures must hold only invented values.

## Decision

### Layers

1. **Unit tests** (`_test.xo`, `xo test`) for every core package, on Xo's
   fakes: `FakeClock` (signing time, retry sleeps), seeded `Rand` (jitter),
   `MemFs` (shared config and credentials files, SSO token cache),
   `FakeEnv` (environment variables), `FakeNet` (HTTP handlers for STS,
   SSO, ECS, IMDS stubs). These run in seconds and form the per commit
   gate.
2. **Signing suites:** the AWS SigV4 and SigV4a request signing test suite
   (the `aws-signing-test-suite` cases in awslabs/aws-c-auth, Apache-2.0,
   copied into `sigv4/testdata/` with attribution in NOTICE), plus S3's
   documented signing examples and presigned URL cases. Every case's
   canonical request, string to sign, signature, and signed request must
   match byte for byte.
3. **Endpoint rules tests:** each service model carries
   `smithy.rules#endpointTests`; the generator emits them as
   `endpoints_test.xo` per service, so every generated service is tested
   against AWS's own expected endpoints. The rules interpreter (0002)
   checks the compiled code on the same cases.
4. **Protocol compliance tests:** Smithy's `aws.protocoltests.*` services
   (restJson1, restXml, awsJson1_0, awsJson1_1, awsQuery, ec2Query, and
   later rpcv2Cbor) from github.com/smithy-lang/smithy (Apache-2.0). They
   are Smithy IDL; the Smithy CLI converts them to the JSON AST once per
   pinned Smithy version, in Docker (`codegen/protocoltests/convert.sh`,
   no Java on the host), and the JSON is committed under
   `codegen/protocoltests/models/` with attribution. The generator turns
   their `httpRequestTests`, `httpResponseTests` and
   `httpMalformedRequestTests` into tests of generated test clients in
   `internal/protocoltest/` (its own module). A failing case is fixed in
   the core or generator, or listed in a skip file with its reason, as
   aws-sdk-go-v2 does.
5. **Emulator integration tests** (`integration/`, own module, opt in):
   MinIO for S3; LocalStack for S3, DynamoDB, SQS, STS, Secrets Manager,
   SNS, Lambda; DynamoDB Local for DynamoDB edge cases. If the current
   LocalStack image needs an account or token (it announced such a change
   for 2026), use a pinned older community image or moto's server
   (`motoserver/moto`, Apache-2.0) instead; this is checked before the
   first run. Containers start through the lead's Docker wrapper,
   one chain per run (start, run, stop), and only containers this run
   created are removed, by ID.
6. **Scale checks:** `xo check` and `xo build` time and peak memory of the
   largest generated services (EC2, S3, SageMaker), recorded per
   generator change that grows output (0002).

### Guards against reaching real AWS

- Credentials in tests and fixtures are the signing suite's
  (`AKIDEXAMPLE`, its published secret) or obviously invented ones
  (`AKIDTEST0000000000`), with account id `123456789012`, the documented
  example account.
- Integration tests give the client `os.net.only(["localhost",
  "127.0.0.1"])` (spec 6.3: an attenuated `Net` fails before any
  connection), and set a base endpoint to the emulator. A request to any
  `*.amazonaws.com` host fails with `Denied` instead of leaving the
  machine.
- Config loading in tests always gets `MemFs` and `FakeEnv`, so a
  developer's real `~/.aws` files and `AWS_*` variables are never read.
  An integration test that loads config gets an env built only from the
  test's own values.
- `scripts/check-public.sh`, run before every push, fails on: account ids
  other than `123456789012`, key ids other than the invented ones, ARNs
  with another account, IP addresses outside documentation and loopback
  ranges, `/Users/` or `/home/` paths, and email addresses; plus gitleaks
  over the whole history (default rules, or the Xo publish tools' config
  when present).

### Gates

- Per commit: unit tests of the touched packages, plus the signing and
  endpoint tests when signing or the rules engine changed.
- Before a release tag: every layer above except the scale checks, with
  the protocol tests on every protocol the release changes.
- Heavy runs (generator over all models, protocol tests across services,
  emulators) go through the Xo project's heavy job wrapper, or to the
  offload hosts for long runs.

## Consequences

- The SDK can reach v1 for a service without one real AWS call; the
  owner may later approve a small real AWS smoke suite in a sandbox
  account (not in this repository's history: its configuration would live
  outside the repo).
- The protocol tests cover what emulators get wrong (emulators accept
  sloppy requests that AWS rejects).

## Alternatives

- Record and replay real AWS traffic: needs real AWS and puts real
  responses (account ids, request ids) in fixtures. Rejected for now.
- Test only against emulators: they are lenient about signing, headers and
  encodings, and would let protocol bugs through. Used only as layer 5.
