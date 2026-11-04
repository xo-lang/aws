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

Workaround: convert in a helper function's return
(`config.default_chain`). Status: reported to the lead 2026-11-04.

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

Workaround: transport.wire_path computes the form std/http sends and the
transport signs that form. Status: reported to the lead 2026-11-04.

Also seen (not a bug, a sharp edge): `os.net.listen("host:80")` is not
reached by a client URL `http://host/...` without the port; with an
explicit port (`host:8080` in both) it is.
