---
name: find-cpa-firm
description: Use whenever the user wants to find, shortlist, vet, or enrich US accounting and tax firms (CPA firms) — financial-statement audit, SOC 1/2 audit, corporate tax, bookkeeping for businesses, advisory/fractional CFO, M&A diligence, 409A valuations, R&D tax credits, IPO readiness, sales-and-use tax. Triggers on "find me a CPA firm for our delaware c-corp series A audit", "shortlist three audit firms with SaaS experience", "we need a tax advisor for our M&A", or "pull contact info for these 10 accounting firm domains", even when described indirectly (audit our books, fractional CFO support, file our 1120). Drives the ServiceGraph API (api.servicegraph.co) — a 100k+ US firm catalog filterable by industry, services, location, size, ratings. Skip personal/consumer tax preparation (1040, individual estate, retirement planning), in-house controller/CFO hires, "how do I file my taxes" DIY questions, accounting-software comparisons (QuickBooks vs Xero), non-US firms, individual freelance bookkeepers.
license: MIT
metadata:
  api_base: https://api.servicegraph.co
  industry: accounting_tax
  version: "0.1"
---

# find-cpa-firm

Drive the **ServiceGraph API** (`https://api.servicegraph.co`) to find,
shortlist, and enrich US **business-to-business** accounting and tax
firms (CPA firms).

**The catalog is B2B-only.** Personal tax prep (individual 1040s,
retirement planning, individual estate planning, personal bookkeeping
for freelancers) is out of scope — those firms were filtered during
the catalog audit.

**Always pin `industry:accounting_tax`.** Sub-services (audit, tax,
bookkeeping, advisory, M&A diligence, 409A, R&D credits, etc.) are
NOT separate tags — `industry:accounting_tax` is the most specific
structured level — so practice-area specialization is a keyword
substring search on firm text.

Any HTTP client works (curl, fetch, requests). Examples below use curl.

## When NOT to use this skill

- Personal/individual tax matters: 1040 prep, IRA/Roth conversions,
  estate planning for an individual, personal-finance "what should I
  do with my refund" questions.
