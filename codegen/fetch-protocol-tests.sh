#!/bin/sh
# Fetch Smithy's AWS protocol test models (smithy-aws-protocol-tests/model,
# plus smithy-validation-model/model which they use; Apache-2.0, IDL
# text files) at the commit pinned in
# protocol-tests.lock into codegen/.protocol-tests (gitignored) and check
# every file's SHA-256. The generator parses them with codegen/idl.
# Usage: codegen/fetch-protocol-tests.sh            fetch and verify
#        codegen/fetch-protocol-tests.sh --relock   rewrite the lock
set -eu
here=$(cd "$(dirname "$0")" && pwd)
dst="$here/.protocol-tests"
lock="$here/protocol-tests.lock"
repo=https://github.com/smithy-lang/smithy.git
sub=smithy-aws-protocol-tests/model
sub2=smithy-validation-model/model
sub3=smithy-aws-endpoints/src/main/resources/software/amazon/smithy/rulesengine/aws/language/functions/partition/partitions.json

if [ "${1:-}" = "--relock" ]; then
  commit=$(git -C "$dst" rev-parse HEAD)
  {
    echo "# smithy-aws-protocol-tests pin (smithy 1.74.1): written by fetch-protocol-tests.sh --relock; do not edit"
    echo "repo $repo"
    echo "commit $commit"
    (cd "$dst" && { find "$sub" "$sub2" -name '*.smithy'; echo "$sub3"; } | LC_ALL=C sort | xargs shasum -a 256)
  } > "$lock"
  echo "relocked at $commit ($(grep -c "\.smithy$" "$lock") files)"
  exit 0
fi

commit=$(awk '$1 == "commit" { print $2 }' "$lock")
if [ ! -d "$dst/.git" ]; then
  git init -q "$dst"
  git -C "$dst" remote add origin "$repo"
  git -C "$dst" sparse-checkout set --no-cone "/$sub/" "/$sub2/" "/$sub3"
fi
if [ "$(git -C "$dst" rev-parse HEAD 2>/dev/null || true)" != "$commit" ]; then
  git -C "$dst" fetch -q --depth 1 --filter=blob:none origin "$commit"
  git -C "$dst" checkout -q --detach FETCH_HEAD
fi
(cd "$dst" && grep -E "\.smithy$|partitions.json$" "$lock" | shasum -a 256 -c --quiet -)
want=$(grep -c "\.smithy$" "$lock")
have=$(cd "$dst" && find "$sub" "$sub2" -name '*.smithy' | wc -l | tr -d ' ')
if [ "$want" != "$have" ]; then
  echo "protocol-tests.lock lists $want files, checkout has $have" >&2
  exit 1
fi
echo "ok: $have protocol test files at $commit"
