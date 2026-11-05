#!/bin/sh
# Moves the api-models-aws pin (codegen/models.lock) to the newest commit
# of its main branch, or to the commit given, and regenerates every
# service client from it (scripts/generate-services.sh). Prints
# "models: current" when the pin is already there, else the old and new
# commits and the modules that changed (scripts/changed-modules.sh).
# Leaves the changes in the working tree for the caller to check and
# commit.
# Usage: XO_CLI=/path/to/xo scripts/update-models.sh [commit]
set -eu
cd "$(dirname "$0")/.."
lock=codegen/models.lock
dst=codegen/.models
repo=$(awk '$1 == "repo" { print $2 }' "$lock")
old=$(awk '$1 == "commit" { print $2 }' "$lock")
new=${1:-$(git ls-remote "$repo" refs/heads/main | cut -f1)}
[ -n "$new" ] || { echo "update-models: no commit found for $repo main" >&2; exit 1; }
if [ "$new" = "$old" ]; then
  echo "models: current ($old)"
  exit 0
fi
codegen/fetch-models.sh >/dev/null
git -C "$dst" fetch -q --depth 1 origin "$new"
git -C "$dst" checkout -q --detach FETCH_HEAD
codegen/fetch-models.sh --relock
codegen/fetch-models.sh
scripts/generate-services.sh
echo "models: $old -> $new"
scripts/changed-modules.sh HEAD
