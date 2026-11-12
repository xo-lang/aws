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

- **The team turns feedback into releases within hours (2026-11-04).**
  `scope` became a contextual word, `display` became callable across
  modules, and the `pub enum Err` and `T ! E` field diagnostics name
  their fix, all from entries in this file, the same day.

- **A Smithy IDL parser in an afternoon (2026-11-04).** Running the
  Smithy CLI (a downloaded binary) was not allowed, so the protocol test
  models needed an IDL parser; Xo's byte slices, `while let`, enums with
  named fields and `?` made a 900 line recursive descent parser that
  reads all 143 files in 5 ms. The one bug was mine.
- **Generated code type checks fast (2026-11-04).** A first generated
  restJson1 client of about 6,000 lines failed only on unused variables;
  `xo check` named each one.
- **json.Value keeps object order and compares structurally (2026-11-04).**
  The whole endpoint rules interpreter (rules, templates, 12 functions,
  partitions) is about 500 lines over json.Value, and it passed all 14,106
  endpointTests of the 435 AWS models on its first full run. `==` on
  values and `get` returning an option made the evaluator read like the
  spec.
- **Generated code at scale type checks quickly (2026-11-04).** IoT's
  generated client is 69,000 lines, Lambda's 28,600; `xo check` on Lambda
  took under a second and 680 MB. Promising for EC2.
- **Catch-all enums (0493) fit the generator exactly (2026-11-04).** One
  emitted form covers known values, unknown values from newer services,
  and `E.from(s)`, with no hand-written helpers.

- **Name hints for other languages' methods (2026-11-11, gcp storage
  step 3).** Writing the signing port, `.has`, `.chars` and
  `Str.from_byte` each failed with a note naming the Xo spelling
  (`contains`, `runes`) or the way to build the value (`BytesBuilder`),
  and `Time.UNIX_EPOCH()` was answered with "a constant, not a
  function". Each error took seconds to fix, not a lookup.
- **FakeNet names a missing route (2026-11-11).** A request to a host
  with no handler fails at once with "no fake handler for GET
  https://nowhere.fake/x". A test that seemed to hang was the
  storage client's own retries of that error, not FakeNet.

## Didn't like, or cost time

- **`env.args()` leaves out the program name (2026-11-04).** Go's
  `os.Args[0]` is the program; Xo's `args()` starts at the first
  argument. Sensible, but a Go port reads the wrong index silently (my
  `loadall` ignored its directory argument). The doc line could say
  "without the program name" where `args()` is declared.

- **Byte vocabulary (2026-11-04).** Bytes iterate as `UInt8`, so the
  conversion is `UInt8(n)`, not `Byte(n)`; `enumerate` is `indexed`;
  an infinite loop is `while {`, not `loop`; `uses` is a keyword, so a
  field cannot be named `uses` (a parser's `use` statements). Each was a
  one-line diagnostic, but four guesses in one file.

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
- **Unused imports are errors, which bites generated code (2026-11-04).**
  A generator has to know exactly which packages each file uses; I ended
  up scanning the emitted code for `pkg.` outside strings and comments.
  An `xo fmt --fix-imports` (or a generated-file pragma that makes unused
  imports warnings) would remove that step.
- **List lacks `index_where` / `position`, Bytes lacks `all`/`any`, Str
  lacks `trim_end_matches` (2026-11-04).** Each cost a compile round; I
  used `map(..).index_of`, a loop, and `cut_suffix`. Small, but they are
  the first names one reaches for.
- **Exhaustiveness warnings on `_ =>` in generated matches (2026-11-04).**
  XO0305 "this arm hides ..." fires on every intentional catch-all in the
  generator; there is no per-match way to say "the rest, on purpose".
- **Front end cache replay warnings (2026-11-04).** After editing
  transport.xo, xo reported cache entries "recorded by xo X did not replay
  in xo X" (same build) and rebuilt. Harmless but alarming; reported to
  the lead.
- **Upstream turnaround is fast (2026-11-04).** Issues 3 and 4 and the
  front end cache replay were fixed within hours of the report, each with
  a golden test; the workarounds came out the same day.
- **`test ... uses (net, env, clock)` with `--real` is the right shape
  for emulator tests (2026-11-04).** The same file skips cleanly in the
  normal gate ("1 uses clock, env, net: run with --real") and runs
  against LocalStack under the script, and `os.net.only([...])` makes
  "never reach real AWS" a type of value, not a convention.

## 2026-11-04: awsJson, DynamoDB, SQS

- Liked: adding awsJson1_0/1_1 to the restJson emitter took one `rpc`
  field and a binding override; the typed enums and optional fields made
  the generated DynamoDB `AttributeValue` (a tagged union) read naturally,
  and `expect(got.item) == Some(item)` compares a nested map of unions
  structurally with no helper.
- Liked: the `{"k": v}` map literal with the type taken from the
  annotation.
- Disliked: finding the map literal syntax: std.md mentions a "Map literal"
  only in passing and has no `Map.from(pairs)`, so my first guess failed.
  A one-line example in std.md's Map section would help.
- Disliked: two backend regressions in one xo update (xo-issues 5, 6):
  arm64 refused an inlined cross-module call that built before, and the Go
  backend misses the `T` to `T?` wrap for `x ?? return Err(..)`. LLVM was
  the working fallback, which made `--backend` a useful escape hatch.

## 2026-11-04: awsQuery and the generated STS

- Liked: module cycles with acyclic packages just work in a workspace,
  so `credentials/stscreds` can use the generated `service/sts` the way
  aws-sdk-go-v2 does, with no restructuring.
- Liked: `var f: query.Form` parameters made the form writer a set of
  small functions that each append under a key prefix, with no builder
  object threaded through returns.
- Disliked: a generated test name collision (a request and a response
  test sharing a Smithy id) was skipped silently by my own generator for
  weeks of suites; Xo rejecting duplicate `test` names is what forced the
  dedupe in the first place, and an error naming both would have been
  better than my workaround. Not a language bug; noted for tooling.
- Disliked: `List.sorted()` vs `sort()`, and no `Byte(n)` conversion: two
  more guesses that failed. std.md's method index answers it, but a
  "did you mean `sort`" hint would save the lookup.

## 2026-11-04: ec2Query, EC2, and the build cache

- Liked: a 270k line generated module (EC2) type checks in about two
  seconds warm and 2.5 GB, and compiles into a test binary that runs a
  LocalStack round trip; Xo held up at AWS's largest model.
- Liked: `--backend=llvm` as an escape hatch, and XO_BACKEND_CACHE_DIR to
  give a run a private cache: together they turned a flaky failure into a
  two step repro (issue 5) without disturbing anyone else's cache.
- Disliked: the native backend's result depends on what was built before
  in the same cache (issue 5): the worst kind of bug for a user, since a
  clean CI passes and a developer's laptop fails. A cache key that misses
  an inlined callee's body is the likely cause.
- Disliked: `xo mod tidy` removing a require the module needs (issue 7);
  a tool that rewrites xo.mod should never make the module unbuildable
  for its users.

## 2026-11-04: paginators, JMESPath, waiters, event streams

- Liked: a JMESPath implementation (Pratt parser, every builtin) passed
  all 892 compliance cases on its first run once it type checked. The
  exhaustive `match` over a 20 variant `Node` enum caught every missing
  case at compile time.
- Liked: generic enums with `derive Display` (`WaitErr[E]`) give each
  waiter a typed error that wraps the operation's own error, with no
  boxing and no interface.
- Liked: `http.Client.open`, `ClientStream.read` and `http.pipe` cover
  event streams and bidirectional streams with no extra library, and
  `os.net.handle` in tests serves a streamed body, so the event stream
  readers are tested without an emulator.
- Liked: std/crc32 and std/binary made the event stream codec about 200
  lines; the aws-sdk-go-v2 vectors pass byte for byte.
- Disliked: `XO0403`, which requires naming the fields of multi-field
  variants when constructing them (`Subexpr(l: a, r: b)`), cost a 30
  line mechanical pass on the parser. Fine for clarity, but positional
  construction when the field types differ, or a fix-it that rewrites the
  call, would help.
- Disliked: no `loop`, `Str.index_of` or `Str.replace_all`; the names
  differ from what I expected (`while true`, `split`, `replace`). Small,
  but each is a failed check and a spec lookup.
- Disliked: issue 8, a native XO1201 on unrelated `List.push` calls that
  appears when a large module gains one more package dependency. It
  shows only when the code is reachable (`--real`), so `xo check` and the
  ordinary tests stay green while the emulator run fails to build.

## 2026-11-04: input streams, issue 9, SigV4a

- Liked: std/crypto had everything SigV4a needs. `parse_private_key`
  takes a SEC 1 key with no public point and computes the point,
  `marshal_public_key` gives the X and Y to compare, and `sign` and
  `verify` speak ASN.1 DER ECDSA. Deriving the key took about 100 lines,
  and all 38 aws-c-auth v4a cases pass.
- Liked: `XO0501` ("method `sign` mutates `signer`, which is captured by
  a closure; closures capture by value") named the exact problem and the
  rule. Moving the `var` inside the closure fixed it.
- Liked: the deadlock fault (`XO-F001: every task is blocked and no
  timer is pending`) makes a hung streaming test fail at once instead of
  timing out, and the Go backend names the blocked task and its line.
- Disliked: issue 9, which turned out not to be a bug. The fake network
  (`os.net.listen(":0")`, `http.client(os.net)`) reads a whole request
  before the handler runs, so a full duplex exchange deadlocks there, and
  the spec did not say so. The same test passes on a loopback socket
  (`uses net`, `--real`). Lang 3 is documenting the limit and making the
  fake path duplex. The deadlock fault was immediate, but it did not say
  "the fake network is not duplex", which would have saved the report.
- Disliked: issue 10, a native build fault (`rt.select_new returns a
  Select` in `http.PipeWriter.write`) that appears only when the duplex
  test and the DynamoDB client share a build. It is the second build
  fault (after issue 8) that depends on what else is in the program, so
  one test passes alone and fails in the suite.
- Disliked: `XO1201` "function values with `var` parameters" on the
  native backends. A local helper closure that takes the stream as
  `var` had to become a top-level function.
- Disliked: `derive Json` field names must be snake_case, and I found no
  rename attribute, so a JSON object with keys `X` and `Y` has to be read
  as a `json.Value`. A `json(name: "X")` field attribute would help.
- Disliked: `Bytes` has no `to_list` or iterator of `UInt8`, so adding
  one to a big endian number is an index loop over a `List[Int]`.
- Disliked: `x ?? return Err("...")` as a struct literal field value
  takes the rest of the literal as the return's operand. `XO0177` then
  points at Go's `return a, b` and the fields after it go missing, which
  is confusing for a typo-free line. Ending a `return` operand at the
  field's comma (or a targeted hint) would help; a `let` binding first
  works around it.
- Liked: config tests on the fake network need no environment, files or
  sockets: an `aws.Config` value, `os.net.handle`, and the generated
  client.
- Liked: both stream blockers were fixed upstream the same evening. The
  fake network became full duplex (0e1d7b177) and `Select` was qualified
  (5dd0b3f4e), each with a regression test, so the input stream test
  runs offline in the normal suite.

## 2026-11-05: all 435 services, real AWS

- Liked: `XO_WORK=<file>` made the workaround for issue 11 a two-line
  change; std had every flexible checksum (crc32 with Castagnoli, crc64
  NVMe, sha1/256/512, md5) with Go's semantics, so S3 checksums need no
  ported code; `binary.u64_be` takes the CRC64's negative Int as Go's
  uint64 bits without a cast.
- Didn't like: issue 11 (a 435-module workspace loads everything, 8.7
  GB for one small check); `?` in a test cannot carry a plain struct
  error (XO0202), so a non-Error error type needs `== Ok(..)` comparisons
  in tests; `"${req.url}"` needed `:?` because `http.Url` has no Display.

## 2026-11-05: customization audit, CI on the 0.39.0 release

- Liked: the 0.39.0 release archives come with SHA256SUMS and a linux
  build for both CPUs, so CI installs a release in two curl calls and a
  checksum; on Linux arm64 the 0.39.0 release passes the whole gate,
  every service and the endpoint tests unchanged (only the two known
  version gaps fail); `Secret.new` and `reveal` made the bearer token
  hard to print by accident.
- Didn't like: `xo test` has `--run` but no `--skip`, so CI leaves out a
  test that needs a newer Xo by deleting its file; a build of main
  reports the last release's version (`xo 0.38.1` for a build with
  0.39-era fixes), so a script cannot tell a main build from the release
  it names; the import detector ignores calls inside `${}` interpolation,
  so `"${crc32.checksum(b)}"` alone left `std/crc32` unimported (moved
  the call out); `url.query_unescape` returns a Result where `??`
  needs an Option, which takes `.ok()` first.

## 2026-11-05: read sweep of 366 services, the first release

Liked:
- Module cycles through MVS just work: the root and service/sts require
  each other at one commit, both tagged v0.1.0, and an app with no
  workspace fetched and built them (tested against a scratch bare
  clone through `XO_GIT_BASE`). A workspace ignores requires of tags
  that do not exist yet, so the requires could land before the tags.
- Typed operation errors held up against 366 real services: every
  error that came back parsed into the operation's enum, and the Go
  and LLVM backends were ready workarounds when native failed.
- The fix for a back-end cache bug (issue 12) came the same morning,
  with its cause explained.

Disliked:
- Three native back-end failures that `xo test` on small modules never
  shows: a duplicate symbol from a cached std unit (12), "reference
  counting ... too many words" for a large struct in a Result (13), and
  an arm64 frame over 4095 bytes the assembler rejects (14). The last
  two are in 0.39.0 too. Large generated code finds these first; a
  native build of a big program in Xo's own tests would catch them.
- `xo version` of a debug checkout build says 0.38.1 while the
  checkout is past 0.39.0, which sent issue 12's first triage the
  wrong way (`version -m` with the binary path gives the build).
- `xo test --run <no match>` skips compiling, and a test that `uses`
  real capabilities is skipped before it compiles without `--real`, so
  a compile-only check needs `--real` with the harness made inert.
- `Rune` has no `to_str`; cutting a string at N characters takes
  summing `utf8_len` over the runes.

## 2026-11-05: the rest of the credential providers

Liked:
- `testing.FakeNet.handle` with a "METHOD URL" pattern made the IMDS
  and container providers testable without a server: the token, the
  role, a 401 that renews the token, a 503 that is retried, and the
  clock advanced past expiry, all in one test file.
- Effects kept the providers honest: `retrieve` declares `net.dial,
  clock, rand`, so reading the EKS token file at every fetch (as
  aws-sdk-go-v2 does) would have widened the interface. `os.tasks`
  ("for services such as caches that refresh in the background") gave
  the honest answer: a background task, started by a call that declares
  `fs.read`, rereads the file, and `retrieve` stays as it was. The
  spec's effect attribution for `spawn_background` (the spawner pays)
  made the design obvious once found.

- The capability rules held through all seven providers: the file
  reads, the SSO token write back and `credential_process`'s program
  run all moved to tasks the caller starts and pays for, and
  `test` blocks gave each one a fake (`os.fs`, `os.proc.on_run`,
  `os.tasks` cancelled at the end, `os.clock.advance`) without extra
  plumbing.
- `write_atomic` keeps the replaced file's permission bits, so an SSO
  token cache at 0600 stays 0600 with one call.

Disliked:
- The flip side: a provider that must run a program or touch a file
  cannot do it lazily, so `credential_process` and the token watches
  need one call each after loading the configuration, where
  aws-sdk-go-v2 needs none. Forgetting the call is a clear error at the
  first request, not at build time.
- Liked: `scope s { s.spawn_background(...); c.http.send(...) }` inside a
  retry closure made the aws-chunked encoder easy: the encoding task is
  cancelled and waited for when the attempt ends, whatever happens, so a
  failed attempt cannot leak a writer. `http.pipe()` plus
  `with_body_reader` did the rest.
- Disliked: a stored closure cannot carry an effect, so "reopen this
  file for a retry" cannot be a `fn() -> BodyReader` field. The
  workaround, a background task serving pipes over a `Chan[PipeWriter]`,
  works but every file upload needs a task group from the caller. A way
  to store a closure with its effects charged at the call site that made
  it would remove this (and the credential_process task too).
- Small papercuts: I missed `Int.to_str_base(16)` (Go's FormatInt) and
  wrote my own hex helper; `xo doc Int` lists it, so check there first. And `if let Some(var x) = ...` is not a pattern, so a
  mutable copy needs `var x = h` first.
- `xo check` accepts a closure with a `var` parameter
  (`fn(var l: List[Str], code: Str)`), but `xo test` on the native
  backends then stops with XO1201 "function values with `var`
  parameters (support is planned)". The checker could warn, since every
  default build is native.
- `xo test --run` is a substring match (documented in `xo help
  test`), where Go's `-run` is a regular expression, so `--run 'a|b'`
  quietly matches nothing. The "no tests match" message could say it
  matched a substring.
- Issue 15: two packages' types with the same short name
  (`imds.Provider`, `container.Provider`) boxed into one interface fail
  the native build with an error that blames a stale cache (XO1510,
  "rebuild with XO_BACKEND_CACHE=off"), and the LLVM backend silently
  runs the program wrongly. The message sent me to the cache first. A
  per-package name is the normal Go habit, so this will hit others.
- No `loop` expression that yields a value with `break v`; a retry loop
  needs a `var got: T? = None` and a `while got.is_none()`.
- A `pub` function's `uses` clause is part of its API: starting that
  task inside `load_default_config` would have added `clock` to it and
  broken callers that declare `uses (env, fs.read)`, so the refresh is a
  separate call (`cfg.watch_token_files`). Right, but easy to miss; a
  vet note on widening a published `uses` would help.
- `testing.FakeNet` is not `Net`: a helper that registers handlers must
  take `testing.FakeNet`, which the error (`Net` has no method
  `handle`) does not suggest.

## 2026-11-05: Azure core, credentials (xo-lang/azure)

Liked:
- `jwt.sign` with `header` and `x5c` made the MSAL client assertion
  (PS256, `x5t#S256`) a few lines.
- `embed` keeps test data next to the test with no fs effect.
- An interface value in a `List` (the policy chain) and a Mutex
  `with` closure that carries effects (the shared bearer token) both
  just worked.

Disliked:
- `embed("...")` works only as a `const` initializer; inside a test
  body it is `function embed not found`, which does not point at the
  rule. A const of type `Str` then needs `.bytes()` for a `Bytes` API;
  `const X: Bytes = embed(...)` would fit binary files (a future .pfx).
- Native RSA key generation is still missing (decision 0285), so a
  test that signs with RSA needs a key on disk, which secret scanners
  flag and the repo must allowlist.
- A stored closure cannot carry effects, so the pager and poller hold
  the pipeline plus pure decoders instead of a "fetch next" closure.
- Correction (retested on xo 9f557bad4): "a stored closure cannot carry
  effects" was too broad. A struct with an effect parameter
  (`Body[fx: Effects]`) works when the variable is threaded through
  explicitly (`send[fx: Effects](req: Request[fx]) uses (..., fx)`).
  What really fails is an interface method with a fixed `uses`: a
  provider holding a `proc` closure cannot implement
  `retrieve(self) uses (net.dial, clock)` (XO0701). That is the shape
  behind credential_process, the SSO write-back, and Azure's
  TokenCredential and Policy. Threading the variable through 435
  generated clients is the other cost, and the XO0701 note for an
  omitted effect argument could suggest the `[fx: Effects]` form.

## 2026-11-05: the Azure ARM generator (xo-lang/azure)

Liked:
- `derive Json` with `as "wire,omitempty"` on each field made the
  generated models short: 82 armresources models are plain structs,
  and the emitter needs no serializer code.
- `derive Json(via: Str, to: f, from: g)` let a newtype over `Time`
  carry Azure's lenient date-time form (no offset means UTC), and the
  same pattern covered RFC 1123 times, unix seconds and base64url bytes
  in about 60 lines.
- The generator is an Xo program that reads 6 MB of JSON specs, and it
  regenerates byte for byte, so a drift check is a plain git status.

Disliked:
- `Time` decodes strict RFC 3339 only, and there is no field-level
  option, so a lenient date needs a wrapper type, and callers write
  `t.0` to reach the `Time`. A field option (`as "createdTime,via=..."`)
  or a lenient `Time` decode mode would keep plain `Time` fields.
- (Corrected 2026-11-05: Xo has this. A `Patch[T]` field is `Absent`,
  `Null` or `Value(v)` on the wire, which is Azure PATCH's explicit
  `null` and Go's `azcore.NullValue`; I had missed it in spec/std.md
  5.) The generated modules don't use it yet; it goes in when a PATCH
  test needs to clear a property.
- No `fail(msg)` in tests: an unexpected match arm needs
  `other => expect("${other:?}") == "what I wanted"` to fail with a
  useful message.

## 2026-11-05: armnetwork, armkeyvault, armauthorization (xo-lang/azure)

Liked:
- Tagged enums and `derive Json(via: json.Value, to:, from:)` made
  autorest's discriminators a direct fit: `<Base>Classification` is an
  enum with one `Variant(from Struct)` per subtype plus the base for an
  unknown value, and the decoder is a `match` on the tag. It took 30
  generated lines per hierarchy and round-tripped on the first try.
- A valued newtype (`type E struct(Int)`) covers autorest's integer
  enums with no new machinery.
- The exhaustiveness warning (XO0305) on a `_` arm over a closed enum is
  right in library code; in tests it is noise, but harmless.

Disliked:
- `derive Json(tag: ...)` refuses an unknown tag value (a `DecodeErr`).
  Azure services add subtypes over time and Go falls back to the base
  type, so I could not use `tag:` and wrote the dispatch by hand through
  `via:`. A catch-all variant for tagged enums, as valued enums have
  (decision 0493), would remove the hand-written decoder.
- `List` has no `flat_map` (or `flatten`); a loop with `ws = ws + ...`
  stood in.
- The offload hosts' seed is xo 0.37.0, and Xo is self-hosted, so a repo
  that needs a newer Xo cannot be tested off the Mac without building
  Xo there first (reported to the lead).

### 2026-11-05: explicit null in Azure PATCH bodies (azure 2e0bba5)

Liked:
- `json.Patch[T]` did the whole job: Absent omits the key under
  `omitempty`, Null writes `null`, Value writes the value, and decoding
  is symmetric. The generator only had to change a field's type and
  default; the request code did not change.
- The compiler's "did you mean" notes (`chars` is `runes`, `insert` is
  `add`, `contains_key` is `contains`) turned five errors into five
  one-word fixes.

