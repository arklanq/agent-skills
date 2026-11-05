#!/usr/bin/env bash
# Read-only evidence for choosing the required status checks of a repository.
# Usage: discover-checks.sh [owner/repo]. Defaults to the repository of the current directory.
# Prints the checks seen on recent pull requests, then every workflow file.
set -uo pipefail

repo="${1:-$(gh repo view --json nameWithOwner --jq .nameWithOwner)}" || exit 2
[ -n "$repo" ] || { echo "Could not resolve the repository." >&2; exit 2; }

# Look at pull requests rather than the default branch: CI often runs only on them,
# so the head of the default branch can carry no checks at all.
prs=$(gh pr list -R "$repo" --state all -L 10 --json number,headRefOid,isDraft \
  --jq '[.[] | select(.isDraft | not)]') || { echo "Could not list pull requests." >&2; exit 2; }
total=$(jq length <<<"$prs")

echo "# Checks on the last $total non-draft pull requests"
if [ "$total" = 0 ]; then
  echo "No pull requests to learn from."
else
  rows=""
  for sha in $(jq -r '.[].headRefOid' <<<"$prs"); do
    runs=$(gh api --paginate "repos/$repo/commits/$sha/check-runs" \
      --jq '.check_runs[] | {name, source: .app.slug, result: (.conclusion // .status), sha: .head_sha}')
    statuses=$(gh api "repos/$repo/commits/$sha/status" \
      --jq '.statuses[]? | {name: .context, source: "commit-status", result: .state}' \
      | jq -c --arg sha "$sha" '. + {sha: $sha}')
    rows+="$runs"$'\n'"$statuses"$'\n'
  done
  jq -s -r --argjson total "$total" '
    group_by(.name)
    | map({
        name: .[0].name,
        source: .[0].source,
        prs: (map(.sha) | unique | length),
        results: (group_by(.result) | map("\(.[0].result)=\(length)") | join(" "))
      })
    | sort_by(-.prs, .name)
    | (["CHECK", "SOURCE", "SEEN_ON_PRS", "RESULTS"] | @tsv),
      (.[] | [.name, .source, "\(.prs)/\($total)", .results] | @tsv)
  ' <<<"$rows"
fi

echo
echo "# Workflows"
states=$(gh api --paginate "repos/$repo/actions/workflows" --jq '.workflows[] | "\(.path)\t\(.state)"' 2>/dev/null)
if [ -z "$states" ]; then
  echo "No workflows."
  exit 0
fi
while IFS=$'\t' read -r path state; do
  echo "--- $path (state: $state)"
  gh api "repos/$repo/contents/$path" --jq .content 2>/dev/null | base64 --decode 2>/dev/null \
    || echo "Could not read this file."
  echo
done <<<"$states"
