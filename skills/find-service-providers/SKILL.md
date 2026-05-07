---
name: find-service-providers
description: Use whenever the user wants to find, shortlist, vet, enrich, or research US professional-services firms — law, marketing, consulting, accounting, IT services, architecture, engineering, HR, PR, design, and similar B2B service providers. Triggers on requests like "find me a PPC agency in California", "shortlist three boutique IP law firms", "build a longlist of 50 mid-size IT consultancies", or "here are 12 agency domains — pull contact info and confirm which are US-based", even when the need is described indirectly without naming a category. Drives the ServiceGraph API (api.servicegraph.co) — a 100k+ US firm catalog with filters for industry, services, location, size, ratings, and third-party listings. Skip when the user is asking for personal/consumer services for themselves (an individual's own legal, tax, or medical needs), non-US firms, individual freelancers, retail/ecommerce/SaaS-product companies, recruiting-an-employee tasks, or general web research that doesn't need a structured firm directory.
license: MIT
metadata:
  api_base: https://api.servicegraph.co
  version: "0.2"
---

# find-service-providers

Drive the **ServiceGraph API** (`https://api.servicegraph.co`) to find,
shortlist, and enrich US professional-services firms. The catalog has
100k+ B2B service firms classified across 22 industries with multi-tag
service taxonomies, location, size, and third-party rating signals.

Any HTTP client works (curl, fetch, requests). Examples below use curl
for clarity.

## The four-tier funnel

The API is a deliberate cost funnel. Cheaper tiers are free or nearly
free; expensive tiers reveal more. **Always work down the funnel — don't
skip tiers.**

| Tier | Auth | Cost | Use it for |
|---|---|---|---|
| `GET /v1/tags` | none | free | **First call of every session.** Discover legal field names, kinds, operators, values. |
| `GET /v1/check?filter=...` | none | free | Validate a filter before spending an explore/search call. |
| `GET /v1/explore?filter=...` | none | free, IP-throttled | Scope: count + breakdowns. Use to size the candidate pool before quota-spending. |
| `GET /v1/search?filter=...` | bearer | 200 unique firms / month free | Brief firm cards. **No url, no contact info.** Use for ranking / shortlisting. |
| `GET /v1/get/:id` | bearer | 50 unique firms / month free | Full bundle: url, phone, email, social, legal name, address. **Only call for shortlisted firms.** |
| `POST /v1/research` | paid | not in MVP | Deferred — skip. |

**Quota rule that matters**: `/search` and `/get` charge per *unique firm
viewed per calendar month*, not per call. Re-paging the same query is
free. Two different filters that overlap charge once for the overlap.
Re-fetching a firm you already pulled this month is free.

## Session-start ritual

Before constructing any filter, call:

```
GET https://api.servicegraph.co/v1/tags?include_values=1
```

Cache the response for the conversation. It returns every filterable
field with its `kind`, allowed `operators`, and (for categorical /
tag-set fields) the legal value list. **Never invent industry or
service values from memory** — the parser silently accepts unknown
values for categorical fields and returns zero results.

You'll get five field kinds:

- **categorical** (e.g. `industry`, `state`, `pricing_model`) — single value, op `:` only.
- **tag_set_with_evidence** (e.g. `service_provided`) — Map<tag, evidence∈{low,medium,high}>. Op `:` with optional `@evidence`.
- **numeric** (e.g. `rating`, `review_count_total`, `founded_year`) — ops `= >= <= > <`.
- **presence** (`has:phone`, `has:clutch`, `has:rating`, …) — boolean populated-ness check on a column or third-party listing.
- **keyword** — free-text substring across firm name / brand / title / meta description / legal name. Any bareword in the filter becomes a keyword.

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
   curl -sX POST 'https://api.servicegraph.co/v1/auth/request-otp' \
     -H 'Content-Type: application/json' \
     -d "{\"email\":\"$EMAIL\"}"

   # 2. exchange the code — agent prompts the user for $CODE — and
   #    pipe the response straight into .env.local. Use jq to extract
   #    only the token field; do NOT cat / echo the response.
   curl -sX POST 'https://api.servicegraph.co/v1/auth/verify-otp' \
     -H 'Content-Type: application/json' \
     -d "{\"email\":\"$EMAIL\",\"code\":\"$CODE\",\"name\":\"claude-cli\"}" \
   | jq -r 'select(.token) | "SERVICEGRAPH_TOKEN=" + .token' \
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
4. **Bareword = keyword search.** Any IDENT or NUMBER not followed by an
   operator becomes a free-text substring across name / brand / title /
   meta / legal_name. Multiple barewords AND.

**Examples** (validate yours with `/v1/check`):

```
industry:marketing_agency service_provided:seo
dental industry:marketing_agency
industry:legal state:CA,NY -company_size_signal:solo
industry:management_consulting (service_provided:strategy-consulting@high OR service_provided:operations-consulting@high)
state:CA has:phone has:email
rating>=4 review_count_total>=20 has:clutch
industry:it_services NOT (service_provided:web-development OR service_provided:hosting)
```

When in doubt about whether a filter parses, hit `/v1/check?filter=...`
first — it's free and returns the canonical normalized form.

## firm_id contract

`firm_id` is a stable 12-hex-char handle:

```
firm_id = sha256(apex.lower().rstrip(".")).hexdigest()[:12]
```

`apex` is the registered domain (`mckinsey.com`, not
`www.mckinsey.com/about`). Anyone with an apex list can compute firm_ids
locally and call `/v1/get/:id` directly — no `/search` needed for BYO
enrichment.

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

### A. Shortlist by industry + state

```
GET /v1/explore?filter=industry:legal+state:CA+-company_size_signal:solo
# → see pool size + breakdowns

GET /v1/search?filter=industry:legal+state:CA+-company_size_signal:solo&limit=20
# → 20 brief cards; pick top 3 with user

GET /v1/get/<firm_id>     # for each of the 3 picks
# → urls, phones, emails for outreach
```

### B. Multi-tag service intersection

User: *"Marketing agency that does both branding and SEO at high evidence."*

```
GET /v1/explore?filter=industry:marketing_agency+service_provided:branding@high+service_provided:seo@high

GET /v1/search?filter=industry:marketing_agency+service_provided:branding@high+service_provided:seo@high&limit=10
```

### C. Quality threshold

User: *"Consultancies with at least 4★ and 20+ reviews and a Clutch listing."*

```
GET /v1/search?filter=industry:management_consulting+rating>=4+review_count_total>=20+has:clutch&limit=10
```

### D. Indirect intent — user describes a need without naming the category

User: *"I need someone to handle our open enrollment communications for 200 employees."*

That's HR consulting + benefits comms. Translate, then verify with
`/v1/check`:

```
GET /v1/check?filter=industry:hr_recruiting_staffing+service_provided:benefits-administration

GET /v1/explore?filter=industry:hr_recruiting_staffing+service_provided:benefits-administration
```

If the breakdown is too narrow, broaden — drop the service tag, add
adjacent industries (`marketing_agency` for the comms angle), or fall
back to keyword: `benefits enrollment industry:marketing_agency,hr_recruiting_staffing`.

### E. Keyword + structured filter

User: *"HIPAA-savvy IT consultancies in Texas."*

```
GET /v1/search?filter=hipaa+industry:it_services+state:TX&limit=10
```

`hipaa` is a bareword keyword → substring match in firm text.

### F. BYO apex list — enrich domains the user already has

User pastes 12 domains. For each:

1. Compute `firm_id` locally (see contract above).
2. `GET /v1/get/<firm_id>` — full bundle if in catalog, 404 (not charged)
   if not.
3. Aggregate, present, flag the not-found ones to the user.

`/get` only charges on first view per calendar month per user, so re-runs
are free.

## Gotchas

- **`looks_not_pro_services` 404 is not a bug.** A `firm_id` may exist
  in `/search` but 404 on `/get` if it's been flagged (residual SaaS /
  B2C leakage). Skip and continue; not charged.
