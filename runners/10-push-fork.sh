#!/usr/bin/env bash
# 10-push-fork.sh — push the capstone product repo to its own GitHub remote.
#
#   bash runners/10-push-fork.sh git@github.com:This1sN0tMe/abode-website.git
#
# Why this is a script and not a command: the fork carries two branches that must both exist remotely
# (requirement 2 says a Git workflow, requirement 3 branch-conditions on master vs develop), and a push
# that exits 0 is not evidence that it landed. This pushes, then proves the remote refs with ls-remote.
#
# The repo must be created EMPTY (no README, no .gitignore, no licence) — an initial commit on the far
# side makes this a non-fast-forward and forces a merge of two unrelated histories.
set -eu

URL="${1:-}"
if [ -z "$URL" ]; then
  echo "usage: bash runners/10-push-fork.sh <git-remote-url>"
  exit 2
fi

cd "$(dirname "$0")/.." || exit 1

echo "== before =="
git branch --show-current
git log --oneline -2
git remote -v

# upstream is hshar/website and is fetch-only in practice. It is never a push target.
if git remote get-url origin >/dev/null 2>&1; then
  git remote set-url origin "$URL"
else
  git remote add origin "$URL"
fi

echo "== dry run =="
git push --dry-run origin master develop

echo "== push =="
git push -u origin master develop

echo "== proof: remote refs =="
git ls-remote --heads origin
echo "== local refs for comparison =="
git rev-parse master develop
