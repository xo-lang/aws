# Xo issues found while building the SDK

Each entry: what fails, the smallest program that shows it, the
workaround in this repository, and its status with the Xo owners.

## 1. Struct to interface conversion in a match arm (XO1201 on native)

Found 2026-11-04 with xo at origin/main (worktree build of that day).
A struct converted to an interface inside a `match` arm, where the
`let` names the interface type, fails on the native backends with
`XO1201: not available on the native backends (arm64, amd64, LLVM) yet:
converting `Wrap` to `xo.iface[P]` (support is planned)`. The same
conversion as a `let` with a type, a function's return, or a list
element works.

```xo
// a/a.xo
pub interface P {
  fn get(self) -> Int ! Str uses clock
}

// b/b.xo
use example.com/repro/a
pub struct WithMutex { m: Mutex[Int] }
pub fn make(n: Int) -> WithMutex { WithMutex{m: Mutex.new(n)} }
fn (w: WithMutex) get() -> Int ! Str uses clock { Ok(w.m.with_read(fn(v: Int) -> Int { v })) }
pub struct Wrap { inner: a.P }
pub fn wrap(p: a.P) -> Wrap { Wrap{inner: p} }
fn (w: Wrap) get() -> Int ! Str uses clock { w.inner.get() }

// main.xo
use example.com/repro/a
use example.com/repro/b

fn pick(o: a.P?, n: Int) -> a.P {
  let p: a.P = match o {
    Some(v) => v
    None => b.wrap(b.make(n))   // XO1201 here
  }
  p
}

fn main(os: Os) ! {
  let z = pick(None, 3)
  os.stdio.println("${z.get()?}")
}
```

Workaround (removed): `config.default_chain`. Status: FIXED on xo main
11b6c6e3e (golden iface_match_arm).

## 2. std/http client drops a request's raw (escaped) path

Found 2026-11-04 (xo at 1aea4b89f). `http.new_request(method, url, ...)`
keeps only the decoded path (std/native/http.xo `new_request` sets
`path` from the URL and no `raw_path`), and the client writes
`escaped_path()`, which re-escapes it Go's EscapedPath way. So a URL
path `/bucket/a%20b%2Bc` goes on the wire as `/bucket/a%20b+c`. Go's
`http.NewRequest` keeps `URL.RawPath` and sends the path as given.

Why it matters: SigV4 signs the path bytes (S3 signs them as given), so
any escaping the client changes after signing breaks the signature;
S3 object keys hold `+`, `%`, `!`, `*`, `'`, `(`, `)` and others whose
escaping must be the caller's.

Repro: transport/transport_test.xo "the wire keeps the escaped path and
raw query": an in-memory listener's handler records
`req.escaped_path()`; the request is built from
`http://objects.test:8080/bucket/a%20b%2Bc/%E1%88%B4//x`.

Ask: `new_request` (and `Request.url` parsing) keep the raw path as Go's
`url.Parse` does (`RawPath` when the escaping differs from the default),
so `escaped_path()` and the request line give it back unchanged.

Workaround (removed): transport.wire_path. Status: FIXED on xo main
6ccace320 (raw path kept; default ports in the in-memory net too).

Also seen (not a bug, a sharp edge): `os.net.listen("host:80")` is not
reached by a client URL `http://host/...` without the port; with an
explicit port (`host:8080` in both) it is.

## 3. Another module's function as a value is XO1201 on native

Found 2026-11-04 (xo at 53ae55bad). Passing `m.double` (a `pub fn` of
an imported module) where a `fn(Int) -> Int` is expected fails on the
native backends: "not available on the native backends (arm64, amd64,
LLVM) yet: the name `m` here (support is planned)". A function of the
same module works as a value.

Repro (one module `example.com/repro`):

```xo
// m/m.xo
pub fn double(n: Int) -> Int { n * 2 }

// main.xo
use example.com/repro/m

fn apply(f: fn(Int) -> Int, n: Int) -> Int { f(n) }

fn main(os: Os) {
  os.stdio.println("${apply(m.double, 21)}")   // XO1201 at `m`
}
```

