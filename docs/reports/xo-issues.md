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
