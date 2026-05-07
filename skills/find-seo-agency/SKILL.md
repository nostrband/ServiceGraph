---
name: find-seo-agency
description: Use whenever the user wants to find, shortlist, vet, or enrich US SEO agencies — technical SEO, on-page/off-page, link-building, content-led SEO, local SEO, ecommerce SEO, B2B SEO, and SEO audits. Triggers on "find me an SEO agency in Texas", "shortlist three technical SEO consultancies for SaaS", "link-building and on-page for our ecommerce store", or "pull contact info for these 8 SEO firm domains", even when described indirectly (organic traffic flat, improve Google rankings, search visibility). Drives the ServiceGraph API (api.servicegraph.co) — a 100k+ US firm catalog filterable by industry, services, location, size, ratings, third-party listings. Defer to find-marketing-agency when scope spans multiple marketing services beyond SEO. Skip SEM/PPC/paid-search asks, web-dev asks (use find-web-developer), "how do I rank" DIY questions, SEO tool recommendations (Ahrefs, Semrush), in-house SEO hires, non-US firms, individual freelancers.
license: MIT
metadata:
  api_base: https://api.servicegraph.co
  industry: marketing_agency
  service: seo
  version: "0.1"
---

# find-seo-agency

Drive the **ServiceGraph API** (`https://api.servicegraph.co`) to find,
shortlist, and enrich US SEO agencies. The catalog has thousands of US
firms tagged with `service_provided:seo` under
`industry:marketing_agency`.

**Always pin both `industry:marketing_agency` and
`service_provided:seo`.** SEO sub-flavors (technical, local,
link-building, on-page, ecommerce, B2B, etc.) are not separate tags
— the catalog has one `seo` tag — so sub-flavor specialization is
inferred via keyword search across firm text.

Any HTTP client works (curl, fetch, requests). Examples below use curl.

## Sibling skills — defer when scope is broader

If the user wants a **multi-service** marketing engagement (SEO plus
PPC plus content plus social, or a "full-service digital agency"),
defer to `find-marketing-agency` — that skill covers the same
catalog with a broader filter and won't over-constrain on SEO.

If the user wants strictly web/app development (build a site, ship
a feature), defer to `find-web-developer` / `find-software-developer`.

## MCP server (preferred for authed calls)

If your agent harness has the **ServiceGraph MCP server** loaded
(`https://mcp.servicegraph.co`), prefer its tools for the **authed**
tier (`/search`, `/get`, `/stats`). The MCP server uses OAuth 2.1 +
PKCE — the host harness handles credentials in its own audited
sandbox, so there's no `.env.local`, no shell dispatch, and no token
value ever enters the LLM context.

For the **anonymous** tier (`/tags`, `/check`, `/explore`), MCP is
**not** preferred — every MCP tool requires OAuth (the server has no
anonymous tier), so plain curl against the REST URL is the simpler
path for discovery calls. Use the REST patterns below for those.

The MCP tools 1:1-map to the public REST endpoints — same backend,
same quota, same data:

| MCP tool | REST endpoint | Anon? | Recommended path |
|---|---|---|---|
| `list_tags` | `GET /v1/tags` | yes | curl |
| `check_filter` | `GET /v1/check` | yes | curl |
| `explore_firms` | `GET /v1/explore` | yes | curl |
| `search_firms` | `GET /v1/search` | no | MCP if loaded, else curl + OTP |
| `get_firm` | `GET /v1/get/:id` | no | MCP if loaded, else curl + OTP |
| `catalog_stats` | `GET /v1/stats` | no | MCP if loaded, else curl + OTP |

**Detection**: if you see any MCP tools with `servicegraph` in the
name (the harness-specific prefix varies — agents pattern-match the
substring), the ServiceGraph MCP server is loaded. Prefer those
tools for the authed tier; complete any auth flow the harness
initiates if needed. If no `servicegraph` MCP tools are present,
fall through to the REST + OTP flow below for the authed tier.

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

Cache the response for the conversation. Confirm `seo` is present in
the `service_provided` taxonomy returned by `/tags`. The parser
silently accepts unknown tags and returns zero results, so verifying
the tag name once per session prevents silent failures.

