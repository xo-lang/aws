# aws: an AWS SDK for Xo

A community AWS SDK for the Xo language. Not affiliated with or endorsed by
Amazon Web Services. AWS and Amazon Web Services are trademarks of
Amazon.com, Inc. or its affiliates.

Status: early development, not yet released. Every one of AWS's 435
published service models generates a client that type checks; the
clients for S3, DynamoDB, SQS, SNS, STS, Secrets Manager, Lambda, EC2
and Kinesis are tested against local emulators and AWS's protocol test
suites, and Transcribe Streaming's input event stream against an
in-process server on the test network. The
design is in [docs/decisions](docs/decisions/README.md), and
[docs/usage.md](docs/usage.md) shows how to use it. Licensed under
Apache-2.0 (LICENSE, NOTICE).

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

`scripts/check-all-services.sh` generates and type checks every model.
Generated files are cut at about 448 KiB, and the generator fails on any
file over 512 KiB.

## Testing policy

Everything is tested offline: AWS's Smithy protocol compliance tests, the
SigV4 and SigV4a signing test suites, the endpoint rules tests carried in
each service model, and local emulators (MinIO, LocalStack or moto) in
Docker with invented credentials. Nothing in this repository talks to real
AWS endpoints.
