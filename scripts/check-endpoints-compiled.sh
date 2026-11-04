#!/bin/sh
# Compiles every pinned model's endpoint rules to Xo (into the ignored
# .gencheck/ep) and runs its endpointTests as Xo tests; all must
# pass. Usage: XO_CLI=/path/to/xo scripts/check-endpoints-compiled.sh [model dirs...]
set -u
root=$(cd "$(dirname "$0")/.." && pwd)
xo=${XO_CLI:-xo}
if [ $# -gt 0 ]; then svcs="$*"; else svcs=$(cd "$root/codegen/.models/models" && ls -d */ | tr -d /); fi
pass=0; fail=0; bad=""
for svc in $svcs; do
  (cd "$root/codegen" && "$xo" run ./cmd/gen -- endpoints "$svc" ".gencheck/ep/$svc" >/dev/null 2>&1)
  line=$(cd "$root" && "$xo" test "./.gencheck/ep/$svc" 2>&1 | grep '^ok\|^FAIL' | tail -1)
  case "$line" in
    ok:*) pass=$((pass + $(echo "$line" | awk '{print $2}'))) ;;
    *) fail=$((fail + 1)); bad="$bad $svc" ;;
  esac
done
echo "compiled endpoint tests: $pass passed; services failing:${bad:- none}"
[ $fail -eq 0 ]