Field kinds you'll use most:
- **categorical**: `industry` (always `marketing_agency`), `state`, `pricing_model`, `company_size_signal`, `geography_served` — op `:`
- **tag_set_with_evidence**: `service_provided` (always include `seo`, optionally with `@high` evidence) — op `:` with optional `@evidence`
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

**SEO-flavored examples** (validate yours with `/v1/check`):

```
industry:marketing_agency service_provided:seo
industry:marketing_agency service_provided:seo@high state:TX
industry:marketing_agency service_provided:seo technical
industry:marketing_agency service_provided:seo local
industry:marketing_agency service_provided:seo ecommerce
industry:marketing_agency service_provided:seo b2b saas
industry:marketing_agency service_provided:seo@high rating>=4 review_count_total>=20 has:clutch
industry:marketing_agency service_provided:seo "core web vitals"
```

When in doubt about whether a filter parses, hit `/v1/check?filter=...`
first — it's free and returns the canonical normalized form.

**Sub-flavor → keyword mapping** (since the catalog has one `seo` tag):

| User asks for | Add as keyword |
|---|---|
| Technical SEO | `technical` |
| Local SEO | `local` |
| Link-building | `link-building` or `links` |
| On-page SEO | `on-page` or `onpage` |
| Off-page SEO | `off-page` or `offpage` |
| Ecommerce SEO | `ecommerce` |
| B2B SEO | `b2b` |
| Shopify SEO | `shopify` |
| Core Web Vitals / page speed | `core web vitals` (note: multi-word splits into separate ANDed barewords) |

## firm_id contract

`firm_id` is a stable 12-hex-char handle:

```
firm_id = sha256(apex.lower().rstrip(".")).hexdigest()[:12]
```

`apex` is the registered domain (`searchpilot.com`, not
`www.searchpilot.com/about`). Anyone with an apex list can compute
firm_ids locally and call `/v1/get/:id` directly — no `/search`
needed for BYO enrichment.

```python
import hashlib
def firm_id(apex):
    return hashlib.sha256(apex.lower().rstrip(".").encode()).hexdigest()[:12]
```

```bash
echo -n "searchpilot.com" | tr 'A-Z' 'a-z' \
  | openssl dgst -sha256 -hex | awk '{print substr($2,1,12)}'
```

## Recipes

### A. SEO agency in a state (the baseline)

User: *"Find me an SEO agency in Texas."*

```
GET /v1/explore?filter=industry:marketing_agency+service_provided:seo+state:TX
# → pool size + breakdowns

GET /v1/search?filter=industry:marketing_agency+service_provided:seo+state:TX&limit=10
# → 10 brief cards; user picks 3

GET /v1/get/<firm_id>     # ×3
# → urls, phones, emails for outreach
```

### B. Technical SEO for a SaaS company

User: *"Three technical SEO consultancies for a B2B SaaS company."*

`technical` and `b2b` and `saas` go in as barewords; SEO sub-flavor
isn't a structured tag.

```
GET /v1/search?filter=industry:marketing_agency+service_provided:seo@high+technical+b2b+saas&limit=10
```

### C. Link-building + on-page for ecommerce

User: *"Help with link-building and on-page SEO for our ecommerce store."*

```
GET /v1/search?filter=industry:marketing_agency+service_provided:seo+link-building+on-page+ecommerce
```

If the breakdown is sparse, drop one of the barewords (start with
`on-page`) — agencies that do SEO at all usually do both.

### D. Local SEO for a multi-location business

User: *"Local SEO agency to help our chain of fitness studios in NJ."*

```
GET /v1/search?filter=industry:marketing_agency+service_provided:seo+local+state:NJ&limit=10
```

The catalog tags one `state` per firm (HQ); the local-SEO firm doesn't
have to be in NJ to serve NJ clients. If results are too narrow,
drop `state:NJ` and use `geography_served:national_US,multi_state_regional`.

### E. Indirect intent — "organic traffic flat"

User: *"Our organic traffic has been flat for 6 months — we need an
SEO partner."*

