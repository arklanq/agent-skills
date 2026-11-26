#!/usr/bin/env bash
# Waits until items change in the watched Status columns of a GitHub Project board, then prints the changes and exits.
# Run it as a background command whose exit wakes the agent, for example Claude Code Bash with run_in_background: true.
#
# Usage: board-watch.sh <owner> <project-number> [--status "Ready,In progress"] [--state-file PATH]
#                       [--interval SECONDS] [--timeout SECONDS]
#
# A change is an item that enters, leaves or moves between the watched columns. Reordering cards is not a change.
# With --state-file, the baseline is the snapshot the previous run saved there, so changes made while the agent
# was busy are reported right away. Without it, or when the file does not exist yet, the baseline is the board
# at start. Each change report saves the new snapshot to the file.
#
# Output: board-watch: <owner>/<number> -> <result>: <details>, then one line per change:
#   added   <status> #<number> <title>
#   moved   <old status> -> <new status> #<number> <title>
#   removed <old status> #<number> <title>
# Results:
#   changed  Items changed in the watched columns.
#   timeout  No change before the timeout.
#   error    The board could not be read at start.

set -uo pipefail

interval=15
timeout=10800
statuses="Ready,In progress"
state_file=""
owner=""
number=""

usage() {
  echo "Usage: board-watch.sh <owner> <project-number> [--status LIST] [--state-file PATH] [--interval SECONDS] [--timeout SECONDS]" >&2
  exit 2
}

# Prints one "<key>\t<status>\t#<number> <title>" line per item in the watched columns, sorted by key.
# The key is the issue or pull request URL, or the item ID for draft items.
fetch() {
  gh project item-list "$number" --owner "$owner" --limit 1000 --format json |
    jq -r --arg statuses "$statuses" '
      ($statuses | split(",") | map(gsub("^ +| +$"; ""))) as $watched
      | .items[]
      | select(.status as $s | $watched | index($s))
      | [(.content.url // .id), .status,
         ((if .content.number then "#\(.content.number) " else "" end) + (.content.title // .title // ""))]
      | @tsv' |
    LC_ALL=C sort
}

# Compares two snapshots and prints one line per change, in the order of the new snapshot.
diff_snapshots() {
  awk -F '\t' '
    FILENAME == ARGV[1] { old[$1] = $2; title[$1] = $3; next }
    {
      seen[$1] = 1
      if (!($1 in old)) printf "added   %s %s\n", $2, $3
      else if (old[$1] != $2) printf "moved   %s -> %s %s\n", old[$1], $2, $3
    }
    END { for (k in old) if (!(k in seen)) printf "removed %s %s\n", old[k], title[k] }
  ' "$1" "$2"
}

main() {
  while [ $# -gt 0 ]; do
    case "$1" in
      --status) statuses="${2:-}"; shift 2 || usage ;;
      --state-file) state_file="${2:-}"; shift 2 || usage ;;
      --interval) interval="${2:-}"; shift 2 || usage ;;
      --timeout) timeout="${2:-}"; shift 2 || usage ;;
      -h | --help) usage ;;
      -*) usage ;;
      *)
        if [ -z "$owner" ]; then owner="$1"
        elif [ -z "$number" ]; then number="$1"
        else usage; fi
        shift
        ;;
    esac
  done
  [ -n "$owner" ] && [[ "$number" =~ ^[1-9][0-9]*$ ]] || usage
  [[ "$interval" =~ ^[1-9][0-9]*$ && "$timeout" =~ ^[0-9]+$ ]] && [ -n "$statuses" ] || usage

  local board="$owner/$number" tmp base current changes
  tmp=$(mktemp -d) || exit 2
  trap 'rm -rf "$tmp"' EXIT
  base="$tmp/base"
  current="$tmp/current"

  if ! fetch >"$current" 2>/dev/null; then
    echo "board-watch: $board -> error: cannot read the project board"
    exit 2
  fi
  if [ -n "$state_file" ] && [ -f "$state_file" ]; then
    cp "$state_file" "$base"
  else
    cp "$current" "$base"
    [ -n "$state_file" ] && cp "$current" "$state_file"
  fi

  local deadline=$(($(date +%s) + timeout))
  while :; do
    changes=$(diff_snapshots "$base" "$current")
    if [ -n "$changes" ]; then
      [ -n "$state_file" ] && cp "$current" "$state_file"
      echo "board-watch: $board -> changed: $(printf '%s\n' "$changes" | wc -l | tr -d ' ') item(s) in $statuses"
      printf '%s\n' "$changes"
      exit 0
    fi
    if [ "$(date +%s)" -ge "$deadline" ]; then
      echo "board-watch: $board -> timeout: no change after ${timeout}s"
      exit 1
    fi
    sleep "$interval"
    # Network errors, for example right after the Mac wakes up, keep the last snapshot until the next poll.
    fetch >"$tmp/next" 2>/dev/null && mv "$tmp/next" "$current"
  done
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  main "$@"
fi
