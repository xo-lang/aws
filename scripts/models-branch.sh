#!/bin/sh
# models-branch.sh BRANCH MESSAGE: the models workflow's branch. Commits the
# index (what Update models staged) to BRANCH and pushes it, never forcing:
# when origin already has BRANCH (an earlier run of the same model commit
# pushed it), the new commit is a merge of that tip and HEAD (main), so the
# push is a fast-forward and the pull request's diff against main is this
# run's tree. A remote tip that already holds this tree and HEAD is reused
# as it is. Leaves BRANCH checked out, the working tree unchanged.
set -eu
b=$1
msg=$2
tree=$(git write-tree)
head=$(git rev-parse HEAD)
if git fetch -q origin "+refs/heads/$b:refs/remotes/origin/$b" 2>/dev/null; then
  tip=$(git rev-parse "refs/remotes/origin/$b")
  if [ "$(git rev-parse "$tip^{tree}")" = "$tree" ] && git merge-base --is-ancestor "$head" "$tip"; then
    git update-ref "refs/heads/$b" "$tip"
    git symbolic-ref HEAD "refs/heads/$b"
    echo "models-branch: origin/$b already holds this tree"
    exit 0
  fi
  c=$(git commit-tree "$tree" -p "$tip" -p "$head" -m "$msg")
else
  c=$(git commit-tree "$tree" -p "$head" -m "$msg")
fi
git update-ref "refs/heads/$b" "$c"
git symbolic-ref HEAD "refs/heads/$b"
git push -q origin "$b"
echo "models-branch: pushed $b at $(git rev-parse --short "$c")"