Disliked:
- No struct update syntax (`Model{..m, patch: true}`): copying a struct
  with one field changed means naming every field, which breaks
  silently when a field is added with a default.
- `Set[T]` has no `new()`; only the `#{}` literal makes an empty set,
  and the error for `Set.new()` gives no hint toward it, unlike the
  method-name notes.
- Patch[T] is a field type, so a model shared between a PATCH body and a
  response must pick one; Go's NullValue works at any depth because it
  is a sentinel value of the field's own type. Nested nulls in ARM
  updates (`properties.diagnosticsProfile: null`) still need a way in.

### 2026-11-05: azservicebus over std/amqp and std/amqptest (azure 8e5f7b2, 6269101)

Liked:
- std/amqptest is the httptest of AMQP: queues, topics, dead letters,
  deferral, scheduling, `$management` and CBS in process, with
  inspection (`ready`, `locked`, `dead_letters`, `tokens`). Nine client
  tests needed no emulator and no namespace.
- The broker runs on the test world's in-memory network, so the tests
  are deterministic and need no `--real`.
- Capabilities stored in a client struct (`net`, `clock`, `rand`) and
  `uses` on each method made the effect of every call visible: a peek
  `uses rand` for its message id, a send does not.
- The predeclared-name error named the convention and a fix
  (`Error` is predeclared: name it `AzservicebusErr`).
- Generic `Pager[T]` composed with `Poller[T]` as
  `Poller[Pager[T]]` without changes to either; only a seeded first
  page was new.

Disliked:
- On the in-memory network, a receive with a timeout on an empty queue
  deadlocks (XO-F001) instead of timing out; on loopback it times out.
  Reported to Lang 3 with a repro.
- std/amqp's send has no message format (no batches), receivers have
  no manual credit or drain, and settlements do not wait for the peer
  in settle mode second. Each makes the port weaker than go-amqp's.
- `Bytes` has no `to_list`/`from_list`; reordering 16 bytes took nine
  slices joined with `+`.
- `loop` is spelled `while { }`; the error says so, but it is the third
  Rust habit in a day (`chars`, `insert`, `loop`).
- No `timeout` on macOS for capping a test run, so a deadlocked test is
  bounded only by the runner's own fault.

### 2026-11-05: azservicebus retries and recovery (azure c79ad22)

Liked:
- A generic `retry[T]` taking two effectful closures
  (`fn(Int) -> T ! E uses (net.dial, clock, rand)` and
  `fn(RecoveryKind) uses (net.dial, clock)`) compiled first time; the
  effects of the retried work are part of its type.
- XO0804 (an action under a lock based on a value read in an earlier
  lock) caught a real check-then-attach race in the sender's link
  cache; moving the attach inside one `with` fixed it.
- Match guards on a Result arm (`Err(amqp.AmqpErr.Net(m)) if ...`) kept
  the receive loop flat.

Disliked:
- XO0804 also fires on a deliberate reserve-then-release (mark a lock
  token settled, settle, unmark on failure), with no way to say it is
  intended short of restructuring.
- Durations have no multiply by Float except `scale`; Go's backoff math
  reads better with operators.

### 2026-11-05: azservicebus/admin over the Atom API (azure e832f31)

Liked:
- std/xml's tree API (`parse`, `child`, `children_named`, `attr`,
  `text`) read every Atom entry with local names, prefixed
  `d2p1:ActiveMessageCount` children included, with no structs to
  declare.
- Resolved names keep the `xmlns` declarations as attributes, so a
  small serializer could rebuild an unknown filter's XML with its
  prefixes and match Go's `innerxml` output exactly.
- The test world's FakeNet served `https://` routes for the HTTP admin
  client and the in-process AMQP broker side by side with no `--real`.
- `Float.to_fixed(6)` is Go's `%f`, and `Time.format_rfc3339` trims
  fractional zeros as Go's RFC3339Nano does; both byte-matched Go's
  bodies the first time.

Disliked:
- No `innerxml` or raw span on an element: keeping an unknown element's
  XML as written means re-serializing it, which loses the original
  escaping and self-closing tags.
- `derive Xml` has no namespaced attributes, so Go's
  `xmlns:_XMLSchema-instance` prefix had to be written by hand with
  string building.
- `opt ?? Err(...)` where a Result is wanted is a type error; the
  working spelling is `Ok(opt ?? return Err(...))`, which reads twice.
- A line cannot start with `+`, so long concatenations need the
  operator at the end of each line (the error says so and gives the
  fix).
- `Response.text()` is `Str?` (UTF-8 check) while `Request.body` is
  Bytes with `to_str_lossy()`; two spellings for the same read.
- `T ! E` is not allowed as a parameter type; `Result[T, E]` there and
  `T ! E` in results is one more rule to remember.
- `cat > file` with no input in a shell snippet blocked the run until
  the tool timeout. That one is mine, not Xo's.

### 2026-11-06: azservicebus on amqp5 (azure a21f24b)

Liked:
- Lang 3's amqp5 covered every gap the port listed (message format,
  manual credit, drain, waited settles, modify annotations, the attach
  reply), and the API matched go-amqp's closely enough that each
  adoption was a small change.
- The dead-letter echo bug in amqptest was found, reported and fixed on
  main within the hour; the waited settle in mode Second is what made it
  visible.
- `Receiver.drain` let the port avoid Go's background releaser loop
  with the same outcome (nothing stays locked between receives).

Disliked:
- A `match` arm cannot be a bare `for` loop (`Ok(ds) => for d in ds {}`
  is "expected an expression"); it needs a block around it.
- The reland of the cc object reuse change rode along with the amqp fix,
  so taking a std fix means taking an unrelated compiler change too; the
  gate passed, but there is no way to pin one without the other.
- amqptest ignores the Modified outcome's annotations, so
  properties_to_modify is sent but not checked against the broker.

### 2026-11-06: azeventhubs over std/amqp (azure 72af2ff)

Liked:
- std/amqp's encoding matched go-amqp's byte for byte on the first try:
  a keyed two-event batch and a 300 byte one hash the same as Go's
  EventDataBatch output (Go run locally on a copy of the module).
- amqptest's event hub mode (partitions, selector filters, epoch with
  `amqp:link:stolen`, the namespace `$management` READ) landed within a
  day of the ask, and the client passed against it with one change to
  a test; the get-message-sessions and string expiration asks landed the
  same day.
- XO0701 caught two public constructors that draw a UUID (`uses rand`
  missing), which in Go would be an invisible global.
- `x ?? continue` and `?? return Err(..)` keep the annotation loop as
  flat as Go's switch.

Disliked:
- `Str.parse_int` does not exist; it is the static `Int.parse(s)`. The
  error lists the methods of Str, so the hint never names the function
  that does it.
- A field and a method cannot share a name (XO0603), so Go's
  `InstanceID()` accessor forces the field to be renamed (`id`).
- `amqp.AmqpErr` has no `display`, so `?` on it in a test is an error
  (XO0202) where a library error with `display` converts; tests need a
  wrapper.
- `is amqp.Value.Map` needs `(..)` even when only the variant matters
  (the fix is offered, but it is noise for a variant check).
- A `match` arm cannot be a bare `for` (second time; it bit again here).
- `Bytes.repeat` is a method (`b"a".repeat(200)`), not a constructor;
  the error said so clearly.

### 2026-11-06: azeventhubs Processor and AMQPAnnotatedMessage (azure 70dddbd, 2f62890)

Liked:
- Structural interfaces: `InMemoryCheckpointStore` is a `CheckpointStore`
  by its methods, as Go's, with no declaration to keep in step.
- `defer` runs shielded when the task is cancelled, so `Processor.run`
  maps onto Go's `Run(ctx)` (close the clients, give the partitions up)
  by cancelling its scope, with nothing extra.
- The deterministic scheduler with `--seed` made a two-processor
  end-to-end test easy to trust: six seeds, the same result.
- std/amqp matched go-amqp byte for byte again for header, footer,
  value and sequence bodies; aliasing `AMQPAnnotatedMessage` to
  `amqp.Message` removed a whole conversion layer Go needs.

Disliked:
- `Ok(()) => {}` fails on the native backends with XO1201 "this tuple
  pattern" (support planned); `Ok(_)` works. The unit pattern being a
  tuple pattern is surprising, and the message does not suggest `_`.
- XO0804 flagged a claim-then-undo (mark a partition taken, remove the
  mark when making its client fails) as a stale decision; the two steps
  are deliberately separate and only one task writes the map.
- `List.sort_by` takes a key function, not a comparator; the first try
  with Go's `less(a, b)` shape gave three errors before the right one.
- `Rand.int(lo, hi)`'s half-open range is only in spec/std.md, not in
  `xo doc Rand`.

### 2026-11-06: azeventhubs Blob checkpoint store (azure 5b7d7e8)

Liked:
- FakeNet with path parameters made a stateful fake blob service (a
  `Mutex[Fake]` behind two handlers) about 80 lines, and the request log
  it keeps matched Go's BlobStore on an httptest server line for line,
  escaped path (`%2F` kept inside `{name}`, `$` unescaped) included.
- `url.path_escape` agreed with Go's `url.PathEscape` on the blob names
  with no special casing.
- `x ?? return fail(404, ..)` and `?? continue` keep a handler's early
  exits flat.

Disliked:
- A second `os.net.handle` for a pattern already registered is ignored
  without a word: the first handler keeps serving, so a test that
  swaps a route to make it fail silently tests nothing. spec/std.md 8.1
  does not say which wins. Either replace (and say so) or fault.
  Fixed upstream (xo 18d7ab44b): the last `handle` now wins.
- `req.param("name")` faults when the matched route has no such
  parameter. One handler shared by `PUT .../c/{name}` and `GET .../c`
  needs a method check first; an `Option` returning variant (or `param`
  returning `Str?`) would fit the rest of std. Fixed upstream (xo
  18d7ab44b): `req.param_opt` returns `Str?`.

### 2026-11-06: custom endpoints in azeventhubs and azservicebus (azure f1314c9)

Liked:
- XO0801 refused relay tasks that could fail with `NetErr` on a group
  from outside the function, and named the fix; `.ignore_err("reason")`
  then made each "the peer closed" ending explicit.
- A TCP relay over FakeNet (listen, accept, dial, two pump tasks) was
  enough to prove the dial goes to the proxy and the Open's bytes name
  the namespace; a mutation (dial the namespace) failed it at once.
- The `loop` diagnostic says to write `while { }` and cites the spec.

Disliked:
- `expected \`Conn\`, found \`Conn\``: a module's own `struct Conn` hides
  the prelude's `Conn`, and the error prints both bare. It should
  qualify them (`prelude.Conn` vs `azeventhubs.Conn`) or say one hides
  the other; there seems to be no way to name the prelude's type once
  it is hidden. Fixed upstream (xo 71583ef3b): the mismatch now names
  each type by module path.
- std/amqp's `dial` takes the TLS server name from the address, with no
  option to set it: a proxy in front of a TLS service cannot be checked
  against the service's name (go-amqp uses the Open's hostname). Fixed
  upstream (xo 4bd90321b): `ConnOptions.hostname` is the SNI and
  certificate name; azure 150fb2f dropped the README deviation.
- No `List.dedup` or `distinct`; a for loop with `contains` stood in.

### 2026-11-06: storage/azqueue (azure c3d8de4)

Liked:
- `xml.escape` is Go's EscapeText, so hand-written XML bodies matched
  encoding/xml byte for byte on the first run (`&lt;&amp;&gt;` included),
  and every Shared Key signature of 25 requests matched Go's.
- Default arguments and `with` kept the port small: Go's option structs
  with format() defaults became parameters with defaults.
- `std/json`, `std/xml`, `url.values().encode()` and `http.parse_url`
  covered everything; no hand-rolled query encoding.

Disliked:
- `std/url` has no URL parser; it is `http.parse_url`, whose `Url` has
  the query as a `Map` and no raw query or escaped path. Splitting a URL
  for a SAS meant reading the raw string again.
- `Option.or` does not exist (the error suggests `??`, which is right),
  but `a ?? b ?? ""` reads oddly the first time; a note in the error
  that `??` chains would help.
- No rune-to-int method; `Int(c)` works but was a guess.
- The check-public rule wants signature hashes in test vectors; a small
  std helper for "hash this secret for a golden file" would save each
  repo writing its own `hide()`.

### 2026-11-06: data/aztables (azure 184ab06)

Liked:
- `json.parse_value` keeps an integer as an exact `Int` and `JsonWriter`
  writes floats as Go's floatEncoder, so re-encoding an entity the way
  Go re-encodes `map[string]any` (sorted keys, `<`, ` `,
  `1e+21`, `-0`) took a 30 line function, and keeping Int64 digits
  that Go rounds away was a one line choice, not a workaround.
- `Request.escaped_path()` and `raw_query()` are Go's EscapedPath and
  RawQuery: logging them made the fake's request lines Go's RequestURI
  exactly, so all 28 requests (SharedKeyLite signatures and the
  multipart batch body included) compared byte for byte on the first
  full run.
- `xo check` reported all 13 first-draft errors at once, each with a
  fix line (`r.ok() ?? default`, missing fields, unused import).
- Six mutations (no `?comp=` in the signed resource, no Cosmos MERGE
  policy, filled batch headers, unsorted keys, no quote doubling, no
  HTML escaping) each failed the differential test.

Disliked:
- `select` is a keyword, so Go's `Select` option cannot be a field
  named `select`, and there is no raw identifier (`r#select`) to keep
  the name. It became `select_fields`.
- FakeNet's `req.path` is the decoded path, which first looked like
  the client had sent `a''b` instead of `a%27%27b` (a signature the
  real service would reject). The doc for `path` could say "decoded;
  `escaped_path()` for the bytes sent".
- A mutation that drops a `let` binding's only use is a hard error
  (unused variable), so a quick "delete this use" mutation needs a
  dummy use; a `--allow-unused` test flag would help.

### 2026-11-06: data/azcosmos (azure d5afa3e)

Liked:
- `json.tokens` and its `offset()` and `skip()` let a query page hand
  back each document's raw JSON bytes, as Go's `[][]byte`, without
  re-encoding. The slices were the service's bytes exactly.
- The master key signature (lowercased verb, resource type and date,
  unescaped resource address, HMAC-SHA256, then query-escaped) ported
  in a dozen lines over `std/crypto` and `std/url`. All 24 requests,
  signatures included, matched Go on the first full run once the
  fake logged escaped paths.
- Seven mutations (wrong address for a feed, no `Prefer` header, no
  upsert header, no query header, wrong offer header, no region
  routing, untrimmed raw slice) each failed a test.

Disliked:
- `runtime.new_pipeline` always adds `x-ms-client-request-id`
  (decision 0003) and Go's `azcore.NewPipeline` does not, so every
  differential has to filter that header. A pipeline option to leave
  it out would let ports match Go without a filter.
- Float to Int is `Int(f)` (spec/std.md 96: truncates toward zero,
  faults on NaN or out of range). I looked for `Float.to_int()` and
  wrote `Int(f.trunc())` before Lang 3 pointed at it. Corrected: the
  note is discoverability (`xo doc Float` does not mention the `Int`
  conversion), and a non-faulting form would need a range guard
  today, as azcosmos's `int_of` now has.
- (Not Xo: my own Azure code.) `BearerTokenPolicy`'s token cache was
  private, so the Cosmos AAD policy copied it. Fixed in azure fac0f57
  with a public `runtime.TokenCache` (decision 0003 amendment 1,
  Proposed).
- A closure inside a `${...}` interpolation is rejected when it spans
  lines inside a one-line `"..."` string: `"[${xs.map(fn(v: Int) -> Str {`
  then the body on the next lines gives XO0151 "string literal not
  terminated" and XO0156 "`${` is not closed by `}`" at the string's
  start, then follow-on errors (`v` not found). A one-line closure in
  `${}` checks clean (Xo Lang 1 checked). The error could say that a
  `"..."` string cannot span lines and suggest `"""` or a `let`.
  (Corrected: this entry first said the error pointed at the closing
  brace.)
- Process note, not the language: a fake that returned one document
  hid an untrimmed slice bug until a two-document test was added.

### 2026-11-06: azcosmos transactional batch (azure 48b3ede)

Liked:
- `json.tokens` again: a batch result's `resourceBody` is kept as the
  service wrote it (spacing inside included) by taking `offset()`
  before and after `skip()`, which is what Go's `json.RawMessage`
  gives. All 9 new requests matched Go on the first run.
- The fix lines after the first draft were each exactly right:
  "construct it with names: `Upsert(item: ..., etag: ...)`" and
  "write `Read(..)` to match any of them".
- `b with {ops: b.ops + [op]}` made the batch builder a value, like
  PatchOperations, with no `var` at the call site.

Disliked:
- A positional enum variant (`Create(Str)`, as in Rust) reports
  "field name `Str` must be snake_case" with the fix "rename to `str`",
  then "expected `:` after the variant field name". The real fix is a
  named field (`Create(item: Str)`). A first error saying "variant
  fields are named (core 2.3)" would save the detour; the fix line
  offered now leads to `Create(str)`, which is also wrong.
- `"${f}"` for a Float prints `1.0` where Go's `%v` prints `1`. That is
  a fair choice, but every Go differential that prints floats needs a
  small `go_float` helper; a `f.format_go()` or `%v`-style formatter
  in std would cover it.
- Mutation testing again ran into the unused-binding error: two
  mutations needed `_e` or `has_read && false` to compile (same note
  as aztables).

### 2026-11-06: azcosmos retry and failover (azure 1f45969)

