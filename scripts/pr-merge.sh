#!/bin/bash
# pr-merge.sh BRANCH: squash-merges BRANCH's open pull request and deletes
# the branch, as the models workflow's Merge and tag step does. Right after
# a push GitHub is still computing mergeability, and `gh pr merge` then
# fails with "Base branch was modified" though main has not moved (run
# 43082284704). So it first waits until mergeStateStatus is CLEAN (every
# 5 s, at most PR_MERGE_WAIT seconds, default 120; past that it tries
# anyway and gh's own error says why), then retries the merge up to 3 times,
# 15 s apart, on that one error. Any other error stops it.
set -euo pipefail
branch=${1:?usage: pr-merge.sh BRANCH}
wait=${PR_MERGE_WAIT:-120}
waited=0
state=$(gh pr view "$branch" --json mergeStateStatus -q .mergeStateStatus)
while [ "$state" != CLEAN ] && [ "$waited" -lt "$wait" ]; do
	echo "pr-merge: $branch is $state, waiting"
	sleep 5
	waited=$((waited + 5))
	state=$(gh pr view "$branch" --json mergeStateStatus -q .mergeStateStatus)
done
echo "pr-merge: $branch is $state after ${waited}s"
for try in 1 2 3; do
	if out=$(gh pr merge "$branch" --squash --delete-branch 2>&1); then
		[ -n "$out" ] && echo "$out"
		exit 0
	fi
	echo "$out" >&2
	case $out in
	*"Base branch was modified"*) ;;
	*) exit 1 ;;
	esac
	[ "$try" -lt 3 ] && { echo "pr-merge: retrying in 15s ($try of 3)"; sleep 15; }
done
echo "pr-merge: $branch not merged after 3 tries" >&2
exit 1
