---
name: find-management-consultant
description: Use whenever the user wants to find, shortlist, vet, or enrich US management consultancies — strategy, operations, executive coaching, leadership development, org-development/change management, PMO/program management, sales/revenue operations consulting. Triggers on "find me three top strategy consultancies in California", "shortlist boutique ops-consulting firms with healthcare experience", "we need an executive coach for our new CEO", or "pull contact info for these 10 consulting firm domains", even when described indirectly (post-merger integration help, change-management partner, fractional COO). Drives the ServiceGraph API (api.servicegraph.co) — a 100k+ US firm catalog filterable by industry, services, location, size, ratings. Skip in-house strategy hires, "help me build a strategy" do-the-work asks, framework comparisons (Lean vs Agile, BCG matrix, etc.), academic/MBA-program questions, life/career coaching for individuals, non-US firms, individual freelancers.
license: MIT
metadata:
  api_base: https://api.servicegraph.co
  industry: management_consulting
  version: "0.2"
---

# find-management-consultant

Drive the **ServiceGraph API** (`https://api.servicegraph.co`) to find,
shortlist, and enrich US management consulting firms. The catalog
tags firms with `industry:management_consulting` and a 7-tag service
sub-taxonomy: strategy, operations, executive-coaching,
leadership-development, organizational-development, pmo-project-management, sales-revenue-consulting.

**Always pin `industry:management_consulting`.** Sub-services are
structured `service_provided` tags (`strategy-consulting`,
`operations-consulting`, `executive-coaching`,
`leadership-development`, `organizational-development`,
`pmo-project-management`, `sales-revenue-consulting` — confirm exact
names via `/v1/tags`).

Any HTTP client works (curl, fetch, requests). Examples below use curl.

## When NOT to use this skill

- "Help me build a strategy / write a plan / make a recommendation" —
  that's do-the-work, not procurement.
- In-house strategy/operations hires (Chief Strategy Officer, COO).
- **Life or career coaching for an individual** — the catalog's
  executive-coaching tag is for B2B (the firm hires the coach for
  their executives), not for the user themselves.