Why it matters: generated clients pass protocol functions
(`query.classify`, a serializer) to the transport; every one needs a
local wrapper today.

Workaround (removed): a local `classify` in stscreds. Status: FIXED on xo
main c65d92cb8 (golden fn_value_qualified).

## 4. A map literal where a `Map?` is expected is XO1201 on native

Found 2026-11-04 (xo at b2e66f690). A map literal converted to an
optional map (a struct field `Map[K, V]? = None` given `{"k": "v"}`)
fails on the native backends: "not available on the native backends
(arm64, amd64, LLVM) yet: this literal (support is planned)". The Go
backend runs it. A typed `let` first, then the field, works.

```xo
struct In {
  a: Map[Str, Str]? = None
}

fn main(os: Os) {
  let ok: Map[Str, Str] = {"k": "v"}
  let y = In{a: ok}                 // fine
  let z = In{a: {"k": "v"}}         // XO1201 at the literal
  os.stdio.println("${y:?} ${z:?}")
}
```

Why it matters: every generated input and output member is optional
(decision 0004), so users and the generated protocol tests write map
literals there (`query_params_map: {"k": ["v"]}`); 50 restJson1 tests hit
it.

Workaround (removed): the generated tests passed map literals through
`protocoltest.map_of`. Status: FIXED on xo main 0e4fa349e (golden
optional_coll_lit).

## 5. arm64: an inlined cross-module call fails as "runtime call" (cache order dependent, FIXED)

Found 2026-11-04 (xo at 97c8b271b). `xo test ./internal/protocoltest/restjson`
(generated RestJson client) stops in the arm64 backend:

```
xo: protocol/restjson/restjson.xo:31:7: in `github.com/xo-lang/aws/protocol/restjson.error_code`
(inlined into `deserialize_greeting_with_errors_error`): arm64 backend: runtime call
`restjson.sanitize_code`
```

`error_code` (pub, module protocol/restjson) calls `sanitize_code` (pub,
same module); the failure appears when `error_code` is inlined into a
generated function of another module. `--backend=llvm` builds and passes
all 194 tests, and the same package passed on arm64 with xo b2e66f690 and
a82f123de. The awsJson packages, which call the same function from
similar generated code, build. Status: reported to the lead 2026-11-04.
Lang 1 could not reproduce it on the pushed tree (9e80ea7) with any cache
state; later the same day it no longer reproduced here either, on the
shared cache or a fresh one (233/233 on arm64, after the package was
regenerated with more response tests).

**Reproduced deterministically, 2026-11-04 16:50**, from an empty backend
cache (`d=$(mktemp -d)`, `XO_BACKEND_CACHE_DIR=$d` for both commands):
`xo test ./internal/protocoltest/jsonrpc10` (ok) then `xo test
./internal/protocoltest/restjson` fails as above. restjson alone, or
after awsquery or ec2query, passes; after jsonprotocol it fails. Both
awsJson suites inline `restjson.error_code` into generated
`deserialize_*_error` functions, so an entry recorded by the first build
is reused by the second and cannot be lowered there. The restxml variant
(`restxml.error_code` inlined, "runtime call restxml.error_element") hit
the shared cache after `error_element` was edited. Status: with Lang 1
(repro handed over 2026-11-04). FIXED on xo main eb839dcfb
(TestFrontCacheRootAndLibrary): the test package and protocol/restjson
share the name `restjson`, so in that program protocol/restjson's
functions are named by full path, while a front end cache entry for
`error_code` recorded in a program with one `restjson` called them
`restjson.sanitize_code`; the cache key now includes the path named
modules (FE_CACHE_VERSION v15). Verified here with xo eb839dcfb: the two
step repro passes (61, then 233) and the whole gate passes on the native
backend (828); the gate's LLVM override is empty again.

## 6. Go backend: `field = (x ?? return Err(..))` into an optional field (FIXED)

