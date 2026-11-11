#!/bin/sh
# Tags the published modules (the root and service/*) that changed since a
# commit, by scripts/changed-modules.sh: the root as vX.Y.Z, a service as
# service/<name>/vX.Y.Z, each one minor or patch past its newest tag.
# Each changed service is first checked against the newest root (the one
# this run tags) and tagged requiring it, so no tagged service calls a
# core function newer than the core it requires. A
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
trap 'rm -f "$plan" "$plan.x" "$planned"' EXIT
scripts/changed-modules.sh "$base" | awk -F'\t' '$1 == "." || $1 ~ /^service\//' > "$plan"
# The root and service/sts are rated against their own newest tags, not
# against the run's base: a root that changed since its last tag is
# tagged by the next run that tags anything, even when that run's own
# commits did not touch it (2026-11-11: the models run's base was its
# PR's parent, the root had changed since v0.1.0 in earlier commits, so
# the root was not in the plan and check-core-requires refused the
# services against v0.1.0). The services are rated from the base as
# before, and each is checked against the root this run tags.
rerate() {
  m=$1
  v=$(latest "$m")
  [ -n "$v" ] || return 0
  b=$(scripts/changed-modules.sh "$(prefix_of "$m")v$v" | awk -F'\t' -v m="$m" '$1 == m { print $2 }')
  awk -F'\t' -v m="$m" '$1 != m' "$plan" > "$plan.x"
  if [ -n "$b" ]; then
    printf '%s\t%s\n' "$m" "$b" >> "$plan.x"
  fi
  mv "$plan.x" "$plan"
}
rerate .
rerate service/sts
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
# every changed service is tagged requiring the newest root: the one this
# run tags, or else the newest root tag. Before any tag, each of them is
# checked against that root's tree (HEAD for a root about to be tagged):
# no call of a core function, type or field newer than it
# (scripts/check-core-requires.sh, names and a type check).
if [ -n "$root" ]; then
  target=$(bumped . "$root")
  target_ref=HEAD
else
  target=v$(latest .)
  target_ref=refs/tags/$target
fi
svcs=$(awk -F'\t' '$1 ~ /^service\//{ print $1 }' "$plan")
if [ -n "$svcs" ]; then
  # shellcheck disable=SC2086
  if ! XO_CLI=$xo scripts/check-core-requires.sh --typecheck --core="$target" --core-ref="$target_ref" $svcs; then
    echo "tag-modules: a changed service does not build with the root $target; nothing tagged" >&2
    exit 1
  fi
fi
root_tagged=0
if [ -n "$root" ]; then
  tag . "$root" && root_tagged=1
fi
# the requires, raised to the root checked above, in one commit
raise=""
for m in $svcs; do
  grep -qx "require github.com/xo-lang/aws $target" "$m/xo.mod" || raise="$raise $m"
done
if [ -n "$raise" ]; then
  n=$(echo "$raise" | wc -w | tr -d ' ')
  if [ $push -eq 0 ]; then
    echo "then: $n service(s) require the root $target, in one commit"
  else
    for m in $raise; do
      sed -i.bak -E "s#^require github\.com/xo-lang/aws v[^ ]+\$#require github.com/xo-lang/aws $target#" "$m/xo.mod"
      rm -f "$m/xo.mod.bak"
      grep -qx "require github.com/xo-lang/aws $target" "$m/xo.mod" || { echo "tag-modules: $m/xo.mod has no core require to raise" >&2; exit 1; }
      git add -- "$m/xo.mod"
    done
    git commit -q -m "Changed services require the root $target"
    git push -q "$remote" HEAD:main
  fi
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