- Bookkeeping for a freelancer or solo creator's personal income.
- In-house finance hires (Controller, CFO, Accountant).
- DIY tax/accounting questions ("how do I claim X", "explain
  depreciation").
- Accounting-software comparisons (QuickBooks, Xero, NetSuite).
- Non-US firms.
- Individual freelance bookkeepers/accountants.

If the user is a *business* (LLC, C-corp, S-corp, partnership, or any
revenue-generating entity) procuring accounting or tax services, this
skill applies — defaults to fire on B2B procurement intent.

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

Cache the response for the conversation. Confirm `accounting_tax` is
present in the `industry` value list.

Field kinds you'll use most:
- **categorical**: `industry` (always `accounting_tax`), `state`, `pricing_model`, `company_size_signal`, `geography_served` — op `:`
- **numeric**: `rating`, `review_count_total`, `founded_year` — ops `= >= <= > <`
- **presence**: `has:phone`, `has:clutch`, `has:rating`, `has:linkedin_company`, …
- **keyword**: free-text substring across firm name / brand / title / meta / legal_name. **This is how you specialize on practice area** (audit, tax, M&A, R&D, 409A, etc.).

## Auth

`/tags`, `/check`, and `/explore` are anonymous. `/search` and `/get`
require a bearer token.

**Resolution rule** — try these sources in order before triggering OTP:

1. **Shell environment**: `$SERVICEGRAPH_TOKEN`. Most agent harnesses
   only inherit explicit `export`s, not dotenv files — so this catches
   the case where the user has it exported in `~/.bashrc` / `~/.zshrc`.

2. **Project dotenv files**: read `.env.local` then `.env` in the
   current working directory and look for a `SERVICEGRAPH_TOKEN=…`
   line. **This is the common case the agent will miss otherwise** —
   users frequently put the token in `.env.local` (gitignored) and
   expect it to "just work," but Claude Code and similar harnesses
   don't auto-load dotenv files. If you find it, use it; don't ask.

If found in any of the above, set
`Authorization: Bearer <token>` on every authed request and skip OTP.

3. **Otherwise, walk the user through OTP** (one-time, ~30 s):
   - Ask the user for their email address.
   - `POST /v1/auth/request-otp` with `{"email": "..."}`. Returns 204; a
     6-digit code lands in their inbox.
   - Ask the user to paste the code.
   - `POST /v1/auth/verify-otp` with `{"email": "...", "code": "...",
     "name": "<a label like claude-cli>"}`. Returns
     `{"token": "vk_...", "expires_at": "...", "user": {...}}`.
   - Use that token for the rest of the session.
   - Tell the user: *"Save this as `SERVICEGRAPH_TOKEN` to skip this
     step next time — either `export SERVICEGRAPH_TOKEN=…` in your
     shell rc, or add `SERVICEGRAPH_TOKEN=…` to a `.env.local` file in
     your project (gitignored). The token is shown once and lasts 90
     days."*

If a `/search` or `/get` returns 401 mid-session, the token expired or
was revoked — re-run the OTP flow.

```bash
# 1. trigger the email
curl -X POST 'https://api.servicegraph.co/v1/auth/request-otp' \
  -H 'Content-Type: application/json' \
  -d '{"email":"you@example.com"}'

# 2. exchange the code
curl -X POST 'https://api.servicegraph.co/v1/auth/verify-otp' \
  -H 'Content-Type: application/json' \
  -d '{"email":"you@example.com","code":"123456","name":"my-cli"}'
# → { "token": "vk_…", "expires_at": "...", "user": {...} }
```

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

**Accounting-flavored examples** (validate yours with `/v1/check`):

```
industry:accounting_tax state:CA audit saas
industry:accounting_tax cpa state:DE,NY
industry:accounting_tax m&a diligence
industry:accounting_tax tax 409a
industry:accounting_tax fractional cfo
industry:accounting_tax r&d tax
industry:accounting_tax soc 2
industry:accounting_tax -company_size_signal:solo rating>=4
```

When in doubt about whether a filter parses, hit `/v1/check?filter=...`
first — it's free and returns the canonical normalized form.

**Practice area → keyword mapping**:

| User asks for | Add as keyword(s) |
|---|---|
| Audit / financial-statement audit | `audit` |
| SOC 1 / SOC 2 audit | `soc 2` (multi-word splits to AND) |
| Corporate tax / 1120 | `tax`, `corporate tax`, `1120` |
| Bookkeeping (for a business) | `bookkeeping` |
| Advisory / fractional CFO | `fractional cfo`, `advisory` |
| M&A diligence | `m&a`, `diligence` |
| 409A valuation | `409a` |
| R&D tax credits | `r&d`, `r&d tax` |
| IPO readiness | `ipo`, `readiness` |
| Sales-and-use tax | `sales tax`, `sales and use` |
| International tax / transfer pricing | `international tax`, `transfer pricing` |

## firm_id contract

`firm_id` is a stable 12-hex-char handle:

```
firm_id = sha256(apex.lower().rstrip(".")).hexdigest()[:12]
```

`apex` is the registered domain (`pwc.com`, not `www.pwc.com/about`).
Anyone with an apex list can compute firm_ids locally and call
`/v1/get/:id` directly — no `/search` needed for BYO enrichment.

```python
import hashlib
def firm_id(apex):
    return hashlib.sha256(apex.lower().rstrip(".").encode()).hexdigest()[:12]
```

```bash
echo -n "pwc.com" | tr 'A-Z' 'a-z' \
  | openssl dgst -sha256 -hex | awk '{print substr($2,1,12)}'
```

## Recipes

### A. CPA firm for a Delaware C-corp audit

User: *"CPA firm for our delaware c-corp series A audit, under 50 ppl."*

```
GET /v1/explore?filter=industry:accounting_tax+audit+state:DE,NY,CA+-company_size_signal:large_50plus
# → pool size + breakdowns

GET /v1/search?filter=industry:accounting_tax+audit+state:DE,NY,CA+-company_size_signal:large_50plus&limit=10

GET /v1/get/<firm_id>     # ×3
```

### B. SaaS-experienced audit firms

User: *"Three audit firms with SaaS experience for our annual review."*

```
GET /v1/search?filter=industry:accounting_tax+audit+saas&limit=10
```

### C. M&A diligence

User: *"Tax advisor for our M&A — Series-B-stage tech company."*

```
GET /v1/search?filter=industry:accounting_tax+m&a+diligence+tech
```

### D. Fractional CFO (indirect intent)

User: *"Fractional CFO to help us through a Series-A close."*

```
GET /v1/search?filter=industry:accounting_tax+fractional+cfo
```

If thin, drop the `cfo` keyword — `fractional` alone catches
fractional finance leaders broadly.

### E. R&D tax credits

User: *"R&D tax credit specialists for biotech."*

```
GET /v1/search?filter=industry:accounting_tax+r&d+biotech
```

### F. Quality threshold — multi-state DTC sales tax

User: *"Outside accountant for state and local tax filings — multi-state DTC business."*

```
GET /v1/search?filter=industry:accounting_tax+(sales tax OR salt)+multi-state&limit=10
```

If barely any results, drop `multi-state` and surface the dimension to the
user from `/get` city/state data.

### G. BYO apex list — enrich domains

User pastes 8–20 accounting-firm domains. For each:

1. Compute `firm_id` locally.
2. `GET /v1/get/<firm_id>` — full bundle if in catalog, 404 (not
   charged) if not.
3. Aggregate; flag the not-found ones.

A 404 here often means the firm focuses on personal tax prep and was
filtered out of the B2B catalog.

## Gotchas

- **Always pin `industry:accounting_tax`.** Without it, "tax" / "audit" / "cfo" as keywords match management consulting and other industries.
- **Refuse personal-tax asks.** 1040 prep for an individual, IRA conversion strategy, personal estate planning, "should I use QuickBooks Self-Employed?" — these are NOT in the catalog. Tell the user the catalog is B2B-only.
- **`industry:accounting_tax` is the only structured handle.** Practice areas (audit, tax, M&A, 409A, R&D credits, etc.) are keyword-only. Multi-word areas split into ANDed barewords (`r&d tax credits` → `r&d` AND `tax` AND `credits`).
- **`looks_not_pro_services` 404 is not a bug.** A `firm_id` may exist in `/search` but 404 on `/get` if it's been flagged. Skip and continue; not charged.
- **`/v1/explore` k=20 suppression.** When fewer than 20 firms match, the response is `{"count": "<20", "suppressed": true, "breakdowns": {}}`. Drilling further makes the count smaller. Broaden or escalate to `/v1/search`.
- **Briefs from `/search` do NOT include `apex`, `url`, `phone_primary`, `email_primary`, `legal_name`, or address.** If the user asks for contact info, you must `/get/:id`.
- **In-house finance hires (Controller, CFO, Accountant) are NOT procurement.** Recruiting an employee is out of scope.
- **Accounting-software comparisons** (QuickBooks vs Xero vs NetSuite) are NOT procurement either.
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

User: *"CPA firm for our delaware c-corp series A audit, recommend 5
options under 50 ppl, ideally with SaaS experience and 4-star ratings."*

```
GET /v1/tags?include_values=1
GET /v1/check?filter=industry:accounting_tax+audit+saas+rating>=4+-company_size_signal:large_50plus
GET /v1/explore?filter=industry:accounting_tax+audit+saas+rating>=4+-company_size_signal:large_50plus
GET /v1/search?filter=...&limit=10
# Header: Authorization: Bearer $SERVICEGRAPH_TOKEN

# user picks 5
GET /v1/get/<firm_id>     # ×5
```

End of session: report `X-Quota-Remaining-Month`.
