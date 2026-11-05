#!/bin/sh
# Fails when tracked files hold data that must not be public (decision 0007):
# account ids other than the documented example, real looking access keys,
# local home paths, IP addresses outside loopback and the documentation
# ranges, and email addresses. Then runs gitleaks over the whole history and the working tree.
# Usage: scripts/check-public.sh             tracked files, history, working tree
#        scripts/check-public.sh <dir>...    those directories only, such as
#                                            .gencheck output before a
#                                            service from it is committed
set -u
cd "$(dirname "$0")/.."
fail=0
files=$(git ls-files | grep -v -E '^(codegen/models\.lock|LICENSE|codegen/LICENSE-models|sigv4a?/testdata/LICENSE-aws-c-auth)$')
dirs_only=0
if [ $# -gt 0 ]; then
  files=$(find "$@" -type f)
  dirs_only=1
fi

report() {
  echo "check-public: $1 ($(echo "$2" | grep -c .) lines)" >&2
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
#   012345678910  models/ec2: KmsKeyId docs (CopyImage, CopySnapshot,
#                 CreateVolume, ImportImage, ImportSnapshot,
#                 ModifyEbsDefaultKmsKeyId) example key ARNs
#   987654321098  models/cloudwatch-logs: a policy document example
#                 (`@aws.account IN [...]`)
#   112233445566  models/iam: the root ARN example in a principal's docs
ALLOW_ACCOUNTS='123456789012|111122223333|444455556666|555566667777|999999999999|012345678910|987654321098|112233445566'
# AWS's documentation example addresses, all private (RFC 1918) or
# shared (RFC 6598) ranges, allowed as exact values like the placeholders
# above (decision 0007):
#   10.0.0.0      models/ec2: CreateVpc, CreateSubnet, CreateIpamPool,
#                 ModifyIpamPool, IpamPool CIDR docs
#   10.1.0.0, 10.2.0.0, 10.3.0.0  models/ec2: IpamPrefixListResolverTargetState docs
#   100.68.0.0, 100.68.0.18  models/ec2: CreateVpc, CreateSubnet,
#                 CreateRoute, CreateNetworkAclEntry,
#                 AuthorizeSecurityGroupIngress, IpRange CIDR docs
#   172.16.0.0    models/ec2: CreateNetworkAclEntry, ReplaceNetworkAclEntry docs
#   10.0.1.0      models/ec2: ExportTransitGatewayRoutes, SearchLocalGatewayRoutes,
#                 SearchTransitGatewayRoutes filter docs
#   10.24.34.0    models/ec2: IpamPoolAllocation, IpamPoolCidr,
#                 IpamPrefixListResolverRule docs
#   169.254.0.0, 169.254.1.0, 169.254.2.0, 169.254.3.0, 169.254.4.0,
#   169.254.5.0   (link local) models/ec2: VpnTunnelOptionsSpecification,
#                 CreateTransitGatewayConnectPeer, TransitGatewayNatRule docs
#   169.254.169.252  (link local) models/ec2: VpnTunnelOptionsSpecification docs
#   224.0.0.0     (multicast) models/ec2: TransitGatewayNatRule docs
#   169.254.169.253  (the Amazon DNS server) models/ec2: ModifyVpcAttribute docs
ALLOW_IPS='10\.0\.0\.0|10\.0\.1\.0|10\.1\.0\.0|10\.2\.0\.0|10\.3\.0\.0|10\.24\.34\.0|100\.68\.0\.0|100\.68\.0\.18|169\.254\.0\.0|169\.254\.1\.0|169\.254\.2\.0|169\.254\.3\.0|169\.254\.4\.0|169\.254\.5\.0|169\.254\.169\.252|169\.254\.169\.253|172\.16\.0\.0|224\.0\.0\.0'
#   Grantees@email.com  models/s3: PutBucketAcl, PutBucketLogging, PutObjectAcl docs
#   xyz@amazon.com, abc@amazon.com  models/s3: PutObjectAcl docs
#   @example.com/.org/.net  reserved documentation domains (RFC 2606)
ALLOW_EMAILS='Grantees@email\.com|xyz@amazon\.com|abc@amazon\.com|[A-Za-z0-9._%+-]+@example\.(com|org|net)'

# the generated docs' other AWS values, exact, each cited to the pinned
# models that carry it (scripts/public-placeholders.tsv, decision 0007)
placeholders() {
  grep -v '^#' scripts/public-placeholders.tsv | awk -F'\t' -v c="$1" '$1 == c {print $2}' | sed 's/[.+@%]/\\&/g' | paste -sd'|' -
}
ALLOW_ACCOUNTS="$ALLOW_ACCOUNTS|$(placeholders account)"
ALLOW_IPS="$ALLOW_IPS|$(placeholders ip)"
ALLOW_EMAILS="$ALLOW_EMAILS|$(placeholders email)"
ALLOW_PATHS="$(placeholders path)"

# lines with the allowed values blanked out (file:line: prefix kept)
strip_allowed() { sed -E "s/$1//g"; }

# (the last group of a UUID, such as the suites' 00000000-...-000000000000,
# and a SigV4 timestamp are not account ids)
hits=$(echo "$files" | xargs grep -n -I -E '[0-9]{12}' 2>/dev/null | strip_allowed "$ALLOW_ACCOUNTS" | sed -E 's/[0-9]{8}T[0-9]{6}Z//g' | grep -E '^[^:]*:[0-9]+:.*(^|[^0-9A-Za-z-])[0-9]{12}([^0-9A-Za-z]|$)')
[ -n "$hits" ] && report "12 digit numbers (account ids?) other than the allowed placeholders" "$hits"

hits=$(echo "$files" | xargs grep -n -I -E '\b(AKIA|ASIA)[A-Z0-9]{16}\b' 2>/dev/null | grep -v -E 'EXAMPLE')
[ -n "$hits" ] && report "access key ids" "$hits"

hits=$(echo "$files" | xargs grep -n -I -E '/(Users|home)/[A-Za-z0-9._-]+' 2>/dev/null | sed -E "s#($ALLOW_PATHS)([^A-Za-z0-9._-]|$)#\\2#g" | grep -E '/(Users|home)/[A-Za-z0-9._-]+')
[ -n "$hits" ] && report "home directory paths" "$hits"

hits=$(echo "$files" | xargs grep -n -I -o -E '\b([0-9]{1,3}\.){3}[0-9]{1,3}\b' 2>/dev/null | grep -v -E ':(127\.|0\.0\.0\.0|192\.0\.2\.|198\.51\.100\.|203\.0\.113\.|169\.254\.169\.254|169\.254\.170\.2)' | grep -v -E ":($ALLOW_IPS)$")
[ -n "$hits" ] && report "IP addresses outside loopback, metadata and documentation ranges" "$hits"

hits=$(echo "$files" | xargs grep -n -I -E '@' 2>/dev/null | strip_allowed "$ALLOW_EMAILS" | grep -E '^[^:]*:[0-9]+:.*[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}')
[ -n "$hits" ] && report "email addresses" "$hits"

if command -v gitleaks >/dev/null; then
  # the shared configuration (or gitleaks' defaults) extended with this
  # repository's exact-value allowlist (scripts/gitleaks-extra.toml)
  gdir=$(mktemp -d); gcfg="$gdir/gitleaks.toml"
  if [ -f ../xo-publish-tools/gitleaks.toml ]; then
    printf '[extend]\npath = "%s"\n\n' "$(cd .. && pwd)/xo-publish-tools/gitleaks.toml" > "$gcfg"
  else
    printf '[extend]\nuseDefault = true\n\n' > "$gcfg"
  fi
  cat scripts/gitleaks-extra.toml >> "$gcfg"
  cfg="--config $gcfg"
  if [ $dirs_only = 1 ]; then
    for d in "$@"; do
      gitleaks dir $cfg --no-banner "$d" >/dev/null 2>&1 || { gitleaks dir $cfg --no-banner --verbose --redact "$d" 2>&1 | grep 'RuleID\|File:\|Line:' | head -20 >&2; report "gitleaks found leaks in $d" ""; }
    done
  else
    gitleaks git $cfg --no-banner . >/dev/null 2>&1 || { gitleaks git $cfg --no-banner . 2>&1 | tail -20 >&2; report "gitleaks found leaks" ""; }
    # the working tree too: history alone misses what the next commit adds
    # (tracked and new files only: a copy, so ignored model downloads are skipped)
    tree=$(mktemp -d)
    git ls-files -co --exclude-standard | rsync -a --files-from=- . "$tree/"
    cfgabs="$cfg"
    (cd "$tree" && gitleaks dir $cfgabs --no-banner . >/dev/null 2>&1) || { (cd "$tree" && gitleaks dir $cfgabs --no-banner . 2>&1 | tail -20 >&2); report "gitleaks found leaks in the working tree" ""; }
    rm -r "$tree"
  fi
  rm -r "$gdir"
else
  report "gitleaks is not installed" ""
fi

# where each allowed placeholder occurs, so a reviewer can spot one that
# is not AWS's: one line per value (category, value, occurrences, the
# first file:line, the pinned models the list cites), and every
# occurrence in .gencheck/public-allowed.tsv
mkdir -p .gencheck
allowed=.gencheck/public-allowed.tsv
: > "$allowed"
grep -v '^#' scripts/public-placeholders.tsv | while IFS="$(printf '\t')" read -r cat val models; do
  locs=$(echo "$files" | grep -v "^scripts/public-placeholders.tsv$" | xargs grep -n -I -F -- "$val" 2>/dev/null | cut -d: -f1,2)
  n=$(echo "$locs" | grep -c .)
  echo "$locs" | grep . | awk -v c="$cat" -v v="$val" '{print c "\t" v "\t" $0}' >> "$allowed"
  printf 'check-public: allowed %s %s: %s, first %s (cited: %s)\n' "$cat" "$val" "$n" "$(echo "$locs" | head -1)" "$models"
done
echo "check-public: every allowed occurrence is in $allowed"

[ $fail -eq 0 ] && echo "check-public: ok"
exit $fail
