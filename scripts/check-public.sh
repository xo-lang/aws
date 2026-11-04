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

# AWS's documented placeholder values (owner decision 2026-11-04, decision
# 0007): kept verbatim in generated docs, removed from each line before the
# checks below, so anything else on the same line is still checked. Each
# is written by AWS in the pinned models (api-models-aws, codegen/models.lock).
#   123456789012  the example account id across AWS's docs and the signing
#                 suite (e.g. models/sts AssumeRole examples)
#   111122223333  models/s3: PutBucketAcl, GetBucketPolicy,
#                 ServerSideEncryptionByDefault$KMSMasterKeyID docs
#   444455556666  models/s3: CreateMultipartUploadRequest$GrantRead docs
#   555566667777  models/s3: PutBucketAcl docs
#   999999999999  smithy-aws-protocol-tests model/awsJson1_1/kitchen-sink.smithy:
#                 a Long member's test value (not an account id)
ALLOW_ACCOUNTS='123456789012|111122223333|444455556666|555566667777|999999999999'
#   Grantees@email.com  models/s3: PutBucketAcl, PutBucketLogging, PutObjectAcl docs
#   xyz@amazon.com, abc@amazon.com  models/s3: PutObjectAcl docs
#   @example.com/.org/.net  reserved documentation domains (RFC 2606)
ALLOW_EMAILS='Grantees@email\.com|xyz@amazon\.com|abc@amazon\.com|[A-Za-z0-9._%+-]+@example\.(com|org|net)'

# lines with the allowed values blanked out (file:line: prefix kept)
strip_allowed() { sed -E "s/$1//g"; }

# (the last group of a UUID, such as the suites' 00000000-...-000000000000,
# and a SigV4 timestamp are not account ids)
hits=$(echo "$files" | xargs grep -n -I -E '[0-9]{12}' 2>/dev/null | strip_allowed "$ALLOW_ACCOUNTS" | sed -E 's/[0-9]{8}T[0-9]{6}Z//g' | grep -E '^[^:]*:[0-9]+:.*(^|[^0-9A-Za-z-])[0-9]{12}([^0-9A-Za-z]|$)')
[ -n "$hits" ] && report "12 digit numbers (account ids?) other than the allowed placeholders" "$hits"

hits=$(echo "$files" | xargs grep -n -I -E '\b(AKIA|ASIA)[A-Z0-9]{16}\b' 2>/dev/null | grep -v -E 'EXAMPLE')
[ -n "$hits" ] && report "access key ids" "$hits"

hits=$(echo "$files" | xargs grep -n -I -E '/(Users|home)/[A-Za-z0-9._-]+' 2>/dev/null)
[ -n "$hits" ] && report "home directory paths" "$hits"

hits=$(echo "$files" | xargs grep -n -I -o -E '\b([0-9]{1,3}\.){3}[0-9]{1,3}\b' 2>/dev/null | grep -v -E ':(127\.|0\.0\.0\.0|192\.0\.2\.|198\.51\.100\.|203\.0\.113\.|169\.254\.169\.254|169\.254\.170\.2)')
[ -n "$hits" ] && report "IP addresses outside loopback, metadata and documentation ranges" "$hits"

hits=$(echo "$files" | xargs grep -n -I -E '@' 2>/dev/null | strip_allowed "$ALLOW_EMAILS" | grep -E '^[^:]*:[0-9]+:.*[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}')
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