Liked:
- XO0540 caught a real bug in the first draft: the endpoint manager's
  `Mutex.with` closure recorded the failed account read's attempt time
  and error, then returned `Err`, which undoes the closure's writes. Go
  keeps both, so the next call would have re-read the account at once
  instead of waiting. The note gave the exact fix: return the outcome
  as the closure's value and apply `?` outside.
- XO0804 flagged a check-then-act race: whether a forced refresh was
  stale was read in one `with`, and the refresh was claimed in
  another, so two failing calls could both force it. Checking and
  claiming in one `with` is what Go's CompareAndSwap does.
- XO0501 on a test closure that pushed to a captured `var` list said
  closures capture by value and offered `Mutex`/`Atomic`, which fixed
  it in one edit.
- Keeping the routing state as plain values (`Locations` with
  `update`, `mark`, `resolve` returning new values) made the location
  cache unit-testable without a fake network, including the 5 minute
  expiry with a computed `now`.

Disliked:
- No destructuring assignment: `(retry, st) = p.on_x(st)` is XO0502
  ("cannot assign to this expression"). Each arm became `let (r, s2) =
  ...; retry = r; st = s2`. A note pointing at that form, or allowing
  tuple assignment to existing `var` bindings, would help code that
  threads state through helpers.
- `FakeNet.fail` stops the request before the handler, so a test that
  logs in its handler cannot see the failed attempts; the count came
  from `net.requests()`. That works, but the doc for `fail` could say
  the handler is not called and point at `requests()`.

### 2026-11-06: azcosmos partition key range cache and feed ranges (azure ee0f9c0)

Liked:
- MurmurHash3 x64_128 ported cleanly onto Int as a 64-bit word:
  `wrapping_mul`, `wrapping_add`, `wrapping_shl`, `shr_logical` and
  `rotate_right` cover every step, and `Float.to_bits`/`from_bits`
  gave the number encoding and exact vectors (negative zero included).
  All 29 of Go's baseline cases matched on the first run.
- A `Mutex[Map[Str, Mutex[T]]]` (outer lock to find or create an entry,
  inner lock held across the network read) gave Go's per-container
  single flight in a few lines, and the generic `entry_of[T]` served
  both caches. The "return the outcome as the closure's value" pattern
  from the failover slice applied unchanged.
- The virtual test clock made the 429 backoff checkable: two throttled
  tries advance it by 300ms to 350ms, asserted exactly, with no real
  wait.
- 22 tests passed on the first compile after two errors, and 10
  mutations (parent removal, If-None-Match, 429 retry, combine, cache
  store, etag carry, completeness, overlap start) each failed a test.

Disliked:
- A `while true { match ... { Ok(p) => return Ok(p) ... } }` loop that
  can only leave by `return` is XO0401 ("expected `FeedPage`, found
  `()`") at the function's end. Rewriting as a bounded `for` plus a
  final call works, but a loop with no exit could type as never, or
  the note could suggest that rewrite.
- `os` is only in scope inside `test` blocks, so a test helper that
  builds a client must take `net`, `clock` and `rand` as parameters.
  XO0601 said "name `os` not found" and suggested `Ok` and `js`; a
  note that `os` is a test-block binding would have pointed at the fix.
- No sort with a comparator: Go sorts ranges with CompareEPK, here
  `sort_by` needs an `Ord` key, so the key is the EPK with trailing
  zeros trimmed (equivalent for hex digits, but it needed an argument
  in a comment). A `sort_with(fn(a, b) -> Int)` would port such code
  directly.

### 2026-11-06: azcosmos ReadMany (azure 3ac0d8c)

Liked:
- The differential caught a real divergence in an earlier slice: Go's
  query responses re-marshal each document (compact, HTML escaped), and
  the port's query pager had kept the service's text since d5afa3e
  because the old fake only returned compact documents. One helper
  (`documents`, reusing the batch slice's `compact`) fixed both the
  pager and ReadMany.
- `crypto.sha256(body).to_hex()` let the 1001 item query (52 KB body)
  be compared with Go's byte for byte by hash.
- 27 tests, and 15 mutations (prefix range, version 1, chunk size, the
  three query shapes, IS_NULL, gone substatus, cache invalidation,
  continuation, range id header, compaction, range bounds, identifier
  digits, range order) each failed a test or hung. The prefix one first
  survived, which showed the fake had no range split inside a prefix's
  span; a unit test now has one.

Disliked:
- `List.enumerate()` does not exist; it is `indexed()`. XO0601 listed
  the first dozen methods (`indexed` among them), which was enough, but
  a "did you mean `indexed`" for the common name from other languages
  would be quicker.
- XO0804 warned that a test fake's second `f.state.with` "acts on a
  decision about `n`" read in the first, although the first is on a
  branch that returns before the second runs. Splitting the state into
  two Mutexes silenced it; the check could follow the `return`.
- A mutation that drops the continuation token makes the page loop
  unbounded; the test run then grows memory until the heavy-job cap
  stops it, with no output. A per-test timeout in `xo test` would make
  such a hang a named failure.

### 2026-11-06: azcosmos change feed (azure e127dde)

Liked:
- The composite token as a value (`CompositeToken` with `advance` and
  `replace_head` returning new tokens) made the queue rotation easy to
  unit-test without a fake network, and the 13 Go cases matched on the
  first run.
- `time.format(t, time.utc(), time.RFC1123)` ends in `UTC` exactly as
  Go's `time.RFC1123` does on a UTC time (the HTTP date helper swaps in
  `GMT`), so If-Modified-Since needed no special case; the spec says so
  in one line.
- 15 mutations; two first survived (children inheriting the etag on a
  split, the token taking the container's resource id), which showed two
  untested Go paths. Both are now Go-verified cases.

Disliked:
- A mutation that left `pmin` unused failed to compile ("rename to
  `_pmin`") instead of failing a test. Right for real code, but
  mutation runs need a second, use-preserving variant. Not a language
  problem; noted for the method.
- Returning partial pages together with an error (Go returns a
  response and an error) has no direct form: `Result` carries one or
  the other. A `Partial[T, E]`-style convention or documenting the
  pattern (an error variant carrying the partial value) would help
  ports of Go APIs that do this.

### 2026-11-06: azcosmos offers and vector/full text policies (azure ab57df0, c273c5b)

Liked:
- `t with {manual: ..., autoscale_max: ...}` made the offer replace
  (read the offer, swap its content, PUT it) one expression, and the 7
  throughput cases matched Go's requests on the first full run.
- Defaulted struct fields (`List[T] = []`, `T? = None`) let the new
  policy fields land in `ContainerProperties` and `IndexingPolicy`
  without touching any existing constructor or test; all 34 tests kept
  passing and the 3 new Go cases matched first time. 8 mutations, all
  caught.

Disliked:
- A Go nil slice and an empty slice marshal differently (`null` vs
  `[]`); a Xo `List` has one empty value, so a port that must echo
  both needs a `List[T]?` field, which every caller then has to wrap.
  Ports of Go JSON models would benefit from a documented convention
  (or a std/json helper) for "omitted, null, or empty".
- `match c.get("x") { Some(json.Value.Object(_)) => ... }` binds
  nothing usable, so the object is fetched a second time with
  `?? json.Value.Null`. An `as`-style binding on a nested pattern
  (`Some(json.Value.Object(_) as a)`) or matching the object's map
  directly would remove the repeat lookup.

### 2026-11-06: azfile directory client (azure 6e4659b)

Liked:
- A `Reads{smb, nfs, last_modified, file_type, metadata, encrypted}`
  struct with defaulted fields let one `dir_response` serve six
  operations that each read a different subset of Go's response
  headers; `Reads{nfs: false}` reads as the difference from the norm.
  The 26 requests and every dumped field matched Go once the test's
  own time constants were right (the client was right on the first run).
- The compiler's XO0160 note on `T ! E` in a parameter (write
  `Result[T, E]`) said exactly what to type.
- Mutation testing found 4 survivors that were test gaps, not bugs
  (a delete reply with an ETag, a metadata reply with SMB headers, NFS
  with property semantics, a rename to `d3/`); each became a Go case.

Disliked:
- No struct embedding: the six per-operation Go response types share
  most fields, so the port either flattens them into one
  `DirectoryResponse` (fields that stay `None` for some operations) or
  repeats them six times. I flattened them; a documented
  embedding or "struct spread" would keep the types honest.
- `std/url` has `path_escape` (one segment) but nothing that escapes a
  path while keeping its slashes, so `to_url` has a hand-written
  `escape_path` and Go's `$&+,;=:@` rules differ (noted in the README).
- Process, not language: I once chained the pre-push checks with `;`
  instead of `&&`, so a gitleaks finding did not stop the push. The
  checks now gate the push with `&&`.

### 2026-11-06: azfile file client, no data calls (azure 7132e26)

Liked:
- Payload enums replaced Go's sealed-interface trick for copy
  properties (`SourceCopyFileCreationTime{}` vs
  `DestinationCopyFileCreationTime(t)`, each with an unexported marker
  method): `enum CopyFileTime { Source, Destination(t: Time) }` and a
  three-arm match say the same thing in five lines.
- `FileReads{...}` with defaulted fields scaled from the directory port
  to eleven calls that read eleven different header subsets; 23
  mutations of the read and request rules, one survivor (a test gap,
  now a Go case).
- XO0406 on `r ?? default` for a Result named both fixes (`?? e =>` or
  `.ok() ??`).
- The byte-for-byte replay caught a real signing bug in the shared
  azblob Shared Key code: a URL joined with a raw space was signed as
  written, where Go signs `EscapedPath()` (`%20`). Every earlier vector
  used already-escaped paths.

Disliked:
- Escaping a path the way Go's url.EscapedPath does needed a hand loop
  over runes with `"${c}".bytes().to_hex()` per character: std/url has
  `path_escape` (one segment, escapes `/` and `;,`) but no "escape a
  path, keep the reserved characters" function, and an http.Request has
  `escaped_path()` while a URL string does not. A `url.escape_path(p)`
  (Go's encodePath mode) would remove both this and azfile's own
  `escape_path`.

### 2026-11-06: azfile file data calls (azure 649bcb2)

Liked:
- `Bytes.quote()` is Go's `%q` of a byte slice exactly (`\a`, `\x7f`,
  `\xff` included), which replaced a hand-written escaper in the test
  dumps; `binary.u64_le` covered the CRC64 header, -1 included.
- The data slice matched Go's 23 cases (21 requests) on its first run, the empty
  `x-ms-range` header Go sends for a count of 0 included. 25 mutations;
  the 2 survivors were test gaps, now Go cases.
- `while start < count` chunk loops read plainly, with no XO0401 (only
  a `while true` that exits by return is flagged).

Disliked:
- No way to test-print: `println` is not in scope in a test, and the
  XO0601 note points at `os.stdio.println` or `dbg`. I probed with
  `expect` instead. A note that `dbg(x)` works in tests, or an example,
  would save a round trip.
- Go's chunked helpers run in parallel; a sequential port is simpler
  but slower on real transfers. A small std helper for "run these N
  calls with at most K in flight, keep the first error" (Go's
  DoBatchTransfer shape) would make a faithful port cheap.

### 2026-11-06: azfile leases (azure 8352ef5)

Liked:
- A `var` receiver (`fn (var l: ShareLeaseClient) change(...)`) ported
  Go's "Change updates the client's lease ID on success" exactly, with
  the mutation visible at the call site (`var sl = ...`). 16 requests
  matched Go on the first run; 13 mutations, all caught.
- `uuid.v4(rand)` takes the Rand capability, so the generated lease ID
  shows in the constructor's signature (`uses rand`) and the test
  checks its version with `uuid.parse(...)?.version()`.

Disliked:
- `break` is a keyword, so Go's `Break` became `break_lease`. Raw
  identifiers (Rust's `r#break`) or a rule that a keyword is allowed as
  a method name after `.` would let ports keep the Go name.

### 2026-11-06: azfile SAS (azure 89622c7)

Liked:
- `std/netip` reproduced Go's `net.ParseIP` plus `IP.String()` in three
  lines (`parse_addr`, refuse a zone, `unmap()` an IPv4 in IPv6 form),
  leading zeros refused as Go refuses them.
- `time.date` and `time.instant` validate a civil time (2027-02-29 is
  refused), so the hand-written reader of Go's four SAS layouts only
  scans digits and leaves the calendar to std.
- `url.Values` keeps keys in first appearance order, which turned a
  map-order nondeterminism in Go's NewQueryParameters (which of `st` and
  `skt` sets the shared layout) into a defined rule.
- XO0177 for `loop` names the fix (`while { ... }`) and the spec section.
- 43 Go cases (account, share, file and user delegation SAS, GetSASURL,
  ParseURL); the only first-run difference was the fraction below. 36
  mutations: 5 survivors were test gaps (now Go cases), 1 equivalent.

Disliked:
- `{frac:7}` writes the leading dot, unlike every other field (`{second}`
  is bare digits). The spec says "exactly three" for `{frac:3}` without
  saying the dot comes with it; I wrote `.${frac}` and got `..1234567`.
  One line in 13.3, or a `{frac_digits:7}` field, would prevent it.
- No way to parse with Go's own layout semantics (a one-digit `15` hour,
  a fraction accepted after `05`, `.0000000` needing exactly seven
  digits), so a port of Go's time.Parse callers needs a small scanner.
  A `time.parse_go(s, go_layout)` in a compat module would cover every
  SDK port that reads Go layouts.
- Answer (Lang 3): the dot in `{frac:N}` is by design (write
  `{second}{frac:7}`), and the field-list doc is getting fixed. A Go layout
  parse needs an ADR and an owner call (decision 0087), so the azure
  modules keep their own layout scanner for now.

### 2026-11-06: azblob to Go v1.8.3 (azure e3e8c1b)

Liked:
- A `List[(Str, Str)]` field (`signed_request_headers`) turned Go's
  map-ordered srh/srq signing (random signature per run, draft 20) into a
  caller-ordered one with no extra type; a struct-field default of `[]`
  kept every existing literal compiling.
- `key with {signed_delegated_user_tenant_id: ...}` built the tenant case
  from the shared test key in one expression.
- All 14 v1.8.3 vectors matched on the first run; 12 of 12 mutations of
  the new signing code were killed by the Go vectors.

Disliked:
- `'${c}'` on a rune prints the character; Go's `%v` on a rune prints the
  number, so matching Go's error text took `${Int(c)}`. Easy once known,
  but nothing points at it; a note in the string interpolation section
  ("a rune prints as its character; Go's `%v` prints the code point")
  would help ports.

### 2026-11-06: azblob service, container, blob and lease clients (azure b08f81e)

Liked:
- `o.conditions with {if_match: Some(e)}` replaced Go's ETag lock in
  DownloadBuffer (clone the options, clone the inner pointer struct, set
  one field: 12 lines) with one expression, and nothing is aliased.
- A `(var l: BlobLeaseClient)` receiver makes `change_lease`'s ID update
  visible at the call site (`var bl = ...`); a failed change leaves the
  ID alone, as Go's does, with no extra code.
- XO0206 refused `let _ = held.change_lease(...)` in a test until I gave
  a reason (`.ignore_err("the 409 is the point")`). Right call: the
  discard is now documented where it happens.
- Byte identity with Go v1.8.3 on the first full run: service and
  container (30 cases), blob (19), leases (19). Downloads differed in one
  field, which turned out to be a Go bug (below). 10 mutations of the
  download and lease logic: 9 killed at once, the survivor showed a
  missing Go case (a server that ignores Range), now added.

Disliked:
- No `Bytes.from_list` and no hex formatting on a byte: Go's `%q` of
  bytes took `b[i..i + 1].to_str_lossy()` and
  `Int(c).to_str_width(2, base: 16, zero: true)`. A `UInt8.to_hex()` (or
  `Bytes.escape_go()` in a compat module) would cover it.
- Still no bounded parallel helper: `download_buffer` asks for its
  blocks one at a time where Go asks five at a time. Same gap as the
  azfile uploads; a `parallel_map(xs, limit, f)` in std would close both.

Go bugs met (for the lead's draft list, not filed):
- `convertDownloadResponse` drops `SmartAccessTier`, which the generated
  download response reads.
- `deserializeORSPolicies` never fills `ObjectReplicationRules` (it
  looks for `or-` after the prefix is already gone).
- `SetTags` writes its map in map order (random body per run); GetTags
  ignores `BlobModifiedAccessConditions`.

### 2026-11-06: azdatalake service and file system clients (azure 7074691)

Liked:
- `options with {audience: ""}` states Go's quirk (the blob client gets
  the pipeline options and not the audience) in one visible line; in Go
  it is an omission you only find by testing with a token.
- `pub type ClientOptions = azblob.ClientOptions` and the other aliases
  let the module reuse azblob's types with no wrappers and no second
  blob core.
- `.map_err(to_dfs_error)` on each call reads as Go's
  `ConvertToDFSError` does, with no `if err != nil`.
- 28 cases byte-identical to Go on the first full run; 10 of 10
  mutations killed after one added Go case (a host with `.dfs.` twice).

Disliked:
- XO0402 could not infer `T` in `fn dfs[T](r: Result[T, CallErr]) -> T !
  CallErr` from the argument `c.create(...)`, whose type is fully known
  (`Result[ETagResponse, CallErr]`). Inferring a type argument from an
  argument's type is the common case; the note's two fixes (explicit
  `dfs[T]` or an expected type) both cost more than the helper saved.
- Test helpers cannot be shared across modules, so the fake service and
  Go dump helpers (200 lines) are copied from azblob's tests. A
  `testdata`-style shared test package, or `pub(test)` items importable
  by tests of other modules, would remove the copy.
- Under `testing.FakeNet`, `req.host()` is empty while `req.url.host`
  has the host. Either both should be set or `host()`'s doc should say
  it is the Host header only.

### 2026-11-06: azdatalake list pagers and the DFS core (azure 777bb91)

Liked:
- `json.parse_value` plus a `match k { ... }` over the object's fields
  ported Go's hand-written `Path.UnmarshalJSON` (string-encoded numbers
  and booleans, case-sensitive keys, null left unset) line for line.
- `runtime.new_pager_with` took a custom next-request rule in one
  closure, so the pagers rebuild the sorted query as Go does instead of
  appending the marker.
- A generic wrapper struct (`DfsPager[T]` around `runtime.Pager[T]`)
  mapped every page error in three lines.
- 4 pagers, 12 cases, byte-identical; 18 mutations, the 2 survivors
  were test gaps (now Go cases).

Disliked:
- `Bool ? ! Str` (a typo, with a space before `?`) was accepted with no
  warning. `xo fmt` would likely normalize it, but the gate does not run
  fmt here, so a lint in `xo check` would catch it sooner.
- A mistake of mine the tooling could not catch: Go's reflective dump
  prints a nil `[]byte` as `""`, and I first read that as "Go fills an
  absent hash with empty bytes" and built it into azblob (since fixed:
  None, and the Xo dump prints `""` for None). Nothing in Xo to fix;
  noted so the next port's harness writer knows.

### 2026-11-06: azdatalake paths and ACLs (azure 3e65be2)

Liked:
- A closure in a struct field (`blob_at: fn(Str) -> azblob.BlobClient`,
  capturing the credential, `net`, `clock` and `rand`) gave Go's "a new
  blob client with the same credential" for sub-paths without an enum of
  credential kinds or threading capabilities through every client.
- `?? e => return Err(...)` and `x with {...}` kept the recursive ACL
  loop (paging, totals, the partial result on error) as short as Go's.
- XO0177 (`loop` is Rust syntax, write `while`) and XO0178 (a line that
  starts with `+`) named the fix exactly.
- About 1,400 lines of Go requests and responses matched byte for byte;
  the one difference was my test log dropping the port. 51 mutations:
  5 survivors were test gaps (now Go cases), 2 are equivalent.

Disliked:
- `Bytes` has no `contains(byte)`, `all` or `any`; I wrote `all_bytes`
  and `has_byte` loops for Go's URL escaping rules.
- `type U8 not found` did not suggest `UInt8`. A "did you mean" for the
  common short spellings (`U8`, `u8`, `byte`) would save a round trip.
