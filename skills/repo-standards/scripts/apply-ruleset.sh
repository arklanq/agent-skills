#!/usr/bin/env bash
# Creates or updates the "main branch protection" ruleset. Prints the planned request
# and changes nothing unless --apply is passed.
# Usage: apply-ruleset.sh <owner/repo> (--check <context>... | --no-status-checks) [--apply]
# Rules and bypass actors outside the standard are kept as they are.
set -euo pipefail

usage() { echo "Usage: apply-ruleset.sh <owner/repo> (--check <context>... | --no-status-checks) [--apply]" >&2; exit 2; }

[ $# -ge 2 ] || usage
repo=$1; shift
apply=false; no_checks=false; contexts=()
while [ $# -gt 0 ]; do
  case $1 in
    --check) [ $# -ge 2 ] || usage; contexts+=("$2"); shift 2 ;;
    --no-status-checks) no_checks=true; shift ;;
    --apply) apply=true; shift ;;
    *) usage ;;
  esac
done
# Exactly one of the two modes, so a forgotten argument cannot silently drop the checks.
if { $no_checks && [ ${#contexts[@]} -gt 0 ]; } || { ! $no_checks && [ ${#contexts[@]} -eq 0 ]; }; then usage; fi

checks_json=$(printf '%s\n' ${contexts[@]+"${contexts[@]}"} | jq -R 'select(length > 0)' | jq -s .)

# Names are only unique within a source, so ignore a same-named organization ruleset here.
id=$(gh api --paginate "repos/$repo/rulesets?includes_parents=false" \
  --jq '.[] | select(.name == "main branch protection") | .id' | head -n 1)
existing='{}'
[ -n "$id" ] && existing=$(gh api "repos/$repo/rulesets/$id")

body=$(jq -n --argjson existing "$existing" --argjson checks "$checks_json" --argjson no_checks "$no_checks" '
  ($existing.rules // []) as $rules
  | def find($type): [$rules[] | select(.type == $type)][0];
  ($rules | map(select(.type | IN("deletion", "non_fast_forward", "pull_request", "required_status_checks") | not))) as $others
  | (find("pull_request") // {
      type: "pull_request",
      parameters: {
        required_approving_review_count: 0,
        dismiss_stale_reviews_on_push: false,
        require_code_owner_review: false,
        require_last_push_approval: false,
        required_review_thread_resolution: false,
        allowed_merge_methods: ["squash", "merge", "rebase"]
      }
    }) as $pull_request
  | (find("required_status_checks").parameters // {}) as $current
  | ($current.required_status_checks // []) as $current_checks
  | {
      name: "main branch protection",
      target: "branch",
      enforcement: "active",
      bypass_actors: ($existing.bypass_actors // []),
      conditions: {ref_name: {include: ["~DEFAULT_BRANCH"], exclude: []}},
      rules: (
        [{type: "deletion"}, {type: "non_fast_forward"}, $pull_request]
        + (if $no_checks then [] else [{
            type: "required_status_checks",
            parameters: {
              strict_required_status_checks_policy: true,
              do_not_enforce_on_create: ($current.do_not_enforce_on_create // false),
              # Keep the app a check is pinned to when the same check stays required.
              required_status_checks: ($checks | map(. as $c | ([$current_checks[] | select(.context == $c)][0] // {context: $c})))
            }
          }] end)
        + $others
      )
    }')

if [ -n "$id" ]; then method=PUT; path="repos/$repo/rulesets/$id"; else method=POST; path="repos/$repo/rulesets"; fi

if ! $apply; then
  echo "# Dry run: $method $path"
  jq . <<<"$body"
  exit 0
fi

gh api -X "$method" "$path" --input - <<<"$body" --jq '"Ruleset \(.id) saved: \(._links.html.href)"'
