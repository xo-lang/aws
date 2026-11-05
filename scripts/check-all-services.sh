#!/bin/sh
# Checks the committed clients of every pinned model (decision 0001):
# regenerates them in place with scripts/generate-services.sh, fails if
# that changes anything staged or committed under service/ or in
# xo.work, or adds a file there (the committed output must be what the
# generator writes), then type checks each service module. Writes one line per module (directory, lines,
# result, first error) to .gencheck/all-services.tsv and fails if any
# module fails, including one with a generated file over 512 KiB (xo
# issue 8).
# Usage: XO_CLI=/path/to/xo scripts/check-all-services.sh [--no-regenerate]
set -u
cd "$(dirname "$0")/.."
xo=${XO_CLI:-xo}
fail=0
if [ "${1-}" != --no-regenerate ]; then
  XO_CLI=$xo scripts/generate-services.sh || fail=1
  # against the index, so staged output counts as committed
  drift=$(git diff --name-only -- service xo.work; git ls-files --others --exclude-standard -- service)
  if [ -n "$drift" ]; then
    echo "check-all-services: the committed output is not what the generator writes:"
    echo "$drift" | head -20
    fail=1
  fi
fi
out=.gencheck/all-services.tsv
mkdir -p .gencheck
: > "$out"
# each module is checked in a workspace of the core and itself: the full
# xo.work lists every service, and xo loads every workspace module, about
# 9 GB for one check (docs/reports/xo-issues.md entry 11)
work=$(mktemp)
trap 'rm -f "$work"' EXIT
for d in service/*/; do
  d=${d%/}
  printf 'xo preview\nuse %s\nuse %s/%s\n' "$PWD" "$PWD" "$d" > "$work"
  n=$(cat "$d"/*.xo | wc -l | tr -d ' ')
  big=$(find "$d" -name '*.xo' -size +512k | tr '\n' ' ')
  c=$(XO_WORK=$work "$xo" check "./$d" 2>&1 | grep -v '^  note\|^  fix')
  first=$(echo "$c" | grep ' error XO' | head -1 | cut -c1-200)
  if [ -n "$big" ]; then r=too-big; first="over 512 KiB: $big"
  elif echo "$c" | grep -q ' 0 error(s)'; then r=ok; else r=fail; fi
  printf '%s\t%s\t%s\t%s\n' "$d" "$n" "$r" "$first" >> "$out"
done
ok=$(grep -c '	ok	' "$out")
total=$(wc -l < "$out" | tr -d ' ')
lines=$(awk -F'\t' '{s+=$2} END {print s}' "$out")
models=$(ls codegen/.models/models | wc -l | tr -d ' ')
echo "check-all-services: $ok of $total service modules type check ($lines lines; $models pinned models)"
grep -v '	ok	' "$out" | cut -f1,3,4
[ "$ok" = "$total" ] && [ "$total" = "$models" ] && [ $fail -eq 0 ]
