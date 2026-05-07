---
name: find-law-firm
description: Use whenever the user wants to find, shortlist, vet, or enrich US B2B law firms — corporate, IP/patent, M&A and securities, employment, commercial litigation, regulatory/compliance, data privacy/cyber, real estate, and tax. Triggers on "find three boutique IP law firms in California", "shortlist M&A counsel for a Series-B fundraise", "patent prosecution for our hardware startup", or "pull contact info for these 10 law firm domains", even when described indirectly (outside counsel, cap-table review, GDPR/SOC2 oversight). Drives the ServiceGraph API (api.servicegraph.co) — a 100k+ US firm catalog filterable by industry, services, location, size, ratings. Skip personal/consumer legal services where the user is the end client (divorce, personal injury, criminal defense, family law, estate planning, wills) — the catalog is B2B-only. Also skip in-house GC hires, "is this NDA enforceable" DIY questions, non-US firms, individual freelancers.
license: MIT
metadata:
  api_base: https://api.servicegraph.co
  industry: legal
  version: "0.1"
---

# find-law-firm

Drive the **ServiceGraph API** (`https://api.servicegraph.co`) to find,
shortlist, and enrich US **business-to-business** law firms.

**The catalog is B2B-only.** A historical audit dropped over half of
high-rank "legal" firms because they served personal/consumer matters
(divorce, personal injury, criminal defense, family law, estate
planning). The remaining catalog skews toward corporate, IP, M&A,
securities, employment, commercial litigation, regulatory, data
privacy, real-estate transactions, and corporate tax.

**Always pin `industry:legal`.** Sub-areas of law are NOT separate
tags — `industry:legal` is the most specific structured level —
so practice-area specialization (IP, M&A, employment, securities,
etc.) is a keyword substring search on firm text.

Any HTTP client works (curl, fetch, requests). Examples below use curl.

## When NOT to use this skill

The single biggest failure mode is firing on **consumer-personal**
legal asks. Refuse those — don't fall back to a partial filter.

Out of scope:
- Personal/family matters where the user is the end client: divorce,
  child custody, family law, estate planning, wills/trusts, personal
  injury, criminal defense, individual bankruptcy, immigration for
  the user themselves, landlord/tenant disputes.
- DIY legal research: "is this enforceable?", "do I owe...?", "what
  does this clause mean?".
- In-house counsel hires (GC, paralegal, contracts manager).
- Non-US firms — the catalog is US-only.
- Individual freelancers / contract attorneys for hire.

If the user is a *business* procuring legal services (corporate
counsel, fundraising, IP, regulatory), this skill applies regardless
of whether the practice area is "boring" — defaults to fire on B2B
procurement intent.

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

Cache the response for the conversation. Confirm `legal` is present
in the `industry` value list. Note that `industry:legal` is the most
specific structured tag for law firms — practice-area specialization
is keyword-based.

Field kinds you'll use most:
- **categorical**: `industry` (always `legal`), `state`, `pricing_model`, `company_size_signal`, `geography_served` — op `:`
- **numeric**: `rating`, `review_count_total`, `founded_year` — ops `= >= <= > <`
- **presence**: `has:phone`, `has:clutch`, `has:rating`, `has:linkedin_company`, …
- **keyword**: free-text substring across firm name / brand / title / meta / legal_name. Bareword in the filter becomes a keyword. **This is how you specialize on practice area** (IP, patent, M&A, employment, securities, etc.).