- No URL parser keeps the raw (escaped) path: `http.Url.path` is all
  there is, so Go's `URL.EscapedPath` (raw path when it is a valid
  escaping, else re-escaped) and `URL.String` were hand-written.
  `std/url` with Go's `Parse`, `RawPath`, `EscapedPath` and `String`
  would make every "rebuild this URL as Go does" port shorter.
- XO0178 fires on every long expression wrapped with a leading `+`
  (my habit from Go's style). The fix is mechanical; `xo fmt` or a
  `xo fix` applying it would beat four rounds of edit and check.

### 2026-11-06: azdatalake file data (azure d1d951a)

Liked:
- About 700 lines of Go requests and responses (append, flush, chunked
  upload, ranged and chunked downloads, a 304, error paths) matched on
  the first run. Reusing slice 2's request and strict-parse helpers
  meant the new file was mostly Go's option mapping.
- `std/base64`'s `DecodeErr` displays as Go's `CorruptInputError`
  (`illegal base64 data at input byte 2`), so the strict header decode
  needed no hand-written offset logic.
- A tuple return (`(DownloadStreamResponse, http.Response)`) was a
  one-line way to hand a raw response up from azblob, where Go needs a
  context-carried capture.
- 39 mutations, all killed once two status-code gaps had Go cases.

Disliked:
- A mutant that leaves a `let` unused fails to compile (XO0110 is an
  error, not a warning), so mutation scripts need a different mutant
  for every "drop this header" case. A `--allow-unused` flag for
  `xo test` (or a warning level) would help mutation runs.
- No bytes-on-a-file-handle story to port Go's `UploadFile` and
  `DownloadFile` against yet (fs effects), so azblob, azfile and
  azdatalake all stop at the bytes forms.
- Not Xo: Go's batch transfer with `Concurrency: 1` still raced one
  chunk past a failure, so the Go vectors needed the failure on the
  last chunk to be deterministic.

### 2026-11-06: azdatalake leases (azure de8501c)

Liked:
- A `var` method on a field of a `var` receiver
  (`l.inner.change_lease(...)` inside `fn (var l: PathLeaseClient)`)
  updated the inner client in place, so the wrapper kept Go's "new ID
  only on success" with two lines.
- `Result.map_err(to_dfs_error)` made each wrapped call one line.
- The Go and Xo runs matched on the first try; 16 mutations, one gap
  (a renew with conditions), now a Go case.

Disliked:
- Nothing new in this slice; it was a thin wrapper over azblob.

### 2026-11-06: azdatalake SAS (azure 47bf39a)

Liked:
- `pub type QueryParameters = blobsas.QueryParameters` and friends let
  the datalake `sas` package hand out azblob's types, so the port
  reused azblob's signer through one field map and matched Go's 178
  vector lines on the first run.
- `with` struct updates (`all with {file_path: ...}`) made each test
  case read like Go's copy-and-change of a values struct.
- XO0177 caught a Rust-style `loop {` and named the fix (`while {`).
- 40 mutations; the survivors were equivalent, and two of them showed
  code that could be simpler.

Disliked:
- An `http.Response{...}` literal needs every field (XO0403), so a
  test fake has to find the `http.text` helper instead; a defaulted
  `headers` field would make the literal usable.
- XO0110 again turned two mutants into compile errors (an unused
  `let`), as in the file data slice.

### 2026-11-06: azdatalake datalakeerror (azure 3f52bcd)

Liked:
- XO0601 caught a Go-style `panic(...)` in a test and named Xo's
  `fault(...)`, with the reason (broken invariant vs `Err`).
- Plain `pub const NAME: Str` codes were simple to generate from Go's
  source and to diff against it one to one.

Disliked:
- Nothing new in this slice; it was a list of constants and one
  matcher.

### 2026-11-06: azqueue responses and errors (azure e35ed16)

Liked:
- A match guard on an option (`Some(v) if v != "" => ...`) read the
  Go "header set and non-empty" rule in one arm.
- `with` on a defaulted struct field (`page with {response: resp}`)
  let a pager page gain Go's response fields without changing the
  parser.

Disliked:
- `Time.parse_rfc3339(x) ?? Err(...)` in a function returning
  `Time ! Str` is a type error (XO0401: the right side is a Result,
  the left a Time). The prelude already has the fix,
  `Option.or_err(e)`, but XO0401's note suggested only `?` or `match`;
  naming `or_err` there would have saved a detour. (Corrected: this
  entry first asked for an `ok_or` helper that `or_err` already is.)

### 2026-11-06: storage challenge policy (azure 337f58f)

Liked:
- An optional function-typed field with effects
  (`Option[fn(policy.Request, Authorizer) -> policy.Request ! SendErr uses (net.dial, clock, rand)]`)
  compiled the first time, so azcore's nil-checked AuthorizationHandler
  hooks ported directly.
- Two closures sharing one `Mutex[List[Str]]` gave the challenge
  policy its persistent scopes with no extra type.

Disliked:
- `http.Response.header(name)` joins repeated fields with ", ". Its
  signature and the std listing don't say so, while Go's `Header.Get`
  returns the first value. A vector diff caught it in the new code,
  and it turned out to be a latent bug in the Key Vault challenge
  port too. A doc line, or a `header_first`, would help Go porters.
- A helper function in a test file can't see `os`. XO0601 said "name
  `os` not found" and suggested `Ok` and `ts`. A note that `os` exists
  only in test bodies (pass `os.net` in) would have pointed straight
  at the fix.
- `xo test --run` takes a substring, not a regex: `--run="a\|b"`
  matched nothing, and the message said only that no tests matched.

### 2026-11-06: azqueue SAS and URLs (azure 40ef4f4)

Liked:
- `pub type URLParts = sas.URLParts` mirrored Go's
  `type URLParts = sas.URLParts` alias exactly, and existing callers
  of the root name kept compiling.
- `match k.to_lower() { "sv" => { ... } ... _ => { known = false } }`
  read like Go's string switch, which made the field-by-field port
  easy to check against the source.

Disliked:
- Turning bytes back into a `Bytes` took a detour.
  `Bytes.from_list(out)` was XO0601 ("no associated function or
  constant `from_list`") with no note. The answer was `BytesBuilder`
  (`write_byte`, then `freeze`), which I found by grepping the prelude.
  A note naming `BytesBuilder` would have saved that.

### 2026-11-06: azqueue v0.2.0 constructors and URLs (azure c927559)

Liked:
- `path.clean` is Go's `path.Clean`, so azcore's `runtime.JoinPaths`
  (path.Join of one segment) ported line for line, and the vectors
  (including `a/../b` and trailing slashes) matched on the first run.
- The lead reported that the XO0401 `or_err` note from the earlier
  entry has landed (xo 41ec7737b), less than an hour after I wrote it
  up.

Disliked:
- Building a fixed UTC instant in a test took three fallible steps:
  `time.instant(time.date(y, m, d).ok()?, time.ClockTime{...}, time.utc()).ok()`.
  I mixed up the fallback types (XO0401 "expected `time.Date`, found
  `Time`", which was a clear message) and switched to
  `Time.from_unix_millis(<computed>)`. Afterwards I saw that
  `Time.parse_rfc3339("2026-11-06T00:00:00Z")` would have been one
  call. It isn't missing, but an infallible
  `Time.utc(y, m, d, h, min, s)` for literals would make test fixtures
  read better.

### 2026-11-06: storage helper dedupe (azure 5082338)

Liked:
- A constant can be defined as another module's constant
  (`pub const TIME_FORMAT: Str = blobsas.TIME_FORMAT`), so azfile
  kept its public names while the values come from one place.
- Moving 160 lines of copied helpers onto azblob's needed no change
  to any vectors file, and every module's tests passed on the first
  run.

Disliked:
- Keeping a module's private name meant writing a one-line forwarding
  function for each helper (`fn go_quote(s: Str) -> Str {
  exported.go_quote(s) }`). I didn't find an import form that brings
  a single function into scope under its own name.
- The copies had already drifted. azqueue's `go_quote` turned out
  not to escape `\n`, `\t` or `\r`, unlike azblob's and Go's. Nothing
  flagged two same-named private functions that differed; I found it
  only by diffing them. That is a project-hygiene problem more than a
  language one, but an easy way to share a single function would
  have prevented the copies in the first place.

### 2026-11-06: Go url.Parse for storage URLs, azfile parse_url (azure 263ad6f)

Liked:
- std/netip's errors are Go's text word for word, so wrapping them as
  Go's url.Parse does (`invalid host: ParseAddr("zz::1"): each
  colon-separated field must have at least one digit (at "zz::1")`)
  matched the Go vectors on the first run, as did the cases with two
  closing brackets.
- core.md 1.6 lists the escapes on one line (`\n \t \r \0 \\ \" \' \$
  \xHH \u{...}`, with `\xHH` at most `\x7f` in `Str`), so the generated
  test could keep Go's `"\x01"` literals as they were.
- std.md states plainly where `url.parse_query` differs from Go
  ("Go keeps the pairs parsed around an error; Xo returns the error
  alone"). That told me why a URL with one bad pair lost all its
  parameters, without any debugging.
- 263 lines of Go output matched after one fix (go_quote's control
  bytes), and a 31-mutant run killed 29. Of the two survivors, one
  pointed at a missing test case and the other at a redundant branch,
  which I removed.

Disliked:
- Because of that `parse_query` difference I wrote my own
  `go_query`. A port from Go wants Go's behavior. A form that returns
  the pairs it read along with the first error (Go's own shape) would
  let ports use std directly.

### 2026-11-06: repeated response headers, AWS generator and core (aws 773e83b)

Liked:
- `http.Response.header_values(name)` returns every field in order
  (decision 0288), and `add_header` adds one more field. That made a
  Go port of smithy-go's list splitting, and fakes that repeat a
  header, short to write. The 48 smithy-go vectors matched on the
  first run.
- Regenerating all 435 services and type checking them took a single
  script run, so I could show that a generator change compiles
  everywhere before I committed it.

Disliked:
- `resp.header(name)` joins the fields with `, `, but code ported from
  Go reaches for it as if it were `Header.Get`, which takes the first
  field. That one difference was behind 13 hand-written AWS sites and
  the generated scalar, list and prefix readers, and about 45 more
  sites in the Azure SDK. A std method with Go's `Get` meaning (for
  example `first_header`) would give ports the right default. So would
  a doc line on `header` saying it is not Go's `Get`.

### 2026-11-06: repeated response headers, Azure SDK (azure 0742aaa)

Liked:
- A policy is a plain struct with a `send` method, so a test-only
  policy that repeats every response header field took 15 lines.
  Adding it as a per-retry policy reran 22 Go vector tests with doubled
  headers, without touching the fakes. It found one site that my
  search had missed.
- When `?` could not convert `CallErr` to a runner's `Str` error type,
  the compiler note listed the conversion rules (same type, `Error`
  with `Display`, or a `from` variant). Switching the runner to
  `! Error` fixed every site at once.
- A helper function with `uses (net.dial, clock, rand)` could take a
  test's `os.net`, `os.clock` and `os.rand`, so each test body moved
  into a runner by text substitution alone.

Disliked:
- A test cannot take parameters. Running one vector test both plainly
  and doubled meant turning each test into a runner function plus two
  one-line tests, 22 times (I scripted it). A table or parameterized
  test form would make "run this suite under N fakes" a one-line
  change.

### 2026-11-06: header numbers and booleans as Go's strconv (aws 8e6520a)

Liked:
- std/big's `BigInt` (`parse`, `lsh`, `mul`, `exp`, `cmp`) made the
  exact decimal against binary compare at a float32 midpoint a short
  function. Porting Go's `ParseFloat(s, 32)` single rounding needed
  nothing outside std.
- `UInt64` with Go's operators and comparisons let Go's `ParseUint`
  cutoff logic port line for line.
- `Float32(x)` from a Float gives +Inf on overflow, as Go's
  conversion does, so the two-rounding body path is one call.

Disliked:
- `Float.parse` and `Int.parse_base` return an Option, so Go's two
  errors (invalid syntax and value out of range) are lost. Getting
  Go's texts meant a hand-written syntax check (a port of Go's
  `readFloat`) in front of `Float.parse`, with None then meaning range.
  A Result with an error kind would remove that port.
- `1 << 63` faults on overflow, where Go's `1 << 63` on uint64 or the
  min int64 needs no special case. The cutoff for 64 bits had to be
  spelled as the literal min.
- Xo's NaN is 0x7ff8000000000000 and Go's `math.NaN()` is
  0x7ff8000000000001, so bit-exact vectors needed a `from_bits` for NaN.
- A Float32 prints as its 64-bit shortest form (`1.100000023841858`),
  not as the shortest text that reads back the same float32 (Go's
  `FormatFloat(f, 'g', -1, 32)` gives `1.1`). Writers for a Float32 need
  their own shortest formatter.
- A float literal cannot go into a `Float32?` field (`a: 1.1` is
  XO0401, expected Float32?, found Float), though `let f: Float32 = 1.1`
  and a `Float32` default work. Generated tests will have to write
  `Float32(1.1)`.

### 2026-11-06: Smithy float members as Float32 (decision 0010)

Liked:
- `Float32(x)` from a Float is IEEE round-to-nearest-even with +Inf on
  overflow, exactly Go's `float32(f64)`: 2,200 Go roundings matched with
  no special code, so every body reader is `Float32(read_float(v)?)`.
- `Float.to_exp(prec)` gives exact digits at any precision
  (`to_exp(120)` writes a float32's whole decimal expansion), which made
  Go's tie rules for the shortest float32 text a string compare.
- Xo's JSON encoder already writes a Float as smithy-go's
  `EncodeFloat(v, 64)` (the `1e-6` and `1e21` bounds and the `e-9`
  cleanup), so a Float32 goes out as `Num` of its shortest text.
- A float literal does go into a `List[Float32]` and a `Float32`
  default, so the generated defaults and the waiters needed no change;
  only a `Float32?` field needed `Float32(lit)` in generated tests.

Disliked:
- Float32 has only `to_bits` and `from_bits`: no `is_nan`, `is_inf`,
  `abs`, Display of its own shortest form, or `to_fixed`/`to_exp` at 32
  bits. Each helper converts to Float first, and Go's
  `FormatFloat(v, 'g', -1, 32)` had to be written by hand (with Go's
  Dragonbox tie rules: half even, but half up at a power of two).
- UInt32 has no methods on a value (`to_int` is XO0601); `Int(u)` works
  but the note does not say so.
- `Float32?` does not implement Display, so a probe could not print an
  optional directly.

### 2026-11-06: Azure Monitor query and ingestion modules

Liked:
- `json.tokens` with `offset()` and `skip()` gives a member's raw text
  in a few lines, which is Go's `json.RawMessage`: azlogs keeps the
  `statistics`, `render` and error JSON exactly as sent, as Go's
  `[]byte` fields do.
- `json.json_writer()` escapes `<`, `>` and `&` by default, as Go's
  json.Marshal, so hand-written bodies matched Go's bytes on the first
  run. `derive Json` with fields declared in sorted order writes Go's
  map-marshal key order for free.
- `time.fixed(name, offset)` with a `{offset}` layout field writes
  `+01:00` as Go's `t.Format(time.RFC3339)` does for a time in a fixed
  zone.
- `url.values().encode()` sorts and escapes as Go's `url.Values.Encode`
  (`+` for a space, `%2C`, `%27`, `%2A`), so azmetrics' long query
  string matched Go's on the first run.

Disliked:
- `Time` is an instant with no zone, so a parsed `+01:00` is lost:
  `TimeInterval.values()` cannot hand back Go's time in its location.
  The port needed `new_time_interval_in` with explicit zones.
- `w.value(v) ?? return x` on a `Result` is XO0406; the form is
  `?? _ => return x`. The note says the left side must be optional but
  not that the `_ =>` form exists for a Result.
- A `match` arm that is a `for` loop needs braces (XO0160 "expected an
  expression"), which is easy to hit when an arm only iterates.
- `T ! E` as a parameter type is XO0160 with a clear fix
  (`Result[T, E]`); good message, though the two spellings of one type
  are a small tax.

### 2026-11-06: Key Vault azadmin, and Go's resume tokens and bodies

Liked:
- Replaying a Go program's log line by line (one `check` helper that
  reports the first differing line) found five root differences in an
  afternoon that unit tests had hidden: resume token names, model key
  order, HTML escaping in bodies, the next-page `Accept` header and
  `//` in data plane paths. Each fix was one place in the runtime or
  the generator, then a regeneration.
- The compiler's hint for `Byte` (`the Kotlin name; Xo's is UInt8`)
  and for `List.remove` (`did you mean remove_at`) fixed each error
  without a trip to the spec.
- `json.json_writer(escape_html: true)` plus `json.to_value` gave
  Go's `json.Marshal` bytes for any `derive Json` type in five lines
  (`runtime.marshal_json`).

Disliked:
- `json.encode` does not escape `<`, `>` and `&`, where Go's
  `json.Marshal` does and `json.json_writer()` does by default. Every
  generated request body with a SAS token (`sv=...&sig=...`) differed
  from Go's by its `&`s until the bodies went through the writer.
  Two encoders in one package with different defaults is a trap for a
  port.
- `if var x = f() { ... }` is XO0160: a mutable binding from an
  optional needs `if let Some(x0) = f() { var x = x0; ... }`.
- `os` is only in scope in a test's body, so a helper in a test file
  that builds a pipeline has to take one as a parameter; the error
  (`name os not found, did you mean Ok`) does not say why.
- `Bytes` has no `all`/`any`, so a "digits only" check over a string
  slice became an index loop with `"0123456789".contains(s[i..i + 1])`.

### 2026-11-06: Go vectors for pagers, pollers and decoding

Liked:
- One shared fake file (queue a reply per `method path`, log every
  request as the Go program does, compare line by line) dropped into
  eight generated modules unchanged, because a test file in a module
  sees the module's private names. Each module's replay was then a
  dozen lines, and five of eight matched Go on the first run.
- `struct ... with {field: v}` made the poller rewrite readable: each
  azcore constructor (async, op, loc, body) became one `base with
  {...}` line next to the azcore code it mirrors.
- Driving azcore's `runtime.NewPoller` directly from Go, with 31
  cases on one fake transport, found seven poller differences
  (first state, missing or relative polling URLs, status codes on
  polls and final GETs, where a result comes from) that per-module
  tests could not have reached.

Disliked:
- Xo's `Time` is an instant with no offset, so `azcore.DateTime`
  cannot write back `+01:00` as Go's `time.Time` does. Fixing it means
  changing a public newtype into a struct with an offset; a
  `std/time` value that keeps its parsed offset (as `Civil` has
  `offset`) and still compares as an instant would have avoided it.
- `List` has no `clear`; emptying a list inside a `Mutex.with`
  closure is `q = []`, which works but is not where one looks first.

### 2026-11-06: azblob block blobs, UploadFile and DownloadFile

Liked:
- `File.write_at`, `truncate` and `stat` (new in xo at 08c33efee) were
  all DownloadFile needed, and they work on the test's MemFs, so the
  Go program's seven file cases replay with no real disk.
- `BytesBuilder.with_capacity` built the 256 MiB + 5 byte pattern for
  the 65 block upload fast enough that the whole replay (1262 lines
  against Go, 65 block bodies hashed) runs in about 2 s.
- The checker's hints were exact: `.insert` on a Map named `.put` and
  said `.insert` is the Rust name; `enumerate` listed `indexed`.

Disliked:
- `xo test` now builds natively by default, and one `==` on a
  `Result[_, CallErr]` in a new test file (XO1201: the error holds a
  response) also printed eight XO1201 "interface value's type number
  given after skipped code" errors at untouched files
  (runtime/pipeline.xo, client.xo, core.xo). They went away with the
  one fix; the extra errors pointed away from the cause.
- `xo check` in the package directory said 0 errors for that same
  test file; only `xo test` showed the XO1201.
- No way to open an existing file for reading and writing without
  truncating it (Go's `os.OpenFile(p, O_RDWR, 0)`): `create` truncates
  and is write only, `open` is read only, `open_append` refuses
  `write_at`. The Go cases that download over an existing file were
  reproduced by writing the old contents through the `create` handle
  first; a real "download into this existing file" caller cannot do
  that.
- `v[0..v.find(":").map(...) ?? 0]` parsed `??` against the range, not
  the bound; the error (`??` needs an optional value, found
  `Range[Int]`) was clear once read, but the precedence surprised me.

### 2026-11-06: azcore.DateTime keeps its offset

Liked:
- `std/time` had what the fix needed: `time.fixed("", offset)` with the
  `RFC3339` layout writes `+01:00`, `-01:30` or `Z` for zero, and its
  `{frac}` trims zeros as Go's RFC3339Nano does, so 12 texts matched
  Go's write-back with no custom formatter.
- `derive Json(via: Str, ...)` moved from a newtype to a struct with no
  change at the 200-odd generated model fields that use it.

Disliked:
- `Time.parse_rfc3339` reads the offset and then drops it; getting it
  back meant parsing the `+hh:mm` again by hand. A parse that returns
  the offset too (or a `Time` that keeps it, as Go's does) would have
  saved that.
- `Duration` has no unary minus here; a negative offset was `0s - d`.

### 2026-11-06: azappconfig, HMAC signing and Go's pagers

Liked:
- `crypto.sha256`, `crypto.hmac_sha256`, `Bytes.to_base64` and the
  `RFC1123` layout gave HMAC-SHA256 signatures identical to Go's on the
  first run, with the fake clock set to each date Go signed at.
- A replay of every public call (357 lines of Go output: requests,
  scripted responses, token scopes, results) passed on its first run
  through `FakeNet` handlers and a `Mutex` log; changing one vector
  line made it fail at that line, so the match was real.
- `xo check` named the bad variant at once (`json.Patch` has no
  `Set`; it is `Value`), and record `with` made the per-page match
  conditions a one-line copy of the options.

Disliked:
- A `FakeNet` handler returns a response, never a transport error, so
  the Go case whose transport fails (an `AADSTS500011` error) could not
  be replayed with the others; it needed a hand-made failing policy in
  its own pipeline.
- `time.date` takes only year, month and day and returns a Result;
  with no date and time constructor, test times were parsed from
  RFC 3339 text.
- `tok ?? ""` on a `Result[Str, Str]` is rejected (name the error or
  use `.ok()`); the note said what to write, but it is one more step
  than for an optional.

### 2026-11-06: an empty body is the zero value in every module

Liked:
- One generator change regenerated 254 files across every module and
  all of them compiled and passed the gate on the first run; a struct
  whose fields all have defaults made `T{}` a valid zero value for
  every model with no per-model work.

Disliked:
- There is no generic zero value for a type (Go's `var zero T`), so the
  generator spells one per shape (`T{}`, `[]`, `{}`, `""`,
  `json.Value.Null`) and a polymorphic interface result has none at
  all; that one operation keeps the old error.

### 2026-11-06: azeventgrid, key credentials and CloudEvent

Liked:
- `derive Json(via: json.Value, to:, from:)` carried CloudEvent's
  hand-written JSON (extensions merged into the object, `data` kept as
  text, Go's required-field errors) with no other machinery; the
  marshal side matched Go's bytes on its first run.
- `xo check` caught a pure `pub fn` that read the clock and rand and
  named where (`Clock.now` uses `clock` here); adding `uses (clock,
  rand)` was the whole fix.

Disliked:
- An error returned from a `via` decoder comes back prefixed `at $: `,
  so Go's exact message needed the prefix stripped in the test; a way to
  return a message as it is would keep error texts equal.
- `match` arms cannot share a line, so a two-arm match inside a string
  interpolation does not parse; the test used `.err() ?? ...` instead.
- `derive Json` on a struct asked for `Json` on a field's enum type
  even though the struct's JSON comes from its own `via` functions, so
  the enum got a `derive Json` it never uses.

### 2026-11-06: azcore v1.23.0 root changes

Liked:
- The `failed: CallErr? = None` field with a default added Go's terminal
  pager state to `runtime.Pager` and azcosmos's pager without touching a
  single caller, and a mutation (dropping the assignment) failed the
  vector test in each.
- xo 975246c99 now reports a test-only XO1201 from `xo check` too, so
  the check and test counts agree.

Disliked:
- `std/json.indent` says it is Go's Indent but drops the text's trailing
  white space, which Go keeps; ResponseError's body had to add it back
  by hand to match Go's text.
- Bytes iterate as `UInt8`, so byte classification needed `Int(c)` at
  every comparison, and there is no `Bytes` builder from a list; the
  escaped-path code fell back to slicing a `Str` one byte at a time.
- `time.parse` checks the weekday against the date, which Go does not,
  so reading Go's RFC 7231 times needed a layout without the weekday
  plus a hand check of the name.
- std/http has no public `status_text`, though the runtime has one
  inside (`http1w.status_text`), so azcore carries its own copy of
  net/http's table.

### 2026-11-06: azeventhubs v2.0.2 (string offsets, geo-replication)

Liked:
- Changing `offset` from `Int` to `Str` on four public structs gave
  `xo check` errors at exactly the seven test lines that used numbers
  and nowhere else; the library code needed no follow-up edits.
- Two std requests (the Attach's desired capabilities, then the
  amqptest broker's `georeplication_factor` and attach log) came back
  from Lang 1 within the session, each with its own test, so the port
  checks every link's Attach instead of trusting the options.
- Guarded match arms (`Err(e) if is_geo_replication_offset_error(e) =>`)
  expressed Go's "retry from earliest on this one error" in three lines.

Disliked:
- `fail_next("attach", ...)` on the broker fails the next attach of any
  kind, and a CBS or `$management` attach can come first, so the
  Processor's fallback could not be driven end to end; the fallback was
  split into a function that takes the opener and tested with a fake.

### 2026-11-06: azcore v1.24.0 ResourceID, azfile v1.7.2

Liked:
- `Time.rfc3339_offset` (asked for in the previous slice) replaced a
  17-line hand parse of the offset in azcore's date-time reader with
  one call, and every module's tests passed unchanged on it.
- A recursive struct through `ResourceID?` (each ID's parent) and
  `while let Some(x) = c` made the parent-chain walk and Go's
  ValidateResourceTypeChain read like the Go code; the whole port
  passed its 62 Go vector lines on the first run.
- `Time` is an instant and every format names its zone, so Go
  azfile v1.7.2's one fix (SAS times not in UTC were written as their
  wall clock with a `Z`) was never a bug here; the new vectors with
  times at -08:00 and +05:30 passed with no code change.

Disliked:
- `json.encode_str` is the way to get a Go-style quoted string, but I
  first reached for a `marshal_json` helper that a different test
  module defines locally; the error (`function not found`) did not
  suggest the std one.

### 2026-11-06: azqueue v2.1.2

Liked:
- Rerunning the old Go vector programs on the new Go major and
  regenerating the vectors found every wire change at once (API
  version, SAS URL joining, path joining, time layouts, empty and zero
  times, int64 counts); the Xo tests then pointed at each one by line.
- A diff of the old and new expected lists, from the `left:`/`right:`
  lines `expect` prints, was enough to locate each mismatch; 30 Go
  time-parsing cases (ranges, one-digit hours, ten-digit fractions,
  `extra text`) passed on the first run once the error forms were in.

Noted (by design, ADR 0364):
- `Time` is int64 nanoseconds, years 1677 to 2262, so Go's zero time
  (year 1, which Azure services send for "unset") is recognized by its
  text before parsing. Go reads any year 0 to 9999. The lead's
  direction: one shared azcore helper, used by every module that meets
  it. Modules that hit it so far: azqueue v2.1.2 (RFC 1123 and RFC 3339
  texts in queue properties and SAS times).

Disliked:
- `Option` has no `filter` and `Bytes` has no `all`; both came up in
  small checks and needed a helper function or a loop.
- `xo test` takes no test-name filter flag that I could find
  (`--run` was read as a path), so each check reran the whole module.

### 2026-11-06: azsecrets v1.5.1 and the generator's enum order

Liked:
- Regenerating from the new spec and diffing the generated files
  against the old ones showed the whole API change in one screen, and
  the one wrong rename (`update_secret` for Go's
  `UpdateSecretProperties`) stood out at once; the TypeSpec parser fix
  was 25 lines with a test, and a one-line mutation of it was caught.
- `sort_by` over tuples and `part` (the generator's Go casing) gave Go's
  case-sensitive constant order directly; a script over all 13
  generated modules then matched 566 of 570 enums against Go's
  `Possible<Type>Values`, name for name.
- A full regenerate of 13 modules plus their tests runs in minutes, so
  a generator-wide change was cheap to check.

Disliked:
- `json.Patch`'s variant names (`Value`, `Absent`) are not in an error
  message or a doc comment I could reach from the use site; I found
  `Value` by grepping other modules' code.

### 2026-11-06: one shared check for Go's zero time

Noted (by design, ADR 0364), for the owner to see whether it recurs:
- Modules that meet Go's zero time (year 1, outside `Time`'s 1677 to
  2262), now all through `azcore.is_go_zero_time` (and its RFC 3339 and
  RFC 1123 forms) or `azcore.GO_ZERO_TIME_RFC3339`: azqueue v2.1.2
  (reads, both forms), azservicebus admin (reads an entity's
  `AccessedAt`), azdatalake (writes it into a SAS string to sign).
  azblob's sas package writes it too, from its layout pieces, and keeps
  that. Four modules out of the 30 or so ported, all storage or
  messaging wire formats.

Liked:
- Moving three copies into one `pub fn` in azcore was mechanical: the
  per-module tests (azqueue's Go time vectors, servicebus admin's
  entity XML) passed unchanged, and two mutations of the shared check
  were caught by its own test.


### 2026-11-06: azidentity, MSAL Go's token request and error text

Liked:
- `let _ = c.get_token(...)` is refused (XO0206): discarding a Result
  needs `.ignore_err("reason")`. In a test that only compares the
  requests, writing the reason once per call was easy, and it would have
  caught a silently dropped error elsewhere.
- Adding two defaulted fields (`text`, `status`) to `azcore.AuthErr`
  changed no other module: every struct literal elsewhere kept
  compiling, and the full gate passed.

Disliked:
- A closure cannot have a default parameter (`fn(..., allowed:
  List[Str] = []) -> ...` is a parse error, XO0160), and the follow-on
  errors (cannot infer `T`, missing argument `#4`) hid the first one; I
  passed `[]` explicitly at each call.


### 2026-11-06: azidentity, instance discovery and the OpenID configuration

Liked:
- `FakeNet.fail_next(pattern, http.ClientErr.Connect(...))` made MSAL's
  "a transport error on instance discovery is ignored" path testable
  with one line, no socket, and the mutation that flipped that rule was
  caught.
- One handler registered on `GET <host>/{rest...}` for each invented
  host let one fake answer discovery, the OpenID document and the token
  endpoint, as the Go program's single `Do` does.

Disliked:
- `trim_start_chars("https://login.example.test/")` took my prefix as a
  character set and turned `tenant-a/...` into `-a/...`; it compiled
  and only the vector diff showed it. `trim_prefix` was what I meant.
  Go has the same pair (TrimLeft, TrimPrefix), so this is a familiar
  trap rather than a new one, but a lint for a `_chars` argument that
  looks like a URL or word would have caught it.
- A helper outside a `test` block cannot see the predeclared `os`; the
  error (`name os not found`, "did you mean `MS`, `Ok`?") did not say
  so, and I read std/testing.xo to learn the type is `testing.TestOs`
  before passing it in.


### 2026-11-06: azblob DownloadFile with Fs.open_rw; azcore on std's json.indent

Liked:
- `Fs.open_rw` is Go's `os.OpenFile(p, O_RDWR)` (plus O_CREATE), so
  the DownloadFile test now opens the existing file exactly as the Go
  program does, and works on the test's MemFs. A new Go case (a failed
  download over a longer file keeps its later bytes) caught the
  truncating `create` that the old cases let through.
- `http.status_text` replaced azcore's 70-line copy of net/http's
  table; a throwaway test compared both for codes 0 to 999 first.

Disliked:
- std's `json.indent` fix (it now keeps trailing white space, as Go's)
  silently doubled the white space my workaround appended: the same
  code compiled on both xo versions and only a Go-vector test noticed.
  A std change that alters a function's output could be listed in a
  "behavior changes" section of std's change log that the SDK can
  check when moving to a new xo.


### 2026-11-06: azidentity ClientAssertionCredential

Liked:
- A struct field can hold a callback with effects (`fn() -> Str ! Str
  uses (net.dial, clock, rand)`), and the checker made me give it the
  same effects as `get_token`, which documents what a callback may do.
- The unknown-method hint listed `Atomic`'s methods (`get, set, add,
  ...`) when I wrote `.load()`, so the fix took one look.

Disliked:
- `Atomic[Int].add(1)` returns the new value (as Go's `atomic.AddInt64`),
  which I assumed was the old one; `"assert-${calls.add(1) + 1}"`
  compiled and only a test that checked the assertion sent showed the
  off-by-one. std/prelude.xo declares `fn (a: Atomic[Int]) add(n: Int)
  -> Int` with no doc comment, so nothing says which value it returns.


### 2026-11-06: azidentity PKCS #12 certificates

Liked:
- std's `x509.parse_pkcs12` matched golang.org/x/crypto/pkcs12 on every
  real file I gave it (3DES and RC2 with and without a password, a
  wrong password, a chain, an EC key, and AES refused with Go's exact
  `algorithm 1.2.840.113549.1.5.13 is not supported`); only the
  malformed-input texts differ, and Lang 3 queued those.
- `crypto.PublicKey` supports `==`, so MSAL's "the certificate whose
  key is the private key's" was one comparison, no DER marshalling.
- `crypto.pem_decode`, `pem_encode`, `generate_key` and
  `x509.create_certificate` let the test build an EC certificate and
  odd PEM files at run time, so only the .pfx files are committed.
- `embed(...)` into a `Bytes` const worked for the binary .pfx files.
- The checker's note for `os.env.only([]).set(...)` said `set` is a
  method of the test fake (`testing.FakeEnv`), not `Env`, which was
  exactly the problem.

Disliked:
- No way to marshal a SEC 1 EC key or read a PKCS #8 key's inner key:
  the test walks the DER by hand (`inner_key`) and splices in the curve
  OID to build what Go's `MarshalECPrivateKey` makes in one call.
- No `Bytes` from a list of numbers (`Bytes.from_list` does not exist);
  I built a two-byte header through `Bytes.from_hex` with a hand-made
  hex digit lookup.

### 2026-11-06: azidentity, the IMDS probe and MSAL Go's token response

Liked:
- `json.tokens` with `skip()` and `offset()` gave each member's exact
  bytes, so MSAL's `DurationTime` (strconv.Atoi of the raw JSON text)
  is reproduced byte for byte: `"360"`, `1e3` and `[1]` fail with
  Go's texts, and repeated names are decoded in order.
- `std/timego` takes Go's layouts as written (`01/02/2006 15:04:05`,
  RFC3339Nano), so MSAL's three `expires_on` date forms were a loop
  over its own layout strings.
- `FakeNet.fail_next` plus its request log made the probe (timeout,
  transport error, retry on the next call) testable with the fake
  clock; a Go vector run per case and the Xo replay agreed on every
  request line.
- Lang 1 turned XO1201 (an effect-generic struct's method through an
  interface on the native backends) into a fix on main the same day
  the prototype reached them.

Disliked:
- `json.parse_value` keeps one member per name, the last value in the
  first one's place (`{"a":"x","b":1,"a":"y"}` encodes back as
  `{"a":"y","b":1}`). The last value is what Go's `json.Unmarshal` into
  `map[string]any` keeps, so that matches Go; what I missed is a line in
  its doc saying so, since `Value.Object(fields: List[(Str, Value)])`
  reads as if every member were kept. MSAL decodes into a struct, member
  by member, so for it I used `json.tokens`.

### 2026-11-06: azcore's TokenCredential[fx] across the Azure repo (decision 0009)

Liked:
- An effect argument left out of a struct field becomes an implicit
  parameter of the struct (core 6.2), so the 300 generated clients'
  operations kept their `uses (net.dial, clock, rand)` clauses, and a
  caller passing a pure credential changed nothing. A test with a pure
  and a file-reading credential driving the same azblob client passes
  on the native and LLVM backends.
- The XO0701 and XO0702 notes name the left-out argument, where it was
  left out, and the two ways to fix it (`[()]`, or name `fx` and list
  it). Most of the sweep was applying those notes with small scripts.
- The generic `Pager[T, fx]` and `Poller[T, fx]` in azcore's runtime
  needed no change to their tests (45 of 45 pass).

Disliked:
- `Generic[X]` with its type argument but no effect argument counts as
  leaving out the effect arguments, silently. The error then shows up at
  a caller several functions away as a bare `fx`. azdatalake's
  `DfsPager[T] { inner: runtime.Pager[T, fx] }` and azcosmos's
  `QueryPager[T]` each took a search back to the struct.
- Two parameters written without effect arguments (`cred:
  TokenCredential` and `opts: ClientOptions`) are two effect variables,
  not one, so every constructor names `[fx: Effects]` and writes it on
  both. That was a generator template change, not the "callers and
  generated code unchanged" the decision first claimed; the decision
  now says so.
- A method on a bare receiver (`fn (c: Client) url_for(...) -> Str`,
  no `uses`) counts as performing the struct's implicit effects when a
  method on `Client[fx]` calls it, even though its body performs
  nothing (`fn (b: Box) name() -> Str` called from `fn (b: Box[fx])
  label() -> Str` gives XO0701 "performs `fx`"). Lang 1 and the lead
  confirmed this is the intended rule: a pub signature is the contract,
  and a left-out effect argument on a pub receiver means the method may
  perform it. Writing `Client[fx]` on the pure method is the intended
  spelling. What I missed was a note on XO0701 pointing there; Lang 1
  plans one, with an `xo fix`.
- A policy struct that calls `next` must carry a phantom `[fx: Effects]`
  until xo decision 0540 (a parameter's implicit effects inside an
  interface method) is decided; user policy lists are written
  `List[policy.Policy[()]]` meanwhile.
- A list literal as an operand of `+` does not get the other operand's
  element type; binding it to a typed `let` first works.
- `xo check .` run inside a nested package reports an import cycle
  that is not there; `xo check ./path/to/pkg` from the module root is
  clean.
- On `--backend=go`, a generic method's default-argument helper was
  declared twice (fixed on xo main the same day), and
  `http.Request.escaped_path()` returns a space unescaped, which fails
  4 of azblob's 27 tests there (routed to the Go backend's owner).

### 2026-11-06: azidentity, Azure Arc on TokenCredential[fs.read]

Liked:
- `match target.os` with every arm checked on every machine let Arc's
  Linux and Windows paths live in one pure function, `arc_paths(os,
  program_data)`, tested for all four OSes on a Mac.
- Go's Windows `filepath` (Clean, Dir, Base, Ext, Join, about 300 lines
  with volume names) ported on byte offsets via `s.bytes()[i]` and `Str`
  slicing, and matched all 58 Go vectors on the first run.
- The test world's MemFs and FakeNet made Arc testable with no real
  paths and no network: the token directory is an option pointed at
  `/tokens` on MemFs, the agent is a FakeNet handler, and a handler can
  arm `fail_next` for the request after it.
- Once 0009 was in, the credential's new `fs.read` showed up exactly
  where it should: DefaultAzureCredential became
  `ChainedTokenCredential[fs.read]`, and the generic chain ran on the
  native, LLVM and Go backends unchanged.

Disliked:
- `os.fs` and MemFs resolve `..` by text, while Linux walks the
  directory before it first, so `stat("/a/missing/../b")` succeeds on an
  Fs where Go's `os.Stat` fails. The std spec says what a `sub`
  capability does with `..`, but not that `os.fs` resolves it by text;
  I learned it from a Go vector.
- `FsErr` has no operation in it, so Go's `stat P: ...` and
  `open P: ...` texts are rebuilt by hand around `display()`.
- `Map.put`, not `set`, and `Option` has no `unwrap` (I reached for
  both from habit); the errors named the type, which was enough.


### 2026-11-06: azidentity, DefaultAzureCredential, RetrySources, workload identity options, OnBehalfOfCredential and AzurePipelinesCredential as Go's

Liked:
- Moving WorkloadIdentityCredential's file read from the constructor to
  `get_token` was one effect: the method gained `fs.read`, and the
  compiler then named every place that had to change, ending with
  DefaultAzureCredential as `ChainedTokenCredential[fs.read]`. No caller
  had to be found by hand.
- A closure returning `T ! E` with `?` inside it gave Go's three
  "no X specified" checks as three lines in Go's order, with the
  `env.get(name) ?? { ... return Err(...) }` block reading like Go's
  `LookupEnv` branch.
- `Env.get` returning `Str?` kept Go's "set but empty counts as set"
  rule visible: `None` and `Some("")` are different values, so the
  empty-variable vector matched without special cases.
- A mutation check (ignore `retry_sources`) failed the vector test at
  the exact line where Go asks the first source again, so the test was
  shown to compare something real.
- A default argument on an existing method (`grant: Str =
  "client_credentials"` on `Confidential.request`) added the
  on-behalf-of and refresh token grants without touching any of the
  five other credentials that call it.
- An enum whose variants hold a secret, a certificate credential or a
  callback (`OboAuth`) made the three on-behalf-of constructors one
  struct and one `match` in `get_token`.
- XO0160 on a positional variant field said exactly what to write
  (`name the field value`).

Disliked:
- Match arms cannot share a line with `,`, so a `match` inside a `${}`
  interpolation is impossible; every such result needs a `let` first.
  The error (XO0169) explains this well, but I hit it twice in one file.
- `ManagedIdentityCredential` in a `[mi, b]` list made the chain's
  `fx` `()` from the other element and then refused `mi`
  (XO0701). The fix was an annotation, but the error pointed at `mi`,
  not at the inference that chose `[()]`.
- A closure cannot have default arguments; calls that left one out
  failed with `missing argument(s) #6`, which names the position, not
  the parameter.
- `testing.FakeEnv` has `set` but no `remove`, so an unset variable is
  only reachable through `env.only([...])` without it; I rebuilt one
  call by hand for the "unset" case.
- A request that `FakeNet.fail_next` fails never reaches the handler,
  so a test that logs requests in its handler has to log that one
  itself to line up with a Go fake that logs before failing.

### 2026-11-06: armstorage, armcompute and armnetwork at Go's next majors

Liked:
- The generator check (regenerate every module, then `git status`)
  showed in one command that the enum and naming rules changed only the
  three modules meant to change, out of more than 30.
- A `match` on a `Str` with a `_` arm, returning `Str?`, plus `??` at
  the call site, made autorest's symbol naming (`*` is `ASTERISK`)
  a four-line function used by both the constant name and its sort key.

Disliked:
- Closures over nested tuples repeat the whole type each time:
  `keyed.sort_by(fn(k: (Str, (Str, Str, Str))) -> Str { k.0 })` and
  then `.map(fn(k: (Str, (Str, Str, Str))) -> (Str, Str, Str) { k.1 })`
  on the next line. A type alias or inferred closure parameter types
  would cut both to a few characters.
- `let before = ...` followed by `before.push(...)` failed until I made
  it `var`; the error was clear and the fix one word.

### 2026-11-06: Azure policies as plain structs (xo decision 0540), armstorage v4 and armcompute v9 from TypeSpec

Liked:
- Decision 0540 let 23 phantom policy types (32 declarations in 27
  files) become plain structs with a `send(...) uses (net.dial, clock,
  rand)` method; `xo check ./...` passed on all 48 modules after the
  sweep with no other edits. The `// 0540:` workaround comments came
  out cleanly because each one was marked where it was written.
- The deadlock fault on the Go backend lists every blocked task with
  the line it waits at and the line each channel was made at, so the
  AMQP fake's two failures were readable without a debugger.

Disliked:
- `List[policy.Policy]` without an argument is effect-generic, so it
  does not unify with `ClientOptions[()]`'s list (XO0701); the
  `Policy[()]` annotations had to stay after 0540, which I had expected
  to remove too.
- `panic` is not available on the native backends (XO1201), so
  tracing a generator rule meant pushing to a report list instead.
- There is no `Rune.to_str` and no `UInt8.to_int`; reading an
  identifier prefix byte by byte meant comparing `UInt8` values to hex
  literals (`0x3b`, `0x7b`).
- A string split on `"\ninterface "` missed every interface declared
  inside an indented namespace block; a line-based helper fixed it, but
  a `lines()` iterator with `trim_start` would have made the first
  version right.

### 2026-11-07: armnetwork v12, armresources v4 and armkeyvault v2, UTC times and Go's parameter order

Liked:
- A new `azcore.DateTimeUTC` with the same fields as `DateTime` and its
  own `derive Json(via: ...)` functions was about 40 lines; the
  generator then picks it per service with one flag, and the native,
  LLVM and Go backends all passed the five ARM modules unchanged.
- The `param_order` rule (a custom TOML table read into a map and a
  pure `reordered()` function) was easy to unit test in
  `names_test.xo` next to the other naming rules.

Disliked:
- The Go backend writes armnetwork as one Go file of 585,001 lines
  (23 MB). Go's compiler peaks near 11.5 GB on it; it passes only with
  `GOGC=25` and `-gcflags=-c=1`, at about 10 GB. Per-type protocol
  methods and JSON code are over half of it, most for types nothing
  reaches.
- JSON options are per type, not per field, so writing one field's time
  in UTC needed a whole new type rather than an attribute on the field.
- `Bytes` has no `all` (or `any`) method; checking a body in a test
  fell back to converting it to a string and calling `contains`.
- `json.decode` takes `Bytes` and returns a `Result`, so a test that
  builds a value from a literal reads more naturally by constructing
  `json.Value.Object` directly than by decoding text.

### 2026-11-07: aznamespaces v1.0.0 (Event Grid Namespaces)

Liked:
- The port reused azcore's `CloudEvent`, `KeyCredential` and the key
  policy as they were. After it compiled, the 88-line Go vector
  comparison passed the first time on the native, LLVM and Go backends,
  including a topic of `a/b c` escaped to `a%2Fb%20c`.
- The compiler's notes were exact: XO0603 for a type named `Error`
  suggested a module-specific name, `to_bytes` suggested `bytes`, and a
  `,` between match arms said to use a newline. Each fix took one edit.
- A one-character mutation of the key prefix showed up as a single
  readable `left:` header line.

Disliked:
- `Error` is predeclared, so Go's `Error` model became `ErrorModel` (the
  repo's existing rule). A type that is the error of one field, not an
  `Error` implementation, could reasonably keep the name.
- A fake handler pattern such as `POST https://host/` matches only that
  exact path, and the message ("no fake handler") does not say that
  `{rest...}` is needed for a prefix.
- An inline `match` with arms on one line is not allowed, so a two-case
  value inside a string interpolation became a six-line block.

### 2026-11-07: azcontainerregistry v0.1.0 (Container Registry)

Liked:
- XO0540 caught a real question in the refresh token cache: a `?` inside
  a `Mutex.with` closure would have undone the write of the attempt
  time. The note's suggested shape (return the outcome as the closure's
  value) made the choice explicit, and the comment now says which
  failures keep the time.
