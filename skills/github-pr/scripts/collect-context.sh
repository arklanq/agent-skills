#!/bin/bash
# Gather repository context for GitHub PR decisions.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATUS=0

echo '$ pwd'
pwd
if ! REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null); then
  echo 'Error: run this script inside a Git working tree.' >&2
  exit 1
fi
cd "$REPO_ROOT"
printf '\nrepository root: %s\n' "$REPO_ROOT"

if ! BRANCH=$(git symbolic-ref --quiet --short HEAD); then
  echo 'Error: detached HEAD; select the branch intended for the PR.' >&2
  exit 1
fi
if ! git rev-parse --verify --quiet HEAD >/dev/null; then
  echo 'Error: no commits yet; there is no branch history to compare.' >&2
  exit 1
fi
printf 'branch: %s\n' "$BRANCH"

UPSTREAM=$(git rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null || true)
REMOTE=${1:-}
if [ -z "$REMOTE" ]; then
  TRACKING_REMOTE=$(git config --get "branch.$BRANCH.remote" || true)
  if [ -n "$TRACKING_REMOTE" ] && [ "$TRACKING_REMOTE" != '.' ]; then
    REMOTE=$TRACKING_REMOTE
  elif git remote get-url origin >/dev/null 2>&1; then
    REMOTE=origin
  else
    REMOTES=$(git remote)
    if [ -n "$REMOTES" ] && [ "$(printf '%s\n' "$REMOTES" | wc -l | tr -d ' ')" = 1 ]; then
      REMOTE=$REMOTES
    fi
  fi
fi

DEFAULT_BRANCH=''
REPOSITORY=''
BASE_BRANCH=''
if [ -n "$REMOTE" ]; then
  if ! REMOTE_URL=$(git remote get-url "$REMOTE"); then
    exit 1
  fi
  DEFAULT_BRANCH=$(git symbolic-ref --quiet --short "refs/remotes/$REMOTE/HEAD" 2>/dev/null || true)
  DEFAULT_BRANCH=${DEFAULT_BRANCH#"$REMOTE"/}
  case "$REMOTE_URL" in
    https://*|http://*|ssh://*)
      REPO_TARGET=${REMOTE_URL#*://}
      REPO_TARGET=${REPO_TARGET#*@}
      ;;
    *@*:*)
      REPO_TARGET=${REMOTE_URL#*@}
      REPO_TARGET=${REPO_TARGET/:/\/}
      ;;
    *)
      echo '(remote URL is not a supported GitHub HTTP or SSH URL)' >&2
      exit 1
      ;;
  esac
  REPO_TARGET=${REPO_TARGET%/}
  REPO_TARGET=${REPO_TARGET%.git}
  if command -v gh >/dev/null 2>&1; then
    # Resolve the selected remote explicitly, including SSH URLs and forks.
    if REPO_INFO=$(gh repo view "$REPO_TARGET" --json url,defaultBranchRef \
      --jq '.url + "\n" + (.defaultBranchRef.name // "")'); then
      REPOSITORY=${REPO_INFO%%$'\n'*}
      DEFAULT_BRANCH=$(printf '%s\n' "$REPO_INFO" | sed -n '2p')
    else
      echo '(repository lookup failed; GitHub state is unknown)' >&2
      STATUS=1
    fi
  else
    echo '(gh CLI is unavailable; GitHub state is unknown)' >&2
    STATUS=1
  fi
else
  echo '(remote is missing or ambiguous; pass the intended remote as the first argument)' >&2
  STATUS=1
fi

printf '\nremote: %s\nupstream: %s\nrepository: %s\ndefault branch: %s\n' \
  "${REMOTE:-(unknown)}" "${UPSTREAM:-(none)}" "${REPOSITORY:-(unknown)}" "${DEFAULT_BRANCH:-(unknown)}"

echo ''
echo '$ git log --oneline --decorate -n 20'
git log --oneline --decorate -n 20

echo ''
echo '$ git status -sb'
git status -sb

echo ''
echo '$ open PR candidates in the selected repository (branch-name matches)'
if [ -n "$REPOSITORY" ]; then
  # Keep the count and base on separate lines before the human-readable details.
  if PR_INFO=$(gh pr list --repo "$REPOSITORY" --head "$BRANCH" --state open \
    --json number,url,title,body,baseRefName,headRefName,headRepository \
    --template '{{len .}}{{"\n"}}{{range .}}{{.baseRefName}}{{"\n"}}PR #{{.number}}: {{.url}}{{"\n"}}Head: {{if .headRepository}}{{.headRepository.nameWithOwner}}{{else}}(unknown repository){{end}}:{{.headRefName}}{{"\n"}}Title: {{.title}}{{"\n"}}{{.body}}{{"\n"}}{{end}}'); then
    PR_COUNT=${PR_INFO%%$'\n'*}
    case "$PR_COUNT" in
      0)
        echo '(no open PR found in the selected repository)'
        BASE_BRANCH=$DEFAULT_BRANCH
        ;;
      1)
        echo '(verify the head repository and branch before using this PR or its candidate base)'
        printf '%s\n' "$PR_INFO" | sed '1d'
        BASE_BRANCH=$(printf '%s\n' "$PR_INFO" | sed -n '2p')
        ;;
      *)
        printf '%s\n' "$PR_INFO"
        echo '(multiple matching PRs; base is ambiguous)' >&2
        STATUS=1
        ;;
    esac
  else
    echo '(PR lookup failed; PR existence and base are unknown)' >&2
    STATUS=1
  fi
