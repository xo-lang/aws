# Xo from the SDK's side: what worked, what didn't

A running log kept while building the AWS SDK in Xo (owner's request,
2026-11-04), to help make the language better. Each entry is dated and
says what happened, not a general opinion. Bugs with repros go in
[xo-issues.md](xo-issues.md); this file is about how Xo feels to write.

## Liked

- **Capabilities make tests honest (2026-11-04).** Config loading takes
  `Env` and `Fs`, so tests run on `FakeEnv` and `MemFs` and can never read
  a developer's real `~/.aws`. The SDK's "no real AWS" rule is enforced by
  the types: integration tests can pass `os.net.only(["localhost"])`. No
  other language I know makes this a compile time property.
- **Virtual clock and seeded Rand (2026-11-04).** Retry backoff, credential
  expiry, and clock skew tests run instantly and deterministically
  (`os.clock.advance(9m)`, `os.clock.sleeps()`). Go needs injected
  interfaces and hand-rolled fakes for the same thing.
- **`Secret[T]` (2026-11-04).** Credentials hide themselves in Debug
  output with no work; a test proves it.
- **Diagnostics with fixes (2026-11-04).** Almost every error told me
  exactly what to write: `scope` is a keyword "rename it, for example
  `scope_name`"; "`var` belongs only on the parameter"; "rename to
  `by_len`"; "construct it with names: `Read(path: ..., msg: ...)`".
  Fixing a whole file took one pass.
- **`T` converts to `T?` (2026-11-04).** Lets the SDK make every input
  member optional (as AWS needs) while call sites stay `bucket: "b"`, no
  `aws.String("b")` as in Go.
- **embed of a directory (2026-11-04).** The 38-case signing suite is one
  `const SUITE: embed.Dir = embed("testdata/v4")`.
- **Std ports of Go (2026-11-04).** url escaping, time layouts with named
  fields (`{year}-{month}`), crypto hmac, http client and server, all with
  Go's behavior, so porting aws-sdk-go-v2 logic is direct.
- **Real in-memory HTTP servers in tests (2026-11-04).** `os.net.listen`
  plus `http.server` in a `scope` gave a wire level test of what the
  client sends (it caught issue 2) with no sockets and no ports.
- **Fast std turnaround (2026-11-04).** crc64 NVME and an ECDSA raw key
  constructor landed the same day they were asked for; the raw path fix
  (issue 2) and the match arm fix (issue 1) landed within hours, each
  with a golden test, so both workarounds are already gone.
- **Effects caught a design gap (2026-11-04).** The credentials
  interface said `uses (net.dial, clock)`; the assume role provider
  retries with jitter, so it needs `rand`, and the compiler refused it
  until the interface said so. In Go that dependency would be invisible.

- **json.Value keeps object order (2026-11-04).** `Object(fields:
  List[(Str, Value)])` preserves the AST's member order, which Smithy
  needs (structure members serialize in model order). The loader reads
  all 435 models (180 MB of JSON, 141,582 shapes) in 0.8 s.
- **Diagnostics teach the std names (2026-11-04).** `insert` → "Xo's is
  `.add`"; `.slice(a, b)` → "Xo slices with a range"; a discarded
  `sort()` → "values are not changed in place, assign it back".

## Didn't like, or cost time

- **No way to make an empty Set by name (2026-11-04).** No `Set.new()`
  and no Set literal I could find; `[].to_set()` works. A `Set[T]` with
  `= {}` or `Set.new()` would be the obvious spelling.
- **Another module's function is not a value on native (2026-11-04).**
  `transport.send(..., query.classify)` is XO1201 (issue 3); every
  cross-module callback needs a local wrapper for now.
- **Fakes are not named in the prelude (2026-11-04).** A test helper
  taking `os.fs` needs `use std/testing` and `testing.MemFs`; `FakeEnv`
  has `set` but no `unset` (setting "" works for the SDK).
- **std/http's client rewrote the path (2026-11-04, fixed same day).** It keeps only the
  decoded path and re-escapes it, so `%2B` goes out as `+`
  (xo-issues.md entry 2). For a signing SDK the request line must be
  exactly what the caller built; Go keeps `RawPath`.
- **A line may not start with `||` (2026-11-04).** Newline-terminated
  statements mean a long boolean must end each line with the operator.
  Go has the same rule, so it is familiar to Go users; it still differs
  from rustfmt and Black, which start continuation lines with the
  operator. Minor: the diagnostic names the fix.
- **FakeNet port matching (2026-11-04).** `listen("host:80")` is not
  reached by `http://host/` (no explicit port); an explicit port in both
  works. Silent, cost one gate run.
- **Common words are keywords (2026-11-04).** `scope` is a keyword, so the
  natural name for SigV4's credential scope fails, and `test`, `type`,
  `match`, `select` are AWS member names the generator must rename.
  Contextual keywords (as `derive`, `with` already are) for `scope` and
  `select` would avoid it.
- **`T ! E` not accepted as a field type (2026-11-04).** `result: T ! E` in
  a struct is a parse error; `Result[T, E]` works. The short form works
  everywhere else, so the field case surprises.
- **`Err` cannot name a user enum (2026-11-04).** `pub enum Err {...}` in a
  module is XO0603 because `Err` is predeclared; fine, but the message
  could suggest `<Module>Err`.
- **`display` must be `pub` to be called across modules (2026-11-04).** An
  error enum implements `Display` in its own module, but another module
  calling `e.display()` gets XO0605. Interface satisfaction ignores `pub`,
  calls do not; a `Display` method is almost always meant to be public.
- **Errors do not convert to `Error` in tests unless they implement
  `Display` (2026-11-04).** `?` on a generic `Attempted[E]` in a test
  fails; a generic `display` needs a constrained impl. Expected, but a test
  body could accept any `Debug` error.
- **The first SDK bug was a native backend gap (2026-11-04).** A struct to
  interface conversion in a match arm is XO1201 on native only
  (xo-issues.md entry 1). Native and Go backends disagreeing on what
  compiles is the most expensive kind of surprise.
- **Gate latency (2026-11-04).** Each test run waits 1 to 5 minutes for
  shared memory on the development Mac; `xo test` itself takes a second.
  Not the language, but it shapes how one works with it: batch more, run
  less.
- **Spec and checkout drift (2026-11-04).** My local xo checkout was two
  days behind main, so I reported std/cbor and std/crc64 missing when they
  existed. `xo doc std` or a `xo version --std-modules` listing from the
  binary in use would make "does std have X" a one command question.
