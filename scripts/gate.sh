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
  dirs=$(git ls-files '*.xo' | xargs -n1 dirname | sort -u)
fi
for d in $dirs; do
  mod=.
  case "$d" in codegen|codegen/*) mod=codegen ;; esac
  rel=${d#"$mod"/}
  [ "$rel" = "$d" ] && [ "$mod" != . ] && rel=.
  echo "== $d"
  (cd "$mod" && "$xo" test "./$rel") || fail=1
done
[ $fail -eq 0 ] && echo "gate: ok" || echo "gate: FAILED"
exit $fail
