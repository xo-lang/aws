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
