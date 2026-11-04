# 0006: Xo language, toolchain and std items the SDK needs

Status: Proposed (Xo AWS 1, 2026-11-04)

## Context

The SDK is built on Xo as it is (spec/core.md and spec/std.md, read
2026-11-04). Changes to Xo land in the Xo repository through its owners,
never here. This record lists what the SDK would use, each with the
workaround the SDK takes meanwhile, so none of them blocks the design.
Items marked **verify** are behaviors the spec does not settle that the
first prototypes will test before anything is asked of the Xo owners.

## Items

1. **Compiler scale on very large generated packages.** EC2 is about 600
   operations and thousands of shapes (aws-sdk-go-v2's EC2 package is
   roughly 300,000 lines of Go). Unknown how `xo check` and `xo build`
   scale in time and memory on a package that size. Workaround: none
   needed until measured; if too slow, split a service into several
   packages of one module (types, serializers, operations). The scale test
   in 0002 produces the numbers for the Xo owners.
2. **Valued enums that keep unknown values.** `enum E: Str` refuses a
   value no variant has (spec 2.3); AWS adds enum values without notice.
   Workaround: generated enums with an `Unknown(value: Str)` variant and
   generated `value`/`parse` methods (0004). A std or language form (for
   example a valued enum's optional catch-all variant that `derive Json`
   fills) would shrink generated code; nice to have.
3. **A streaming JSON writer and token reader.** std/json has `encode`,
   `Value`, and a push Decoder of whole values. Large responses (DynamoDB
   Scan, a big ListObjects in JSON protocols) are fully built as a
   `json.Value` tree before decoding into shapes. Workaround: `Value`
   trees (correct, more memory). A token level reader (Go's
   `json.Decoder.Token`) and an encoder of strings and numbers in JSON's
   exact forms (Go's `strconv.Quote` rules for JSON, shortest float text)
   would let generated code stream. **verify** first whether `json.Value`
   `Num` encoding of floats matches the shortest form AWS expects.
4. **CRC64/NVME** (S3's newest checksum algorithm). std has crc32 IEEE and
   Castagnoli but no crc64. Workaround: implement it in the core
   (`checksum/`, slicing by 8, tested against AWS's published vectors). A
   `std/crc64` (Go's `hash/crc64` plus the NVME polynomial) would be the
   natural home.
5. **ECDSA private key from a raw scalar** (SigV4a). std/crypto loads keys
   only from DER. Workaround: build SEC 1 `ECPrivateKey` DER around the
   derived scalar and call `crypto.parse_private_key`. A
   `crypto.ecdsa_private_key(alg, d: Bytes)` would be cleaner.
6. **CBOR codec** for Smithy RPC v2 CBOR. Required for full coverage:
   3 services speak only CBOR and 22 more (CloudWatch among them) list it
   next to JSON or query (docs/reports/service-names-2026-11-04.md).
   Workaround: a CBOR encoder and decoder in the core, written before the
   generator reaches those 3 services. A `std/cbor` would serve other
   users too.
7. **Iteration protocol for user types.** `for x in` works on builtin
   collections, channels and ranges; a paginator cannot be iterated with
   `for page in pages`. Workaround: `has_more_pages()`/`next_page()`, as
   Go's paginators. If Xo gains an iterator interface, paginators gain
   it.
8. **http client: exact request path bytes.** SigV4 signs the escaped path
   exactly as sent; S3 keys contain spaces, `+`, `%`, unicode, and `//`.
   **verify** that `Client.send` sends a request built with a given
   escaped path byte for byte (no re normalization, no `..` cleaning, no
   double slash merge), and how to set it (`Url.path` holds a decoded
   path). If not, the item is a request builder that takes the raw escaped
   path (Go's `URL.RawPath`/`Opaque`).
9. **http client: automatic gzip.** The client adds `Accept-Encoding: gzip`
   and decodes gzip bodies unless the request sets `Accept-Encoding`
   itself (std.md 4.5). S3 objects stored with `Content-Encoding: gzip`
   must come back as stored. Workaround: the SDK always sets
   `Accept-Encoding: identity` (as aws-sdk-go-v2 disables decompression).
   **verify** that this disables decoding.
10. **http client: headers the SDK must control.** **verify** that a
    request can set `Content-Length` for a streamed body (std.md says a
    `with_body_reader` body uses the request's own `Content-Length`),
    `Host` (for virtual hosted style the URL host is enough), and
    `Expect: 100-continue` for large S3 uploads (optional; Go's SDK sends
    it above 2 MB).
11. **xo.mod of many modules in one repository.** **verify** with the
    first two services that `xo publish --check` and tag naming work for
    `s3/vX.Y.Z` alongside a root module `vX.Y.Z`, that a committed
    `xo.work` listing hundreds of modules loads quickly, and that `xo
    get github.com/xo-lang/aws/s3@v0.1.0` fetches only that directory's
    tree.
12. **Embedding a large data file in the core.** The partitions table
    (tens of KB) and, for tests, endpoint rule sets: `embed("path")`
    (decision 0304 of Xo) is expected to suffice. **verify** size limits.

## Decision

Report items 1 to 12 to the lead as one list. The SDK proceeds with the
workarounds; none blocks the design or the first services. Items found
during implementation are added here and reported the same way.

## Consequences

The Xo owners get concrete, prioritized requests with a consumer waiting
on them, and the SDK does not stall on any of them.

## Alternatives

Wait for each Xo change before building: rejected, every item has a
working workaround.
