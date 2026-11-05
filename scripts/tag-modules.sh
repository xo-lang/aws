#!/bin/sh
# Tags the published modules (the root and service/*) that changed since a
# commit, by scripts/changed-modules.sh: the root as vX.Y.Z, a service as
# service/<name>/vX.Y.Z, each one minor or patch past its newest tag. A
# module with no tag yet is left for the first release, which is made by
# hand (docs/release-checklist.md). The root and service/sts require each
# other (decision 0003), so the order is the checklist's: the root first,
# then service/sts after it requires that root tag, then a root patch
# that requires the new sts tag.
# Without --push it prints the plan and changes nothing. With --push it
# creates and pushes each tag in order, and for the cycle runs
# `xo mod tidy`, commits the requires it writes, and pushes them.
# Usage: XO_CLI=/path/to/xo scripts/tag-modules.sh <base commit> [--push]
set -eu
cd "$(dirname "$0")/.."
xo=${XO_CLI:-xo}
base=$1
push=0
[ "${2-}" = --push ] && push=1
remote=${TAG_REMOTE:-origin}

prefix_of() { if [ "$1" = . ]; then echo ""; else echo "$1/"; fi; }
# the newest vX.Y.Z tag of a module, without its prefix ("" when none)
latest() {
  p=$(prefix_of "$1")
  { git tag -l "${p}v*"; cat "$planned"; } | grep "^${p}v" | sed "s#^$p##" | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | sed 's/^v//' | sort -t. -k1,1n -k2,2n -k3,3n | tail -1
}
bumped() {
  v=$(latest "$1")
  [ -n "$v" ] || return 0
  echo "$v" | awk -F. -v b="$2" '{ if (b == "minor") print "v" $1 "." $2 + 1 ".0"; else print "v" $1 "." $2 "." $3 + 1 }'
}
plan=$(mktemp)
# tags this run made or, without --push, would make
planned=$(mktemp)
trap 'rm -f "$plan" "$planned"' EXIT
scripts/changed-modules.sh "$base" | awk -F'\t' '$1 == "." || $1 ~ /^service\//' > "$plan"
if [ ! -s "$plan" ]; then
  echo "tag-modules: no published module changed since $base"
  exit 0
fi
bump_of() { awk -F'\t' -v m="$1" '$1 == m { print $2 }' "$plan"; }
tag() {
  m=$1
  next=$(bumped "$m" "$2")
  if [ -z "$next" ]; then
    echo "tag-modules: $m has no tag yet; its first release is made by hand (docs/release-checklist.md)"
    return 1
  fi
  t="$(prefix_of "$m")$next"
  echo "tag $t ($2)"
  echo "$t" >> "$planned"
  if [ $push -eq 1 ]; then
    git tag -a "$t" -m "$t"
    git push -q "$remote" "$t"
  fi
  return 0
}
tidy_commit() {
  m=$1
  msg=$2
  if [ $push -eq 0 ]; then
    echo "then: xo mod tidy in $m, commit \"$msg\""
    return 0
  fi
  "$xo" mod tidy --dir="$m"
  if [ -n "$(git status --porcelain -- "$m/xo.mod" "$m/xo.lock")" ]; then
    git add -- "$m/xo.mod" "$m/xo.lock"
    git commit -q -m "$msg"
    git push -q "$remote" HEAD:main
  fi
}
root=$(bump_of .)
sts=$(bump_of service/sts)
root_tagged=0
if [ -n "$root" ]; then
  tag . "$root" && root_tagged=1
fi
# every other service
awk -F'\t' '$1 != "." && $1 != "service/sts"' "$plan" | while IFS='	' read -r m b; do
  tag "$m" "$b" || true
done
# the cycle: sts after it requires the new root, then the root again
if [ $root_tagged -eq 1 ] && [ -z "$sts" ]; then
  sts=patch
fi
if [ -n "$sts" ]; then
  if [ $root_tagged -eq 1 ]; then
    tidy_commit service/sts "service/sts requires the new root tag"
  fi
  if tag service/sts "$sts"; then
    tidy_commit . "The root requires the new service/sts tag"
    tag . patch || true
  fi
fi
