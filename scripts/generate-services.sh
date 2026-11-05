#!/bin/sh
# Regenerates the committed client of every pinned model (or of the
# models named) into service/<name>/, and lists each in xo.work. The
# output is committed (decision 0001); scripts/check-all-services.sh
# checks it is current.
# Usage: XO_CLI=/path/to/xo scripts/generate-services.sh [model...]
set -u
cd "$(dirname "$0")/../codegen"
xo=${XO_CLI:-xo}
fail=0
models=${*:-$(ls .models/models)}
for m in $models; do
  out=$("$xo" run ./cmd/gen -- service "$m" - 2>&1)
  if ! echo "$out" | grep -q '^wrote '; then
    echo "generate-services: $m: $(echo "$out" | grep -v '^  note\|^  fix' | head -3 | tr '\n' ' ')" >&2
    fail=1
  fi
done
exit $fail
