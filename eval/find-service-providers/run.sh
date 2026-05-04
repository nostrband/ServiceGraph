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
SKILL="find-service-providers"
QUERIES="queries.json"

case "$SPLIT" in
  train|validation|all) ;;
  *) echo "Unknown split '$SPLIT'. Use train, validation, or all." >&2; exit 2 ;;
esac

command -v claude >/dev/null 2>&1 || { echo "claude CLI not on PATH" >&2; exit 1; }
command -v jq     >/dev/null 2>&1 || { echo "jq not on PATH"          >&2; exit 1; }
[ -f "$QUERIES" ]                  || { echo "$QUERIES not found"      >&2; exit 1; }

# Returns 0 iff Claude Code invoked the Skill tool with our skill name.
# If the JSON shape ever changes, run a single query manually with
#   claude -p "<query>" --output-format json
# and adjust the jq filter below.
check_triggered() {
  local q="$1"
  claude -p "$q" --output-format json 2>/dev/null \
    | jq -e --arg skill "$SKILL" '
        any(.messages[]?.content[]?;
            .type == "tool_use"
            and .name == "Skill"
            and (.input.skill // "") == $skill)
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
