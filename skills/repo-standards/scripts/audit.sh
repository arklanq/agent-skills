#!/usr/bin/env bash
# Read-only audit of a GitHub repository against the repo standards.
# Usage: audit.sh [owner/repo]. Defaults to the repository of the current directory.
# Output: tab-separated lines of STATUS, check, expected, actual, where STATUS is
# PASS, FAIL, UNKNOWN (could not read), REVIEW (needs the check analysis) or NOTE.
set -uo pipefail

repo="${1:-$(gh repo view --json nameWithOwner --jq .nameWithOwner)}" || exit 2
[ -n "$repo" ] || { echo "Could not resolve the repository." >&2; exit 2; }

emit() { printf '%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4"; }

# Compares a jq expression against an expected value. A null means the token cannot
# see the field, usually because it lacks admin access, which is not a failure.
expect() { # json, check, jq expression, expected
  local actual
  actual=$(jq -r "$3 | tostring" <<<"$1")
  if [ "$actual" = "null" ]; then
    emit UNKNOWN "$2" "$4" "not visible to this token"
  elif [ "$actual" = "$4" ]; then
    emit PASS "$2" "$4" "$actual"
  else
    emit FAIL "$2" "$4" "$actual"
  fi
}

# Requiring a pull request ends direct pushes, so the user should know if they rely on them.
note_direct_pushes() {
  local shas sha prs total=0 direct=0
  shas=$(gh api "repos/$repo/commits?per_page=10" --jq '.[].sha' 2>/dev/null) || return 0
  for sha in $shas; do
    prs=$(gh api "repos/$repo/commits/$sha/pulls" --jq length 2>/dev/null) || continue
    total=$((total + 1))
    [ "$prs" = 0 ] && direct=$((direct + 1))
  done
  [ "$direct" != 0 ] && emit NOTE "Recent default branch commits without a pull request" "0" "$direct of $total"
  return 0
}

settings=$(gh api "repos/$repo") || { echo "Could not read repos/$repo." >&2; exit 2; }

echo "# Repository: $repo ($(jq -r .visibility <<<"$settings"), admin: $(jq -r .permissions.admin <<<"$settings"))"
echo "# Settings"
expect "$settings" "Default branch" .default_branch main
expect "$settings" "Automatically delete head branches" .delete_branch_on_merge true
expect "$settings" "Allow auto-merge" .allow_auto_merge true
expect "$settings" "Allow rebase merging" .allow_rebase_merge true
expect "$settings" "Allow squash merging" .allow_squash_merge true
expect "$settings" "Squash default commit title" .squash_merge_commit_title PR_TITLE
expect "$settings" "Squash default commit message" .squash_merge_commit_message BLANK
expect "$settings" "Allow merge commits" .allow_merge_commit true
expect "$settings" "Merge default commit title" .merge_commit_title PR_TITLE
expect "$settings" "Merge default commit message" .merge_commit_message BLANK

echo "# Ruleset: main branch protection"
if ! list=$(gh api --paginate "repos/$repo/rulesets?includes_parents=true" 2>&1); then
  # Private repositories on the Free plan answer 403 here.
  emit UNKNOWN "Ruleset" "main branch protection" "$(tr '\n' ' ' <<<"$list")"
  exit 0
fi
ids=$(jq -s -r 'add // [] | .[] | select(.name == "main branch protection") | .id' <<<"$list")
if [ -z "$ids" ]; then
  emit FAIL "Ruleset exists" "main branch protection" "missing"
  other=$(jq -s -r 'add // [] | map(.name) | join(", ")' <<<"$list")
  [ -n "$other" ] && emit NOTE "Other rulesets" "-" "$other"
  emit REVIEW "Required status checks" "from discover-checks.sh" "no ruleset"
  note_direct_pushes
  exit 0
fi

for id in $ids; do
  rs=$(gh api "repos/$repo/rulesets/$id") || { emit UNKNOWN "Ruleset $id" "readable" "request failed"; continue; }
  echo "# Ruleset id $id, source: $(jq -r '.source_type + " " + .source' <<<"$rs")"
  emit PASS "Ruleset exists" "main branch protection" "found"
  expect "$rs" "Enforcement" .enforcement active
  expect "$rs" "Target" .target branch
  expect "$rs" "Branch targeting: include" '.conditions.ref_name.include | join(",")' "~DEFAULT_BRANCH"
  expect "$rs" "Branch targeting: exclude" '.conditions.ref_name.exclude | length' 0
  for pair in "deletion:Restrict deletions" "non_fast_forward:Block force pushes" "pull_request:Require a pull request"; do
    type=${pair%%:*}
    expect "$rs" "${pair#*:}" "any(.rules[]; .type == \"$type\")" true
  done

  checks=$(jq -c '[.rules[] | select(.type == "required_status_checks")][0].parameters // empty' <<<"$rs")
  if [ -z "$checks" ]; then
    emit REVIEW "Required status checks" "from discover-checks.sh" "rule absent"
  else
    emit REVIEW "Required status checks" "from discover-checks.sh" \
      "$(jq -r '[.required_status_checks[].context] | join(",")' <<<"$checks")"
    expect "$checks" "Require branches to be up to date" .strict_required_status_checks_policy true
  fi

  jq -e 'any(.rules[]; .type == "pull_request")' <<<"$rs" >/dev/null || note_direct_pushes

  # Not part of the standard, but each can undermine it.
  methods=$(jq -r '[.rules[] | select(.type == "pull_request").parameters.allowed_merge_methods // [] | .[]] | sort | join(",")' <<<"$rs")
  [ -n "$methods" ] && [ "$methods" != "merge,rebase,squash" ] && \
    emit NOTE "Ruleset limits merge methods" "merge,rebase,squash" "$methods"
  bypass=$(jq -r '.bypass_actors // [] | length' <<<"$rs")
  [ "$bypass" != 0 ] && emit NOTE "Bypass actors can skip the ruleset" "0" "$bypass"
  approvals=$(jq -r '[.rules[] | select(.type == "pull_request").parameters.required_approving_review_count // 0][0] // 0' <<<"$rs")
  [ "$approvals" != 0 ] && emit NOTE "Required approvals" "0" "$approvals"
done
exit 0
