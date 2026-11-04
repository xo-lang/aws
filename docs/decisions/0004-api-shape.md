# 0004: API shape: aws-sdk-go-v2 in Xo style

Status: Accepted (owner, 2026-11-04; proposed by Xo AWS 1, 2026-11-04)

## Context

The owner decided (2026-11-04) to mirror aws-sdk-go-v2: a client per
service, typed Input and Output structs, paginators, waiters, and
middleware-like options, so Go users find it familiar. Xo differs from Go
where it matters for an SDK: no nil (`T?` instead of pointers, and a `T`
converts to `T?` where one is expected, spec 2.10), struct fields may have
defaults, closed enums with exhaustive `match`, `Result` errors instead of
`(T, error)`, capability values instead of ambient I/O, `Secret[T]`, and
naming enforced by the compiler (types `UpperCamel`, everything else
`snake_case`).

## Decision

### What a program looks like

```xo
use github.com/xo-lang/aws/config
use github.com/xo-lang/aws/s3

fn main(os: Os) ! {
  let cfg = config.load_default_config(os.env, os.fs)?
  let client = s3.new_from_config(os.net, os.clock, os.rand, cfg)

  client.put_object(s3.PutObjectInput{
    bucket: "example-bucket",
    key: "notes/hello.txt",
    body: s3.Body.bytes(b"hello"),
    content_type: "text/plain",
  })?

  var pages = s3.ListObjectsV2Paginator.new(client, s3.ListObjectsV2Input{bucket: "example-bucket"})
  while pages.has_more_pages() {
    let page = pages.next_page()?
    for obj in page.contents {
      os.stdio.println("${obj.key ?? ""} ${obj.size ?? 0}")
    }
  }

  match client.get_object(s3.GetObjectInput{bucket: "example-bucket", key: "missing"}) {
    Ok(out) => out.body.close()
    Err(e) => match e {
      s3.GetObjectErr.NoSuchKey(_) => os.stdio.println("not found")
      _ => return Err(e)
    }
  }
}
```

### Mapping from aws-sdk-go-v2

| aws-sdk-go-v2 | xo-lang/aws |
|---|---|
| `s3.NewFromConfig(cfg, optFns...)` | `s3.new_from_config(net, clock, rand, cfg, opts: List[s3.Opt] = [])`, plus `s3.new(net, clock, rand, opts)` |
| `client.PutObject(ctx, &in, optFns...)` | `client.put_object(in, opts: List[s3.Opt] = [])` |
| `*s3.PutObjectInput` with `*string` | `s3.PutObjectInput` with `Str?` fields defaulting to `None`; write `bucket: "b"` |
| `aws.String("x")`, `aws.ToString(p)` | not needed: `T` converts to `T?`; read with `??` |
| `types.StorageClassStandard` (string type) | `s3.StorageClass.Standard`, a closed enum with `Unknown(value: Str)` |
| `types.NoSuchKey` via `errors.As` | `match` on the per operation error enum |
| `ctx` deadline and cancellation | Xo's structured cancellation (`scope`, task cancel) and a `timeout` option |
| `s3.NewListObjectsV2Paginator` | `s3.ListObjectsV2Paginator.new(client, in)` |
| `s3.NewObjectExistsWaiter` | `s3.ObjectExistsWaiter.new(client).wait(in, max_wait)` |
| middleware stack `APIOptions` | an ordered list of named steps (below) |

### Inputs and outputs

- Every member of an Input is `T?` with `= None` (Go's pointers have the
  same reason: AWS may relax `@required`, and Smithy inputs are client
  optional). `@required` is checked before sending, with an
  `InvalidParams` error naming every missing member, as Go's validation
  middleware does. Lists and maps are `List[T]?` and `Map[Str, T]?`, so
  an empty list sent on purpose differs from one not sent.
- Output members are `T?` unless the model gives them a default or marks
  them required in an output (Smithy's nullability rules, as Go's
  `nullability` pass decides); lists and maps are `List[T]`/`Map[Str, T]`
  defaulting to empty, as Go users already treat them.
- Every Output has a field `metadata: aws.Metadata` (request id,
  extended request id, HTTP status) in place of Go's `ResultMetadata`.
- Shapes are plain structs, no derives except `Eq` and `Debug`;
  `Secret[T]` wraps members the model marks `@sensitive`, so Debug output
  and logs never show them.
