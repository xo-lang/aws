#!/bin/sh
# Runs one CI step and records its name, result and wall time as a row of
# a Markdown table (CI_TIMINGS, default .ci/timings.md), which the
# workflow's last step adds to the run's summary. Exits as the step did.
# Usage: scripts/ci-step.sh <name> <command> [args...]
set -u
name=$1
shift
out=${CI_TIMINGS:-.ci/timings.md}
mkdir -p "$(dirname "$out")"
[ -s "$out" ] || printf '| Step | Result | Time |\n|---|---|---|\n' > "$out"
start=$(date +%s)
"$@"
status=$?
secs=$(($(date +%s) - start))
if [ $status -eq 0 ]; then r=ok; else r="failed ($status)"; fi
printf '| %s | %s | %dm%02ds |\n' "$name" "$r" $((secs / 60)) $((secs % 60)) >> "$out"
echo "ci-step: $name: $r in $((secs / 60))m$((secs % 60))s" >&2
exit $status