Note: `service_provided` tags are not populated for `industry:legal`
in the current catalog (see catalog notes — Clutch and similar
directories don't break legal down further). Use barewords for
practice areas instead.

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

**Legal-flavored examples** (validate yours with `/v1/check`):

```
industry:legal state:CA patent
industry:legal state:NY,DE m&a
industry:legal employment
industry:legal securities ipo
industry:legal data privacy gdpr
industry:legal commercial litigation state:TX
industry:legal -company_size_signal:solo rating>=4 review_count_total>=20
industry:legal corporate startup
```

When in doubt about whether a filter parses, hit `/v1/check?filter=...`
first — it's free and returns the canonical normalized form.

**Practice area → keyword mapping** (since legal sub-areas are not
structured tags):

| User asks for | Add as keyword(s) |
|---|---|
| IP / patents / trademarks | `patent`, `trademark`, `ip` |
| M&A / mergers and acquisitions | `m&a` (or `mergers`) |
| Securities / IPO / capital markets | `securities`, `ipo` |
| Employment law (employer-side) | `employment`, `labor` |
| Commercial litigation / disputes | `litigation`, `commercial` |
| Regulatory / compliance | `regulatory`, `compliance` |
| Data privacy / cyber / GDPR / CCPA | `privacy`, `gdpr`, `ccpa`, `cyber` |
| Real estate (commercial) | `real estate`, `commercial real estate` |
| Tax (corporate) | `tax` |
| Corporate / formation / governance | `corporate`, `formation`, `governance` |
| Antitrust | `antitrust` |
| Bankruptcy (corporate) | `bankruptcy` |
| Immigration (corporate sponsorship) | `immigration` |

## firm_id contract

`firm_id` is a stable 12-hex-char handle:

```
firm_id = sha256(apex.lower().rstrip(".")).hexdigest()[:12]
```

`apex` is the registered domain (`dlapiper.com`, not
`www.dlapiper.com/about`). Anyone with an apex list can compute
firm_ids locally and call `/v1/get/:id` directly — no `/search`
needed for BYO enrichment.

```python
import hashlib
def firm_id(apex):
    return hashlib.sha256(apex.lower().rstrip(".").encode()).hexdigest()[:12]
```

```bash
echo -n "dlapiper.com" | tr 'A-Z' 'a-z' \
  | openssl dgst -sha256 -hex | awk '{print substr($2,1,12)}'
```

## Recipes

### A. IP / patent firm in a state

User: *"Three boutique IP law firms in California for hardware-startup
patent prosecution."*

```
GET /v1/explore?filter=industry:legal+state:CA+patent
# → pool size + breakdowns

GET /v1/search?filter=industry:legal+state:CA+patent+-company_size_signal:large_50plus&limit=10
# → 10 brief cards (boutique ⇒ exclude large firms); user picks 3

GET /v1/get/<firm_id>     # ×3
# → urls, phones, emails for outreach
```

### B. M&A counsel for a fundraise

User: *"M&A counsel for a Series-B fundraise — top firms in NY."*

```
GET /v1/search?filter=industry:legal+state:NY+m&a&limit=10&order_by=relevance
```

### C. Securities / IPO experience

User: *"Securities law firms experienced with IPOs."*

```
GET /v1/search?filter=industry:legal+securities+ipo&limit=10
```

### D. Indirect intent — "outside counsel for GDPR/SOC2"

User: *"Our compliance is getting complex — we need outside counsel
for GDPR, CCPA, and SOC2 oversight."*

That's a B2B legal procurement ask in regulatory/data-privacy:

```
GET /v1/search?filter=industry:legal+(gdpr OR ccpa OR privacy)+compliance&limit=10
```

### E. Employment law for a tech employer

User: *"Mid-size firms specializing in employment law for tech
companies."*

```
GET /v1/search?filter=industry:legal+employment+tech+company_size_signal:medium_10_50,small_2_10
```

### F. Quality threshold + commercial litigation

User: *"Three commercial litigation firms in Texas with at least
4-star ratings."*

```
GET /v1/search?filter=industry:legal+commercial+litigation+state:TX+rating>=4&limit=10
```

### G. BYO apex list — enrich domains the user already has

User pastes 8–20 law-firm domains. For each:

1. Compute `firm_id` locally (see contract above).
2. `GET /v1/get/<firm_id>` — full bundle if in catalog, 404 (not
   charged) if not.
3. Aggregate, present, flag the not-found ones to the user. A 404
   often means the firm is consumer-focused (divorce, PI) and was
   filtered out of the B2B catalog.

## Gotchas

- **Always pin `industry:legal`.** Without it, "patent" or "m&a" as keywords would also match marketing/IT firm meta tags.
- **Refuse consumer-personal legal asks.** Divorce, personal injury, criminal defense, family law, estate planning, wills, individual immigration, personal bankruptcy — these are NOT in the catalog. Tell the user the catalog is B2B-only and suggest they look elsewhere (state bar referral services, Avvo, etc.). Do NOT return a partial result hoping it's close enough.
- **`industry:legal` is the only structured handle.** Practice areas (IP, M&A, employment, securities, etc.) are keyword-only. Multi-word areas split into ANDed barewords (`commercial litigation` = `commercial` AND `litigation`).
- **`looks_not_pro_services` 404 is not a bug.** A `firm_id` may exist in `/search` but 404 on `/get` if it's been flagged. Skip and continue; not charged.
- **`/v1/explore` k=20 suppression.** When fewer than 20 firms match, the response is `{"count": "<20", "suppressed": true, "breakdowns": {}}`. Drilling further makes the count smaller. Broaden or escalate to `/v1/search`.
- **Briefs from `/search` do NOT include `apex`, `url`, `phone_primary`, `email_primary`, `legal_name`, or address.** If the user asks for contact info, you must `/get/:id`. Do not pretend to have it from the brief.
- **Catalog skews toward mid/large B2B firms.** Solo practitioners and very small (<5 attorney) shops are under-represented after the audit. If the user wants a "boutique" firm, exclude `company_size_signal:large_50plus` rather than requiring solo.
- **DIY/legal-research questions** ("is this NDA enforceable?", "explain fair use") are NOT procurement. Refuse and offer to find a firm if the user wants advice rather than research.
- **Software-product comparisons** (Ironclad vs DocuSign, etc.) are NOT procurement either.
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

Authed responses carry `X-RateLimit-*` and `X-Quota-*` headers. Surface
the remaining-month value to the user when it gets low so they can
budget.

## End-to-end example

User: *"Three boutique IP law firms in California that handle patent
prosecution for hardware startups, ideally with at least a 4-star
rating."*

```
# 1. Discover fields (once per session)
GET /v1/tags?include_values=1
# Confirms 'legal' is a valid industry value, 'rating' is numeric.

# 2. Validate the filter and scope the pool (free, no auth)
GET /v1/check?filter=industry:legal+state:CA+patent+rating>=4+-company_size_signal:large_50plus
# → {"valid": true, "normalized": "..."}

GET /v1/explore?filter=industry:legal+state:CA+patent+rating>=4+-company_size_signal:large_50plus
# → {"count": 27, "breakdowns": {...}}

# 3. Search briefs
GET /v1/search?filter=...&limit=10
# Header: Authorization: Bearer $SERVICEGRAPH_TOKEN
# → 10 brief cards.

# 4. Present briefs to user, get their pick of 3.

# 5. Pull full bundles for the 3 picks
GET /v1/get/<firm_id>     # ×3
# → urls, phones, emails for outreach
```

End of session: report `X-Quota-Remaining-Month` so the user knows how
much budget is left.
