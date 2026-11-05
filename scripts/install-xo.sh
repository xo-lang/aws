#!/bin/sh
# Installs a public Xo release (the newest, or XO_VERSION such as
# v0.39.0) for this machine from github.com/xo-lang/xo, checks it against
# the release's SHA256SUMS, and prints the path of its bin directory.
# Usage: scripts/install-xo.sh [install dir]   (default: .ci/xo)
# GITHUB_TOKEN, when set, is sent to the GitHub API (its rate limit).
set -eu
cd "$(dirname "$0")/.."
dir=${1:-.ci/xo}
api=https://api.github.com/repos/xo-lang/xo/releases
auth=""
[ -n "${GITHUB_TOKEN-}" ] && auth="Authorization: Bearer $GITHUB_TOKEN"
if [ -n "${XO_VERSION-}" ]; then
  tag=$XO_VERSION
else
  tag=$(curl -fsSL ${auth:+-H "$auth"} "$api/latest" | sed -n 's/^ *"tag_name": *"\([^"]*\)".*/\1/p' | head -1)
fi
[ -n "$tag" ] || { echo "install-xo: no release found" >&2; exit 1; }
case $(uname -s) in Linux) os=linux ;; Darwin) os=darwin ;; *) echo "install-xo: unsupported OS" >&2; exit 1 ;; esac
case $(uname -m) in x86_64|amd64) arch=amd64 ;; arm64|aarch64) arch=arm64 ;; *) echo "install-xo: unsupported CPU" >&2; exit 1 ;; esac
name="xo-$tag-$os-$arch"
if [ ! -x "$dir/$name/bin/xo" ]; then
  tmp=$(mktemp -d)
  trap 'rm -rf "$tmp"' EXIT
  base=https://github.com/xo-lang/xo/releases/download/$tag
  curl -fsSL -o "$tmp/$name.tar.gz" "$base/$name.tar.gz"
  curl -fsSL -o "$tmp/SHA256SUMS" "$base/SHA256SUMS"
  sum="shasum -a 256"
  command -v sha256sum >/dev/null && sum=sha256sum
  (cd "$tmp" && grep " $name.tar.gz\$" SHA256SUMS | $sum -c - >&2)
  mkdir -p "$dir"
  tar -xzf "$tmp/$name.tar.gz" -C "$dir"
fi
"$dir/$name/bin/xo" version >&2
cd "$dir/$name/bin" && pwd
