# Using the SDK

Every example here comes from a test in this repository (`integration/`,
`transport/`, `sigv4a/`); the test file is named where it helps.

## Making a client

A client needs a `Net`, a `Clock` and a `Rand` (the program's `os.net`,
`os.clock`, `os.rand`, or a test's fakes) and its options:

```
let c = dynamodb.new(os.net, os.clock, os.rand, dynamodb.Options{
  region: "us-west-2",
  credentials: credentials.static_provider(key_id, secret),
})?
```

Or from shared configuration, the way the other AWS SDKs read it:

```
let cfg = config.load_default_config(os.env, os.fs, os.net, os.clock, os.rand)?
let c = dynamodb.from_config(os.net, os.clock, os.rand, cfg)?
```

`dynamodb.options_from_config(cfg)` returns the options instead, to
change before `dynamodb.new` (`opts with {max_attempts: 5}`).

### Credentials

| Provider | Where it reads |
|---|---|
| `credentials.static_provider(id, secret, token)` | the values given |
| `credentials.env_provider(os.env)` | `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN` |
| `credentials.Chain` | each provider in order; `NotFound` moves on, any other error stops |
| `credentials.cache(p, clock, window)` | keeps credentials until `window` before they expire |

`config.load_default_config` builds the chain: the environment's keys,
then the profile's static keys, or a role assumed through STS from
`source_profile` or `credential_source = Environment`. SSO, web identity,
container and instance metadata credentials are not implemented yet.

### Settings from configuration

`aws.Config` carries the region, the credentials, `max_attempts`,
`use_fips`, `use_dualstack` and configured endpoint URLs. A client takes
`AWS_ENDPOINT_URL_<SERVICE>` (the sdkId upper cased, spaces as
underscores: `AWS_ENDPOINT_URL_DYNAMODB`), then `AWS_ENDPOINT_URL`, then
the profile's `services` section and `endpoint_url`
(`integration/config_test.xo`).

## Calling an operation

Each operation is a method that takes its input struct and returns its
output or an error enum with one variant per modeled error, plus `Api`
(an unmodeled service error: code, message, status), `Send` (network,
credentials, retries exhausted), `InvalidInput` and `Deserialize`:

```
match c.get_item(dynamodb.GetItemInput{table_name: table, key: key}) {
  Ok(out) => ...
  Err(dynamodb.GetItemErr.ResourceNotFoundException(_)) => ...
  Err(e) => ...
}
```

Members are snake_case fields with `None` defaults; enums are Xo enums
with an `Unknown` variant for values newer than the model. Where a model
name would collide with Xo, the service's RENAMES.md lists the change.

### Retries

Calls use the SDKs' standard retry mode: up to `max_attempts` (3)
attempts, exponential backoff with jitter, a retry quota that limits
retries (`QuotaExceeded` when it runs out), and clock skew correction from a response's `Date`. A
streaming body is retried only before the response head arrives.

## Paginators

Every operation marked `smithy.api#paginated` has a paginator that copies
each page's token into the next input and stops on an absent, empty or
repeated token (`integration/s3_test.xo`):

```
var pages = s3.new_list_objects_v2_paginator(c, s3.ListObjectsV2Request{bucket: bucket, prefix: "p/"})
while pages.has_more_pages() {
  let page = pages.next_page()?
  for o in page.contents ?? [] { ... }
}
```

## Waiters

Every `smithy.waiters#waitable` waiter is a function that calls the
operation until an acceptor reaches success or failure or `max_wait`
passes, with Smithy's jittered exponential delay between `min_delay` and
`max_delay` (the model's defaults when omitted):

```
dynamodb.wait_until_table_exists(c, dynamodb.DescribeTableInput{table_name: t}, 5m)?
```

The error is `waiter.WaitErr[OpErr]`: `Failure` (a failure acceptor
matched), `TimedOut(attempts)`, or `Failed(e)` (an error no acceptor
expected).

## Event streams

An operation with an output stream returns a reader of its union's
events; the response's other members are in its `output` field
(`integration/eventstream_test.xo`):

```
var events = c.select_object_content(s3.SelectObjectContentRequest{...})?
while let Some(e) = events.next()? {
  match e {
    Records(r) => ...
    End(_) => ...
    _ => {}
  }
}
```

`next` fails with the union's error enum (`<Union>Err`): one variant per
modeled exception event, `Api` for an error message, and `Read` for a
stream that does not decode. S3's `SelectObjectContentEventStreamErr`
has only the last two.

An operation with an input stream returns a stream to `send` events on,
each signed in a chain from the request's signature; `close_send` sends
the signed end message, and `next` reads the output events, if any, as
they arrive (`integration/transcribe_test.xo`):

```
var st = c.start_stream_transcription(ts.StartStreamTranscriptionRequest{...}, first: [audio(chunk1)])?
st.send(audio(chunk2))?
st.close_send()?
while let Some(e) = st.next()? { ... }
st.close()
```

Input streams need a full duplex connection; the test network is one
(xo 0e1d7b177 or later), so an in-process server tests them.

## Signing

`sigv4` signs with Signature Version 4, by header or presigned in the
query. `sigv4a` signs with Signature Version 4a (ECDSA P-256, for a set
of regions); clients use it when the endpoint rules choose `sigv4a` (S3
Multi-Region Access Points, EventBridge global endpoints, CloudFront
KeyValueStore and a few more). Both pass the aws-c-auth signing test
suites.

### Presigned requests

The operations aws-sdk-go-v2 presigns have a `presign_<op>` method: S3's
GetObject, PutObject, HeadObject, DeleteObject, UploadPart, HeadBucket
and DeleteBucket, and STS GetCallerIdentity (sent as a GET with the form
in the query). The result is a `transport.Presigned` with the method,
the URL and any headers that were signed; anyone holding it can send it
without credentials until it expires (15 minutes by default, at most 7
days). The body's length is not signed.

```
let p = c.presign_get_object(s3.GetObjectRequest{bucket: b, key: k}, expires: 1h)?
// hand p.url to a browser, or:
let resp = http.client(os.net).send(http.new_request(p.method, p.url, {}, b""))?
```

`sigv4.sign_query` presigns any other request by hand.

## Testing code that uses the SDK

Clients take the `Net` they send through, so a test can hand them the
fake network and register handlers:

```
os.net.handle("POST https://sts.test/", fn(req: http.Request) -> http.Response {
  http.text(200, "<GetCallerIdentityResponse>...</GetCallerIdentityResponse>")
})
let c = sts.new(os.net, os.clock, os.rand, sts.Options{endpoint: "https://sts.test", credentials: ...})?
```

For an emulator, pass its URL as `endpoint` and a `Net` limited to the
loopback host (`os.net.only(["127.0.0.1", "localhost"])`), as the
LocalStack and MinIO tests do (`scripts/integration-localstack.sh`,
`scripts/integration-minio.sh`).
