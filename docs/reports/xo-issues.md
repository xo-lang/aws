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

Workaround: a local function that calls it
(credentials/stscreds/stscreds.xo `classify`). Status: reported to the
lead 2026-11-04.

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

Workaround: the generated tests pass map literals through
`protocoltest.map_of` (an identity on `Map[Str, V]`). Status: reported
to the lead 2026-11-04.