else
  echo '(PR lookup skipped; repository is unknown)'
fi

echo ''
echo '$ unpushed commits (relative to the locally known push destination)'
PUSH_REF=$(git rev-parse --symbolic-full-name '@{push}' 2>/dev/null || true)
if [ -n "$PUSH_REF" ]; then
  printf 'push reference: %s\n' "$PUSH_REF"
  git log "$PUSH_REF"..HEAD --oneline || STATUS=1
else
  echo '(push destination or its local ref is unknown; verify the intended head remote and branch)'
fi

echo ''
echo '$ pull request template'
cat .github/pull_request_template.md 2>/dev/null || cat .github/PULL_REQUEST_TEMPLATE.md 2>/dev/null || cat "$SCRIPT_DIR/../template.md" 2>/dev/null || echo '(no template)'

echo ''
echo '$ ticket-system evidence'
printf 'branch ticket candidates: '
printf '%s\n' "$BRANCH" | grep -Eo '[A-Z][A-Z0-9]+-[0-9]+' | paste -sd, - || true
EVIDENCE_PATHS=()
for path in CONTRIBUTING.md README.md .github docs; do
  [ ! -e "$path" ] || EVIDENCE_PATHS+=("$path")
done
if [ "${#EVIDENCE_PATHS[@]}" -eq 0 ]; then
  echo '(no common project files found)'
elif command -v rg >/dev/null 2>&1; then
  if rg -n -i -m 20 \
    'linear\.app|atlassian\.net|youtrack|shortcut\.com|app\.clickup\.com|github\.com/[^ ]+/issues|gitlab\.[^ ]+/issues|dev\.azure\.com' \
    "${EVIDENCE_PATHS[@]}"; then
    :
  else
    RG_STATUS=$?
    if [ "$RG_STATUS" -eq 1 ]; then
      echo '(no provider evidence found in common project files)'
    else
      echo '(provider evidence search failed)' >&2
      STATUS=1
    fi
  fi
else
  echo '(rg unavailable; inspect common project files for provider evidence)'
fi

echo ''
echo '$ diff against candidate base branch'
if [ -n "$BASE_BRANCH" ] && [ -n "$REMOTE" ]; then
  BASE_REF="refs/remotes/$REMOTE/$BASE_BRANCH"
  printf 'base: %s\n' "$BASE_REF"
  if ! git diff "$BASE_REF"...HEAD --stat; then
    echo "(could not diff against $BASE_REF; verify that the remote ref is available locally)" >&2
    STATUS=1
  fi
else
  echo '(base is unknown; no comparison performed)'
  STATUS=1
fi

exit "$STATUS"