Found 2026-11-04 (xo at 97c8b271b). `xo test --backend=go
./internal/protocoltest/restjson` fails in `go build` ("a code generator
bug"):

```
client.xo:7626: cannot use x_c3537 (variable of type int64) as rt.Option[int64] value in assignment
```

from `out.header_byte = (Int.parse(hv) ?? return Err("..."))` where
`header_byte: Int? = None`: the implicit `T` to `T?` wrap is missing when
the right side is a `?? return` expression (also for `(s == "true")` into a
`Bool?`, and Time). Native and LLVM accept it. Status: FIXED upstream
in 6c1839fc2 (Lang 4, 2026-11-04: a parenthesized value converted to `T?`
is wrapped in Some in assignments, field inits, arguments and locals;
golden optional_assign_go). Verified here with xo 9ee7f840f: `xo test
--backend=go ./internal/protocoltest/restjson` passes 233/233.

## 7. `xo mod tidy` drops the require of a nested module the parent imports (FIXED)

Found 2026-11-04 (xo at 97c8b271b) while checking the module cycle of
decision 0003 (credentials/stscreds in the root module uses
service/sts, a nested module that requires the root back). Repro: local
git repositories through XO_GIT_BASE, XO_PROXY=direct, XO_SUMDB=off, no
workspace. Repository github.com/acme/awsx holds the root module and
`service/sts/xo.mod`; the root's package `stscreds` imports
`github.com/acme/awsx/service/sts`.

- In the root module with no `require` of service/sts, `xo check ./...`
  passes: the nested module resolves from its subdirectory although the
  spec (core 4.2) says a directory with its own xo.mod is never part of
  the module around it, and a module must require every module it
  imports from (XO1306).
- `xo get github.com/acme/awsx/service/sts@v1.0.0` adds the require;
  `xo mod tidy` then removes it again ("removed ... v1.0.0").
- A root version tagged after tidy has no require, so a consumer gets
  `XO1306` inside the fetched module (`cache/github.com/acme/awsx@v1.1.0/
  stscreds/stscreds.xo: module ... is not required`).

Expected: check reports XO1306 in the root module, and tidy keeps (or
adds) the require. Workaround: add the require with `xo get` and do not
run `xo mod tidy` in the root module.

Also checked, and working as Go documents for module cycles (the spec
does not say; worth a line in core 4.2): a tagged require cycle, root
v1.2.0 -> service/sts v1.1.0 -> root v1.1.0 -> service/sts v1.0.0 ->
root v1.0.0, resolves by minimal version selection; xo.lock records each
version's hashes; `xo get`, `xo vendor` (selects sts v1.1.0, the root's
requirement) and an app importing both run. XO0604 is a package import
cycle (it fires on pa -> pb -> pa across two modules), not a module
requirement cycle; core 4.1 calls packages "modules" there, which reads
as the xo.mod sense. Smaller: `xo get sts@v1.0.0` in the app prints
"v1.1.0 => v1.0.0" while selection stays v1.1.0 (required by the root),
and there is no `xo mod graph` to see the selection (added on xo main
f53b79214: Go's edge format, cycles included, `--json` with the selected
versions).
Status: FIXED upstream in ec7332b77 (Lang 4, 2026-11-04): `xo check`
reports XO1306 for an unrequired nested module, `xo mod tidy` keeps (or
adds) the require, `xo get X@v` reports when a higher version stays
selected and why, and core 4.1/4.2 now say XO0604 is about packages and
require cycles resolve by MVS. `xo mod graph` remains a later item. Verified
here with xo 9ee7f840f: the repro now reports XO1306 in the root, tidy
keeps the require, and `xo get` explains the higher selected version;
the release checklist's workaround is removed.

## 8. A new package dependency makes native reject List.push in unrelated functions (XO1201, FIXED)

xo 9ee7f840f (native arm64). With the event stream work, the generated
S3 client imports one more package (github.com/xo-lang/aws/eventstream).
`xo test --real` of the integration tests (which reach
serialize_put_object and deserialize_put_object) then fails to build:

    service/s3/client.xo:29342:5: error XO1201: not available on the
    native backends (arm64, amd64, LLVM) yet: the method `List.push`
    (support is planned)
    service/s3/client.xo:29400:3: error XO1201: ... assigning to this
    expression

