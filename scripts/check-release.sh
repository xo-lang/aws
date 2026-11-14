#!/bin/sh
# Rehearses scripts/release-all.sh with no network write: clones HEAD into
# a scratch directory with a bare "remote", runs release-all.sh --push
# against that remote, type checks every published module from the
# tagged clone with no workspace (after `xo mod tidy`, which must leave
# each xo.mod as it is), fetching what it requires from the scratch
# remote (XO_GIT_REWRITE), and last an app that gets the root, s3,
# config and fileio with `xo get`, type checks with no workspace and
# whose xo.lock shows decision 0011's effects: the root and the services
# reach only clock, net.dial and rand.
# Usage: XO_CLI=/path/to/xo scripts/check-release.sh v0.3.0 [scratch dir]
set -eu
cd "$(dirname "$0")/.."
v=${1:?usage: check-release.sh v0.3.0 [scratch dir]}
xo=${XO_CLI:-xo}
work=${2:-$(mktemp -d)}
mkdir -p "$work"
src=$(pwd)
[ -d "$work/modcache" ] && chmod -R u+w "$work/modcache"
rm -rf "$work/remote.git" "$work/clone" "$work/app" "$work/modcache"
git clone -q --bare "$src" "$work/remote.git"
git -C "$work/remote.git" tag -l | xargs -n 200 git -C "$work/remote.git" tag -d > /dev/null 2>&1 || true
git clone -q "$work/remote.git" "$work/clone"
(cd "$work/clone" && GIT_COMMITTER_NAME=release-check GIT_COMMITTER_EMAIL=release-check@invalid TAG_REMOTE=origin sh scripts/release-all.sh "$v" --push)
export XO_GIT_REWRITE="github.com/xo-lang/aws=$work/remote.git"
export XO_MODCACHE="$work/modcache"
rm -f "$work/clone/xo.work"
mods=$(cd "$work/clone" && git ls-files '*/xo.mod' | sed 's#/xo.mod$##' | grep -vxE 'codegen|examples|integration(/.*)?')
fails=0
n=0
for m in . $mods; do
  d="$work/clone/$m"
  n=$((n + 1))
  # the root's packages: directories with .xo files outside every nested
  # module (./... would load them all)
  pkgs=.
  if [ "$m" = . ]; then
    pkgs=$(cd "$d" && git ls-files '*.xo' | awk -F/ 'NF == 1 { print "." ; next } { sub("/[^/]*$", ""); print "./" $0 }' | sort -u | awk -v mods="$(git ls-files '*/xo.mod' | sed 's#/xo.mod$##' | tr '\n' ' ')" 'BEGIN { n = split(mods, a, " ") } { p = substr($0, 3); for (i = 1; i <= n; i++) if (p == a[i] || index(p, a[i] "/") == 1) next; print }')
  fi
  if ! (cd "$d" && "$xo" mod tidy > "$work/check.out" 2>&1 && git diff --quiet -- xo.mod && "$xo" check --workspace=off $pkgs >> "$work/check.out" 2>&1); then
    echo "check-release: FAIL $m"
    (cd "$d" && git diff --stat -- xo.mod) | sed 's/^/  /'
    tail -5 "$work/check.out" | sed 's/^/  /'
    fails=$((fails + 1))
  fi
done
echo "check-release: $n modules checked with no workspace, $fails failed"
[ $fails = 0 ] || exit 1
mkdir -p "$work/app"
cd "$work/app"
printf 'module example.com/app\nedition preview\n' > xo.mod
cat > main.xo <<'XO'
use github.com/xo-lang/aws
use github.com/xo-lang/aws/config
use github.com/xo-lang/aws/fileio
use github.com/xo-lang/aws/service/s3

fn main(os: Os) {
  let c = s3.new(os.net, os.clock, os.rand, s3.Options{region: "us-west-2", credentials: aws.static_provider("AKIDEXAMPLE000000000", "invented-secret")})
  let _ = c
  let _ = config.load_default_config
  let _ = fileio.upload_file
}
XO
"$xo" get github.com/xo-lang/aws@"$v" github.com/xo-lang/aws/service/s3@"$v" github.com/xo-lang/aws/config@"$v" github.com/xo-lang/aws/fileio@"$v" > "$work/get.out" 2>&1 || { echo "check-release: FAIL xo get"; tail -5 "$work/get.out"; exit 1; }
"$xo" check --workspace=off . > "$work/app.out" 2>&1 || { echo "check-release: FAIL app"; tail -5 "$work/app.out"; exit 1; }
echo "check-release: an app got the root, s3, config and fileio at $v and checks"
# decision 0011: the root and the services reach only what a request
# needs; credentials, config and fileio show their wider sets by name
for m in github.com/xo-lang/aws github.com/xo-lang/aws/service/s3 github.com/xo-lang/aws/service/sts; do
  fx=$(awk -v m="$m" '$1 == m && $2 == "effects" { print $3 }' xo.lock)
  [ "$fx" = clock,net.dial,rand ] || { echo "check-release: FAIL $m effects '$fx', want clock,net.dial,rand (decision 0011)"; exit 1; }
done
echo "check-release: effects: $(awk '$2 == "effects" { printf "%s %s; ", $1, $3 }' xo.lock)"
