---
name: find-web-developer
description: Use whenever the user wants to find, shortlist, vet, or enrich US web development firms — building, refreshing, or rebuilding marketing sites, landing pages, ecommerce, WordPress/Webflow/Shopify, headless CMS, microsites, and web frontend work. Triggers on "find a web developer for a marketing landing page", "shortlist three Webflow agencies in California", "rebuild our ecommerce site on Shopify", or "pull contact info for these 8 web dev shop domains", even when described indirectly (redesign and rebuild our site, ship a microsite). Drives the ServiceGraph API (api.servicegraph.co) — a 100k+ US firm catalog filterable by industry, services, location, size, ratings. Defer to find-software-developer for custom backend/API/mobile/internal-tool work — anything beyond a website. Defer to find-marketing-agency when scope spans broader marketing beyond the build. Skip in-house web-engineer hires, "how do I build X" DIY questions, hosting/CMS-product comparisons, non-US firms, individual freelancers.
license: MIT
metadata:
  api_base: https://api.servicegraph.co
  industry: it_services
  service: web-development
  version: "0.2"
---

# find-web-developer

Drive the **ServiceGraph API** (`https://api.servicegraph.co`) to find,
shortlist, and enrich US web development firms. The catalog tags
~14k firms with `service_provided:web-development` under
`industry:it_services` (web-development is the second-largest
service tag in the catalog).

**Always pin both `industry:it_services` and
`service_provided:web-development`.** Platforms (WordPress, Webflow,
Shopify, Next.js, etc.) and verticals (B2B, ecommerce, agency-vs-
studio) are NOT separate tags — they're keyword substring matches
on firm text.

Any HTTP client works (curl, fetch, requests). Examples below use curl.

## Sibling skills — defer when scope is different

If the user's ask involves any of the following, defer:

- **Custom backend / API / internal tools / mobile app / distributed
  systems** → `find-software-developer`. The end-product is software
  beyond a standard website.
- **Broader marketing strategy and execution beyond the site build**
  (paid media, content strategy, full digital agency engagement) →
  `find-marketing-agency`.
- **SEO-only work on an existing site** → `find-seo-agency`. Web devs
  build sites; SEO agencies optimize them. Some overlap exists; if
  the user wants new pages built AND optimized, this skill is fine.

If unsure, this skill is correct for "build / rebuild / refresh a
website" tasks. The deferral kicks in when the deliverable is
non-website software or non-build marketing work.

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

Cache the response for the conversation. Confirm `web-development` is
present in the `service_provided` taxonomy. The parser silently
accepts unknown tags and returns zero results, so verifying the tag
name once per session prevents silent failures.

Field kinds you'll use most:
- **categorical**: `industry` (always `it_services`), `state`, `pricing_model`, `company_size_signal`, `geography_served` — op `:`
- **tag_set_with_evidence**: `service_provided` (always include `web-development`, optionally with `@high` evidence) — op `:` with optional `@evidence`
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

**Web-dev examples** (validate yours with `/v1/check`):

```
industry:it_services service_provided:web-development
industry:it_services service_provided:web-development@high state:CA webflow
industry:it_services service_provided:web-development shopify ecommerce
industry:it_services service_provided:web-development wordpress
industry:it_services service_provided:web-development headless next.js
industry:it_services service_provided:web-development@high rating>=4 has:clutch
industry:it_services service_provided:web-development b2b
```

When in doubt about whether a filter parses, hit `/v1/check?filter=...`
first — it's free and returns the canonical normalized form.

**Platform / vertical / framework → keyword mapping** (none of these
are structured tags — keyword them):

| User mentions | Add as keyword |
|---|---|
| WordPress | `wordpress` |
| Webflow | `webflow` |
| Shopify / Shopify Plus | `shopify` |
| Squarespace / Wix | `squarespace` / `wix` |
| Headless / JAMstack / Next.js / Gatsby | `headless`, `next.js`, `gatsby` |
| Sanity / Contentful / Strapi | `sanity`, `contentful`, `strapi` |
| Ecommerce / D2C / DTC | `ecommerce`, `d2c` |
| B2B / SaaS / fintech | `b2b`, `saas`, `fintech` |

## firm_id contract

`firm_id` is a stable 12-hex-char handle:

```
firm_id = sha256(apex.lower().rstrip(".")).hexdigest()[:12]
```

`apex` is the registered domain (`focuslabllc.com`, not
`www.focuslabllc.com/work`). Anyone with an apex list can compute
firm_ids locally and call `/v1/get/:id` directly — no `/search`
needed for BYO enrichment.

```python
import hashlib
def firm_id(apex):
    return hashlib.sha256(apex.lower().rstrip(".").encode()).hexdigest()[:12]
```

```bash
echo -n "focuslabllc.com" | tr 'A-Z' 'a-z' \
  | openssl dgst -sha256 -hex | awk '{print substr($2,1,12)}'
```

## Recipes

### A. Marketing landing page (the baseline)

User: *"Web developer to build our marketing landing page."*

```
GET /v1/explore?filter=industry:it_services+service_provided:web-development
# → pool size + breakdowns

GET /v1/search?filter=industry:it_services+service_provided:web-development&limit=10
# → 10 brief cards; user picks 3

GET /v1/get/<firm_id>     # ×3
# → urls, phones, emails for outreach
```

