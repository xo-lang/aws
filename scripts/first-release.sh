#!/bin/sh
# The first release (docs/release-checklist.md, "First release"): tags the root
# module and every service module at HEAD with one version, v0.1.0 for
# the first. The root and service/sts require each other (decision 0003)
# and both requires name that version at the same commit, which minimal
# version selection resolves. Later releases go through
# scripts/tag-modules.sh, which bumps each changed module from its tag.
# Without --push it checks the tree and the requires and prints the
# tags in order. With --push it creates annotated tags at HEAD and pushes
# them to $TAG_REMOTE (origin by default).
# Usage: scripts/first-release.sh v0.1.0 [--push]
set -eu
cd "$(dirname "$0")/.."
v=${1-}
push=0
[ "${2-}" = --push ] && push=1
remote=${TAG_REMOTE:-origin}
echo "$v" | grep -Eq '^v[0-9]+\.[0-9]+\.[0-9]+$' || { echo "first-release: want a version like v0.1.0" >&2; exit 2; }
if [ -n "$(git status --porcelain)" ]; then
  echo "first-release: the working tree is not clean" >&2
  exit 1
fi
if [ -n "$(git tag -l 'v*' 'service/*/v*')" ]; then
  echo "first-release: tags exist already; later releases use scripts/tag-modules.sh" >&2
  exit 1
fi
bad=0
grep -qx "require github.com/xo-lang/aws/service/sts $v" xo.mod || { echo "first-release: xo.mod does not require service/sts $v" >&2; bad=1; }
for m in service/*/xo.mod; do
  grep -qx "require github.com/xo-lang/aws $v" "$m" || { echo "first-release: $m does not require the root $v" >&2; bad=1; }
done
[ $bad -eq 0 ] || exit 1
tags=$(mktemp)
trap 'rm -f "$tags"' EXIT
{ echo "$v"; echo "service/sts/$v"; ls -d service/*/ | sed 's#/$##' | grep -vx service/sts | sed "s#\$#/$v#"; } > "$tags"
n=$(wc -l < "$tags" | tr -d ' ')
echo "first-release: $n tags at $(git rev-parse --short HEAD), in order:"
head -3 "$tags" | sed 's/^/  /'
echo "  ... ($((n - 3)) more service tags)"
if [ $push -eq 0 ]; then
  echo "first-release: dry run; --push creates and pushes them to $remote"
  exit 0
fi
while read -r t; do
  git tag -a "$t" -m "$t"
done < "$tags"
# in order, 50 to a push
split -l 50 "$tags" "$tags.part."
for p in "$tags".part.*; do
  # shellcheck disable=SC2046
  git push -q "$remote" $(sed 's#^#refs/tags/#' "$p")
  rm -f "$p"
done
echo "first-release: pushed $n tags to $remote"
