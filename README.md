# aws: an AWS SDK for Xo

A community AWS SDK for the Xo language. Not affiliated with or endorsed by
Amazon Web Services. AWS and Amazon Web Services are trademarks of
Amazon.com, Inc. or its affiliates.

## Status

The first release is v0.1.0, for the core and every service module.
What is true today:

- **All 435 of AWS's published service models** have a generated client
  module, committed under `service/`, and every one type checks.
- **Offline suites pass:** AWS's Smithy protocol compliance tests (741
  cases across restJson1, restXml, awsJson1_0, awsJson1_1, awsQuery and
  ec2Query), the SigV4 and SigV4a signing suites, the endpoint rule tests
  carried in every model, the JMESPath compliance suite, and the event
  stream codec vectors.
- **LocalStack:** S3, DynamoDB, SQS, SNS, STS, Secrets Manager, Lambda,
  EC2 and Kinesis, with S3 signature checking on.
- **Real AWS, 2026-11-04** (ca-central-1, eu-north-1):
  - S3: objects, multipart upload, CopyObject, paginators, waiters,
    presigned PUT and GET, modeled errors;
  - S3 Control and a Multi-Region Access Point, signed with SigV4a;
  - DynamoDB, SQS, SNS, STS (including a presigned GetCallerIdentity),
    Secrets Manager and EC2;
  - Kinesis SubscribeToShard (an output event stream);
  - Polly, and Transcribe Streaming (an input event stream with chained
    signatures);
  - Lambda InvokeWithResponseStream.

- **Real AWS read sweep, 2026-11-05** (ca-central-1): one free List,
  Describe or Get call per service, chosen from the models, for the 366
  services that have one needing no input. 243 succeeded. The other 123
  returned errors that the SDK parsed into the operation's typed errors:
  - 76 services are not offered in the region (DNS);
  - 28 need access, an opt-in or a subscription;
  - 16 rejected the request (the service wants input the model leaves
    optional, or the account is not onboarded);
  - 3 answered with no error code or with silence (one never answers).

  No call failed to sign or to decode. The 69 services left out have no
  read call that needs no input, or bill per call.

Hand-written behavior from the other AWS SDKs (flexible checksums, S3
Express sessions, account ID endpoints, endpoint discovery,
cross-region presigned URLs, hand-written paginators and more) is
listed in [docs/customizations.md](docs/customizations.md), each with
its test. The few items still open are listed there too.

The design is in [docs/decisions](docs/decisions/README.md), and
[docs/usage.md](docs/usage.md) shows how to use it. Licensed under
Apache-2.0 (LICENSE, NOTICE).

## Requirements

Xo 0.39.0 or later, except for two cases:

- A program that uses DynamoDB together with `select` needs Xo 0.40 or
  later (or main at or after 5dd0b3f4e). Earlier versions fail to build
  it because DynamoDB's `Select` type clashes with a runtime name.
- This repository's own tests need Xo main at or after 0e1d7b177, which
  makes the test network full duplex.
- On arm64, the native backend cannot build programs that use
  MediaConvert or WAFV2 yet (in 0.39.0 and on main;
  [xo-issues](docs/reports/xo-issues.md) entries 13 and 14). Build those
  with `--backend=llvm`.
- With Xo 0.39.0, the first native build of a program after Xo has
  cached its std can fail to link with `duplicate symbol
  _xo_f_zero__val_...`. Build again, or set `XO_BACKEND_CACHE=off`.
  Fixed on Xo main at 842702e6d ([xo-issues](docs/reports/xo-issues.md)
  entry 12).

Both were checked against the 0.39.0 release: it builds and passes
everything else, fails to build DynamoDB with `select`
(`integration/dynamodb_select_test.xo`), and deadlocks in the duplex
test.

## Install

Each service is its own module, next to the core module
`github.com/xo-lang/aws`. Require the core and the services you use in
your `xo.mod`:

```
module example.com/app
edition preview

require github.com/xo-lang/aws v0.1.0
require github.com/xo-lang/aws/service/s3 v0.1.0
require github.com/xo-lang/aws/service/dynamodb v0.1.0
```

Then import the packages you use:

```
use github.com/xo-lang/aws/config
use github.com/xo-lang/aws/service/s3
```

Versions are git tags: `vX.Y.Z` for the core and `service/<name>/vX.Y.Z`
for a service (`service/s3/v0.1.0`). v0.1.0 tags every module at one
commit; after it, each module gets a new tag only when it changes.

## Layout

A hand written core module, `github.com/xo-lang/aws`, holds the parts
every service shares:

| Package | What it does |
|---|---|
| `sigv4`, `sigv4a` | Signature Version 4 (HMAC) and 4a (ECDSA P-256, multi-region), and the chained event stream signer |
| `credentials`, `config` | static, environment and cached credentials; shared config and credentials files |
| `endpoints` | the Smithy endpoint rules engine and its standard library |
| `transport` | signing, retries (the standard retry mode), clock skew correction, streamed bodies |
| `protocol` | restJson1, restXml, awsJson1_0 and 1_1, awsQuery, ec2Query |
| `eventstream` | the `application/vnd.amazon.eventstream` codec and an incremental decoder |
| `jmespath`, `waiter` | JMESPath (the full compliance suite passes) for waiter matchers, and the waiter loop |
| `retry` | the standard retry strategy and its token bucket |