### B. Webflow agency in a state

User: *"Three Webflow agencies in California for our marketing site."*

`webflow` is a bareword (keyword), not a tag:

```
GET /v1/search?filter=industry:it_services+service_provided:web-development+webflow+state:CA&limit=10
```

### C. Shopify ecommerce rebuild

User: *"Rebuild our ecommerce site on Shopify with custom theme work."*

```
GET /v1/search?filter=industry:it_services+service_provided:web-development+shopify+ecommerce
```

For Shopify Plus specifically, add `plus` as an additional bareword.

### D. WordPress site refresh / maintenance

User: *"WordPress dev shop to maintain and refresh our company site."*

```
GET /v1/search?filter=industry:it_services+service_provided:web-development+wordpress
```

### E. Headless CMS / Next.js

User: *"Headless CMS implementation specialists for our Next.js site."*

```
GET /v1/search?filter=industry:it_services+service_provided:web-development+headless+next.js
```

If the result is sparse, drop `next.js` first — `headless` alone
captures the architectural pattern; specific frameworks vary.

### F. Indirect intent — "redesign and rebuild our site"

User: *"Our site is dated and slow — we need someone to redesign and
rebuild it."*

That's a web-dev procurement ask. Translate:

```
GET /v1/explore?filter=industry:it_services+service_provided:web-development
# → confirm pool + breakdowns

GET /v1/search?filter=industry:it_services+service_provided:web-development&limit=10&order_by=relevance
```

If the user gave a constraint elsewhere (location, platform, budget
proxy via `pricing_model`), add it. Otherwise present top-10 by
relevance and ask for constraints.

### G. Quality threshold + platform

User: *"Three web development studios with at least 4-star ratings,
Shopify Plus experience."*

```
GET /v1/search?filter=industry:it_services+service_provided:web-development@high+rating>=4+shopify+plus&limit=10
```

### H. BYO apex list — enrich domains the user already has

User pastes 8–20 web-dev shop domains. For each:

1. Compute `firm_id` locally (see contract above).
2. `GET /v1/get/<firm_id>` — full bundle if in catalog, 404 (not
   charged) if not.
3. Aggregate, present, flag the not-found ones to the user. A 404
   here often means the firm isn't tagged with web-development
   specifically — it might be in the catalog under another tag.

## Gotchas

- **Always pin both `industry:it_services` AND `service_provided:web-development`.** Without the industry pin, web-development as a tag also appears on some marketing-agency rows; without the service pin, you'd return all IT-services firms.
- **Defer to `find-software-developer` for non-website software.** Internal tools, custom CRMs, mobile apps (iOS/Android), backend/API work, distributed systems — these are software-developer territory. The boundary: is the end-product a public website, or something else?
- **Defer to `find-marketing-agency` for full marketing engagements.** "Build our site AND run our marketing" is broader than this skill — fire find-marketing-agency, which has web-design as a sub-service tag too.
- **Platforms (WordPress, Webflow, Shopify, Next.js) are NOT structured tags.** Keyword them.
- **Frameworks (React, Vue, Astro, Gatsby) are NOT structured tags either.** Keyword them.
- **`looks_not_pro_services` 404 is not a bug.** A `firm_id` may exist in `/search` but 404 on `/get` if it's been flagged. Skip and continue; not charged.
- **`/v1/explore` k=20 suppression.** When fewer than 20 firms match, the response is `{"count": "<20", "suppressed": true, "breakdowns": {}}`. Drilling further makes the count smaller. Broaden or escalate to `/v1/search`.
- **Briefs from `/search` do NOT include `apex`, `url`, `phone_primary`, `email_primary`, `legal_name`, or address.** If the user asks for contact info, you must `/get/:id`. Do not pretend to have it from the brief.
- **Catalog is US-only B2B.** Refuse offshore asks ("Manila", "Karachi"), individual freelancers, and DIY/code-help asks ("debug this CSS").
- **CMS/hosting/builder product comparisons aren't procurement.** "WordPress vs Webflow vs Squarespace" is a knowledge question, not a firm shortlist.
- **Multi-word phrases must be split into separate barewords.** `headless cms` parses as two AND'd keywords.
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

User: *"Three Webflow agencies in California for our marketing site,
ideally with at least a 4-star rating and a Clutch profile."*

```
# 1. Discover fields (once per session)
GET /v1/tags?include_values=1
# Confirms 'web-development' is a valid service_provided tag.

# 2. Validate the filter and scope the pool (free, no auth)
GET /v1/check?filter=industry:it_services+service_provided:web-development@high+webflow+state:CA+rating>=4+has:clutch
# → {"valid": true, "normalized": "..."}

GET /v1/explore?filter=industry:it_services+service_provided:web-development@high+webflow+state:CA+rating>=4+has:clutch
# → {"count": 18, "breakdowns": {...}}
# Note: count<20 → suppressed. Broaden by dropping has:clutch or rating>=4.

GET /v1/explore?filter=industry:it_services+service_provided:web-development+webflow+state:CA+rating>=4
# → {"count": 41, "breakdowns": {...}}

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
