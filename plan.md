# Plan — `find-service-providers`

A first-cut Agent Skill that teaches an AI agent how to use the **ServiceGraph
API** (`https://api.servicegraph.co`) to find US professional-services firms
(law, marketing, consulting, accounting, IT services, architecture,
engineering, HR, etc.).

This document is the design doc. Once we agree, I'll write the actual
`find-service-providers/SKILL.md` against it.

## 0. Locked decisions (2026-05-04)

- **Skill / folder name**: `find-service-providers` (task-oriented; matches
  the agentskills.io conventions like `pdf-processing` / `data-analysis`).
- **Auth flow**: read `$SERVICEGRAPH_TOKEN` if set; otherwise the skill
  walks the user through `request-otp` + `verify-otp` (asking the user for
  their email, then the 6-digit code from their inbox). No web token-issuance
  UI yet — comes later.
- **Catalog scale claim**: round (e.g. "100k+ US firms"), not a precise
  count that will drift.
- **License**: `MIT`.
- **No bundled scripts** in v1. Single-file `SKILL.md`.
- **Eval set required before shipping** — see §8.

---

## 1. What the skill is and isn't

**Is**: a single `SKILL.md` that lets an agent answer requests like
*"find me a PR firm in NY"* / *"shortlist three SOC-2-savvy boutique law firms
in California"* / *"compare SEO agencies that serve enterprise clients
nationally"* by driving the public ServiceGraph endpoints.

**Isn't (v1)**:
- A wrapper around an API key the user doesn't have. The skill must work
  partly without auth (explore/check/tags) and explain how to obtain a token
  for the rest.
- A tutorial on the internal pipeline (`vendorclaw`, ClickHouse, Common
  Crawl, classifiers). All of that is invisible to API callers.
- A code library or scripts. Single-file `SKILL.md`, no `scripts/` or
  `references/` for the first cut. We can add those if usage data tells us to.
- A pricing/research guide. `/v1/research` is deferred upstream; we'll add
  it when it ships.

## 2. Skill structure (per agentskills.io spec)

```
find-service-providers/
└── SKILL.md
```

Single file, one level. Stays well under the spec's soft limits (500 lines,
5000 tokens). Frontmatter:

```yaml
---
name: find-service-providers
description: <see §3>
license: MIT
metadata:
  api_base: https://api.servicegraph.co
  version: "0.1"
---
```

`name` must match the folder name and may only contain `[a-z0-9-]`, no
leading/trailing/double hyphens (spec). `find-service-providers` qualifies.

