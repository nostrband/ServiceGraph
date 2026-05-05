---
name: find-software-developer
description: Use whenever the user wants to find, shortlist, vet, or enrich US software development firms — custom software, web development, mobile app development, backend/API development, DevOps/cloud, system integration, and hosting. Triggers on "find a software dev shop in Austin", "shortlist three custom-software firms with healthcare experience", "we need a mobile app developer for our iOS launch", or "pull contact info for these 10 dev shop domains", even when described indirectly (build a tool, ship a feature, technical partner). Drives the ServiceGraph API (api.servicegraph.co) — a 100k+ US firm catalog filterable by industry, services, location, size, ratings. Defer to find-web-developer for strictly website/landing-page projects. Defer AI/ML, ML pipelines, model building, and data-engineering asks — those are a sibling industry, not software development. Skip in-house engineer hires, code-writing/debugging tasks, cloud-product comparisons, hardware/civil engineering, non-US firms, individual freelancers.
license: MIT
metadata:
  api_base: https://api.servicegraph.co
  industry: it_services
  version: "0.2"
---

# find-software-developer

Drive the **ServiceGraph API** (`https://api.servicegraph.co`) to find,
shortlist, and enrich US software development firms. The catalog has
tens of thousands of US IT-services firms tagged across 21 service
sub-tags (custom-software, web-development, mobile-app-development,
api-integrations, devops, cloud-consulting, hosting, system-
integration, etc.).

**Always pin `industry:it_services` in the filter.** This skill
exists to do that automatically — the user shouldn't have to think
about catalog taxonomy.

Any HTTP client works (curl, fetch, requests). Examples below use curl.

## Sibling skills — defer when scope is narrow

If the user's ask is **strictly** website / landing-page work (build
or refresh a site, marketing-site replacement, simple WordPress site),
defer to `find-web-developer`. If unsure, this skill is the safer
default — it covers web development too and won't over-narrow.

If the user wants AI/ML modeling specifically (recommendation engines,
LLM apps, ML pipelines as the core deliverable), that lives in a
different industry (`data_ai_consulting`) — defer to
`find-service-providers` for now (a dedicated AI/ML skill is planned).

If the user wants strictly marketing work (SEO, paid media, branding,
content), defer to `find-marketing-agency` or `find-seo-agency`.

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

Cache the response for the conversation. Confirm IT-relevant tags
exist in the returned `service_provided` taxonomy (custom-software,
web-development, mobile-app-development, devops, cloud-consulting,
api-integrations, etc.) — names occasionally drift, and the parser
silently accepts unknown tags and returns zero results.

Field kinds you'll use most:
- **categorical**: `industry` (always `it_services`), `state`, `pricing_model`, `company_size_signal`, `geography_served` — op `:`
- **tag_set_with_evidence**: `service_provided` — Map<tag, evidence∈{low,medium,high}>. Op `:` with optional `@evidence`
- **numeric**: `rating`, `review_count_total`, `founded_year` — ops `= >= <= > <`
- **presence**: `has:phone`, `has:clutch`, `has:rating`, `has:linkedin_company`, …
- **keyword**: free-text substring across firm name / brand / title / meta / legal_name. Bareword in the filter becomes a keyword.

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

**IT-flavored examples** (validate yours with `/v1/check`):

```
industry:it_services service_provided:custom-software@high state:TX
industry:it_services service_provided:mobile-app-development service_provided:custom-software
industry:it_services service_provided:devops aws
industry:it_services service_provided:api-integrations fintech
industry:it_services python aws state:CA
industry:it_services service_provided:custom-software@high rating>=4 has:clutch
industry:it_services NOT service_provided:hosting
```

When in doubt about whether a filter parses, hit `/v1/check?filter=...`
first — it's free and returns the canonical normalized form.

**Tech stack / vertical → keyword mapping** (the catalog tags services,
not languages or industries served, so stack and client-vertical are
keyword searches):

| User mentions | Add as keyword |
|---|---|
| Python / Django / Flask | `python` |
| Node.js / TypeScript / React | `node` or `react` |
| Go / Rust / Java / .NET | `go`, `rust`, `java`, `.net` |
| AWS / GCP / Azure | `aws`, `gcp`, `azure` |
| Fintech / healthcare / govtech / SaaS | `fintech`, `healthcare`, `govtech`, `saas` |
| SOC 2 / HIPAA / compliance | `soc2`, `hipaa`, `compliance` |

## firm_id contract

`firm_id` is a stable 12-hex-char handle:

```
firm_id = sha256(apex.lower().rstrip(".")).hexdigest()[:12]
```

`apex` is the registered domain (`thoughtworks.com`, not
`www.thoughtworks.com/about`). Anyone with an apex list can compute
firm_ids locally and call `/v1/get/:id` directly — no `/search`
needed for BYO enrichment.

```python
import hashlib
def firm_id(apex):
    return hashlib.sha256(apex.lower().rstrip(".").encode()).hexdigest()[:12]
```

```bash
echo -n "thoughtworks.com" | tr 'A-Z' 'a-z' \
  | openssl dgst -sha256 -hex | awk '{print substr($2,1,12)}'
```

## Recipes

### A. Custom-software shop in a state

User: *"Software dev shop in Austin for a custom B2B platform."*

```
GET /v1/explore?filter=industry:it_services+service_provided:custom-software@high+state:TX
# → pool size + breakdowns

GET /v1/search?filter=industry:it_services+service_provided:custom-software@high+state:TX&limit=10
# → 10 brief cards; user picks 3

GET /v1/get/<firm_id>     # ×3
# → urls, phones, emails for outreach
```

