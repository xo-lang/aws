#!/bin/sh
# One version for every published module at HEAD (decision 0011, v0.3.0
# on): the root, credentials, config, fileio and every service, tagged at
# one commit. Since v0.3.0 the root requires no module (credentials and
# config, which use service/sts, are modules of their own), so there is
# no cycle and no order: every module requires the others it uses at
# this version. scripts/tag-modules.sh stays for a patch to some
# modules.
# Without --push it checks the tree and the requires and prints the
# tags. With --push it creates annotated tags at HEAD and pushes them to
# $TAG_REMOTE (origin by default).
# Usage: scripts/release-all.sh v0.3.0 [--push]
set -eu
cd "$(dirname "$0")/.."
v=${1-}
push=0
[ "${2-}" = --push ] && push=1
remote=${TAG_REMOTE:-origin}
echo "$v" | grep -Eq '^v[0-9]+\.[0-9]+\.[0-9]+$' || { echo "release-all: want a version like v0.3.0" >&2; exit 2; }
if [ -n "$(git status --porcelain)" ]; then
  echo "release-all: the working tree is not clean" >&2
  exit 1
fi
mods=$(git ls-files '*xo.mod' | sed 's#/*xo.mod$##' | grep -vxE 'codegen|examples|integration(/.*)?' | sed 's#^$#.#')
bad=0
tags=""
for m in $mods; do
  t=$v
  [ "$m" = . ] || t=$m/$v
  if git rev-parse -q --verify "refs/tags/$t" > /dev/null; then
    echo "release-all: tag $t exists already" >&2
    bad=1
  fi
  # every aws module it requires, at this version
  if grep -E '^require github.com/xo-lang/aws(/[a-z0-9/]+)? ' "$m/xo.mod" | grep -v " $v\$" >&2; then
    echo "release-all: $m/xo.mod requires the lines above, not $v" >&2
    bad=1
  fi
  tags="$tags $t"
done
[ $bad = 0 ] || exit 1
n=$(echo $tags | wc -w | tr -d ' ')
echo "release-all: $n tags at $(git rev-parse --short HEAD):"
echo $tags | tr ' ' '\n' | head -5 | sed 's/^/  /'
echo "  ... ($((n - 5)) more)"
[ $push = 1 ] || exit 0
for t in $tags; do
  git tag -a "$t" -m "$t" HEAD
done
# in batches, so one push does not carry hundreds of refs
echo $tags | tr ' ' '\n' | xargs -n 100 sh -c 'git push -q "$0" $(printf "refs/tags/%s " "$@")' "$remote"
echo "release-all: pushed $n tags to $remote"