The flagged lines are ordinary `headers.push((name, v))` and
`out.field = hv`, which build fine without the import. Bisected: the
trigger is any new package dependency (a one-function package does
it), together with the newly generated SelectObjectContent serializer
code; either alone builds. Not a cache effect (fresh HOME and backend
cache give the same). Without `--real` the code is unreachable and the
build passes. A repro outside this repository's working tree: the two
client files differ only in importing and calling the one-function
package; `repro.sh WORKDIR` clones this repository at 91c7c6c, swaps
each in and builds.
Status: FIXED upstream in 7e82ae5c6 (Lang 1, 2026-11-04). The cause:
the checker keyed a node by its file, start and end packed in 20 bits
each, so a node past 1 MiB of a file took the records of a node in the
next file (the new import renumbered the files). It could also resolve a
call to the wrong function with no error, so every earlier build that
included a generated file over 1 MiB (EC2's client.xo, 8.2 MB, and
types.xo, 2.2 MB; S3's client.xo, 1.27 MB) is untrusted and was rerun.
Verified here with xo 7e82ae5c6: the repro builds and fails only at run
time, as expected with no emulator. The generator now also cuts every
file at about 448 KiB (split_file) and fails on one over 512 KiB, and
the gate and scripts/check-all-services.sh check that limit.

## 9. A full duplex HTTP/1.1 exchange on the test network deadlocks

xo 7e82ae5c6, native and Go backends. The spec's recipe for a
bidirectional stream (std 4.x, decisions 0433 and 0444): a
`handle_stream` route answers with `http.stream(...).with_full_duplex()`
and echoes each body piece as it reads it; the client writes a first
piece into an `http.pipe()`, `Client.open`s the request with
`with_body_reader`, reads the echo, writes the next piece, and so on.
On `os.net.listen(":0")` with `http.client(os.net)` the test faults
with `XO-F001: deadlock: every task is blocked and no timer is pending`
(the Go backend names only the server task, blocked in serve). The
input event stream clients (Transcribe, Bedrock bidirectional, Lex, and
others) depend on exactly this exchange. A 25 line repro is fd_test.xo
(with its xo.mod) in the lead's notes, issue9.
Status: reported to Xo Lang 1 (2026-11-04).

Update (2026-11-04, Xo Lang 3): not a std bug. The fake network's
`Client.open` reads the whole request body before the handler runs and
returns the whole response, so a full duplex exchange cannot run on it.
On a real loopback socket (`uses net`, `xo test --real`,
`listen("127.0.0.1:0")`) the repro passes. Lang 3 is documenting the
limit and making the fake path duplex.
FIXED in 0e1d7b177 (Lang 3): `Client.open` with an `http.pipe` body is full
duplex on the fake network. Verified: the Transcribe input stream test
passes there, in the integration module, without `--real`.

## 10. Native: `rt.select_new` returns a `Select` in `http.PipeWriter.write`

xo 7e82ae5c6, arm64 and LLVM backends, `xo test --real`. The full duplex
test from issue 9 builds and passes on its own and next to any other
integration test, except DynamoDB's (dynamodb_test.xo). With those two
files in the integration module, the build fails with
`std/native/http.xo:3267:5: in http.PipeWriter.write: arm64 backend: the
runtime call rt.select_new returns a Select`. Neither file fails without
the other. The repro (repro.sh, zz_fd_test.xo) is in the lead's notes,
issue10.
Cause (Xo Lang 1): the runtime handle of `select` is registered under
the bare type name `Select`, and DynamoDB's generated `enum Select` takes
that name, so `rt.select_new` appears to return the enum. The bug dates
back to at least xo 0.38.1, and it always fails at build time, never as
a silent miscompile. The fix gives program types named like a runtime
handle their module path. The four bare handle names are Scope, Select,
Listener and Conn (Lang 1). Scope, Listener and Conn are also prelude
types, so a program type with one of those names already got its module
path. In the generated SDK, `Select` is DynamoDB's (a value enum),
`Scope` occurs in 13 models (EC2 and ECS among them), `Listener` in 5,
and `Conn` in none. Names are kept as aws-sdk-go-v2 has
them; the duplex test has its own module until the fix lands.
Lang 1's matrix on 0.38.1 covered Scope, Listener, Conn, Select, Task and
Group, each as a struct, an enum, a newtype, a value enum, and a value
enum with a catch-all. Every program also used scope, spawn, a group,
select, listen and dial, on arm64, LLVM and amd64, in both declaration
orders. Only Select fails, so the Scope and Listener models (EC2 and ECS
included) are safe.
FIXED in 5dd0b3f4e (Lang 1). Verified: the duplex test and the DynamoDB
client share the integration build again, and the gate passes.

## 11. Every workspace module is loaded, used or not (memory)

With all 435 service modules listed in xo.work, `xo check
./service/accessanalyzer` (a small service that imports only the core)
peaks at 8.7 GB resident. The same check with `XO_WORK` naming a
workspace of the core and that one service peaks at 0.63 GB, and reports
"2 module(s), 0 error(s)". So xo loads (and seems to check) every module
the workspace lists, not only those the checked package imports.
Expected: a workspace only redirects module paths, so modules nobody
imports cost nothing. Workaround: scripts/check-all-services.sh writes a
two-module workspace per service. Repro: this repository at the 435
service commit, `/usr/bin/time -l xo check ./service/accessanalyzer`.

## 12. Native link: duplicate `zero` of `http.Request` in a program using S3

Found 2026-11-05 (xo main at 5dd0b3f4e) while checking the first
release from a scratch clone. A program (not a test) that uses
`service/s3` fails to link on the native backend:

```
xo: link: duplicate symbol _xo_f_zero__val_2enative_2ehttp_2eRequest in prog-darwin.15.o and .../prog-darwin.3.o
```

Repro: a `main` that makes an S3 client with static credentials and
presigns a GetObject (no network). The same failure appears in a
workspace and with the modules fetched at a tag, so it is not about
module resolution.

- The Go backend runs it.
- Xo 0.39.0 links and runs the same program from the same fetched
  modules, so this is a regression after 0.39.0.
- Programs using only STS or only DynamoDB link. The only user of
  `http.Request` here is `transport` (`sign_attempt`, `signed_request`,
  `unsigned_request`), so the zero helper seems to be emitted in a
  second codegen unit when S3's larger program splits.
- `xo test` (the gate, the integration suite) links, so no suite here
  caught it.

Expected: one definition (or a linkonce/weak one) per zero helper.

Narrowed the same day with xo-lang-4: with `XO_BACKEND_CACHE=off` the
same xo links and runs it, and a fresh private back-end cache does too.
So a cached unit from another build is reused when it should not be;
the compiler output itself is fine. The "0.39.0 links it" result above
came from a different cache key, so it says nothing about a regression.
Cause (xo-lang-4): a fault exit's shared zero value is emitted in the
program when one of its own functions is built first (transport's
functions that return a Request), while std's separately compiled
object has a copy too; both were strong symbols. It shows only on the
first build after std's variants are cached, so a rebuild or a fresh
cache links. 0.39.0 has it too; there, set `XO_BACKEND_CACHE=off` or
build again.
Status: FIXED upstream in 842702e6d (xo-lang-4, 2026-11-05).

## 13. Native arm64: "reference counting of `Result[Output, Str]` (too many words)"

Found 2026-11-05 by the read-only AWS sweep (one ListX call per
service). A test that calls the MediaConvert client fails to build:
`xo: arm64 backend: reference counting of
`Result[github.com/xo-lang/aws/service/mediaconvert.Output, Str]` (too
many words)`. MediaConvert's `Output` struct is large. It fails the
same way on the 0.39.0 release and on main at 5dd0b3f4e. The LLVM
backend is the workaround. Status: open, owned by Xo Lang 1.

## 14. Native arm64 assembler: `sub sp, sp, #5280`

Found the same way, with WAFV2: `xo: assembler: line 9750: unsupported
instruction: sub sp, sp, #5280`. An arm64 add/sub immediate is 12 bits
(optionally shifted by 12), so a frame over 4095 bytes needs the
shifted form or a scratch register. It fails the same way on 0.39.0 and
on 5dd0b3f4e. The LLVM backend is the workaround. Status: open, owned
by Xo Lang 1.
