#!/usr/bin/env bash
# Waits until a GitHub pull request needs the agent's attention, then prints one result line and exits.
# Run it as a background command whose exit wakes the agent, for example Claude Code Bash with run_in_background: true.
#
# Usage: pr-watch.sh <pr-url> [--interval SECONDS] [--timeout SECONDS]
#
# Result line: pr-watch: <url> -> <result>: <details>
# Results:
#   merged    The pull request was merged.
#   closed    The pull request was closed without merging.
#   ready     Checks passed and it can be merged, but auto-merge is not enabled.
#   failed    A check failed.
#   conflict  The branch has merge conflicts with the base branch.
#   behind    The branch must be updated with the base branch before it can merge.
#   blocked   Checks passed, but merging is blocked, for example by a required review.
#   draft     Checks passed, but the pull request is a draft.
#   timeout   No result before the timeout.
#   error     The pull request could not be read at start.

set -uo pipefail

interval=15
timeout=10800
url=""

usage() {
  echo "Usage: pr-watch.sh <pr-url> [--interval SECONDS] [--timeout SECONDS]" >&2
  exit 2
}

# Reads one tab-separated line from fetch and prints "<result>\t<details>", or nothing while waiting.
classify() {
  local state merge_state draft auto_merge failed pending total
  IFS=$'\t' read -r state merge_state draft auto_merge failed pending total

  case "$state" in
    MERGED) printf 'merged\tmerged\n'; return ;;
    CLOSED) printf 'closed\tclosed without merging\n'; return ;;
  esac

  if [ "$failed" -gt 0 ]; then
    printf 'failed\t%s of %s checks failed\n' "$failed" "$total"
    return
  fi
  case "$merge_state" in
    DIRTY) printf 'conflict\tmerge conflicts with the base branch\n'; return ;;
    BEHIND) printf 'behind\tbranch is behind the base branch and must be updated\n'; return ;;
  esac
  [ "$pending" -gt 0 ] && return

  case "$merge_state" in
    CLEAN | HAS_HOOKS | UNSTABLE)
      # With auto-merge enabled, GitHub merges on its own, so keep waiting for the merge.
      [ "$auto_merge" = "true" ] && return
      printf 'ready\tall %s checks passed and it can be merged; auto-merge is not enabled\n' "$total"
      ;;
    BLOCKED) printf 'blocked\tchecks passed but merging is blocked, for example by a required review\n' ;;
    DRAFT) printf 'draft\tchecks passed but the pull request is a draft\n' ;;
  esac
}

fetch() {
  gh pr view "$url" --json state,mergeStateStatus,isDraft,autoMergeRequest,statusCheckRollup --jq '
    [.statusCheckRollup[]? | if .__typename == "StatusContext"
      then (if .state == "SUCCESS" then "ok" elif .state == "PENDING" or .state == "EXPECTED" then "pending" else "failed" end)
      else (if .status != "COMPLETED" then "pending"
            elif .conclusion == "SUCCESS" or .conclusion == "NEUTRAL" or .conclusion == "SKIPPED" then "ok"
            else "failed" end)
      end] as $c
    | [.state, .mergeStateStatus, (.isDraft | tostring), (.autoMergeRequest != null | tostring),
       ($c | map(select(. == "failed")) | length), ($c | map(select(. == "pending")) | length), ($c | length)]
    | @tsv'
}

main() {
  while [ $# -gt 0 ]; do
    case "$1" in
      --interval) interval="${2:-}"; shift 2 || usage ;;
      --timeout) timeout="${2:-}"; shift 2 || usage ;;
      -h | --help) usage ;;
      -*) usage ;;
      *) [ -n "$url" ] && usage; url="$1"; shift ;;
    esac
  done
  [ -n "$url" ] || usage
  [[ "$interval" =~ ^[0-9]+$ && "$timeout" =~ ^[0-9]+$ ]] || usage

  if ! gh pr view "$url" --json number >/dev/null 2>&1; then
    echo "pr-watch: $url -> error: cannot read the pull request"
    exit 2
  fi

  local deadline=$(($(date +%s) + timeout)) last="" line verdict
  while :; do
    # Network errors, for example right after the Mac wakes up, are skipped until the next poll.
    if line=$(fetch 2>/dev/null) && [ -n "$line" ]; then
      verdict=$(printf '%s\n' "$line" | classify)
      case "$verdict" in
        merged* | closed* | failed* | conflict* | behind*)
          echo "pr-watch: $url -> ${verdict/$'\t'/: }"
          exit 0
          ;;
        "") last="" ;;
        *)
          # Checks may not be registered right after a push, so a waiting-free state must hold for two polls.
          if [ "$verdict" = "$last" ]; then
            echo "pr-watch: $url -> ${verdict/$'\t'/: }"
            exit 0
          fi
          last="$verdict"
          ;;
      esac
    fi
    if [ "$(date +%s)" -ge "$deadline" ]; then
      echo "pr-watch: $url -> timeout: no result after ${timeout}s"
      exit 1
    fi
    sleep "$interval"
  done
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  main "$@"
fi