- **`/v1/explore` k=20 suppression.** When fewer than 20 firms match,
  the response is `{"count": "<20", "suppressed": true,
  "breakdowns": {}}`. Drilling further makes the count smaller, not
  bigger. Broaden the filter or escalate to `/v1/search` if the user
  wants the actual firms.
- **Briefs from `/search` do NOT include `apex`, `url`, `phone_primary`,
  `email_primary`, `legal_name`, or address.** If the user asks for
  contact info, you must `/get/:id`. Do not pretend to have it from
  the brief.
- **Catalog is US-only B2B pro-services.** Refuse non-US asks rather
  than returning misleading partial matches. Refuse consumer-facing
  legal/financial requests (e.g. *"I need a divorce lawyer for
  personal matters"*) — the catalog is built for B2B procurement.
- **Always use `/v1/tags` for legal field values.** Inventing
  `industry:law` instead of `industry:legal` returns zero results
  silently — the parser doesn't validate categorical values.
- **Multi-word phrases must be split into separate barewords.**
  `family law` parses as two AND'd keywords (`family` AND `law`),
  not one phrase.
- **Quota is per-user-per-month, deduped on first view.** Don't refuse
  to look up a firm "to save quota" if the user already viewed it this
  month — re-views are free.
- **Re-pagination is free.** Pulling page 2 of the same `/search` query
  doesn't re-charge for firms returned on page 1.

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

Authed responses carry `X-RateLimit-*` and `X-Quota-*` headers. Surface
the remaining-month value to the user when it gets low so they can
budget.

## End-to-end example

User: *"Find me three top management-consulting firms in California
focused on strategy, with strong third-party ratings."*

```
# 1. Discover fields (once per session)
GET /v1/tags?include_values=1
# Confirms 'management_consulting' is a valid industry value, that
# 'strategy-consulting' is in the service_provided taxonomy, and that
# rating + review_count_total are numeric.

# 2. Validate the filter and scope the pool (free, no auth)
GET /v1/check?filter=industry:management_consulting+state:CA+service_provided:strategy-consulting@high+rating>=4+review_count_total>=20
# → {"valid": true, "normalized": "..."}

GET /v1/explore?filter=industry:management_consulting+state:CA+service_provided:strategy-consulting@high+rating>=4+review_count_total>=20
# → {"count": 47, "breakdowns": {...}}

# 3. Search briefs (charges new firms against monthly /search quota)
GET /v1/search?filter=...&limit=10
# Header: Authorization: Bearer $SERVICEGRAPH_TOKEN
# → 10 brief cards with industry, service tags, size, state, etc.

# 4. Present briefs to user, get their pick of 3.

# 5. Pull full bundles for the 3 (charges 3 against monthly /get quota)
GET /v1/get/<firm_id>     # ×3
# → urls, phones, emails for outreach
```

End of session: report `X-Quota-Remaining-Month` so the user knows how
much budget is left.