There is one generated module per service under `service/`
(`github.com/xo-lang/aws/service/s3`, `.../service/dynamodb`, ...). The
generator in `codegen/` reads AWS's Smithy JSON models the way
aws-sdk-go-v2 is generated, and the API is shaped like aws-sdk-go-v2's
so Go users find it familiar.

## Using a client

```
use github.com/xo-lang/aws/config
use github.com/xo-lang/aws/service/s3

fn main(os: Os) -> () ! Error {
  // region, credentials, retries and endpoint URLs from the environment
  // and the shared config files, as the other AWS SDKs read them
  let cfg = config.load_default_config(os.env, os.fs, os.net, os.clock, os.rand)?
  let c = s3.from_config(os.net, os.clock, os.rand, cfg)?
  c.put_object(s3.PutObjectRequest{bucket: "my-bucket", key: "hello.txt", body: b"hi"})?
  Ok(())
}
```

`s3.new` takes `s3.Options` directly (region, credentials such as
`credentials.static_provider`, an endpoint for a local emulator), and
`s3.options_from_config(cfg)` gives the options to adjust with `with`
first.

Each operation is a method that returns its output or a typed error, one
variant per modeled error plus `Api`, `Send`, `InvalidInput` and
`Deserialize`:

```
match c.get_item(dynamodb.GetItemInput{table_name: table, key: key}) {
  Ok(out) => ...
  Err(dynamodb.GetItemErr.ResourceNotFoundException(_)) => ...
  Err(e) => ...
}
```

Generated alongside the operations:

- Paginators, for every `smithy.api#paginated` operation:
  ```
  var pages = s3.new_list_objects_v2_paginator(c, s3.ListObjectsV2Request{bucket: b})
  while pages.has_more_pages() {
    let page = pages.next_page()?
    ...
  }
  ```
- Waiters, for every `smithy.waiters#waitable` operation, with Smithy's
  jittered exponential delay:
  ```
  dynamodb.wait_until_table_exists(c, dynamodb.DescribeTableInput{table_name: t}, 5m)?
  ```
- Event streams. An operation with an output stream returns a reader
  (`while let Some(e) = events.next()? { ... }`), and one with an input
  stream returns a stream with `send`, `close_send` and `next`, each
  event signed in the chain.
- Presigned requests (`presign_get_object`, `presign_put_object`, ...,
  STS `presign_get_caller_identity`), as aws-sdk-go-v2's presign clients.
- Endpoint resolution from each model's rules, FIPS, dual stack and
  SigV4a included.

## Generating

```
cd codegen
xo run ./cmd/gen -- service s3 -          # writes ../service/s3
xo run ./cmd/gen -- aws s3 /tmp/s3-check  # any directory
```

All 435 services are committed under `service/`.
`scripts/generate-services.sh` regenerates them, and
`scripts/check-all-services.sh` checks that the committed output is what
the generator writes and type checks every service module.
Generated files are cut at about 448 KiB, and the generator fails on any
file over 512 KiB.

## Testing policy

Every gate and every emulator script runs offline, with invented
credentials:

- AWS's Smithy protocol compliance tests;
- the SigV4 and SigV4a signing test suites;
- the endpoint rules tests carried in each service model;
- tests on Xo's in-process test network;
- local emulators (LocalStack, MinIO) in Docker.

Real AWS is opt in. `scripts/integration-aws.sh` runs against AWS only
when `XO_AWS_REAL=1` is set together with `XO_AWS_EXPECT_ACCOUNT`, the
account the credentials must belong to. It is never part of a gate, and
it cleans up everything it creates. See
[docs/real-aws-tests.md](docs/real-aws-tests.md) for the steps and the
guards, and [docs/real-aws-policy.json](docs/real-aws-policy.json) for an
IAM policy limited to the resources the tests create.

## Versioning and compatibility

Each module follows semantic versioning on its own:

- A service module's minor version goes up when AWS adds operations,
  members or enum values to its model.
- A service module's patch version goes up for a generator fix that
  changes no API.
- The core module's minor version goes up for new features (a credential
  provider, a protocol detail). A major version goes up only for a
  breaking API change.
- Each service module requires the lowest core version it needs, and
  your program builds with the highest core version any module requires.

Before 1.0, a minor version may break the API. Breaking changes are
listed in the release notes.

## Reporting issues and security

- **Bugs and requests:** open an issue at
  https://github.com/xo-lang/aws/issues. Include the Xo version, the
  service and operation, and the error.
- **Never put credentials in an issue,** and none of: access keys,
  session tokens, account IDs, ARNs, request signatures, or
  configuration files. Replace them with placeholders.
- **Security problems:** report them privately through GitHub's
  "Report a vulnerability" on the repository's Security tab, not in a
  public issue.

## Contributing

- Generated code (`service/`, `internal/protocoltest/`) is never edited
  by hand. Change the generator in `codegen/` and regenerate (see
  [Generating](#generating)).
- Run `scripts/gate.sh` and `scripts/check-public.sh` before sending a
  change.
- Hand-written code (the core packages, the generator, the scripts) is
  reviewed like any other code. Commits must carry no credentials or
  private values; check-public and gitleaks enforce this.
