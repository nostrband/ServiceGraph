# Trigger eval — `find-service-providers`

A small labeled set of user prompts used to tune the skill's `description`
field for correct triggering. See repo `plan.md` §8 for the rationale.

## Files

- `queries.json` — 20 labeled queries, frozen. Each has an `id`, `query`,
  `should_trigger` (bool), `split` (`train` | `validation`), and `notes`
  on what it tests.
- `run.sh` — runner that fires each query through the Claude Code CLI
  and reports per-query PASS/FAIL plus a tally.

## Split

- **Train (12)**: 6 positives + 6 negatives. The hardest cases (P4, N6, N9)
  live here so iteration on the description has signal.
- **Validation (8)**: 4 positives + 4 negatives. Held aside; only consulted
  to pick the final description.

The split is fixed across iterations so before/after comparisons are valid.

## How to run against Claude Code

Pattern lifted from [agentskills.io](https://agentskills.io/skill-creation/optimizing-descriptions):
fire each query at an agent that has the skill installed, multiple times,
and check whether the agent invoked the skill.

Prereqs:
- Claude Code CLI on `PATH` (`claude --version`).
- `jq` on `PATH`.
- The skill loaded into a directory Claude Code scans. Easiest path:

  ```bash
  mkdir -p ~/.claude/skills
  ln -s "$(pwd)/find-service-providers" ~/.claude/skills/find-service-providers
  ```

  Confirm: open `claude` in any project, type `/skills`, and verify
  `find-service-providers` is listed. (For a project-local install,
  drop the symlink at `.claude/skills/` inside the project instead.)

Then, from the repo root:

```bash
./eval/find-service-providers/run.sh             # train, 3 runs each (default)
./eval/find-service-providers/run.sh train 5     # train, 5 runs each
./eval/find-service-providers/run.sh validation  # validation set
./eval/find-service-providers/run.sh all         # full set
```

The script prints a PASS/FAIL row per query and a tally at the end,
and exits non-zero if any query failed (handy for CI later).

**Workflow**: run on `train` first, iterate the description, only score
`validation` when you're picking the final description.

**Detection caveat**: the script reads Claude Code's NDJSON transcript
(`--output-format stream-json --verbose`) and greps for `assistant`
records whose `message.content` contains a `tool_use` with
`name="Skill"` and `input.skill="find-service-providers"`. If Claude
Code's shape ever changes, the script will silently report 0 triggers
everywhere — sanity-check by running

```bash
claude -p "find me three boutique IP law firms in California" \
  --output-format stream-json --verbose \
  --dangerously-skip-permissions </dev/null \
  | jq -c 'select(.type=="assistant") | .message.content[]? | select(.type=="tool_use") | {name, input_skill: .input.skill}'
```

manually and confirming you see a `{"name":"Skill","input_skill":"find-service-providers"}`
line.

## Interpreting results

A query *passes* if its trigger behavior matches its label:
- `should_trigger: true` → triggered on more than half of the runs.
- `should_trigger: false` → triggered on at most half of the runs.

A run is non-deterministic, so don't over-interpret a single failure.
With `RUNS=3`, treat 0/3 and 1/3 as "didn't fire" and 2/3 / 3/3 as
"fired"; the boundary is fuzzy.

## The optimization loop (recap)

1. Score the current `description` against `train`. Note failures.
2. **False negatives** (should fire, didn't) → broaden the description with
   the missed *concept class*, not the exact failing keyword. Adding
   "even when the user describes the need without naming the service
   category" is generalization; adding "open enrollment" is overfitting.
3. **False positives** (fired when it shouldn't) → tighten the scope or
   add an exclusion clause that rules out the offending shape (consumer
   vs B2B, US vs international, etc.).
4. Re-score on `train`. Repeat 3–5 iterations.
5. When you stop seeing improvements, score every candidate against
   `validation` and pick the description with the best validation pass
   rate. **It may not be the latest iteration** — later edits often
   overfit train.
6. Sanity check: write 5 fresh queries (not in this file), run them, and
   make sure the chosen description still behaves.

When the description changes meaningfully, bump the skill `metadata.version`
in `find-service-providers/SKILL.md` and note the diff in this folder.

## Cost

20 queries × 3 runs ≈ 60 invocations. The agent only needs to *decide*
whether to load the skill — it doesn't have to execute the recipes — so
the dollar cost is small (well under $1 on Sonnet/Haiku tiers). Wall
time depends on parallelism in the runner; sequential is fine at this size.
