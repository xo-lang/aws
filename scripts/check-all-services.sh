#!/bin/sh
# Regenerates every pinned model into the untracked .gencheck/all/<model>
# and type checks each one (decision 0001, amended 2026-11-04): run on
# every generator change until all services are committed. Writes one
# line per model (model, lines, result, first error) to
# .gencheck/all-services.tsv and fails if any model fails.
# Usage: XO_CLI=/path/to/xo scripts/check-all-services.sh [model...]
set -u
cd "$(dirname "$0")/.."
xo=${XO_CLI:-xo}
out=.gencheck/all-services.tsv
mkdir -p .gencheck/all
: > "$out"
models=${*:-$(ls codegen/.models/models)}
for m in $models; do
  d=.gencheck/all/$m
  rm -rf "$d"
  g=$(cd codegen && "$xo" run ./cmd/gen -- aws "$m" "$d" 2>&1 | grep -v '^  note\|warnings in files\|^wrote' | head -3 | tr '\n\t' '  ')
  if [ ! -d "$d" ]; then
    printf '%s\t0\tgen-fail\t%s\n' "$m" "$g" >> "$out"
    continue
  fi
  n=$(cat "$d"/*.xo | wc -l | tr -d ' ')
  c=$("$xo" check "./$d" 2>&1 | grep -v '^  note\|^  fix')
  first=$(echo "$c" | grep ' error XO' | head -1 | cut -c1-200)
  if echo "$c" | grep -q ' 0 error(s)'; then r=ok; else r=fail; fi
  printf '%s\t%s\t%s\t%s\n' "$m" "$n" "$r" "$first$g" >> "$out"
done
ok=$(grep -c '	ok	' "$out")
total=$(wc -l < "$out" | tr -d ' ')
lines=$(awk -F'\t' '{s+=$2} END {print s}' "$out")
echo "check-all-services: $ok of $total models type check ($lines lines)"
grep -v '	ok	' "$out" | cut -f1,3,4
[ "$ok" = "$total" ]