- Framework explanations (Lean vs Agile, Porter's Five Forces, etc.).
- MBA program questions, academic research.
- Non-US firms.
- Individual freelance consultants ("a freelance strategy consultant").

If the user is a *business* procuring consulting services, this skill
applies — defaults to fire on B2B procurement intent.

## The four-tier funnel

| Tier | Auth | Cost | Use it for |
|---|---|---|---|
| `GET /v1/tags` | none | free | **First call of every session.** Discover legal field names, kinds, operators, values. |
| `GET /v1/check?filter=...` | none | free | Validate a filter before spending an explore/search call. |
| `GET /v1/explore?filter=...` | none | free, IP-throttled | Scope: count + breakdowns. Use to size the candidate pool before quota-spending. |
| `GET /v1/search?filter=...` | bearer | 200 unique firms / month free | Brief firm cards. **No url, no contact info.** Use for ranking / shortlisting. |
| `GET /v1/get/:id` | bearer | 50 unique firms / month free | Full bundle: url, phone, email, social, legal name, address. **Only call for shortlisted firms.** |
| `POST /v1/research` | paid | not in MVP | Deferred — skip. |

**Quota rule that matters**: `/search` and `/get` charge per *unique
firm viewed per calendar month*, not per call. Re-paging the same
query is free. Two different filters that overlap charge once for
the overlap. Re-fetching a firm you already pulled this month is free.

## Session-start ritual

Before constructing any filter, call:

```
GET https://api.servicegraph.co/v1/tags?include_values=1
```

Cache the response for the conversation. Confirm
`management_consulting` is in the `industry` value list and that the
relevant sub-service tags (`strategy-consulting`,
`operations-consulting`, `executive-coaching`, etc.) are in
`service_provided`.

Field kinds you'll use most:
- **categorical**: `industry` (always `management_consulting`), `state`, `pricing_model`, `company_size_signal`, `geography_served` — op `:`
- **tag_set_with_evidence**: `service_provided` — Map<tag, evidence∈{low,medium,high}>. Op `:` with optional `@evidence`
- **numeric**: `rating`, `review_count_total`, `founded_year` — ops `= >= <= > <`
- **presence**: `has:phone`, `has:clutch`, `has:rating`, `has:linkedin_company`, …
- **keyword**: free-text substring across firm name / brand / title / meta / legal_name. Bareword in the filter becomes a keyword.

## Auth

`/tags`, `/check`, and `/explore` are anonymous. `/search` and `/get`
require a bearer token.

**Security model — keep the token out of the LLM context.**

- **Never** read `.env`, `.env.local`, or any other credential file
  into your context. The token's literal value should never appear
  in the conversation.
- Use shell dispatch for every authed request so the token flows
  directly from the user's environment / dotenv file into the
  `Authorization` header without round-tripping through the LLM.
- **Always ask the user once per session** before using a detected
  token, even if it's already in their shell or `.env.local`.

**Resolution rule**:

1. **Detect** whether a token is available — without reading its
   value. Run a shell check that only inspects exit codes:

   ```bash
   ( [ -n "${SERVICEGRAPH_TOKEN:-}" ] \
     || grep -qs '^SERVICEGRAPH_TOKEN=' .env.local \
     || grep -qs '^SERVICEGRAPH_TOKEN=' .env )
   ```

   Exit code `0` = token is available somewhere; non-zero = no token.

2. **Confirm with the user** before the first authed call this session:

   > "I found a `SERVICEGRAPH_TOKEN` in your environment / `.env.local`.
   > OK to use it for ServiceGraph API requests this session?"

   If the user says no, stay on the anonymous tiers (`/tags`, `/check`,
   `/explore`) and skip authed calls. Don't re-ask later unless the
   user asks for authed work.

3. **Dispatch via shell** — every authed call goes through a shell
   wrapper so the literal token never enters the conversation:

   ```bash
   # If exported in the shell environment:
   curl -H "Authorization: Bearer $SERVICEGRAPH_TOKEN" \
        'https://api.servicegraph.co/v1/search?filter=...'

   # If in .env.local — source it inside a subshell so it doesn't
   # leak into the parent shell either:
   ( set -a; . ./.env.local; set +a;
     curl -H "Authorization: Bearer $SERVICEGRAPH_TOKEN" \
          'https://api.servicegraph.co/v1/search?filter=...' )
   ```

   Capture the response body to a tmp file or jq-process it, but do
   NOT echo the request command with the token expanded.

4. **OTP flow** if no token is detected — capture the new token
   directly into `.env.local` without surfacing its value to the LLM:

   ```bash
   # 1. trigger the email — agent prompts the user for $EMAIL
   curl -fsS -X POST 'https://api.servicegraph.co/v1/auth/request-otp' \
     -H 'Content-Type: application/json' \
     -d "{\"email\":\"$EMAIL\"}"

   # 2. exchange the code — agent prompts the user for $CODE.
   #    The ?format=env query param returns SERVICEGRAPH_TOKEN=<token>
   #    as plain text appended to .env.local — no jq needed. The -f
   #    flag makes curl exit non-zero on 4xx so a wrong code doesn't
   #    pollute the file (the error mirror is also a `# comment` line,
   #    safe to ignore even if it lands).
   curl -fsS -X POST 'https://api.servicegraph.co/v1/auth/verify-otp?format=env' \
     -H 'Content-Type: application/json' \
     -d "{\"email\":\"$EMAIL\",\"code\":\"$CODE\",\"name\":\"claude-cli\"}" \
     >> .env.local

   # 3. confirm capture without revealing the value
   grep -q '^SERVICEGRAPH_TOKEN=' .env.local && echo "OTP token captured."
   ```

   After a successful capture, the user has implicitly consented
   (they just completed the flow), so proceed to dispatch (step 3).
   The token is now persistent in `.env.local` for future sessions.

5. If a `/search` or `/get` returns `401 unauthorized` mid-session,
   the token expired or was revoked — re-run the OTP flow.

## Filter DSL

One query parameter, GitHub-search-style.

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

**Four rules that bite:**

1. **AND binds tighter than OR.** `a OR b c` parses as `a OR (b AND c)`.
   Use parens.
2. **Comma list = OR within one predicate.** `state:CA,NY,TX` matches
   any of the three.
3. **Negation is `-x` or `NOT x`.** Negative literals inside a comma
   list are **not** allowed: `state:CA,-NY` is rejected. Use
   `state:CA -state:NY`.
4. **Bareword = keyword search.** Any IDENT or NUMBER not followed by
   an operator becomes a free-text substring across name / brand /
   title / meta / legal_name. Multiple barewords AND.

**Management-consulting examples** (validate yours with `/v1/check`):

```
industry:management_consulting service_provided:strategy-consulting@high
industry:management_consulting service_provided:operations-consulting state:NY
industry:management_consulting service_provided:executive-coaching
industry:management_consulting (service_provided:strategy-consulting@high OR service_provided:operations-consulting@high)
industry:management_consulting service_provided:organizational-development change
industry:management_consulting service_provided:strategy-consulting@high rating>=4 has:clutch
industry:management_consulting service_provided:pmo-project-management
```

When in doubt, hit `/v1/check?filter=...` first.

**Sub-service tag → typical user phrasing**:

| User asks for | Tag |
|---|---|
| Strategy / strategic planning | `service_provided:strategy-consulting` |
| Operations / ops consulting | `service_provided:operations-consulting` |
| Executive coach (for senior leaders) | `service_provided:executive-coaching` |
| Leadership development programs | `service_provided:leadership-development` |
| Org design / change management | `service_provided:organizational-development` |
| PMO / program management | `service_provided:pmo-project-management` |
| Sales/revenue ops | `service_provided:sales-revenue-consulting` |

## firm_id contract

`firm_id` is a stable 12-hex-char handle:

```
firm_id = sha256(apex.lower().rstrip(".")).hexdigest()[:12]
```

`apex` is the registered domain (`mckinsey.com`, not
`www.mckinsey.com/about`).

```python
import hashlib
def firm_id(apex):
    return hashlib.sha256(apex.lower().rstrip(".").encode()).hexdigest()[:12]
```

```bash
echo -n "mckinsey.com" | tr 'A-Z' 'a-z' \
  | openssl dgst -sha256 -hex | awk '{print substr($2,1,12)}'
```

## Recipes

### A. Strategy consultancy in a state

User: *"Three top strategy consultancies in California for a Series-B SaaS."*

```
GET /v1/explore?filter=industry:management_consulting+state:CA+service_provided:strategy-consulting@high
GET /v1/search?filter=industry:management_consulting+state:CA+service_provided:strategy-consulting@high&limit=10
GET /v1/get/<firm_id>     # ×3
```

### B. Boutique ops consulting + vertical

User: *"Boutique operations consulting firms with healthcare experience."*

```
GET /v1/search?filter=industry:management_consulting+service_provided:operations-consulting+healthcare+-company_size_signal:large_50plus&limit=10
```

### C. Executive coach for a CEO

User: *"Executive coach for our new CEO."*

```
GET /v1/search?filter=industry:management_consulting+service_provided:executive-coaching@high
```

### D. Indirect intent — post-merger / change

User: *"Change-management partners for a post-merger integration."*

```
GET /v1/search?filter=industry:management_consulting+service_provided:organizational-development+(merger OR integration)
```

If thin, drop the keywords and use `service_provided:organizational-development@high`
alone — the tag itself captures change-management.

### E. Indirect intent — "fractional COO"

User: *"Fractional COO support for the next 6 months."*

```
GET /v1/search?filter=industry:management_consulting+service_provided:operations-consulting+fractional
```

### F. Quality threshold + Big-3 alumni

User: *"Three management consulting firms with 4-star ratings and Big-3
alumni."*

```
GET /v1/search?filter=industry:management_consulting+service_provided:strategy-consulting@high+rating>=4+(mckinsey OR bcg OR bain)&limit=10
```

The "alumni" angle isn't structured — keyword the firm names of the
shops the alumni came from; many spinout consultancies advertise it
in their bio text.

### G. BYO apex list — enrich domains

User pastes 8–20 consulting-firm domains. For each:

1. Compute `firm_id` locally.
2. `GET /v1/get/<firm_id>` — full bundle if in catalog, 404 if not.
3. Aggregate, present, flag the not-found ones.

## Gotchas

- **Always pin `industry:management_consulting`.** Without it, `service_provided:strategy-consulting` could surface marketing or IT firms that list "strategy" as a sub-service.
- **`executive-coaching` is for B2B.** When a firm hires a coach for their executives, this skill applies. When an *individual* asks for a life coach or career coach for themselves, it's out of scope.
- **"Help me build a strategy" is do-the-work, not procurement.** Refuse and offer to find a firm if the user wants to hire one.
- **Framework comparisons** (Lean vs Agile, etc.) and **MBA-program questions** are knowledge, not procurement.
- **`looks_not_pro_services` 404 is not a bug.** A `firm_id` may exist in `/search` but 404 on `/get` if it's been flagged. Skip and continue; not charged.
- **`/v1/explore` k=20 suppression.** When fewer than 20 firms match, the response is `{"count": "<20", "suppressed": true, "breakdowns": {}}`. Drilling further makes the count smaller. Broaden or escalate to `/v1/search`.
- **Briefs from `/search` do NOT include `apex`, `url`, `phone_primary`, `email_primary`, `legal_name`, or address.** If the user asks for contact info, you must `/get/:id`.
- **In-house hires (CSO, COO, etc.) are NOT procurement.**
- **Quota is per-user-per-month, deduped on first view.** Re-views are free; re-pagination is free.

## Errors

All errors return JSON: `{"error": {"code": "...", "message": "..."}}`.

| Status | Code | What to do |
|---|---|---|
| 400 | `filter_parse_error` | Payload includes `position`. Fix the filter, re-validate with `/v1/check`. |
| 400 | `filter_required` | Empty filter where one is required. |
| 400 | `invalid_firm_id` | firm_id must be 12 lowercase hex chars. Re-derive. |
| 401 | `unauthorized` | Token missing/expired. Re-run OTP. |
| 404 | `not_found` | Firm not in catalog or flagged. Not charged. Skip and continue. |
| 429 | `rate_limited` | Honor `Retry-After` header / `retry_after` field. |
| 429 | `monthly_quota_exhausted` | Switch to `/v1/explore`-only mode for the rest of the month. Tell the user. |

## End-to-end example

User: *"Three top management-consulting firms in California focused on
strategy, with strong third-party ratings."*

```
GET /v1/tags?include_values=1
GET /v1/check?filter=industry:management_consulting+state:CA+service_provided:strategy-consulting@high+rating>=4+review_count_total>=20
GET /v1/explore?filter=industry:management_consulting+state:CA+service_provided:strategy-consulting@high+rating>=4+review_count_total>=20
GET /v1/search?filter=...&limit=10
GET /v1/get/<firm_id>     # ×3
```

End of session: report `X-Quota-Remaining-Month`.