- `FakeClock.set` and `advance` made Go's temporal.Resource window and
  30 second backoff testable at their exact boundaries, which Go's own
  code (it reads `time.Now`) cannot do. The test showed that at exactly
  30 seconds Go refetches, and the port does too.
- The 353-line Go vector comparison reported one readable `left:` and
  `right:` line at a time. Each mismatch (a 404 delete success, two
  Accept fields, a second `?` in an upload URL, an Accept Go leaves out,
  a credential error's text) was one generator or test fix.
- The XO0401 note for an Option used where a Result is expected gave the
  exact `.or_err(...)?` rewrite.

Disliked:
- XO0402 suggested writing `Mutex.with[T](...)` to fix an inference
  failure, but a method call refuses type arguments (XO0407). A typed
  `let` binding was the fix; the note should say so for methods.
- `??` on a Result needs `?? _ => x`, while on an Option it is `?? x`.
  Three of the first errors in the test file were this, all on
  `url.parse_query` and `url.path_unescape`.
- `var x: T` with no initializer is a parse error (XO0160), so a value
  set in three `if` branches became a `let x = if ... { } else { }`
  expression. That reads fine, but the error points at the newline, not
  at the missing initializer.
- `Map.map` changes only values and there is no `Map.from_entries`, so
  lower casing a map's keys was a loop; List has `index_of(x)` and
  `find(pred)` but no index for a predicate, so finding where to insert
  a parameter was another loop.
- armnetwork's Go-backend step went over the 10 GB cap (10,587 MB) after
  a regeneration that only changed how each request's URL is built;
  `GOGC=15` brought it back under. The one-file Go output leaves no
  margin.

### 2026-11-07: azcore SSE streaming (server-sent events)

Liked:
- Go's SSE reader (sse.go) ported with its edge cases (a lone CR, a CRLF
  split across reads, a BOM on the first line only, an `id` with a NUL,
  a `retry` that is not all digits, the 1 MiB line limit) matched all
  272 lines of the Go program's output on the first full run. Three
  mutations (the split CRLF, the retry precedence, the BOM) each broke
  the vectors.
