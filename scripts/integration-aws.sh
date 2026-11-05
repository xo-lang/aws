#!/bin/sh
# The real AWS tests (docs/real-aws-tests.md): integration/realaws.
#
#   scripts/integration-aws.sh             dry run: the plan, the guards,
#                                          and the offline tests; no network
#   scripts/integration-aws.sh --emulator  every step LocalStack supports,
#                                          against LocalStack in Docker
#   XO_AWS_REAL=1 XO_AWS_EXPECT_ACCOUNT=<12 digits> scripts/integration-aws.sh
#                                          against AWS, with the default
#                                          credentials chain of the shell
#                                          that runs it
#   scripts/integration-aws.sh --sweep [--delete]
#                                          list (and delete) leftovers of
#                                          any run: names starting
#                                          xo-lang-aws-it-
#
# A real run is for the owner to start in their own terminal, after the
# test plan is confirmed. The tests refuse to create anything unless STS
# GetCallerIdentity names XO_AWS_EXPECT_ACCOUNT. Every resource is named
# xo-lang-aws-it-<8 hex>-..., each step deletes what it made, and the EXIT
# trap sweeps this run's prefix. XO_AWS_STEPS (for example "1,2,13")
# chooses steps; the optional ones (3, 13) run only when listed.
set -u
cd "$(dirname "$0")/.."
xo=${XO_CLI:-xo}
mode=dry
delete=0
for a in "$@"; do
  case $a in
    --emulator) mode=emulator ;;
    --sweep) mode=sweep ;;
    --delete) delete=1 ;;
    *) echo "integration-aws: unknown argument $a" >&2; exit 2 ;;
  esac
done
if [ "${XO_AWS_REAL-}" = 1 ]; then
  case $mode in
    dry) mode=real ;;
    sweep) ;;
    *) echo "integration-aws: XO_AWS_REAL=1 cannot be combined with --emulator" >&2; exit 2 ;;
  esac
  case ${XO_AWS_EXPECT_ACCOUNT-} in
    [0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]) ;;
    *) echo "integration-aws: XO_AWS_EXPECT_ACCOUNT must be the 12 digit account to test in" >&2; exit 2 ;;
  esac
elif [ "$mode" = sweep ]; then
  echo "integration-aws: --sweep needs XO_AWS_REAL=1 and XO_AWS_EXPECT_ACCOUNT" >&2
  exit 2
fi
prefix="xo-lang-aws-it-$(od -An -N4 -tx1 /dev/urandom | tr -d ' \n')"

# $1: the text the tests' names contain ("aws step" or "aws sweep"); a
# step may wait up to an hour (a Multi-Region Access Point)
# (-v shows what the sweep prints)
run_tests() {
  (cd integration/realaws && XO_AWS_RUN_PREFIX="$prefix" "$xo" test --real -v --fail-empty --timeout=90m --run "$1" .)
}

case $mode in
dry)
  echo "integration-aws: dry run (no network). Steps:"
  grep -h '^test "aws ' integration/realaws/*_test.xo | sed 's/^test "\(.*\)" uses.*/  \1/'
  echo "integration-aws: the offline tests of the guards and the sweep:"
  (cd integration/realaws && "$xo" test .)
  exit $?
  ;;
emulator)
  image=${LOCALSTACK_IMAGE:-localstack/localstack:3}
  port=${LOCALSTACK_PORT:-14567}
  up=${DOCKER_UP:-$HOME/xo-lead/agents/docker-up.sh}
  "$up" || exit 1
  id=""
  cleanup() {
    if [ -n "$id" ]; then docker rm -f "$id" >/dev/null 2>&1; id=""; fi
    "$up" stop
  }
  trap cleanup EXIT
  trap 'exit 143' TERM
  trap 'exit 130' INT
  id=$(docker run -d -p "127.0.0.1:$port:4566" -e SERVICES=s3,sts,sqs,dynamodb,secretsmanager,sns,ec2,kinesis -e S3_SKIP_SIGNATURE_VALIDATION=0 "$image")
  [ -n "$id" ] || exit 1
  i=0
  while [ $i -lt 120 ] && ! curl -sf "http://127.0.0.1:$port/_localstack/health" | grep -q '"s3": "\(available\|running\)"'; do sleep 1; i=$((i + 1)); done
  export XO_AWS_EMULATOR="http://127.0.0.1:$port"
  run_tests 'aws step'
  status=$?
  # step 98 left a bucket, a queue and a table: the sweep must find and
  # delete those three, and a second sweep must find nothing
  XO_AWS_SWEEP_EXPECT=3 XO_AWS_SWEEP_DELETE=1 run_tests 'aws sweep' || status=1
  XO_AWS_SWEEP_EXPECT=0 run_tests 'aws sweep' || status=1
  [ $status -eq 0 ] && echo "integration-aws: emulator run ok"
  exit $status
  ;;
real)
  # the regions are set here, never taken from the profile: the owner's
  # choice (ca-central-1, with eu-north-1 for the multi-region step)
  export XO_AWS_REGION=${XO_AWS_REAL_REGION:-ca-central-1}
  export XO_AWS_REGION2=${XO_AWS_REAL_REGION2:-eu-north-1}
  reports=$(mktemp -d)
  export XO_AWS_REPORT_DIR="$reports"
  echo "integration-aws: real AWS in $XO_AWS_REGION and $XO_AWS_REGION2, steps ${XO_AWS_STEPS:-default}, run prefix $prefix"
  # whatever happens, sweep this run's prefix, then show what was skipped
  # or timed out
  finish() {
    XO_AWS_SWEEP_DELETE=1 run_tests 'aws sweep' || echo "integration-aws: the sweep failed; run --sweep"
    for f in "$reports"/*.txt; do [ -f "$f" ] && echo "integration-aws: $(basename "$f" .txt): $(cat "$f")"; done
    rm -rf "$reports"
  }
  trap finish EXIT
  trap 'exit 143' TERM
  trap 'exit 130' INT
  run_tests 'aws step'
  exit $?
  ;;
sweep)
  export XO_AWS_REGION=${XO_AWS_REAL_REGION:-ca-central-1}
  export XO_AWS_REGION2=${XO_AWS_REAL_REGION2:-eu-north-1}
  (cd integration/realaws && XO_AWS_RUN_PREFIX="$prefix" XO_AWS_SWEEP_PREFIX=xo-lang-aws-it- XO_AWS_SWEEP_DELETE=$delete "$xo" test --real -v --fail-empty --run 'aws sweep' .)
  exit $?
  ;;
esac
