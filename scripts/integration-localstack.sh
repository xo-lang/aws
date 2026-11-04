#!/bin/sh
# Runs the integration tests against LocalStack (community image 3,
# which needs no account) in Docker, published on 127.0.0.1 only, with
# invented credentials. Starts Docker through the lead's wrapper, removes
# only the container this run created (by ID), and stops Docker after.
# Usage: XO_CLI=/path/to/xo scripts/integration-localstack.sh
set -u
cd "$(dirname "$0")/.."
xo=${XO_CLI:-xo}
image=${LOCALSTACK_IMAGE:-localstack/localstack:3}
port=${LOCALSTACK_PORT:-14566}
up=${DOCKER_UP:-$HOME/xo-lead/agents/docker-up.sh}
"$up" || exit 1
id=$(docker run -d -p "127.0.0.1:$port:4566" -e SERVICES=s3,sts,sqs,dynamodb,secretsmanager,sns,lambda,ec2 "$image")
status=1
if [ -n "$id" ]; then
  i=0
  while [ $i -lt 120 ] && ! curl -sf "http://127.0.0.1:$port/_localstack/health" | grep -q '"s3": "\(available\|running\)"'; do sleep 1; i=$((i + 1)); done
  (cd integration && XO_AWS_TEST_S3_ENDPOINT="http://127.0.0.1:$port" XO_AWS_TEST_ENDPOINT="http://127.0.0.1:$port" XO_AWS_TEST_KEY_ID=AKIDTEST0000000000 XO_AWS_TEST_SECRET=xo-lang-aws-test-secret-not-real "$xo" test --real .)
  status=$?
  docker rm -f "$id" >/dev/null
fi
"$up" stop
exit $status