- An effect parameter on the reader (`SSEReader[T, fx]`, a connector
  `fn(Str) -> Body? ! SSEErr uses fx`) let the test's connector use the
  fake network while the type stays generic.
- `testing.FakeClock`'s `sleeps()` made the reconnect delays (the
  server's `retry`, the clamp of a huge one) checkable without waiting.

Disliked:
- A response from `http.stream(...)` on FakeNet comes back with an empty
  body through both `Client.open` and `Client.send`, so the streaming
  path is tested with plain bodies read in chunks, not with a body that
  arrives in parts.
- A struct's fn-typed field can only carry the struct's own effect
  parameter (XO0701), so the connector field could not say
  `uses net.dial` directly.
- `${}` cannot span lines (XO0156); a long message became a `let` first.
- `let v = o ?? return f() ?? e => Err(g(e))` passes the native and LLVM
  backends but the Go backend emits Go that does not build (the returned
  value is not wrapped in Ok). It stopped every Go-backend dir, since it
  was in the pipeline's transport step; a `match` was the workaround.

### 2026-11-07: ai/azopenai v0.9.0 Azure types

Liked:
- `json.TokenReader` (`next`, `skip`, `value`) made Go's encoding/json
  reading of an error envelope portable: duplicate members merged, null
  leaving a member as it was, and names matched in any case, all on one
  pass, where `parse_value` keeps only a duplicate's last value.
- The generator took a models-only module with two small options
  (`keep_definitions`, a hand written type for an `x-ms-external`
  field); 55 models and 9 enums matched Go's names and fields at once.
- A pinned table of known differences in the test (each with its
  reason and the port's output, failing if the output becomes Go's)
  keeps intentional gaps visible instead of dropping the cases.

Disliked:
- `json_writer().value(v)` writes a float -0 as `0`, while
  `json.encode` and Go write `-0`; the two encoders of one value
  disagree.
- A closure cannot assign to a captured `var` (XO0502), so a helper
  that sets one of four string fields became a function that returns
  the new value, assigned at each of the four call sites.
- `loop` and `enumerate` are not Xo (`while { }` and `indexed()`); both
  errors named the replacement, but they cost a compile round each.
- No way to read a null as a struct's zero value in `derive Json`, which
  Go's autorest decoders do (a null array element is `{}`); the port
  pins it as a difference.

### 2026-11-07: SSE read as the server flushes, and the AMQP fakes on the Go backend

Liked:
- The FakeNet fixes (an `http.stream` body flush by flush, deadlines
  on the virtual clock) arrived about an hour after the repros, and
  the AMQP suites that stopped with XO-F001 on the Go backend
  (azeventhubs 25, azservicebus 23) now pass there unchanged.
- A `Chan[Int]` between the FakeNet handler and the test makes "the
  second event is written only after the first is read" a few lines,
  and the deadlock detector turns the mutation (the body read whole)
  into a clear `XO-F001: deadlock` instead of a hang.

Disliked:
- `http.stream` returns a Response with no headers, so the test sets
  `Content-Type` with `resp with {headers: ...}`; a `stream` that took
  headers, as `text` sets its own, would read better.

### 2026-11-07: azsystemevents (Event Grid system events)

Liked:
- `json.TokenReader.offset()` plus `skip()` cut an event's `data` text
  out of the input byte for byte, as Go's `json.RawMessage` keeps it,
  in about 30 lines: the Event Grid event matches all of Go's outputs,
  spacing and `-999.0` included.
- The UpperCamel error for Go's unexported `internalACS...` types
  named the fix, and dropping `pub` gives the same "module's own"
  meaning Go's lower case has.
- `derive Json(via: json.Value, to:, from:)` handled an error type with
  two wire shapes (a channel error and a nested router error folded
  into one message) with no change to the 270 generated models.

Disliked:
- `json.encode` writes a `Map` in insertion order and Go sorts map
  keys, so 21 of 178 spec examples write differently from Go. It is
  by design (decision 0091), and an ADR is being drafted.
- A `json.Value` number is written normalized (`2.0` as `2`), so the
  `derive Json` path of an event cannot keep raw `data` text; only the
  token reader path can.
- `Bytes` has no `slice` method (it is `b[i..j]`), and `Error` is a
  prelude name, so Go's `Error` became `ErrorModel` again.
