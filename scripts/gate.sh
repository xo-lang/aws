#!/bin/sh
# One gate run: checks and tests every module of the repository.
# Usage: XO_CLI=/path/to/xo scripts/gate.sh [package dirs...]
# With no arguments it tests every directory holding .xo files.
set -u
cd "$(dirname "$0")/.."
xo=${XO_CLI:-xo}
fail=0
if [ $# -gt 0 ]; then
  dirs="$*"
else
  dirs=$(git ls-files -co --exclude-standard '*.xo' | xargs -n1 dirname | sort -u)
fi
for d in $dirs; do
  # the nearest directory with an xo.mod is the module to run from
  mod=$d
  while [ "$mod" != . ] && [ ! -f "$mod/xo.mod" ]; do mod=$(dirname "$mod"); done
  if [ "$mod" = "$d" ]; then rel=.; else rel=${d#"$mod"/}; fi
  echo "== $d"
  # packages listed in XO_GATE_LLVM build with the LLVM backend (a native
  # backend bug: docs/reports/xo-issues.md entry 5)
  flags=""
  for p in ${XO_GATE_LLVM-internal/protocoltest/restjson}; do [ "$p" = "$d" ] && flags=--backend=llvm; done
  (cd "$mod" && "$xo" test $flags "./$rel") || fail=1
done
[ $fail -eq 0 ] && echo "gate: ok" || echo "gate: FAILED"
exit $fail
