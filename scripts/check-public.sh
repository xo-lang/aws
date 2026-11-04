#!/bin/sh
# Fails when tracked files hold data that must not be public (decision 0007):
# account ids other than the documented example, real looking access keys,
# local home paths, IP addresses outside loopback and the documentation
# ranges, and email addresses. Then runs gitleaks over the whole history and the working tree.
# Usage: scripts/check-public.sh
set -u
cd "$(dirname "$0")/.."
fail=0
files=$(git ls-files | grep -v -E '^(codegen/models\.lock|LICENSE|codegen/LICENSE-models|sigv4a?/testdata/LICENSE-aws-c-auth)$')

report() {
  echo "check-public: $1" >&2
  echo "$2" | head -20 >&2
  fail=1
}

hits=$(echo "$files" | xargs grep -n -I -E '(^|[^0-9A-Za-z])[0-9]{12}([^0-9A-Za-z]|$)' 2>/dev/null | grep -v -E '123456789012|[0-9]{8}T[0-9]{6}Z' | grep -E ':[^:]*\b[0-9]{12}\b')
[ -n "$hits" ] && report "12 digit numbers (account ids?) other than 123456789012" "$hits"

hits=$(echo "$files" | xargs grep -n -I -E '\b(AKIA|ASIA)[A-Z0-9]{16}\b' 2>/dev/null | grep -v -E 'EXAMPLE')
[ -n "$hits" ] && report "access key ids" "$hits"

hits=$(echo "$files" | xargs grep -n -I -E '/(Users|home)/[A-Za-z0-9._-]+' 2>/dev/null)
[ -n "$hits" ] && report "home directory paths" "$hits"

hits=$(echo "$files" | xargs grep -n -I -o -E '\b([0-9]{1,3}\.){3}[0-9]{1,3}\b' 2>/dev/null | grep -v -E ':(127\.|0\.0\.0\.0|192\.0\.2\.|198\.51\.100\.|203\.0\.113\.|169\.254\.169\.254|169\.254\.170\.2)')
[ -n "$hits" ] && report "IP addresses outside loopback, metadata and documentation ranges" "$hits"

hits=$(echo "$files" | xargs grep -n -I -E '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}' 2>/dev/null | grep -v -E '@example\.(com|org|net)')
[ -n "$hits" ] && report "email addresses" "$hits"

if command -v gitleaks >/dev/null; then
  cfg=""
  [ -f ../xo-publish-tools/gitleaks.toml ] && cfg="--config ../xo-publish-tools/gitleaks.toml"
  gitleaks git $cfg --no-banner . >/dev/null 2>&1 || { gitleaks git $cfg --no-banner . 2>&1 | tail -20 >&2; report "gitleaks found leaks" ""; }
  # the working tree too: history alone misses what the next commit adds
  # (tracked and new files only: a copy, so ignored model downloads are skipped)
  tree=$(mktemp -d)
  git ls-files -co --exclude-standard | rsync -a --files-from=- . "$tree/"
  cfgabs=""
  [ -f ../xo-publish-tools/gitleaks.toml ] && cfgabs="--config $(cd .. && pwd)/xo-publish-tools/gitleaks.toml"
  (cd "$tree" && gitleaks dir $cfgabs --no-banner . >/dev/null 2>&1) || { (cd "$tree" && gitleaks dir $cfgabs --no-banner . 2>&1 | tail -20 >&2); report "gitleaks found leaks in the working tree" ""; }
  rm -r "$tree"
else
  report "gitleaks is not installed" ""
fi

[ $fail -eq 0 ] && echo "check-public: ok"
exit $fail