- `?` on an optional in a function that returns `Str` is an error,
  so it doesn't work as optional chaining; each lookup became a `let ... ?? _ =>
  return` line.

### 2026-11-07: azwebpubsub (Web PubSub)

Liked:
- `crypto.hmac`, `base64` with `RawUrl` and `json.json_writer` (HTML
  escaping on, keys written in the order given) made an HS256 JSON Web
  Token in about 15 lines. Two fixed-claims tokens hash to the same
  SHA-256 as golang-jwt's, and every per-request token's claims and
  signature match Go's.
- `testing.FakeNet` with `{rest...}` patterns per method and host
  served all 18 operations, four endpoints and the token credential
  path from one handler. The vectors compare line for line, with only
  three error texts pinned.
- `std/regexp` `replace_all` with `$1$2` let the generator take Go's
  autorest.md `where: $` text rewrites as data (`[[replace]]`) instead
  of new code.

Disliked:
- A helper that registers fake routes must take `testing.FakeNet`,
  not `Net`, and a test's `os` is a `TestOs`, not an `Os`. The errors
  explain both, but it was two rounds of fixes.
- Xo's string escapes are `\u{XXXX}` and JSON's are `\uXXXX`, so a
  generated test vector cannot be written with `json.dumps`; the
  generator needed its own string quoting.
- `List.sort_by` takes a key function, not a comparator, and `Str` has
  no `replacen`. Both are small, but each cost a compile round.
- There is no shared Go-compatible `url.Parse` outside azblob's
  `exported` package, so azwebpubsub depends on a storage module for
  it.

### 2026-11-07: bearer policy's plain HTTP text

Liked:
- Moving the bearer and Key Vault challenge policies onto the key
  policy's `check_https_for_auth` was a three-line change each, and
  `?` on its `() ! policy.SendErr` result kept the call sites short.

Disliked:
- `xo fmt` on one file also rewrote an unrelated closure's `uses (a,
  b)` to `uses a, b`, so a small fix carries a formatting change in a
  line it did not touch. Both forms parse; one canonical form that the
  old code already met would avoid that.

### 2026-11-07: azbatch (Azure Batch data plane)

Liked:
- The whole 76-operation client came out of the generator with one
  short custom file. The new pieces (typed response headers, RFC 1123
  header times, the TypeSpec `@client` forms) were each a small change
  to the generator, not hand-written code in the module.
- `Mutex[T].with` and `testing.FakeNet.handle` with `{rest...}` made a
  fake that records every request in a dozen lines, and the same
  fake served all 76 Go vector tests.
- Typed time JSON (`derive Json(via: Str, to:, from:)`) let armstorage's
  RFC 7231 fields switch from `Str` to a proper time type with no hand
  written serde.

Disliked:
- `xo test ./codegen` fails with "has no .xo files"; the packages are
  one level down (`./codegen/gen`, or `codegen/...`). The message says
  how, but a module root with only subpackages is the common case.
- Map has no `+`, so merging two TOML tables needed a helper.
- `xo fmt --check` lists files on main that were never formatted, and
  the gate does not run it, so it cannot tell a new change apart from
  old drift.

### 2026-11-07: Service Fabric's pinned client (Client.with_verify)

Liked:
- `with_verify(tls.Verify.None)` is refused at connect time unless a
  `verify_conn` hook is set, so "no chain check" cannot ship without
  the pin. The test can show that directly, and a mutation (Full in
  place of None) fails the right-pin case as it should.
- `tls_options()` reports `verify`, so a unit test can check the
  pairing without a socket.
- A test marked `uses net, env, fs, clock, rand` is skipped unless
  `xo test --real` runs it, which keeps the loopback TLS check out of
  the deterministic gate without a separate module.

Disliked:
- FakeNet does no TLS, so the pin and Verify.None checks need real
  sockets on 127.0.0.1 (ADR 0544's `handle_tls` would fix this).
- Under `--real`, `os.env.set` does not reach `only()`, so the test
  needed a hand-written `Env` (ten methods) to hold three variables. A
  `testing` map-backed Env usable in real tests would help.
- `vars` as both a field and a method name is an error (XO0603); fine,
  but the interface's method names leak into how you name fields.
- A new required struct field (`TlsOptions.verify`) breaks every
  literal of it in downstream tests; a default value would not.

### 2026-11-07: Go's url.Parse moved into azcore

Liked:
- Moving a file of helpers between packages was mechanical: the
  checker named every caller (`function not found`, with a "did you
  mean" hint) and every unused import, so nothing was missed.
- Each package's tests ran unchanged after the move, so it was safe to
  call it "moved unchanged".

Disliked:
- The checker reports 11 errors in a package that only fails because
  a helper it uses (`go_quote`) was left behind; one "this file needs
  these names from elsewhere" summary would be faster to act on.
- The Go backend still leaves a space unescaped in `escaped_path` on
  FakeNet requests (known, Lang 2), so azfile and azdatalake fail
  there on main. Every gate has to tell those known failures apart
  from new ones by hand.

### 2026-11-07: azopenai's -0 repin

Liked:
- Lang 3's json fix made a float -0 come out as `-0` through
  `json.Value` and the writer, matching Go. The KNOWN pin got narrower
  with a one-line change, and the test's "a KNOWN case must still
  differ from Go's" check flagged the pin right away.

Disliked:
- The repo's tests now need an xo built after f306a31fd. There is no
  way to state a minimum xo version in xo.mod, so the requirement only
  lives in the CHANGELOG.

### 2026-11-07: armsubscriptions, and measuring the Go backend

Liked:
- A new ARM module was one services.toml row and one generator rule
  (a TypeSpec parameter moved onto its method); the reflection Go
  program and vector generator from azbatch carried over with small
  edits, and all 7 calls matched on the first run after one filler fix.
- Lang 2's escaped_path fix turned the known azfile, azdatalake and
  azblob Go-backend failures green with no change on our side.
- `XO_BUILD_DIR` keeps the generated Go, so line counts for the
  protocol-pruning ADR were a grep away.

Disliked:
- A list of models cannot hold a JSON null, where Go keeps a nil
  pointer; real services rarely send one, but it is a decode failure
  where Go succeeds.
- The Go backend's own `go build` flags (`-gcflags=all=-dwarf=false`,
  empty GOFLAGS) are not visible from the CLI, so a manual rebuild to
  measure memory did not match xo's and ran over the cap. A flag to
  print the go command xo runs would help.

### 2026-11-07: armcontainerservice

Liked:
- A 7,000-line ARM module (69 calls, 13 clients) came out of the
  generator with no change at all: one services.toml row, and every
  operation and type name matched Go's.
- The Go backend built and ran all 69 tests at a 10 GB cap with
  GOGC=15, and the `contains`/`index_of` XoEq fault the lead warned
  about did not show up in this module.
- `poll_until_done` with a fake clock and Go's own "response is missing
  polling URL" error text lined up line for line with the Go program.

Disliked:
- One module's Go-backend step still needs its own memory cap and GC
  setting, so a gate is two heavy runs instead of one.

### 2026-11-07: armmsi

Liked:
- The first autorest ARM module after a run of TypeSpec ones needed no
  generator change: a services.toml row with a readme tag and a
  one-line custom file. All 12 calls matched Go's on the first test
  run.
- The vectors catch real drift: renaming one JSON field failed all five
  tests that touch it, the PATCH Update included.

Disliked:
- What Go's generator was told is split across autorest.md and a
  `go:generate` line in build.go (`-removeUnreferencedTypes`), and
  nothing on our side reads build.go, so the difference showed up as
  three extra types that took a comparison of Go modules to explain.

### 2026-11-07: armdeployments

Liked:
- 55 calls matched Go's after one generator rule (reading the Go
  emitter's `stutter` option from tspconfig.yaml), and the full regen
  proved the rule touched no other module.
- The new xo build with Lang 2's go-backend XoEq fix ran the whole gate,
  llvm and Go backends, with no workaround.
- A HEAD-as-boolean response's `success` is a plain Bool, so the 404
  case is one `expect` with no option unwrapping.

Disliked:
- `xo fmt --check` flags generated and test files across the repo on
  both the current and previous xo builds, and the gate does not run
  it, so the formatter and the generator's output have drifted apart
  without anything noticing.

### 2026-11-07: armcontainerregistry

Liked:
- Ten clients and 58 calls with no generator change and no test
  failures on the first run; the reflection Go program carried over
  with only its client list edited.
- Checking `xo fmt` before changing anything was quick: `--check`
  lists the files, a second run changes nothing, and three xo builds
  agree on every file.

Disliked:
- There is no formatter in std, so a generator written in Xo cannot
  format its own output; it has to emit formatted text itself or shell
  out to `xo fmt` afterwards.

### 2026-11-07: xo fmt in the gate

Liked:
- `xo fmt` is idempotent and stable: builds from three points on main
  agree on every file, so formatting 104 files was one mechanical
  commit with nothing to review but the diff's shape.
- The generator's drift was only two patterns (empty structs over two
  lines, a doubled blank line), so a small text step at write time made
  every generated file match `xo fmt` byte for byte.
- `xo fmt --check ./...` lists the files and exits 1, which drops into a
  shell gate as is.

Disliked:
- The formatter has no library form, so tools written in Xo (our
  generator, the vector writer) cannot format their own output in
  process.

### 2026-11-07: armprivatedns and armdns

Liked:
- Two more ARM modules, one TypeSpec and one autorest, with no
  generator change; 31 calls matched Go's on the first run, and both
  came out formatted, so the new fmt gate passed without a touch.
- The fmt gate caught the first thing it could: a test file copied from
  an older module and the vector writer's output, both fixed by running
  `xo fmt` once.

Disliked:
- Lang 2's narrower protocol walk (7b68edb9e) kept equality and hash
  methods on every client, options and response type of armnetwork:
  91,526 lines of them against 55,782 before. The tests still pass, so
  only a line count shows the regression; a size check on the generated
  Go would catch it earlier.

### 2026-11-07: armcosmos

Liked:
- The largest ARM module so far (237 operations, 360 models) passed
  239 of 239 tests on the native, llvm and Go backends, and its Go step
  stayed under the 10 GB cap (about 10.7 GB sampled across the whole
  tree, 3 GB for the largest process).
- Two Go generator rules (TypeSpec `@@override` parameter order and
  `additionalProperties`) went into the Xo generator as small, tested
  changes, and a full regeneration showed one other diff: an armnetwork
  pager that now takes its parameters in Go's order, which is a fix.
- `derive Json(via: ...)` let a model with extra properties round-trip
  through a generic JSON value without hand-written code per type.

Disliked:
- std has no JSON catch-all field: every model with
  `additionalProperties` needs a private shadow struct plus conversion
  functions, where Go uses one map field with a custom marshaler.
- A subtype of a polymorphic model, encoded on its own, leaves out its
  discriminator, while Go's always writes it. It affects every module;
  no test caught it until a Go vector did.
- The Go backend's output for this module is 296,442 lines, so its Go
  step needs a separate run with a larger memory cap.

### 2026-11-07: polymorphic discriminators

Liked:
- Pinning a known gap as data first (a list of Go's line and ours)
  made the fix a visible flip: the second commit only empties the
  lists, and the test fails if the gap comes back or a fix is partial.
- `derive Json(via: ..., to: ..., from: ...)` with a private twin
  struct let each subtype set its discriminator without hand-written
  code per type, and the same shape already served
  AdditionalProperties, so one emitter function covers both.

Disliked:
- The twin is needed only because `to:` cannot call the plain derived
  encoder of the same type: about 2,250 generated lines across five
  modules to add one key. A hook such as `derive Json(after: f)`, which
  edits the derived value, would make this a few lines per type.
- `xo test` reused a cached test binary while `XO_GO_PROTO=why` was
  set, so the diagnostic printed nothing and looked like an answer.
  Env switches that change code generation are not in the cache key
  (the xo knowledge base notes this); only turning every cache off
  gave a real run.

### 2026-11-07: constant fields

Liked:
- The same pin-then-fix shape took under an hour end to end: a Go
  program, a generated test with a known list, then a builder change
  of about 40 lines. A full regeneration touched exactly the 10 models
  Go's own serializers list, which made the rule easy to trust.
- Match guards on patterns (`Some(json.Value.Str(c)) if ...`) kept the
  constant detection to one expression.

Disliked:
- A Go CONSTANT field is a `Str?` here, so a caller can still set it
  to anything and only the encoder corrects it. A field that cannot be
  set (or a default that is the constant) would say what the wire does,
  but Xo has no read-only or computed struct field.

### 2026-11-07: armservicebus

Liked:
- An autorest module went from spec to 66 of 66 calls matching Go's on
  the first test run, with the same fake and vector writer as the
  last four modules; the generator now covers this kind of module with
  no per-module code.
- A one-line name rule (`pascal_part`, without the reserved-word
  suffix) fixed the only naming difference, and a full regeneration
  proved it changed nothing else.

Disliked:
- Xo predeclares `Error`, so a generator must rename any type called
  that (`ErrorModel`) and remember to reserve whole names only. A
  module-local type that shadows a predeclared one, with a warning,
  would let generated code keep the spec's names.

### 2026-11-07: armeventhub

Liked:
- A second autorest module in a row matched Go on all 66 calls at the
  first run, with no generator change, from setup to gate in about an
  hour; the pipeline is now routine for this kind of module.

Disliked:
- Nothing new from Xo itself. A process note: a gate started as a
  plain `&` job gives no completion signal, so it needs its own waiter
  on the PID; the language has no part in that.

### 2026-11-07: Azure bulk generation (290 ARM modules)

Liked:
- `xo check` per module made the bulk triage cheap: 290 generated
  modules sorted into 11 failure classes in one pass, each error with a
  code (XO0603, XO0601, XO0404) that grouped cleanly by count.
- The XO0601 note that lists a type's methods ("`Str` has len,
  rune_count, ... (`xo doc Str` lists all 52)") turned a guessed
  `trim_matches` into the right `trim_chars` in one step.
- Predeclared names are refused with the spec section named (core
  1.4), and the checker's list is one readable match, so the generator
  could copy it whole instead of discovering names one module at a
  time.

Disliked:
- A local of a module's name (a parameter called `policy`) silently
  hides the module, and the error comes later, far from the cause
  (`Policy has no field Request`). A note on XO0601 pointing at the
  shadowing binding would have saved the search.
- Deep recursion still ends in SIGBUS rather than a stack overflow
  message (seen on a self-referencing `$ref`).

### 2026-11-07: Azure differential batch 1 (six modules against Go)

Liked:
- A test file that fails to build reports XO0603 with the previous
  declaration's file and line, so the two harness collisions (a
  generated fake against a module's own `EP` and `opts`, then against an
  older fake that already used the same prefix) were each found and
  fixed from one output, without opening the files.
- The XO0601 "did you mean `new_resource_skus_client`?" note named the
  exact snake-case mismatch between two tools, which made the fix (use
  the generator's own `snake`) obvious.
- After the fixes, five modules with tens of thousands of lines of
  vectors (armnetwork's file is 5 MB) built and passed in one run on the
  native backend.

Disliked:
- Every `_test.xo` file of a module shares one namespace, so generated
  test helpers and hand-written tests collide on short names; the
  workaround is a prefix on every helper. A file-private declaration
  (or test helpers scoped to their file) would remove the class.
- A failed `xo test` build gives no `--- FAIL` lines, so a script that
  counts failures reads it as "0 failing" unless it also counts
  `error XO` lines; a final summary line for a build failure, as the
  test runner prints for a run, would make that unambiguous.

### 2026-11-07: Azure differential batch 2 (25 modules against Go)

Liked:
- XO0406 on `regexp.compile(...) ?? return []` named the problem (a
  Result, not an optional) and gave both fixes, `?? e =>` or
  `.ok() ??`; the build was green on the next try.
- An unused import is an error (XO0110), so a generated vectors file
  that imported std/json without using it failed at once and pointed at
  the generator, instead of passing quietly.
- Generator tests in `xo test ./codegen/spec ./codegen/gen` run in
  seconds, so each new TypeSpec rule got its own test before a module
  was regenerated.

Disliked:
- A module whose 22 build errors all came from one constructor
  signature showed them as 44 lines, two per call site (the argument
  shift); a grouped summary ("22 calls of new_alerts_client: expected
  Str, found GvCred") would read faster.

### 2026-11-07: Azure differential batch 3 (25 modules against Go)

Liked:
- `time.format(t, time.utc(), time.DATE)` gave Go's 2006-01-02 form for
  `format: date` parameters in one line; no layout string to get wrong.
- A field inserted by a script landed inside a doc comment's backticks;
  XO0177 pointed at the exact line instead of failing later in a
  confusing place.
- Every generator rule in this batch was a small pure function over a
  TypeSpec chunk (`plain_action`, the `patch_op` regex), so each got a
  unit test in tsp_test.xo before 25 modules were regenerated.

Disliked:
- armbilling's test (1.2 MB of generated vectors, 188 tests) peaks at
  1.3 GB RSS under `xo test`. On a shared host under memory pressure it
  was killed with no output at all, which looks like a pass/fail
  question until you check the host; a test binary that size should not
  need that much memory to compile.

### 2026-11-07: Azure differential batches 4, 4b and 4c (172 modules against Go)

Liked:
- A throwaway debug program got four compile errors from guessed APIs
  (`os.args`, `.slice`, `os.stdout`), and each came with the exact fix:
  `os.env.args()` with a note on how it differs from Go's `os.Args`,
  "Xo slices with a range, `x[a..b]`", and `stdio`. It ran on the next
  try.
- `json.Value.Array` was rejected at compile time with "has no
  variant", so building a synthesized schema by hand could not
  silently produce the wrong JSON shape.
- Generator rules stay pure functions over TypeSpec text, so a rule
  that worked in its unit test but not in the real module could be
  narrowed down with a ten-line program that called the same function
  on the real files. That showed the rule was right and the file walk
  was wrong: a sibling directory was skipped by a string-prefix check.

Disliked:
- `Str.starts_with` on paths is an easy trap: `Discovery.Management.Shared`
  "starts with" `Discovery.Management`. A path-aware helper
  (`os.path.has_prefix` by segments) in std would have prevented a bug
  that hid a whole TypeSpec directory from the generator.
- Two hosts' test runs that crashed in the generator (`body[0]` on an
  empty list) aborted a whole 72-module batch under `set -e`; the fault
  message was good, but the shell script needed its own guard because
  a generator panic is just a nonzero exit.

### 2026-11-07: Azure batch 4d fixes and GCP vector batches g3 and g4

Liked:
- Generator fixes stayed small because the generator is plain Xo over
  parsed JSON and TypeSpec text: a subtype with its own subtypes, a
  parameter group struct from an `@@override`, a next link's verb and
  TypeSpec header names were each a few dozen lines plus a unit test,
  and a test that fed a pasted `.tsp` fragment to the parser found a
  regex gap (the qualified `@@Azure.ClientGenerator.Core.override`) in
  one run.
- 300 GCP modules went from "compiled" to "Go-verified" in two host
  runs of about four minutes each. Every failure was a single line in
  the run's summary, so the batch needed no log reading.

Disliked:
- A generated service method named `debug` (Google App Engine's
  `Instances.Debug`) broke the module's tests with XO1510, "a stale
  cached piece", which is misleading: it reproduces with the backend
  cache off. Derive Debug's `xo.debug[T]` appears to call the type's own
  `debug` method, with the wrong arity. Either the checker should
  reject the clash or the derive should not see a user method. Reported
  to the lead; the generator renames such methods with a trailing `_`
  until it is fixed.
- A test cannot read a file outside its sandbox (`os.fs.read_text` of a
  spec path failed), so a quick check against a real spec file needed
  the file's text pasted into the test as a literal.

### 2026-11-07: Azure classes 4 to 17 and GCP batch g6

Liked:
- Each remaining Azure failure class closed with a small generator
  change plus a unit test that fed a pasted spec fragment to the
  parser: library alternate types, provider routes in a combined
  TypeSpec client, PATCH bodies that keep extra keys, client parameters
  moved onto methods, and autorest parameter groups. Fourteen classes
  took one session, and a full regeneration of all 319 modules after
  each step showed that nothing else changed.
- `derive Json(via: json.Value, to: f, from: g)` let a PATCH model carry
  unknown keys by changing about ten generator lines; Patch's
  Absent/Null fields went through the same path unchanged.
- The test cache (`(cached)`) made a rerun of an unchanged module
  instant, so a check after an unrelated change cost nothing.
- XO0177's message for a stray `/* */` named the cause and the fix,
  which pointed straight at a vectors-tool bug (a field written
  `name as "Alias"` was not parsed).

Disliked:
- On linux/arm64 the native backend failed four large Google modules
  with "closure of `xo.frameargs(...)` captures too many words" (methods
  whose options struct has many fields), and compute/v0.alpha's link
  failed with "branch out of range". They pass on the go backend, so
  coverage lists them apart until the two bugs (reported) are fixed.
- An `Option` chain needs a full closure type each time
  (`.and_then(fn(i: json.Value) -> json.Value? { i.get("name") })`),
  which makes a one-field lookup a long line. A short closure form or a
  `?.` path would help generator code that walks JSON.

### 2026-11-07: GCP pagers, media upload and download, and 0555's `,string`

Liked:
- Pagers, downloads and both upload protocols (multipart, and resumable
  in chunks) took one session in the generator and gensupport. Their
  vectors matched Go's requests byte for byte on the first run that
  compiled, including the multipart framing and the Content-Range of
  each chunk.
- `testing.FakeClock` let a unit test drive the resumable chunk's retry
  after a 503: Go's backoff sleeps, and the test still finishes at once.
- ADR 0555's `as "n,omitempty,string": Int` turned 9,666 generated
  string-typed integers into Int with one generator switch and one tag.
  The Go vectors matched on the first try (storage, bigquery, tasks).
- Rebuilding xo from a new main commit took about 2 minutes, with the
  previous xo as its seed.

Disliked:
- `a || b.map(f) ?? false` parses as `(a || b.map(f)) ?? false`. The
  error ("`??` needs an optional value on the left, found `Bool`") was
  clear, but the precedence surprised me: `??` binds looser than `||`.
- `while true { ... return x }` is not treated as diverging, so a
  function ending in that loop fails with "expected T, found ()". I
  rewrote the loop with a condition.
- One `xo check` over all 667 generated modules used more than 12 GB,
  so the gate now checks them one at a time. A bounded-memory mode for
  a many-module check would avoid that.
- A `Response` literal has to name `headers: {}` even when a test
  doesn't care about headers; a default would shorten test fakes.

### 2026-11-07: Azure drift refresh, monitor/azquery, and decision drafts

Liked:
- `xo check` on one data-plane module took 1 to 3 seconds and stayed
  under 1 GB, so checking the 9 modules a docs-only change touched was
  cheap enough to do before every push.
- monitor/azquery (about 920 lines, two clients and 25 models) matched
  a 180-line Go transcript on its first test run. `derive Json` with
  `as "key,omitempty"` covered every metrics model, and a newtype
  (`struct(Str)`) worked as a JSON string field without extra code.
- The effect error on a free function generic over `fx` was exact:
  "`send` declares `uses clock, net.dial, rand`, but performs `fx`".
  Adding `fx` to `uses` fixed it. A method on the client needed nothing,
  because the struct's implicit effect parameter covers it.
- Copying a sibling module's models and renaming types with
  word-boundary replacements was safe, because the checker caught every
  missed rename at once.

Disliked:
- Xo has no `context.Context`, so azcore's tracing (an active span
  carried through the call, nested spans suppressed) has no natural
  carrier. Decision 0013 proposes `Request.values` as the carrier.
- std/trace's span (an id, a name, a start and a duration) can't hold
  what OpenTelemetry adapters need: attributes, kinds, events, status
  text, parent ids. tracing/azotel waits on that.

### 2026-11-08: Azure goes public, and two xo changes found downstream

Liked:
- Decision 0543 (JSON writes a Map's keys sorted) made 20 of the 21
  azsystemevents cases pinned as "differs from Go only in key order"
  produce Go's exact output. Only a `json.Value` object, which keeps
  insertion order, still differs. The test caught this because each pin
  asserts the case differs from Go, not just that it matches when
  sorted.
- Bisecting an xo regression took minutes: kept builds of xo27 to xo31
  in their own worktrees showed which range each change came from
  (0543 between 48f4d7450 and 2875a1383; the 0554 fault between
  b0c4d89bd and a195c4ebd).
- Lang 4 measured compute/v0.alpha and aiplatform/v1 builds and found
  the arm64/amd64 parallel-move resolver was O(n^3) in moved words
  (wide structs passed by value); 5eedd890d took aiplatform/v1's build
  from 11:42 to 1:17 and compute/v0.alpha's from 3:20 to 0:48.

Disliked:
- Output-changing decisions reach downstream repos silently. 0543
  failed an azsystemevents test for about 13 hours before a full gate
  surfaced it, inside an unrelated push.
- Decision 0554 (small List literals on the stack, bcc8bc945) made the
  arm64 compiler fault on storage/azblob and storage/azdatalake:
  "stack_lists: core_with_token: v183 escape after the later passes
  (decision 0554) at arm64/inline.xo:824". A build fault prints only as
  `fault:` with no FAIL line, so a gate log grep for FAIL missed it the
  first time. Fixed in 1670a356e; the lead held release 0.44.0 for it.
- The owner approved adding the largest generated SDK modules
  (armnetwork, compute/v0.alpha, aiplatform/v1, azblob, azdatalake) as
  a stress corpus in xo's 8-hourly tier, so these surface in xo first.

### 2026-11-08: Azure tracing (decision 0013 step 1)

Liked:
- Spans need shared, mutable state in many closures: a recording
  tracer, its spans, and their ends. `Mutex[T].new(v)` with
  `.with(fn(var x: T) -> R {...})` covered all of it with no new
  mechanism, and Go's provider, tracer and span interfaces ported as
  structs of optional `fn` fields.
- `?? e => return Err(sp.fail(e))` inside a call argument let each
  generated method end its span on every error path in one line.
- A Go-to-Xo span comparison on armstorage was 162 lines matching on
  the first run, apart from the expected differences. The whole azure
  gate (319 modules regenerated) passed on xo 1e530f877.

Disliked:
- Xo has no request-scoped context, so a span's parent has to travel in
  a `Map[Str, Str]` inside each request, and a poller has to save and
  restore its own span values around each nested call. Spans also start
  with no parent, unlike Go, where the caller's context carries one.

### 2026-11-08: Azure DeviceCodeCredential (decision 0003 Amendment 2)

Liked:
- The device code prompt is a caller-supplied
  `fn(DeviceCodeMessage) -> () ! Str uses (fx)`, generic over the
  caller's effects. Printing to a terminal stays the caller's effect, and
  the credential needs no default prompt the way Go has one.
- `Secret[Str]` refresh tokens in a `Mutex[Map[...]]` keyed by CAE and
  account matched MSAL's per-account cache with no new mechanism. All 136
  vector lines from a local Go program matched once the tests ran.
- Polling on the injected Clock means the test fake clock runs MSAL's
  50 ms to 5 s backoff and the 15 minute code expiry instantly.

Disliked:
- `xo check` caught a field and a method sharing a name (`record`) only
  as a declaration clash. Renaming the field to `account` was easy, but
  Go allows both and the rule surprised me.
- A test's Go vectors used a user address on a `.test` domain, which
  check-public's email rule doesn't allow (only example.com/org/net).
  That cost a second 20 minute gate after a green one. Checking public data before
  gating, not after, would have avoided it.

### 2026-11-08: Azure InteractiveBrowserCredential (decision 0003 Amendment 2)

Liked:
- Opening the browser is a required `open_url` callback, generic over
  the caller's effects. The library declares only `net.listen` for its
  loopback listener and never starts a process. A caller's opener in
  the example declares `proc` itself.
- `scope s { s.spawn(...) }` ran the loopback accept loop next to the
  caller's `open_url` with no extra machinery. `--explore=20` ran the
  tests under 20 schedules, which gives real confidence that the
  listener and the browser don't race.
- All 83 lines from a local Go program (azidentity with a scratch
  WithOpenURL hook, so no browser) matched on the first passing run.

Disliked:
- Under the fake network, std's http client reaches only an
  `http.server`, never a bare `Listener`: a client request to a raw
  accept loop hangs, and the test faults with "deadlock: every task is
  blocked". Raw `Net.dial` to the same listener works. It took five
  probe tests to find, and the test browser now writes HTTP/1.1 by
  hand. A FakeNet note in std.md, or routing client requests to a bare
  listener over the fake TCP, would save the next person the hunt.
  **Fixed** on xo main in e4bf9a2be: a bare Listener a task accepts on
  now takes std's http client requests as HTTP/1.1 over the fake TCP
  (no redirects, compression or streamed request bodies on that path).
  The SDK's hand written test browser can go once it moves to that xo.
- `xo fmt` writes a closure's `uses (a, b)` without the parentheses.
  `xo check` accepts both forms, so only the gate's fmt step caught it,
  which cost one extra gate run. An `xo fmt --check` before committing
  would have caught it.

### 2026-11-08: Azure tracing for the hand written data plane clients (decision 0013)

Liked:
- Carrying the active span in `policy.Request.values` (no context)
  held up across seven very different modules. A hand written method
  became one `runtime.traced(...)` call around its body. azappconfig's
  generated layer needed no change at all: a pipeline whose first policy
  merges the values (`Pipeline.with_values`) was enough.
- Effect-generic closures (`uses (net.dial, clock, rand, fx)`) let one
  helper wrap every azcosmos operation, whatever the credential's
  effects.
- The Go oracles over fakes found two real gaps on the way, both now
  fixed: azcosmos's error code (Go uses the status line) and a whole
  float's `%v` text (`0`, not `0.0`). They also found a fact about Go
  worth knowing: Go shares azcosmos's range and container caches
  between clients of one endpoint.

Disliked:
- In a method of a type whose effect parameter is elided (`Client`,
  not `Client[fx]`), a closure that calls the inner client fails with
  "performs `Client.fx`". Writing `uses (..., fx)` there works in some
  methods and is "unknown effect `fx`" in others, depending on whether
  the receiver names `fx`. Saying which name to write in the message
  would have saved several rounds.
- `http.Request.url.host` has no port (it is in `url.port`), while Go's
  `URL.Host` keeps it. A test fake keyed by host silently answered the
  `:8081` client with another host's reply. That looked like an SDK
  routing bug until a probe showed the SDK was right.
- `tracing.Value` has one float type, so Go's float32 attribute
  (azcosmos's request charge) can only be recorded as a known
  difference. That is harmless for OpenTelemetry, which exports a
  double either way.

### 2026-11-08: Azure UsernamePasswordCredential (decision 0003 Amendment 2)

Liked:
- std/xml mirrors Go's encoding/xml closely enough to port MSAL's
  WS-Trust code: `xml.reader` gives Go's tokens and Go's syntax error
  texts ("XML syntax error on line 1: unexpected EOF"), `xml.escape` is
  Go's EscapeText (`&#34;`, `&#x9;`, `&#xA;` all matched), and
  `xmlns:` declarations stay in an element's attributes, as MSAL's
  `xml:"sp,attr"` fields need.
