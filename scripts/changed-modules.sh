#!/bin/sh
# Lists the modules whose files differ from a commit (the working tree,
# new files included), one per line: the module directory and the bump
# its next tag needs. "minor" when the change adds an operation or a type
# (a new `pub fn (c: Client)`, `pub struct` or `pub enum` line, or a new
# module) or adds, removes or changes a member (an indented `pub` line:
# a field's type changing, as Smithy floats becoming Float32 in decision
# 0010, breaks the API), "patch" otherwise.
# Usage: scripts/changed-modules.sh [commit]   (default HEAD)
set -eu
cd "$(dirname "$0")/.."
base=${1:-HEAD}
# the nearest directory holding an xo.mod
module_of() {
  d=$(dirname "$1")
  while [ "$d" != . ] && [ ! -f "$d/xo.mod" ]; do d=$(dirname "$d"); done
  echo "$d"
}
{
  git diff --name-only "$base" --
  git ls-files --others --exclude-standard
} | grep -E '\.xo$|(^|/)xo\.mod$' | while read -r f; do module_of "$f"; done | sort -u | while read -r m; do
  if [ "$m" = . ]; then
    # the root without the modules nested in it
    paths="-- . $(git ls-files '*/xo.mod' | xargs -n1 dirname | sed "s/.*/:(exclude)&/" | tr '\n' ' ')"
    modfile=xo.mod
  else
    paths="-- $m"
    modfile=$m/xo.mod
  fi
  if ! git cat-file -e "$base:$modfile" 2>/dev/null; then
    bump=minor
  elif git diff "$base" $paths | grep -qE '^\+pub (fn \(c: Client\)|struct |enum )'; then
    bump=minor
  elif git diff "$base" $paths | grep -qE '^[-+][[:space:]]+pub '; then
    bump=minor
  elif [ -n "$(git ls-files --others --exclude-standard $paths | grep '\.xo$' || true)" ]; then
    bump=minor
  else
    bump=patch
  fi
  printf '%s\t%s\n' "$m" "$bump"
done
