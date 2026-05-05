#!/usr/bin/env bash
# Trigger eval for the find-service-providers skill.
#
# Usage:
#   ./run.sh [train|validation|all] [runs]
#
# Defaults: split=train, runs=3.
#
# Each query in queries.json is fired through the Claude Code CLI; we
# inspect the JSON transcript to see whether the agent invoked the
# Skill tool with skill="find-service-providers". A query passes when
# the trigger rate matches its should_trigger label (>50% of runs for
# positives, ≤50% for negatives).

set -uo pipefail

cd "$(dirname "$0")"

SPLIT="${1:-train}"
RUNS="${2:-3}"
SKILL="find-law-firm"
QUERIES="queries.json"

case "$SPLIT" in
  train|validation|all) ;;
  *) echo "Unknown split '$SPLIT'. Use train, validation, or all." >&2; exit 2 ;;
esac

command -v claude >/dev/null 2>&1 || { echo "claude CLI not on PATH" >&2; exit 1; }
command -v jq     >/dev/null 2>&1 || { echo "jq not on PATH"          >&2; exit 1; }
[ -f "$QUERIES" ]                  || { echo "$QUERIES not found"      >&2; exit 1; }

# Returns 0 iff Claude Code invoked the Skill tool with our skill name.
#
# Why each flag matters:
#   --dangerously-skip-permissions: without it, claude -p blocks on the
#     first tool-call confirmation prompt and the eval never exits. We
#     only inspect the transcript for whether Skill was invoked, so
#     any side-effect tool calls during the run are irrelevant.
#   --output-format stream-json --verbose: the default `json` format
#     emits only the final result message, which usually doesn't
#     contain the Skill tool_use event. stream-json with --verbose
#     emits one NDJSON record per assistant/user turn so we can find
#     the Skill invocation reliably.
#   </dev/null: claude reads stdin in -p mode and would otherwise
#     drain the outer `while read` loop's stdin, killing iteration
#     after the first query.
#
# If the JSON shape ever changes, capture a sample with
#   claude -p "<query>" --output-format stream-json --verbose \
#          --dangerously-skip-permissions </dev/null > sample.ndjson
# and adjust the jq filter below.
check_triggered() {
  local q="$1"
  claude -p "$q" \
      --output-format stream-json --verbose \
      --dangerously-skip-permissions \
      </dev/null 2>/dev/null \
    | jq --slurp -e --arg skill "$SKILL" '
        any(.[];
            .type == "assistant"
            and any(.message.content[]?;
                    .type == "tool_use"
                    and .name == "Skill"
                    and (.input.skill // "") == $skill))
      ' >/dev/null 2>&1
}

printf '%-6s %-5s %-11s %-7s %-5s %s\n' RESULT ID SPLIT TRIG/N RATE QUERY
printf '%-6s %-5s %-11s %-7s %-5s %s\n' "------" "---" "----------" "------" "----" "-----"

pass=0
fail=0
total=0
fail_ids=()

while IFS= read -r row; do
  id=$(jq    -r '.id'             <<<"$row")
  split=$(jq -r '.split'          <<<"$row")
  query=$(jq -r '.query'          <<<"$row")
  label=$(jq -r '.should_trigger' <<<"$row")

  triggers=0
  for _ in $(seq 1 "$RUNS"); do
    if check_triggered "$query"; then
      triggers=$((triggers + 1))
    fi
  done
  rate=$(awk -v t="$triggers" -v r="$RUNS" 'BEGIN{printf "%.2f", t/r}')

  if [ "$triggers" -gt $((RUNS / 2)) ]; then fired=true; else fired=false; fi
  if [ "$fired" = "$label" ]; then
    result=PASS
    pass=$((pass + 1))
  else
    result=FAIL
    fail=$((fail + 1))
    fail_ids+=("$id")
  fi
  total=$((total + 1))

  printf '%-6s %-5s %-11s %-7s %-5s %s\n' \
    "$result" "$id" "$split" "$triggers/$RUNS" "$rate" "$query"
done < <(jq -c --arg s "$SPLIT" '.queries[] | select($s == "all" or .split == $s)' "$QUERIES")

echo
echo "split=$SPLIT  runs_per_query=$RUNS  total=$total  pass=$pass  fail=$fail"
if [ "$fail" -gt 0 ]; then
  echo "failed: ${fail_ids[*]}"
fi
[ "$fail" -eq 0 ]
