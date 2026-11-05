#!/bin/sh
# (MinIO stopped publishing public images in 2025: Docker Hub and quay.io
# refuse the pull; set MINIO_IMAGE to a mirror, or use
# integration-localstack.sh.)
# Runs the S3 integration tests against MinIO in Docker, published on
# 127.0.0.1 only, with invented credentials. Starts Docker through the
# lead's wrapper, removes only the container this run created (by ID),
# and stops Docker after. Usage: XO_CLI=/path/to/xo scripts/integration-minio.sh
set -u
cd "$(dirname "$0")/.."
xo=${XO_CLI:-xo}
image=${MINIO_IMAGE:-quay.io/minio/minio:RELEASE.2024-10-13T13-34-11Z}
port=${MINIO_PORT:-19000}
user=AKIDTEST0000000000
secret=xo-lang-aws-test-secret-not-real
up=${DOCKER_UP:-$HOME/xo-lead/agents/docker-up.sh}
"$up" || exit 1
id=""
# remove this run's container (by ID) and stop Docker however the run
# ends, a TERM from heavy.sh's memory cap included (a KILL cannot be
# caught)
cleanup() {
  if [ -n "$id" ]; then docker rm -f "$id" >/dev/null 2>&1; id=""; fi
  "$up" stop
}
trap cleanup EXIT
trap 'exit 143' TERM
trap 'exit 130' INT
id=$(docker run -d -p "127.0.0.1:$port:9000" -e "MINIO_ROOT_USER=$user" -e "MINIO_ROOT_PASSWORD=$secret" "$image" server /data)
status=1
if [ -n "$id" ]; then
  i=0
  while [ $i -lt 60 ] && ! curl -sf "http://127.0.0.1:$port/minio/health/live" >/dev/null; do sleep 1; i=$((i + 1)); done
  (cd integration && XO_AWS_TEST_S3_ENDPOINT="http://127.0.0.1:$port" XO_AWS_TEST_KEY_ID=$user XO_AWS_TEST_SECRET=$secret "$xo" test --real .)
  status=$?
fi
exit $status