- `json.tokens` (Go's Decoder.Token) made MSAL's streaming realm decoder
  a short loop: what follows the object is never read, as in Go.
- All 50 sections from a local Go program over a fake token host and a
  fake WS-Trust host matched after four small fixes; the federated
  flow, SOAP body included, matched on its first run.

Disliked:
- Xo has no deprecation marker. Go's `// Deprecated:` paragraph is a
  doc convention its tools read (gopls and staticcheck warn on use).
  Here it is only text in the doc comment, so a caller gets no warning.
  An attribute, or `xo check` reading a `Deprecated:` paragraph as Go's
  tools do, would carry Go's intent.
- The xml tree keeps no source offsets, so Go's `,innerxml` (the raw
  bytes of an element's content, which MSAL base64s as the SAML
  assertion) needed a hand written scanner over the text. An
  `Element`'s source span, or a reader `offset()` like
  `json.TokenReader`'s, would remove it.
- `json.TokenReader` errors use Unmarshal's texts, and Go's Decoder has
  its own in some states (a missing colon is "expected colon after
  object key" from Decode, "invalid character '1' after object key"
  from Unmarshal). One mapping covered the case seen; others may differ.
- `List.enumerate` and `Str.split_whitespace` do not exist (`indexed`
  and a `cut(" ")` do the job). `xo check` lists the near names, which
  made each a one line fix.

### 2026-11-09: Azure persistent token cache (decision 0012 step a)

Liked:
- Effect parameters made the cache's cost exact: a credential given a
  store performs the store's effects (a file store's `fs.read` and
  `fs.write`), and one without performs nothing new. Go has no way to
  say this; its `Cache` option is an interface any code can do I/O in.
- `json.Value` keeps an object's fields in order and round-trips what
  it doesn't know, so MSAL's rule (other programs' entries, unknown
  fields and unknown sections survive a write) was a tree edit, not a
  schema. All 10 sections from a local Go program over a fake token
  host matched, each stored cache's byte length included; the public
  half matched on its first run.
- The XO0701 notes on an omitted effect argument named both fixes
  (`Options[()]`, or a named parameter listed in `uses`) and the
  decision behind them; each of 17 errors was a mechanical edit.

Disliked:
- One generic field rippled through 13 types and every method whose
  receiver they are: each receiver had to be written `T[fx]` and each
  `uses` list given `fx`, even where the method never touches the
  field. A default for an effect argument (`Options[fx = ()]`), so
  existing signatures keep meaning "pure", would have made the change
  one field and the methods that use it.
- In a generic test helper, `o with {client: ...}` on an `Options[fx]`
  returned by another generic helper failed with "the expected type
  `Options[fx]` fixes these effects as pure, but performs `fx`", while
  building the same value as a struct literal passed. Either the
  message or the rule is off; worth a minimal repro on the xo side.
- No regexp replace with a function (Go's `ReplaceAllStringFunc`):
  masking times needed a `find_index` loop.
- Match arms can't share a line (`XO0169`), so a two-arm match inside a
  closure becomes six lines; `.map(...) ?? default` was the short form.

### 2026-11-09: Azure cache parity and the ADFS and tenant rules (decision 0012 step a, gap 17)

Liked:
- `json.tokens(...).value()` reads one value and leaves the rest, which
  is exactly MSAL Go's "text after the object is ignored"; no extra
  parser state was needed to match Go there.
- `json.Value`'s variants made Go's per-type decode errors ("cannot
  unmarshal number into Go value of type string") a small match, one
  arm per JSON kind.
- `jwt.sign` took the algorithm and the header as values, so the ADFS
  assertion (RS256 with a SHA-1 `x5t`) is one branch beside AAD's
  (PS256 with `x5t#S256`), no second signer.
- Default arguments let `client_assertion` gain the ADFS thumbprint
  without touching its other callers.

Disliked:
- `??` on a `Result` is rejected (XO0406: it wants an Option), so
  `base64.decode(...) ?? b""` needs `.ok()` first. The message names the
  fix's direction but not `.ok()` itself; a hint would save a lookup.
- Mixed-case tenant handling had to be found by an oracle: nothing in
  the types says a tenant is case-insensitive in one layer (MSAL's
  cache keys) and case-preserving in another (URLs). A `CaseFolded`
  newtype would have made the split visible; I did not find a
  zero-cost way to write one over Str.

## 2026-11-09: an OpenAI client (openai-go v3.98.0 subset, its own repo)

Liked:
- `xo.work` made the two-module layout (the client, and an `azure`
  module over the azure repo's azcore) cheap: `use ./azure` and
  `use ../azure`, with no publish step between them.
- `http.Client.open` plus `head()` let the streamed call share the
  retry rules with the plain one: the decision is made on the head,
  and the body stays open only on success.
- The exhaustiveness warning (XO0305) caught three `_` arms over a
  private enum in the accumulator; listing the variants cost a line each.
- Interfaces are structural, so the test's counting credential is a
  plain struct with `get_token`, no registration.

Disliked:
- Mutating a captured variable is XO0501, so building a JSON object
  field by field inside closures needed small helpers returning lists
  (`f = f + opt_x(...)`). Clear rule, but it reshapes ordinary code.
- A `var` parameter rejects a temporary (XO0502) even for a struct
  literal passed once; I moved the value into the callee instead.
- `testing.expect_eq` does not exist (it is `expect(a) == b`); the
  error names the module but not the spelling to use.
- Under `env -i` the gate's `gitleaks` call failed as "found leaks"
  when the binary was simply not on PATH; that is check-public's
  message, not Xo's, but worth fixing in the script.

## 2026-11-09: Azure developer-tool credentials (az, azd, pwsh)

Liked:
- `Proc.cmd(...).dir(...).output()` and FakeProc made a credential that
  runs other programs testable with no program run at all; with a
  `Proc.only` list a caller can bound what it may start.
- `task.with_timeout` plus `task.deadline` expressed Go's "ten seconds
  unless the context already has a deadline" directly.
- `charset.encode(s, Utf16Le)` was exactly Go's base64EncodeUTF16LE input.
- `std/timego` parsed Go's layouts as written, so the CLI's
  `2006-01-02 15:04:05.999999` needed no translation.

Disliked:
- String literals cannot span lines, so a 40-line PowerShell script is a
  list of quoted lines joined with `\n` (generated from Go's source).
- FakeProc answers by command name and records nothing, so the test
  cannot see the arguments; I kept Go's executor hook to log them.
- timego's parse errors are std's text, not Go's, so error messages a
  port must match need rebuilding by hand.
- A boxed `TokenCredential[fs.read]` does not widen to
  `TokenCredential[(fs.read, proc)]`; a one-field adapter struct does.
  The XO0701 message described the mismatch the wrong way round.
- `Rune` has no `to_str` and no ASCII `is_alphanumeric`; `"${r}"` and a
  three-range helper worked.

## 2026-11-09: Xo 0.45.0, and tracing/azotel over std/trace

Liked:
- std/trace's Recorder is OpenTelemetry's span model with the SDK's own
  rules (last value wins at the first place, Ok drops its description,
  Unset never undoes Error), so azotel is a 70-line table, and it matched
  a Go program over the real OpenTelemetry SDK on the first full run.
- `FakeProc.runs()` and `timego.go_text` landed within the day and let
  two workarounds go; the developer-credential test now also compares the
  default chain's arguments.
- Exhaustive matches turned 0.45.0's new `FreeBSD` and `Riscv64` targets
  into compile errors at every place that names an OS or arch, and that
  found a latent `other:wasip1` vs Go's `Other:wasip1` casing bug.

Disliked:
- `xo check ./...` over 361 modules reports 1,708 impossible errors
  ("expected `Str`, found `Str`"); the per-module gate passes. Reported
  with evidence; not bisected yet.
- Adding effects to callback types is a signature change for every
  wrapper on the path (`start_span`, `ActiveSpan.end`, ...), though the
  callers already had the effects; the compiler named each one, which
  made it mechanical.
- xobuild refuses to run outside heavy.sh, and `env -i` drops the
  marker (`HEAVY_JOB`), so it has to be passed through by hand.

## 2026-11-10: a docs builder for pkg.xolang.org over `xo doc --json`

Liked:
- `xo doc --json` gave everything a docs page needs per symbol: kind,
  signature with effects and errors, doc comment, examples, and a file and
  line for source links. A static site for 29 aws packages and 77 std
  modules took about 20 seconds.
- `xo get` with XO_PROXY and XO_SUMDB lets a builder reuse xo's own fetch
  and log verification instead of reimplementing the Merkle proofs.

Disliked:
- `xo doc --json ./...` answers `no declaration named ./...` in 0.45.0,
  though the help says DIR/... covers the directories below; the builder
  runs one `xo doc` per package directory instead.
- The JSON has no package-level doc and no schema version, so a module's
  page has no overview paragraph.
- github.com/xo-lang/aws/service/sts@v0.1.0 ships an xo.lock without the
  root module's lines, so `xo get` warns of XO1305 "errors in its own
  code" when fetching it.
- A module in a subdirectory of its repository has no LICENSE in its tree
  (Go copies the root's), so a "no license, no docs" site hides nearly all
  of them; decision 0590 proposes Go's rule.

## 2026-11-11: the gcp Cloud Storage client, step 1 (decision 0010)

Liked:
- FakeNet plus a Go program printing every request made a line-for-line
  oracle easy: 28 cases (headers, sorted queries, bodies, errors,
  retries) passed on first run, and changing one expected line failed
  4 tests, so the comparison is real.
- `json.Value` built by hand is enough for Go's ForceSendFields and
  NullFields PATCH bodies (empty values sent, nulls on purpose), with no
  reflection.

Disliked:
- A FakeNet handler cannot cut a response body short: an `http.stream`
  whose function returns `Err` after writing reads as a clean end, and a
  `Content-Length` larger than the body is ignored. Go's server drops the
  connection there, and the client sees `unexpected EOF`. So the storage
  Reader's reopen-after-a-dropped-connection path can't be tested
  against FakeNet. The same holds for a real `http.server` on an
  in-memory listener: a stream's `Err` ends a chunked body cleanly, where
  Go's handler can abort the connection (panic(http.ErrAbortHandler)).
  And an `http.client` cannot reach a raw `os.net.listen` listener under
  FakeNet ("fakenet: raw listener"), so a hand-written short response
  isn't possible either. Proposal: a stream function's `Err` aborts the
  connection, so the client's `read` gets `Protocol("unexpected EOF")`,
  as std.md 4.5 says for a body cut short.
- Under FakeNet, `ClientStream.read(max)` can return more than `max`
  bytes (`read(3)` gave all 5 bytes of "hello"), though std.md says "at
  most max". The storage Reader now buffers the excess; a caller that
  sizes a buffer by `max` would overrun it.

### 2026-11-11: BigQuery step 1 (gcp ac7f65d)

Liked:
- The storage port's pattern carried over whole: a fake on FakeNet, Go's
  JSON rendered from `json.Value`, and a generated test file. 43 of 44
  Go oracle cases passed on the first run; the 44th was a planned
  departure (std/json's error text).
- Effect-generic handles (`Table[fx]`, `Routine[fx]`) caught a helper
  that forgot its `[fx: Effects]` (XO0702 names the fix).

Disliked:
- XO1301 reads a Google API version as a semver major: `require
  github.com/xo-lang/gcp/bigquery/v2 v0.1.0` fails ("a module path
  ending in /v2 takes only v2.x.y versions") though the tag
  `bigquery/v2/v0.1.0` exists. 91 generated gcp modules end in `/v2` or
  above, so none of them can be required outside the workspace.
  `bigquery` resolves `bigquery/v2` through `xo.work` until the owner
  picks a fix (tag them vN, exempt them, or rename the paths).
  (Settled 2026-11-11 by gcp decision 0012: `apivN` paths.)

### 2026-11-11: BigQuery step 2a, row values (gcp decision 0011)

Liked:
- An enum `Value` with one variant per BigQuery kind made Go's `any`
  plus type switches into exhaustive matches; the checker found every
  conversion that forgot a kind. All 39 Go oracle cases passed on the
  first full run once the module type-checked.
- `Float.to_general(-1)`, `to_exp(-1)` and `to_fixed(-1)` reproduce
  Go's `%v`, `strconv 'g'` and encoding/json's float forms exactly, and
  `Int.parse`/`Bool.parse`/`Float.parse` name the Go functions they
  match, so Go's strconv error texts could be kept byte for byte.
- Compile errors were precise and fixable in one pass: XO0410 (Map
  index faults) with the `get_or_fault` fix, XO0403 naming the
  variant's field names, XO0156 for an interpolation spanning lines.

Disliked:
- An interface method cannot declare `var self`: `interface Loader {
  fn load(var self, n: Int) }` gives XO0403 ("must take `self` first")
  and XO0160, though a type's own method can (`fn (var b: Box)
  load(...)`, as the spec's `next(var self)` iterators do). So Go's
  `ValueLoader` (whose `Load` fills its receiver) became a function
  `fn(List[Value], Schema) -> T ! BqErr`. With a plain `self` in the
  interface, a `var` receiver method satisfies it, but the native
  backends refuse the call through the interface (XO1201, planned).
  Repro sent to the lead.
- (Corrected: my first draft said std/json had no hook for a type's own
  JSON form. It has one, `derive Json(via: P, to: f, from: g)`
  (decision 0478, core 2.3); I had not checked the spec. The `Null*`
  types now use it, with `json.Value` as the proxy: 3 more Go cases
  pass. One snag: `derive Json(via: ...)` still requires every field to
  implement Json (XO0404 on a `DateTime` field), though the fields never
  travel; `DateTime` gained `derive Json` to satisfy it.)
- `Time` holds 1677-09-21 to 2262-04-11 by design (decision 0364), so a
  BigQuery TIMESTAMP outside those years (the API allows 1 to 9999, a
  year-1 cell is `-62135596800000000` microseconds) is an error in Xo
  where Go reads it. The lead has asked for an ADR on Go's full range.
- `json.Value.Object` is a field list, so a Map's JSON has to be sorted
  by hand to match Go's encoding/json (sorted map keys); the saver's
  row JSON (sorted keys, `<>&` escapes, NaN refused) is a hand-written
  encoder.

### 2026-11-11: BigQuery step 3, queries, jobs, rows and inserts (gcp decision 0011)

Liked:
- Interface values (`List[ValueSaver]`) made Go's `Put(src any)` of a
  slice of savers a plain typed parameter; mixed saver types in one
  list need no reflection.
- `var self` methods on a value type (`Job.status`, `RowIterator.next`)
  carry Go's pointer-receiver state (last status, the page buffer)
  without aliasing; a copied iterator is independent.
- The injected `Clock` and `Rand` made Go's random job and insert ids
  and its time-stamped request ids testable: the tests run every poll
  and retry pause at 1 ms. All 43 Go oracle cases matched on the first
  run that type-checked (a mutated expected line fails, as it should).
- XO0603 caught a field and a method with the same name (`Job.config`
  and `config()`) and named both; XO0702's note gave the exact fix for
  a free function over `Client[fx]` (`fn f[fx: Effects](...)`).

Disliked:
- A false XO0407, "type alias `Schema` refers to itself", depends on
  declaration names. Minimal repro (three declarations): `struct A {
  schema: Schema }`, `type Schema = List[Field]`, `struct Field {
  schema: Schema }` errors at Field's field; rename `A` to `B` (sorting
  after `Field`) and it checks clean. In gcp it came from bigquery's
  `FetchedPage` (sorting before `FieldSchema`) holding a `Schema?`;
  writing `List[FieldSchema]?` works around it. Sent to Lang 1.
- `Error` is the prelude interface, so Go's bigquery `Error` struct had
  to be renamed (`ServiceError`); XO0603's note suggests `BigqueryErr`,
  which here would clash with the module's own `BqErr`.
