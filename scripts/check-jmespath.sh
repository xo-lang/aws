#!/bin/sh
# Runs the JMESPath compliance suite against the jmespath package. The
# suite is fetched at a pinned commit into codegen/.cache (untracked: the
# suite states no license, so it is used, not copied).
set -eu
cd "$(dirname "$0")/../codegen"
commit=53abcc37901891cf4308fcd910eab287416c4609
if [ ! -d .cache/jmespath.test ]; then
  git clone -q https://github.com/jmespath/jmespath.test .cache/jmespath.test
fi
git -C .cache/jmespath.test checkout -q "$commit" 2>/dev/null || { git -C .cache/jmespath.test fetch -q origin && git -C .cache/jmespath.test checkout -q "$commit"; }
out=$("${XO_CLI:-xo}" run ./cmd/jmescheck)
echo "$out" | tail -60
echo "$out" | grep -q '^jmespath compliance: [0-9]* passed, 0 failed$'
