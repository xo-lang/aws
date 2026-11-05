# 0009: Streamed request bodies

Status: Proposed (Xo AWS 1, 2026-11-05)

## Context

Every request body was a `Bytes` value, so uploading a 5 GB object meant
holding 5 GB in memory. aws-sdk-go-v2 takes an `io.Reader` for an
operation's streaming blob payload (S3 PutObject's `Body`) and, for S3,
sends it in the `aws-chunked` content encoding with the flexible checksum
as a trailer (`STREAMING-UNSIGNED-PAYLOAD-TRAILER`), computed as the body
goes out, so it is read once.

Xo's std/http sends a `BodyReader` as it is read
(`Request.with_body_reader`), and `http.pipe()` gives one that a task
writes. A provider or transport function has no file effect, and Xo does
not let a stored closure carry one (decision 0003, amended), so the
transport cannot open a file itself.

## Decision

- `aws.Upload` is a streamed body with an optional length. Each input
  whose payload is a streaming blob gets a `<payload>_stream:
  aws.Upload?` field beside the `Bytes?` one.
- `aws.upload_file(os.tasks, os.fs, path)` reads a file on a background
  task started on the caller's group. Each attempt sends the task a new
  pipe and the task writes the whole file into it, so a retry sends the
  body again from its start. The operation closes the task's channel
  when it returns, so an upload is used once.
- `aws.upload_reader(reader, length)` sends any `BodyReader` once: such
  an operation gets one attempt.
- S3 operations, and operations with `aws.auth#unsignedPayload`, stream
  the body. With a request checksum (S3's default CRC32, or the caller's
  algorithm), the transport frames it in unsigned `aws-chunked` chunks of
  64 KiB on a scoped task, the checksum computed as the chunks go, and
  sends `Content-Encoding: aws-chunked`, `X-Amz-Decoded-Content-Length`,
  `X-Amz-Trailer` and the encoded `Content-Length`. Without a checksum
  it sends the body as it is, with `UNSIGNED-PAYLOAD`.
- S3 needs the body's length (S3 answers 411 without one), so an S3
  upload without a length is refused before it is sent. For bodies of
  unknown length, a multipart transfer manager is the later answer (as
  aws-sdk-go-v2's feature/s3/manager).
- Other operations sign the body's hash (Glacier also sends a tree
  hash), so their serializer reads the upload whole before signing. This
  saves nothing in memory, but it lets the same field work everywhere.
- The generator now sets `unsigned_payload` for operations with
  `aws.auth#unsignedPayload`, as aws-sdk-go-v2 does (EBS PutSnapshotBlock,
  MediaStore Data PutObject, Lex PostContent, Omics uploads).

## Consequences

- An S3 upload holds one 64 KiB chunk in memory, plus whatever the pipe
  holds (up to 64 KiB).
- aws-chunked over plain HTTP uses the unsigned trailer, as over HTTPS.
  aws-sdk-go-v2 refuses an unseekable body without TLS. LocalStack accepts
  it. The signed chunk variant (`STREAMING-AWS4-HMAC-SHA256-PAYLOAD-TRAILER`)
  is not implemented.
- `Expect: 100-continue` for large uploads waits on std/http's client
  (queued with Xo).

## Alternatives

- A `fn() -> BodyReader` in the upload to reopen the file: it would need
  the `fs` effect inside a stored closure, which Xo does not allow.
- Reading the whole stream to compute the checksum header: it is what
  `body` already does, and it defeats the point.
- Chunked transfer encoding with HTTP trailers: S3 refuses
  `Transfer-Encoding: chunked` uploads, and the checksum trailer is part
  of the aws-chunked body, not an HTTP trailer.
