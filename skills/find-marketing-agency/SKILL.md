---
name: find-marketing-agency
description: Use whenever the user wants to find, shortlist, vet, or enrich US marketing agencies — including branding, content marketing, PPC/paid media, social media, email marketing, performance/demand-gen, video production, and full-service digital agencies. Triggers on requests like "shortlist three B2B branding agencies in California", "find a PPC shop with ecommerce experience", "we need a content marketing partner for a SaaS launch", or "pull contact info for these 12 agency domains", even when the need is described indirectly. Drives the ServiceGraph API (api.servicegraph.co) — a 100k+ US firm catalog filterable by industry, services, location, size, ratings, and third-party listings. Skip SEO-only asks (use find-seo-agency), web/software-development asks (use find-web-developer or find-software-developer), recruiting an in-house marketing hire, "write me a marketing plan" do-the-work asks, non-US firms, individual freelancers, marketing-software-product recommendations, and consumer/personal-brand asks.
license: MIT
metadata:
  api_base: https://api.servicegraph.co
  industry: marketing_agency
  version: "0.3"
---

# find-marketing-agency

Drive the **ServiceGraph API** (`https://api.servicegraph.co`) to find,
shortlist, and enrich US marketing agencies. The catalog has tens of
thousands of US marketing firms tagged across 26 service sub-tags
including branding, content-marketing, ppc, social-media-marketing,
email-marketing, web-design, video-production, inbound-marketing,
marketing-strategy, and conversion-optimization. (Note: the catalog has no
`performance-marketing` or `demand-gen` / `demand-generation` tag —
those user-phrasings map to `inbound-marketing` /
`marketing-strategy` / `conversion-optimization` plus a keyword
fallback.)

**Always pin `industry:marketing_agency` in the filter.** This skill
exists to do that automatically — the user shouldn't have to think
about catalog taxonomy.

Any HTTP client works (curl, fetch, requests). Examples below use curl.

## Sibling skills — defer when scope is narrow

If the user's ask is **strictly** one of the following, defer to the
dedicated skill:

- Strictly SEO/search-ranking work → `find-seo-agency`
- Strictly web/app/software development → `find-web-developer` /
  `find-software-developer`

If the user wants a marketing agency that *also* does SEO or web work
as part of a broader engagement, this skill is correct — pin
`industry:marketing_agency` and add the relevant `service_provided:`
tags.

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

Cache the response for the conversation. Confirm the marketing-relevant
service tags exist in the returned `service_provided` taxonomy
(branding, content-marketing, ppc, social-media-marketing,
email-marketing, video-production, inbound-marketing,
marketing-strategy, conversion-optimization, etc.) — names drift, and the parser
silently accepts unknown tags and returns zero results. Common
mis-mappings: there is no `performance-marketing`,
`demand-gen`, or `demand-generation` tag — use `inbound-marketing` /
`marketing-strategy` / `conversion-optimization` plus a keyword
fallback.

Field kinds you'll use most:
- **categorical**: `industry` (always `marketing_agency`), `state`, `pricing_model`, `company_size_signal`, `geography_served` — op `:`
- **tag_set_with_evidence**: `service_provided` — Map<tag, evidence∈{low,medium,high}>. Op `:` with optional `@evidence`
- **numeric**: `rating`, `review_count_total`, `founded_year` — ops `= >= <= > <`
- **presence**: `has:phone`, `has:clutch`, `has:rating`, `has:linkedin_company`, …
- **keyword**: free-text substring across firm name / brand / title / meta / legal_name. Any bareword in the filter becomes a keyword.

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
4. **Bareword = keyword search.** Any IDENT or NUMBER not followed by
   an operator becomes a free-text substring across name / brand /
   title / meta / legal_name. Multiple barewords AND.

**Marketing-flavored examples** (validate yours with `/v1/check`):

```
industry:marketing_agency service_provided:branding@high
industry:marketing_agency service_provided:ppc service_provided:content-marketing
industry:marketing_agency state:CA,NY -company_size_signal:solo
industry:marketing_agency (service_provided:inbound-marketing@high OR service_provided:marketing-strategy@high)
b2b industry:marketing_agency service_provided:content-marketing@high
industry:marketing_agency rating>=4 review_count_total>=20 has:clutch
industry:marketing_agency NOT (service_provided:seo OR service_provided:web-development)
```

When in doubt about whether a filter parses, hit `/v1/check?filter=...`
first — it's free and returns the canonical normalized form.

## firm_id contract

`firm_id` is a stable 12-hex-char handle:

```
firm_id = sha256(apex.lower().rstrip(".")).hexdigest()[:12]
```

`apex` is the registered domain (`ogilvy.com`, not
`www.ogilvy.com/about`). Anyone with an apex list can compute firm_ids
locally and call `/v1/get/:id` directly — no `/search` needed for BYO
enrichment.

```python
import hashlib
def firm_id(apex):
    return hashlib.sha256(apex.lower().rstrip(".").encode()).hexdigest()[:12]
```

```bash
echo -n "ogilvy.com" | tr 'A-Z' 'a-z' \
  | openssl dgst -sha256 -hex | awk '{print substr($2,1,12)}'
```

