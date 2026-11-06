#!/bin/bash
# Checks that each service module builds with the core version its
# xo.mod requires, so a tagged service never calls a core function, type
# or constant newer than that version (a user's build may select exactly
# that version).
#
# Two passes:
# - names (always): every `pkg.name` a service's code uses, for each core
#   package it imports (`use github.com/xo-lang/aws/...`), must be a
#   top-level `pub fn`, `struct`, `enum`, `const` or `interface` of that
#   package at the required version (the tag's tree, from git). It is
#   fast and names each missing symbol.
# - --typecheck: each service is type checked against the required
#   version's tree in a scratch workspace, offline, which also catches a
#   new struct field or a changed signature.
#
# The required version comes from the service's xo.mod, or from
# --core=<version> with --core-ref=<git ref> to check against a version
# about to be tagged (scripts/tag-modules.sh passes the planned root tag
# and HEAD). A required version with no tag and no --core-ref fails.
# Usage: XO_CLI=/path/to/xo scripts/check-core-requires.sh [--typecheck]
#          [--core=vX.Y.Z --core-ref=<ref>] [service/<name>...]
# With no modules it checks every service/<name>.
set -u
cd "$(dirname "$0")/.."
xo=${XO_CLI:-xo}
typecheck=0
core=""
core_ref=""
mods=()
for a in "$@"; do
  case $a in
    --typecheck) typecheck=1 ;;
    --core=*) core=${a#--core=} ;;
    --core-ref=*) core_ref=${a#--core-ref=} ;;
    *) mods+=("${a%/}") ;;
  esac
done
if [ ${#mods[@]} -eq 0 ]; then
  for d in service/*/; do mods+=("${d%/}"); done
fi
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fail=0

# the git ref holding version v of the root module
ref_of() {
  if [ -n "$core" ] && [ "$1" = "$core" ] && [ -n "$core_ref" ]; then
    echo "$core_ref"
  elif git rev-parse -q --verify "refs/tags/$1" >/dev/null; then
    echo "refs/tags/$1"
  fi
}

# the exported top-level names of core package dir $2 at ref $1, cached
names_of() {
  local key
  key=$(echo "$1 $2" | tr '/ ' '__')
  if [ ! -f "$tmp/names.$key" ]; then
    git ls-tree --name-only "$1" -- "$2/" 2>/dev/null | grep '\.xo$' | grep -v '_test\.xo$' | while read -r f; do
      # only files of this package, not of a package below it
      [ "$(dirname "$f")" = "$2" ] && git show "$1:$f"
    done | sed -nE 's/^pub (fn|struct|enum|const|interface) ([A-Za-z_][A-Za-z0-9_]*).*/\2/p' | sort -u > "$tmp/names.$key"
  fi
  cat "$tmp/names.$key"
}

for m in "${mods[@]}"; do
  [ -f "$m/xo.mod" ] || { echo "check-core-requires: $m has no xo.mod" >&2; fail=1; continue; }
  v=$(sed -nE 's/^require github\.com\/xo-lang\/aws (v[0-9][^ ]*)$/\1/p' "$m/xo.mod")
  [ -n "$core" ] && v=$core
  if [ -z "$v" ]; then
    echo "check-core-requires: $m does not require the core" >&2
    fail=1
    continue
  fi
  ref=$(ref_of "$v")
  if [ -z "$ref" ]; then
    echo "check-core-requires: $m requires core $v, which has no tag" >&2
    fail=1
    continue
  fi
  # alias and package directory of each core import, then each use
  missing=$(for f in "$m"/*.xo; do
    sed -nE 's#^use github\.com/xo-lang/aws(/[a-z0-9/]+)?( as ([a-z_0-9]+))?$#\1 \3#p' "$f" | while read -r p a; do
      if [ -z "$p" ]; then dir=.; else dir=${p#/}; fi
      if [ -z "$a" ]; then
        if [ -z "$p" ]; then a=aws; else a=$(basename "$p"); fi
      fi
      # code only: comment lines and string literals dropped (a doc line
      # or a string may say `aws.amazon.com`)
      grep -vE '^[[:space:]]*//' "$f" | sed -E 's/"([^"\\]|\\.)*"/""/g' | grep -oE "(^|[^A-Za-z0-9_.])$a\.[A-Za-z_][A-Za-z0-9_]*" | sed -E "s/^.*$a\.//" | sort -u | while read -r n; do
        names_of "$ref" "$dir" | grep -qx "$n" || echo "$dir.$n"
      done
    done
  done | sort -u)
  if [ -n "$missing" ]; then
    echo "check-core-requires: $m requires core $v, which lacks: $(echo "$missing" | sed 's#^\.\.#aws.#' | tr '\n' ' ')"
    fail=1
    continue
  fi
  if [ $typecheck -eq 1 ]; then
    w=$tmp/ws-$v
    if [ ! -d "$w" ]; then
      mkdir -p "$w/core"
      git archive "$ref" | tar -x -C "$w/core"
    fi
    rm -rf "$w/svc"
    cp -R "$m" "$w/svc"
    # the core at v and its service/sts (the root requires it): both from
    # the tag's tree, so nothing is fetched
    if [ "$m" = service/sts ]; then
      printf 'xo preview\nuse ./core\nuse ./svc\n' > "$w/xo.work"
    else
      printf 'xo preview\nuse ./core\nuse ./core/service/sts\nuse ./svc\n' > "$w/xo.work"
    fi
    if ! out=$(cd "$w" && XO_OFFLINE=1 "$xo" check ./svc 2>&1); then
      echo "check-core-requires: $m does not type check against core $v:"
      echo "$out" | grep -v '^  note\|^  fix' | grep 'error' | head -5 | sed 's/^/  /'
      fail=1
    fi
  fi
done
[ $fail -eq 0 ] && echo "check-core-requires: ${#mods[@]} module(s) ok"
exit $fail