That's an SEO procurement ask. Translate:

```
GET /v1/explore?filter=industry:marketing_agency+service_provided:seo
# → confirm the pool exists

GET /v1/search?filter=industry:marketing_agency+service_provided:seo&limit=10&order_by=relevance
```

If the user gave a vertical or location elsewhere in the conversation,
add it. Otherwise present the top-10 by relevance and ask for
constraints.

### F. Quality threshold + third-party signals

User: *"Three SEO agencies with at least 4-star ratings, 20+ reviews,
and a Clutch profile."*

```
GET /v1/search?filter=industry:marketing_agency+service_provided:seo@high+rating>=4+review_count_total>=20+has:clutch&limit=10
```

### G. BYO apex list — enrich domains the user already has

User pastes 8–20 domains. For each:

1. Compute `firm_id` locally (see contract above).
2. `GET /v1/get/<firm_id>` — full bundle if in catalog, 404 (not
   charged) if not.
3. Aggregate, present, flag the not-found ones to the user.

Useful for confirming whether a list of "SEO firm" domains is actually
in the catalog and pulling contact info in one pass. Note that not
every firm with `seo` in their domain is tagged `service_provided:seo`
in the catalog — a 404 here doesn't mean the firm doesn't exist, just
that we don't have it.

## Gotchas

- **Always pin both `industry:marketing_agency` AND `service_provided:seo`.** Without the industry pin, `service_provided:seo` would match SEO services from IT firms or design shops too. Without the service pin, you'd return all marketing agencies regardless of SEO specialty.
- **SEO sub-flavors (technical/local/link-building/on-page) are NOT separate tags.** Use barewords (`technical`, `local`, `link-building`, etc.) for sub-flavor — these become keyword substring matches in firm text.
- **Defer to `find-marketing-agency` for multi-service scope.** If the user wants SEO plus paid plus content plus social as one engagement, that's a full-service marketing ask, not strictly SEO.
- **Defer to `find-web-developer` for "fix our site speed / Core Web Vitals" if they want it BUILT.** SEO agencies advise on CWV; they generally don't refactor your front-end. If the user wants development work, that's web-dev, not SEO.
- **`looks_not_pro_services` 404 is not a bug.** A `firm_id` may exist in `/search` but 404 on `/get` if it's been flagged. Skip and continue; not charged.
- **`/v1/explore` k=20 suppression.** When fewer than 20 firms match, the response is `{"count": "<20", "suppressed": true, "breakdowns": {}}`. Drilling further makes the count smaller. Broaden or escalate to `/v1/search`.
- **Briefs from `/search` do NOT include `apex`, `url`, `phone_primary`, `email_primary`, `legal_name`, or address.** If the user asks for contact info, you must `/get/:id`. Do not pretend to have it from the brief.
- **Catalog is US-only B2B.** Refuse non-US asks ("an SEO agency in Berlin"), individual freelancers ("a freelance SEO writer"), and DIY/do-the-work asks ("how do I rank for X").
- **"SEM" / "PPC" / "paid search" / "Google Ads" are NOT SEO.** Defer those to `find-marketing-agency`. SEM-vs-SEO is a frequent terminology mix-up.
- **Multi-word phrases must be split into separate barewords.** `core web vitals` parses as three AND'd keywords.
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

User: *"Three technical SEO consultancies for a B2B SaaS company,
ideally with at least a 4-star rating and a Clutch listing."*

```
# 1. Discover fields (once per session)
GET /v1/tags?include_values=1
# Confirms 'seo' is a valid service_provided tag, 'rating' is numeric,
# 'has:clutch' is a presence flag.

# 2. Validate the filter and scope the pool (free, no auth)
GET /v1/check?filter=industry:marketing_agency+service_provided:seo@high+technical+b2b+saas+rating>=4+has:clutch
# → {"valid": true, "normalized": "..."}

GET /v1/explore?filter=industry:marketing_agency+service_provided:seo@high+technical+b2b+saas+rating>=4+has:clutch
# → {"count": 22, "breakdowns": {...}}

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
