#!/bin/sh
# Loads all pinned models (codegen/fetch-models.sh first) with the Xo
# loader and compares the totals with an independent count made for the
# commit in codegen/models.lock (a Python walk of the same JSON).
set -eu
cd "$(dirname "$0")/../codegen"
want="models 435 failed 0 shapes 141582 operations 19521 reachable 141427"
got=$("${XO_CLI:-xo}" run ./cmd/loadall | sed 's/ ms [0-9]*$//')
if [ "$got" != "$want" ]; then
  echo "check-models: got:  $got" >&2
  echo "check-models: want: $want" >&2
  exit 1
fi
echo "check-models: ok ($want)"
