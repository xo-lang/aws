#!/bin/sh
# Fetch the AWS Smithy models at the commit pinned in models.lock into
# codegen/.models (gitignored) and check every file's SHA-256.
# Usage: codegen/fetch-models.sh            fetch and verify
#        codegen/fetch-models.sh --relock   rewrite models.lock from .models
set -eu
here=$(cd "$(dirname "$0")" && pwd)
dst="$here/.models"
lock="$here/models.lock"
repo=https://github.com/aws/api-models-aws.git

if [ "${1:-}" = "--relock" ]; then
  commit=$(git -C "$dst" rev-parse HEAD)
  {
    echo "# api-models-aws pin: written by fetch-models.sh --relock; do not edit"
    echo "repo $repo"
    echo "commit $commit"
    (cd "$dst" && find models -path '*/service/*' -name '*.json' | LC_ALL=C sort | xargs shasum -a 256)
  } > "$lock"
  echo "relocked at $commit ($(grep -c '  models/' "$lock") files)"
  exit 0
fi

commit=$(awk '$1 == "commit" { print $2 }' "$lock")
if [ ! -d "$dst/.git" ]; then
  git init -q "$dst"
  git -C "$dst" remote add origin "$repo"
fi
if [ "$(git -C "$dst" rev-parse HEAD 2>/dev/null || true)" != "$commit" ]; then
  git -C "$dst" fetch -q --depth 1 origin "$commit"
  git -C "$dst" checkout -q --detach FETCH_HEAD
fi
(cd "$dst" && grep '  models/' "$lock" | shasum -a 256 -c --quiet -)
want=$(grep -c '  models/' "$lock")
have=$(cd "$dst" && find models -path '*/service/*' -name '*.json' | wc -l | tr -d ' ')
if [ "$want" != "$have" ]; then
  echo "models.lock lists $want files, checkout has $have" >&2
  exit 1
fi
echo "ok: $have models at $commit"
