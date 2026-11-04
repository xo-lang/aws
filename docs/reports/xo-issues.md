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

## 5. arm64: an inlined cross-module call fails as "runtime call" (cache order dependent)

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
(repro handed over 2026-11-04); the gate builds internal/protocoltest/
restjson and restxml with `--backend=llvm` until it is fixed
(XO_GATE_LLVM).

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
and there is no `xo mod graph` to see the selection.
Status: FIXED upstream in ec7332b77 (Lang 4, 2026-11-04): `xo check`
reports XO1306 for an unrequired nested module, `xo mod tidy` keeps (or
adds) the require, `xo get X@v` reports when a higher version stays
selected and why, and core 4.1/4.2 now say XO0604 is about packages and
require cycles resolve by MVS. `xo mod graph` remains a later item. Verified
here with xo 9ee7f840f: the repro now reports XO1306 in the root, tidy
keeps the require, and `xo get` explains the higher selected version;
the release checklist's workaround is removed.