- Enums: `enum StorageClass { Standard, ReducedRedundancy, ...,
  Unknown(value: Str) }` with generated `value() -> Str`,
  `StorageClass.parse(s) -> StorageClass` and `StorageClass.values() ->
  List[StorageClass]`. The `Unknown` variant keeps values a newer service
  sends (forward compatible), and `match` stays exhaustive. Xo's valued
  enums (`enum E: Str`) are not used: they refuse unknown values by design
  (spec 2.3), which breaks when AWS adds a value (0006 item 2). `intEnum`
  maps the same way over `Int`.
  - Target shape (Xo decision 0493, accepted by the owner 2026-11-04):
    a valued enum with a catch-all, `enum StorageClass: Str { Standard =
    "STANDARD", ..., Unknown(Str) }`, where `StorageClass.from(v)` always
    gives a value (unknown text lands in `Unknown`) and `known(v)` gives
    `E?`. The generator emits this form once Xo implements 0493; until
    then it emits the plain enum above with generated `value`/`parse`,
    which have the same meaning, so the switch changes no call site
    except `parse` becoming `from`.
- Unions: an enum with one variant per member plus `Unknown(tag: Str)`.
- Timestamps are `Time`; blobs `Bytes`; documents `json.Value`; `Long` and
  `Integer` both `Int` (Go uses `int64`/`int32`; Xo's `Int` is 64 bit),
  `Byte`/`Short` `Int8`/`Int16`; `BigInteger`/`BigDecimal` std/big.

### Streaming bodies

- Input payloads with `@streaming` take `Body`: `Body.bytes(b)`,
  `Body.reader(r, length: Int?)` over an `http.BodyReader` (sent as it is
  read; the length decides between a signed or unsigned payload and the
  aws-chunked encoding).
- Output payloads with `@streaming` are a `ResponseBody` over std/http's
  `ClientStream` (`read`, `read_all`, `close`); the caller must close it,
  as Go's `Body.Close`.

### Errors

- Each operation returns `Output ! <Op>Err`, an enum of the modeled
  errors the operation declares plus the shared variants:
  `Api(aws.ApiErr)` (an unmodeled service error: code, message, fault,
  request id, status), `Transport(aws.TransportErr)` (connect, timeout,
  protocol), `Credentials(aws.CredentialsErr)`, `Endpoint(...)`,
  `InvalidParams(...)`, `Canceled`. Retries have already run when an
  error returns; `aws.RetryErr` wraps the last error with the attempt
  count, as Go's `retry.MaxAttemptsError`.
- Every error type implements `Error` (display) and Debug; a generic
  `aws.error_code(e) -> Str?` gives the AWS error code of any of them for
  code that does not want to match.

### Options and middleware

- `Options` is a struct with defaults: region, credentials provider,
  endpoint resolver and base endpoint, retryer, HTTP client, app id,
  logger, client log mode, checksum settings, `use_path_style` and the
  other service specific options from the model's customizations (S3's
  accelerate, dualstack, disable multi region access points, ...).
- Per call: `opts: List[Opt]`, where `Opt` is
  `fn(Options) -> Options`, as Go's `optFns`.
- The middleware stack is Go's five steps (initialize, serialize, build,
  finalize, deserialize) as named lists of `Middleware` values in
  `Options.api_options`, so a user inserts a step before or after another
  by name (add a header, log a request, record timings). A middleware is
  an interface with one `handle(req, next)` method; a closure adapter
  covers the common case. The generated operation registers its steps;
  the core's transport runs them.

## Consequences

- Go users recognize every concept; names are snake case and the
  pointers are gone.
- Matching on an operation's error enum makes the modeled errors visible
  at compile time, which Go cannot do.
- Generated code size grows with one error enum per operation (EC2 has
  about 600); measured with the EC2 scale test (0002).

## Alternatives

- Required input members as non optional fields (compile time required):
  nicer at the call site, but AWS may drop `@required` on a member
  (compatible for AWS, a breaking type change for us). Rejected, with
  runtime validation as Go does.
- One error type per service instead of per operation: fewer types, but
  `match` could not show which errors an operation actually returns.
- Valued enums for AWS enums: refuse unknown values. Rejected (above).