The `compatibility` field is omitted — the skill needs only `curl` (or the
agent's HTTP tool) and standard JSON parsing. Listing that adds noise.

## 3. The `description` field (the most important line we'll write)

Per agentskills' best-practices: imperative, intent-focused, lists trigger
contexts including ones the user wouldn't name explicitly, ≤1024 chars.

Draft:

> Use this skill whenever the user wants to find, shortlist, vet, or research
> US professional-services firms — law firms, marketing agencies,
> consultancies, accounting firms, IT services, architecture, engineering,
> HR/recruiting, PR, design agencies, and similar B2B service providers.
> Triggers on requests like "find me a PPC agency in California", "shortlist
> three boutique IP law firms", "who does Series-A fundraising advisory in
> NYC", "compare SEO agencies that serve enterprise clients", or "build me a
> longlist of 50 mid-size IT consultancies", **even when the user doesn't
> name ServiceGraph**. The skill drives the ServiceGraph HTTP API
> (api.servicegraph.co) — a structured catalog of 100k+ US firms with
> filters for industry, services offered, location, size, ratings, and
> third-party listing presence. Skip for non-US firms, individual
> freelancers without a firm presence, retail/ecommerce/SaaS-product
> companies, or general web research that doesn't need a structured firm
> directory.

Action: I'll iterate this on a small trigger-eval set before locking it
(per agentskills' optimizing-descriptions guide), but this is the v0.

## 4. Body outline

In order, with rationale for each section.

### 4.1 What this API is (≤8 lines)
One-paragraph recap: structured catalog of US pro-services firms, four-tier
funnel (explore → search → get → research-deferred), filter DSL discoverable
via `/v1/tags`. No marketing copy.

### 4.2 The funnel and when to use each tier
A table the agent can pattern-match against:

| Tier | Auth | Cost | When to use |
|---|---|---|---|
| `GET /v1/explore` | none | free, IP-throttled | scoping ("how big is the candidate pool?"), discovering breakdowns before committing quota |
| `GET /v1/check` | none | free | validating a filter string before spending an `/explore` or `/search` call |
| `GET /v1/tags` | none | free | one-time per session: discover legal field names, kinds, operators, values |
| `GET /v1/search` | bearer | 200 unique firms / month free | brief cards (no apex/url/contact) — for ranking and shortlisting |
| `GET /v1/get/:id` | bearer | 50 unique firms / month free | full bundle: url, phone, email, social, legal name, address, pricing — call only on shortlisted firms |
| `POST /v1/research` | paid | deferred | not in MVP — skip |

**The rule the skill drills in**: always burn `/explore` (free) and
`/search` (cheap brief) before `/get` (expensive full bundle). Re-pages and
overlapping queries are free for already-seen firms — the quota is on
*unique* firm views per calendar month.

### 4.3 Quick start (working curl snippets)
Three blocks, copy-pasteable:
1. Anonymous catalog probe (`/v1/explore` with no auth).
2. Get a token: `request-otp` → user reads OTP from email → `verify-otp`
   returns a `vk_…` bearer. Note that the token is shown once.
3. First authed search.

**Auth-resolution rule the body teaches the agent**:
1. If `$SERVICEGRAPH_TOKEN` is set in the environment, use it directly. Skip
   the OTP dance.
2. Otherwise, before any /search or /get call: ask the user for their email
   address, POST it to `/v1/auth/request-otp`, ask the user to paste the
   6-digit code that just landed in their inbox, POST email+code to
   `/v1/auth/verify-otp`, capture the returned `vk_…` token for the rest of
   the session.
3. Tell the user "this token is shown once — save it as `SERVICEGRAPH_TOKEN`
   in your shell rc to skip this next time." That's the only secrets
   guidance the skill gives; we don't try to prescribe per-harness storage.

### 4.4 Filter DSL — the heart of the skill
Verbatim grammar block (same one the API exposes at `/v1/dsl`):
```
filter   := orExpr
orExpr   := andExpr ("OR" andExpr)*
andExpr  := notExpr (("AND")? notExpr)*    # whitespace = implicit AND
notExpr  := ("NOT" | "-") notExpr | atom
atom     := "(" filter ")" | predicate
predicate:= IDENT op valueOrList | bareword
op       := ":" | "=" | ">=" | "<=" | ">" | "<"
valueOrList := value ("," value)*
value    := IDENT | NUMBER | tagAtEvidence
tagAtEvidence := IDENT "@" ("low"|"medium"|"high")
bareword := IDENT | NUMBER          # → keyword:<bareword>
```

Then the four rules that bite:
1. AND binds tighter than OR — use `( ... )` to override.
2. `-x` / `NOT x` for negation; **negative literals in lists are not
   supported** (`state:CA,-NY` is rejected — write `state:CA -state:NY`).
3. Comma-list = OR scoped to one predicate (`state:CA,NY,TX`).
4. Bareword = keyword search across name/brand/title/meta/legal_name.

Worked examples (lifted from the API's own docs page so they match what
`/v1/check` accepts):
```
industry:marketing_agency service_provided:seo
dental industry:marketing_agency
industry:legal state:CA,NY -company_size_signal:solo
industry:management_consulting (service_provided:strategy-consulting@high OR service_provided:operations-consulting@high)
state:CA has:phone has:email
rating>=4 review_count_total>=20 has:clutch
industry:it_services NOT (service_provided:web-development OR service_provided:hosting)
```

### 4.5 Field discovery — the agent's session-start ritual
The skill instructs: **first call of every session, hit
`GET /v1/tags?include_values=1`** and cache the result for the conversation.
Don't memorize industry / service tag enums in this file; they'll drift.
Memorize the *kinds* (categorical / tag_set_with_evidence / numeric /
presence / keyword) and the operators each takes. Concrete values come from
`/tags`.

This is the single most important "do this first" rule — it's why the body
has a whole section for it.

### 4.6 firm_id contract
```
firm_id = sha256(apex.lower().rstrip(".")).hexdigest()[:12]
```
Documented so an agent that already has an apex list (BYO procurement
sourcing) can call `/v1/get/:id` directly without `/search`. One example
in three languages (Python, Node, shell+openssl).

### 4.7 Recipes — the meat
A short library of complete query patterns the agent can adapt. Each is
filter + the natural-language ask it answers. Keep these grounded in
real-looking asks, not toy examples.

- **Shortlist by industry + state + size** — "boutique IP law firms in NY"
- **Multi-tag service intersection** — "SEO + content marketing agencies
  with high evidence on both"
- **Negation** — "marketing agencies that aren't SEO-only" (`industry:marketing_agency -service_provided:seo`)
- **Quality threshold** — "consultancies with ≥4★ from ≥20 reviews and a
  Clutch profile"
- **Keyword + structure** — "HIPAA-conversant IT consultancies in TX"
  (`hipaa industry:it_services state:TX`)
- **Geographic scope** — "national-US accounting firms" (`industry:accounting_tax geography_served:national_US`)
- **BYO apex enrichment** — given a list of domains, hash to firm_ids and
  /get/ each (with the quota budgeting note)

Each recipe ends with a one-line "what to do with the result" — usually:
take top-N briefs, present to the user for confirmation, then `/get` on
their selections to surface contact info.

### 4.8 Quota and rate-limit awareness (gotchas section)
Per agentskills' best-practices, gotchas are the highest-value content. A
short list of things the agent will get wrong without being told:

- **`/get/:id` charges only on first view per calendar month per user.**
  Re-fetching a firm the user already pulled this month is free; the agent
  shouldn't refuse to look up "to save quota" if the firm was already seen.
- **`/search` charges per *new* firm in the response, not per call.**
  Pagination through the same filter is free. Two different filters that
  return overlapping firms charge once for the overlap.
- **`/v1/explore` suppresses breakdowns when count < 20** ("k=20"). If
  `count: "<20"` comes back, broaden the filter, don't drill harder.
- **Negative comma-list is invalid** (covered in §4.4 but repeated here as
  a gotcha because models will try it).
- **The internal flag `looks_not_pro_services` causes 404 on /get/** —
  if a `firm_id` round-trips through search → get and gets 404, that's
  expected; it's not charged. The agent should treat it as "firm filtered
  out, skip and continue."
- **Always use `/v1/tags` for field/value names**, never invent tags.
  Hallucinating `industry:law` instead of `industry:legal` will silently
  return zero results — the parser accepts unknown values for categorical
  fields.
- **Brief responses do not include `apex`, `url`, `phone_primary`,
  `email_primary`, `legal_name`, or address.** If the user asks for
  contact info, the agent must call `/get/:id`. Don't try to scrape the
  brief for an email.
- **Keyword search is substring, not full-text.** Multi-word phrases must
  be split into separate barewords (which AND).
- **The skill is US-only.** International firms aren't in the catalog;
  refuse the request rather than returning misleading partial matches.

### 4.9 Error handling (short)
The shape is always `{ "error": { "code": "...", "message": "..." } }`.
Common codes the agent should handle distinctly:
- `filter_parse_error` (400, `position` field on payload) — fix the filter
- `filter_required` (400) — empty filter where one is required
- `unauthorized` (401) — re-prompt for token
- `rate_limited` (429, `Retry-After` header / `retry_after` field) — back off
- `monthly_quota_exhausted` (429) — switch to /explore-only mode for the
  rest of the month
- `not_found` (404) — firm not in catalog; not charged; skip and continue

### 4.10 Example end-to-end conversation (one block)
A condensed transcript of "find me three top management-consulting firms in
California with strategy-consulting at high evidence and ≥4★ rating." Shows
the full tags → check → explore → search → get pipeline with realistic
quota counters.

## 5. What we deliberately leave OUT

- `/v1/research` — deferred upstream; will appear in v0.2.
- Brave-source internals (`pilot_10pct_*` source tags, etc.) — agents only
  need the public surface (`has:clutch`, `rating`, `founded_year`).
- Internal scores (`hc_pos`, `is_pro_score`, `facet_confidence`) — none of
  these are exposed publicly; mentioning them invites hallucination.
- ClickHouse / SQL / `/firm/{apex}` / pipeline scripts — internal API only.
- Specific industry/service enum values — those live in `/v1/tags`, not in
  the skill. We mention only enough examples to make the DSL clear.
- Token storage best-practices beyond "use $SERVICEGRAPH_TOKEN if set."
  Different agent harnesses handle secrets differently; we don't try to
  prescribe.

Per agentskills best-practices: "ask whether the agent would get this wrong
without the skill — if no, cut it." The above all fail that test.

## 6. Open questions

All resolved in §0. Nothing outstanding for v0.1 except the eval set
(§8 below).

## 7. Build order

1. Build the trigger-eval set per §8 (with you, before SKILL.md exists —
   the description is what we're tuning, so we need targets first).
2. Write `find-service-providers/SKILL.md` per §3 + §4.
3. Validate frontmatter against the spec (`skills-ref validate
   ./find-service-providers` if installed, else manual check against the
   field constraints).
4. Run the eval: load the skill, fire each query a few times, check
   triggering. Fix description if the train-set numbers say to.
5. Smoke-test the body: pick 2-3 should-trigger queries and run the
   recipes end-to-end against the live API; watch for misuse of /get
   without /search, missed /tags-first ritual, etc.
6. Commit. Future passes can add `references/` (e.g. a frozen tag
   snapshot for offline reasoning) or `scripts/` if real usage demands.

## 8. Trigger-eval — what it is, how it works

The point of the eval: the *one thing* an agent decides about a skill
based purely on its `description` field is **"should I activate this skill
for the current user prompt?"** A correctly-triggering skill is gold; a
miss-firing one is dead weight (or worse, hijacks the agent's context).
We tune the description to maximize correct activations.

### How it works mechanically

1. **Build a query set** — ~20 realistic user prompts, each labeled with
   `should_trigger: true|false`.
   - Roughly half positive (skill SHOULD fire) and half negative (skill
     should NOT fire).
   - Phrasing varied: formal, casual, with typos, terse vs context-heavy.
   - The most useful positives are ones that don't name the domain
     directly ("my boss wants three vendors who can run our open enrollment
     comms" should fire even though "HR consulting" isn't said).
   - The most useful negatives are **near-misses** — prompts that share
     keywords but actually need something else. ("Update my Excel formulas"
     vs "find me an Excel-savvy bookkeeping firm".)

2. **Split the set 60/40** into a *train* set and a *validation* set.
   Each split holds proportional positives and negatives. Train guides
   our description edits; validation is held aside and only used to
   confirm an edit generalizes (prevents us from overfitting to specific
   wording).

3. **Run the eval**:
   - Install the skill in a host that supports the spec (Claude Code is
     fine — same host the user will use).
   - For each query in the set, send it to the agent ~3 times (model
     output is non-deterministic, so we measure a *rate*, not a
     binary).
   - Watch tool calls / logs to see whether the agent invoked the skill
     (i.e. called the Skill tool with `find-service-providers`).
   - Compute `trigger_rate = times_triggered / runs` per query. Above
     ~0.5 = "fired"; below = "did not fire".
   - A query *passes* if its trigger behavior matches its label.

4. **Iterate the description**:
   - Look only at *train* failures.
   - False negatives (should fire but didn't) → broaden, add the missed
     concept-class (not the exact failing keyword — that's overfitting).
   - False positives (fired when it shouldn't) → add a clearer
     scope/exclusion clause.
   - Re-run on train. Repeat ~3-5 iterations.
   - At the end, score each candidate description against the
     *validation* set. Pick the description with the best validation
     pass-rate — not necessarily the most-iterated one.

5. **Sanity check** with 5-10 fresh queries the eval never saw, to
   confirm the final description generalizes.

### Concrete shape we'll produce

Eval scaffolding lives at the repo root under `eval/<skill-name>/`, so
future skills in this repo each get their own eval folder without
polluting the shipped skill directory:

```
eval/
└── find-service-providers/
    ├── queries.json       # labeled set, ~20 queries
    └── README.md          # how to run against Claude Code or other host
```

The shipped skill folder (`find-service-providers/`) stays clean —
only `SKILL.md` ships with the skill.

### Cost

20 queries × 3 runs each = 60 model invocations of whatever host you're
testing in. With Claude Code on Sonnet 4.6 / Haiku 4.5 the dollar cost is
small (<$1 for triggering checks, since the model only needs to read
descriptions and decide; it doesn't have to execute the recipes). Wall
time depends on how parallelizable your runner is — sequential is fine
at this size, ~10-15 min.

### What we'll do next

I won't draft queries unilaterally. Once you confirm the approach, I'll
propose a candidate set of 20 — 10 should-trigger and 10 should-not-
trigger — and you'll sanity-check that the asks reflect *real* user
phrasings (you know the audience better than I do). Then we lock the
set, write `SKILL.md`, run the eval, iterate the description.

### Results

| Version | Train (12) | Validation (8) | Notes |
|---|---|---|---|
| v0.1 | 10 / 12 | — | P9 (BYO enrichment) and N6 (consumer legal) failed. |
| **v0.2** | **12 / 12** | **8 / 8** | Added `enrich` verb + BYO-domain trigger example for P9; sharpened consumer-services exclusion for N6. **Locked.** |