## Recipes

### A. Branding agency in a state

User: *"Three B2B branding agencies in California for a Series-A SaaS company."*

```
GET /v1/explore?filter=industry:marketing_agency+state:CA+service_provided:branding@high
# → pool size + breakdowns

GET /v1/search?filter=industry:marketing_agency+state:CA+service_provided:branding@high&limit=10
# → 10 brief cards; user picks 3

GET /v1/get/<firm_id>     # ×3
# → urls, phones, emails for outreach
```

### B. PPC + ecommerce vertical

User: *"PPC shop that specializes in ecommerce."*

The "ecommerce" qualifier is keyword-extracted from firm text since
client-vertical isn't a structured facet:

```
GET /v1/search?filter=industry:marketing_agency+service_provided:ppc+ecommerce&limit=10
```

### C. Multi-tag intersection — content + email + B2B vertical

User: *"Content marketing partner for a SaaS launch — should also do email."*

```
GET /v1/search?filter=industry:marketing_agency+service_provided:content-marketing@high+service_provided:email-marketing+saas
```

### D. Performance / demand-gen (indirect intent)

User: *"Someone to run our quarterly demand-gen campaigns and own the funnel."*

The catalog has **no** `performance-marketing` / `demand-gen` /
`demand-generation` tags — that user-phrasing maps to
`inbound-marketing`, `marketing-strategy`, or
`conversion-optimization`, plus a keyword fallback for the user's
exact wording:

```
GET /v1/search?filter=industry:marketing_agency+(service_provided:inbound-marketing@high OR service_provided:marketing-strategy@high OR service_provided:conversion-optimization@high)+(demand OR funnel)
```

If breakdowns come back thin, drop the `@high` evidence qualifier or
fall back to pure keyword: `demand industry:marketing_agency`.

### E. Quality threshold (third-party signals)

User: *"Compare three social media agencies that have worked with Fortune 500 — high evidence."*

```
GET /v1/search?filter=industry:marketing_agency+service_provided:social-media-marketing@high+rating>=4+review_count_total>=20+has:clutch&limit=10
```

`fortune 500` is hard to filter structurally; surface to the user in
the brief cards and let them pick from there, or add as a keyword
(`industry:marketing_agency service_provided:social-media-marketing@high fortune`).

### F. Video production

User: *"Video production studio for a 90-second product launch film, NYC or LA."*

```
GET /v1/search?filter=industry:marketing_agency+service_provided:video-production+state:NY,CA
```

The catalog uses one `state` per firm based on HQ; if the user wants
NYC specifically, use `state:NY` and surface the city to the user from
the `/get` bundle.

### G. BYO apex list — enrich domains the user already has

User pastes 8–20 domains. For each:

1. Compute `firm_id` locally (see contract above).
2. `GET /v1/get/<firm_id>` — full bundle if in catalog, 404 (not
   charged) if not.
3. Aggregate, present, flag the not-found ones to the user.

Useful for confirming whether a list of domains is actually in the
US marketing-agency catalog and pulling contact info in one pass.

## Gotchas

- **Always pin `industry:marketing_agency`.** Without it, `service_provided:branding` would match design firms, IT services, and others that also have branding tags. The industry pin is what makes this skill the marketing-agency skill.
- **Defer to sibling skills for narrow asks.** If the user asks strictly for "an SEO agency" with no other marketing scope, use `find-seo-agency`. If strictly web/app development, use `find-web-developer` / `find-software-developer`. This skill is for marketing engagements that span branding/content/paid/social/etc.
- **`looks_not_pro_services` 404 is not a bug.** A `firm_id` may exist in `/search` but 404 on `/get` if it's been flagged. Skip and continue; not charged.
- **`/v1/explore` k=20 suppression.** When fewer than 20 firms match, the response is `{"count": "<20", "suppressed": true, "breakdowns": {}}`. Drilling further makes the count smaller, not bigger. Broaden or escalate to `/v1/search`.
- **Briefs from `/search` do NOT include `apex`, `url`, `phone_primary`, `email_primary`, `legal_name`, or address.** If the user asks for contact info, you must `/get/:id`. Do not pretend to have it from the brief.
- **Catalog is US-only B2B.** Refuse non-US asks ("a luxury-brand agency in London"), individual freelancers, and personal-brand consulting for the user themselves.
- **Multi-word phrases must be split into separate barewords.** `b2b saas` parses as two AND'd keywords.
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

User: *"Shortlist three B2B branding agencies in California for a
Series-A SaaS company — high evidence on branding, ideally with at
least a 4-star rating."*

```
# 1. Discover fields (once per session)
GET /v1/tags?include_values=1
# Confirms 'branding' is a valid service_provided tag, 'rating' is numeric.

# 2. Validate the filter and scope the pool (free, no auth)
GET /v1/check?filter=industry:marketing_agency+state:CA+service_provided:branding@high+rating>=4+b2b
# → {"valid": true, "normalized": "..."}

GET /v1/explore?filter=industry:marketing_agency+state:CA+service_provided:branding@high+rating>=4+b2b
# → {"count": 38, "breakdowns": {...}}

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
