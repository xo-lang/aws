#!/bin/sh
# Builds each program under examples/ with the native backend and runs
# it, comparing its output with examples/<name>/want.txt. The gate only
# runs tests, and a program links differently (docs/reports/xo-issues.md
# entry 12 linked in every test and failed in a program).
# Usage: XO_CLI=/path/to/xo scripts/check-programs.sh
set -u
cd "$(dirname "$0")/.."
xo=${XO_CLI:-xo}
fail=0
out=$(mktemp -d)
trap 'rm -rf "$out"' EXIT
# a workspace of the root, service/sts (the root requires it), examples
# and the services the examples use: the full xo.work loads every module
# (docs/reports/xo-issues.md entry 11)
{
  echo "xo preview"
  echo "use $PWD"
  echo "use $PWD/examples"
  { echo sts; grep -ho 'use github.com/xo-lang/aws/service/[a-z0-9]*' examples/*/*.xo | sed 's#.*/##'; } | sort -u | sed "s#^#use $PWD/service/#"
} > "$out/xo.work"
export XO_WORK="$out/xo.work"
for d in examples/*/; do
  n=$(basename "$d")
  if ! (cd examples && "$xo" build -o "$out/$n" "./$n") > "$out/$n.build" 2>&1; then
    echo "check-programs: $n does not build:"
    grep -v '^  note\|^  fix' "$out/$n.build" | tail -5
    fail=1
    continue
  fi
  if ! "$out/$n" > "$out/$n.txt" 2>&1 || ! cmp -s "$out/$n.txt" "$d/want.txt"; then
    echo "check-programs: $n output differs from $d/want.txt:"
    diff "$d/want.txt" "$out/$n.txt" | head -10
    fail=1
    continue
  fi
  echo "check-programs: $n ok"
done
exit $fail
