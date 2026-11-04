#!/bin/sh
# Runs every pinned model's endpointTests (codegen/fetch-models.sh first)
# against the endpoints rules interpreter; all must pass.
set -eu
cd "$(dirname "$0")/../codegen"
out=$("${XO_CLI:-xo}" run ./cmd/endpointtests)
echo "$out" | tail -20
echo "$out" | grep -q '^endpoint tests: [0-9]* passed, 0 failed$'