### B. Mobile app — vertical and platform

User: *"Mobile app developer to ship our iOS app in Q1."*

iOS / Android distinctions aren't separate tags — use barewords:

```
GET /v1/search?filter=industry:it_services+service_provided:mobile-app-development+ios&limit=10
```

### C. DevOps + cloud migration

User: *"DevOps consultancy to migrate us from on-prem to AWS."*

```
GET /v1/search?filter=industry:it_services+service_provided:devops+aws+migration
```

If breakdowns come back thin, drop `migration` first — it's a vertical
keyword, not a service tag.

### D. Indirect intent — "technical partner to build out tooling"

User: *"We need a technical partner to build out our internal tooling,
Northeast preferred."*

That's a custom-software ask. Translate:

```
GET /v1/search?filter=industry:it_services+service_provided:custom-software+state:NY,MA,CT,NJ,PA
# → 10 brief cards; user narrows
```

### E. Vertical + cert (fintech + SOC 2)

User: *"Software houses that specialize in fintech and have SOC 2 readiness."*

`fintech` and `soc2` are not structured facets — keyword them:

```
GET /v1/search?filter=industry:it_services+service_provided:custom-software+fintech+soc2
```

### F. Quality threshold + third-party signals

User: *"Three custom software firms with at least 4-star ratings, 50+ reviews."*

```
GET /v1/search?filter=industry:it_services+service_provided:custom-software@high+rating>=4+review_count_total>=50&limit=10
```

### G. API/backend specialty + remote

User: *"API/backend team to extend our SaaS — Bay Area or remote-friendly."*

`remote-friendly` isn't structured. Use `geography_served:national_US`
(a national-scope firm is more likely to serve remotely) and add
`api` / `backend` keywords:

```
GET /v1/search?filter=industry:it_services+service_provided:api-integrations+(state:CA OR geography_served:national_US)+saas
```

### H. BYO apex list — enrich domains the user already has

User pastes 8–20 domains. For each:

1. Compute `firm_id` locally (see contract above).
2. `GET /v1/get/<firm_id>` — full bundle if in catalog, 404 (not
   charged) if not.
3. Aggregate, present, flag the not-found ones to the user.

Useful for confirming whether a list of dev-firm domains is in the
US IT-services catalog and pulling contact info in one pass.

## Gotchas

- **Always pin `industry:it_services`.** Without it, `service_provided:custom-software` may match marketing or design firms that also list software services.
- **`industry:data_ai_consulting` is a sibling industry, not a sub-tag.** AI/ML-focused firms live there. If the user wants strictly an AI/ML/data-engineering firm, this skill returns an under-precise list — defer to `find-service-providers` (or a future AI-focused skill).
- **Defer to `find-web-developer` for strictly website/landing-page projects** when that skill is loaded. This skill covers web dev as a sub-service, but the dedicated skill will out-rank it on narrow web-only asks.
- **Programming language and tech stack are NOT structured tags.** `python`, `react`, `aws`, `kubernetes`, `rust`, etc. are keyword substring matches. Multi-word stacks (`ruby on rails`) split into separate AND'd keywords.
- **Client-vertical (fintech, healthcare, govtech) is NOT a structured tag.** Keyword it.
- **`looks_not_pro_services` 404 is not a bug.** A `firm_id` may exist in `/search` but 404 on `/get` if it's been flagged. Skip and continue; not charged.
- **`/v1/explore` k=20 suppression.** When fewer than 20 firms match, the response is `{"count": "<20", "suppressed": true, "breakdowns": {}}`. Drilling further makes the count smaller. Broaden or escalate to `/v1/search`.
- **Briefs from `/search` do NOT include `apex`, `url`, `phone_primary`, `email_primary`, `legal_name`, or address.** If the user asks for contact info, you must `/get/:id`. Do not pretend to have it from the brief.
- **Catalog is US-only B2B.** Refuse offshore asks ("a software firm in Bangalore"), individual freelancers ("a freelance developer"), in-house engineering hires ("hire a senior backend engineer"), and DIY/code tasks ("debug this", "review this PR").
- **Cloud product comparisons aren't procurement.** "Which is better, AWS or GCP?" is a knowledge question, not a firm shortlist.
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

User: *"Three custom software firms with healthcare-industry experience,
SOC 2-ready, ideally with at least a 4-star rating."*

```
# 1. Discover fields (once per session)
GET /v1/tags?include_values=1
# Confirms 'custom-software' is a valid service_provided tag, 'rating'
# is numeric, has:clutch is a presence flag.

# 2. Validate the filter and scope the pool (free, no auth)
GET /v1/check?filter=industry:it_services+service_provided:custom-software@high+healthcare+soc2+rating>=4
# → {"valid": true, "normalized": "..."}

GET /v1/explore?filter=industry:it_services+service_provided:custom-software@high+healthcare+soc2+rating>=4
# → {"count": 31, "breakdowns": {...}}

# 3. Search briefs
GET /v1/search?filter=...&limit=10
# Header: Authorization: Bearer $SERVICEGRAPH_TOKEN
# → 10 brief cards with service tags, size, state.

# 4. Present briefs to user, get their pick of 3.

# 5. Pull full bundles for the 3 picks
GET /v1/get/<firm_id>     # ×3
# → urls, phones, emails for outreach
```

End of session: report `X-Quota-Remaining-Month` so the user knows how
much budget is left.
