#!/bin/sh
# Leaves out the tests in scripts/xo-skips.tsv that need a newer Xo than
# the one in use (XO_CLI), printing each with its reason. It deletes the
# files from the working tree, so it runs only in CI (CI=true) or with
# --force, never on a working copy by accident.
# Usage: XO_CLI=/path/to/xo scripts/apply-xo-skips.sh [--force]
set -eu
cd "$(dirname "$0")/.."
xo=${XO_CLI:-xo}
if [ "${CI-}" != true ] && [ "${1-}" != --force ]; then
  echo "apply-xo-skips: deletes test files; runs only with CI=true or --force" >&2
  exit 2
fi
have=$("$xo" version | awk '{print $2}')
# version_lt A B: A is older than B (numeric, dot separated)
version_lt() {
  [ "$1" != "$2" ] && [ "$(printf '%s\n%s\n' "$1" "$2" | sort -t. -k1,1n -k2,2n -k3,3n | head -1)" = "$1" ]
}
grep -v '^#' scripts/xo-skips.tsv | while IFS='	' read -r needs file reason; do
  [ -n "$needs" ] || continue
  if version_lt "$have" "$needs"; then
    rm -f "$file"
    echo "skipped: $file (needs Xo $needs, this is $have): $reason"
  fi
done
