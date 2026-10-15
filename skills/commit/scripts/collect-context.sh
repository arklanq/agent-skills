#!/bin/bash
# Gather context for git commit decisions.

set -euo pipefail

echo '$ pwd'
pwd

if ! REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null); then
  echo 'Error: run this script inside a Git working tree.' >&2
  exit 1
fi
cd "$REPO_ROOT"

echo ''
echo '$ repository root'
pwd

echo ''
echo '$ git diff --cached --name-only'
git diff --cached --name-only

echo ''
echo '$ git diff --cached --stat'
git diff --cached --stat

echo ''
echo '$ git log --oneline -n 5'
if git rev-parse --verify --quiet HEAD >/dev/null; then
  git log --oneline -n 5
else
  echo '(no commits yet)'
fi

echo ''
echo '$ git status --short'
git status --short

echo ''
echo '$ git diff --stat'
git diff --stat

echo ''
echo '$ git ls-files --others --exclude-standard'
git ls-files --others --exclude-standard

echo ''
echo '$ git diff --cached'
git diff --cached
