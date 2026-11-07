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

Disliked:
- `Time` covers only 1678 to 2262 (int64 nanoseconds), so Go's zero
  time (year 1, which Azure services send for "unset") cannot be read
  at all; the port has to recognize the zero time by its text before
  parsing. Go reads any year 0 to 9999.
- `Option` has no `filter` and `Bytes` has no `all`; both came up in
  small checks and needed a helper function or a loop.
- `xo test` takes no test-name filter flag that I could find
  (`--run` was read as a path), so each check reran the whole module.
