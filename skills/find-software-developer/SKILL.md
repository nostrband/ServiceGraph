---
name: find-software-developer
description: Use whenever the user wants to find, shortlist, vet, or enrich US software development firms — custom software, web development, mobile app development, backend/API development, DevOps/cloud, system integration, and hosting. Triggers on "find a software dev shop in Austin", "shortlist three custom-software firms with healthcare experience", "we need a mobile app developer for our iOS launch", or "pull contact info for these 10 dev shop domains", even when described indirectly (build a tool, ship a feature, technical partner). Drives the ServiceGraph API (api.servicegraph.co) — a 100k+ US firm catalog filterable by industry, services, location, size, ratings. Defer to find-web-developer for strictly website/landing-page projects. Defer AI/ML, ML pipelines, model building, and data-engineering asks — those are a sibling industry, not software development. Skip in-house engineer hires, code-writing/debugging tasks, cloud-product comparisons, hardware/civil engineering, non-US firms, individual freelancers.
license: MIT
metadata:
  api_base: https://api.servicegraph.co
  industry: it_services
  version: "0.3"
---

# find-software-developer

Drive the **ServiceGraph API** (`https://api.servicegraph.co`) to find,
shortlist, and enrich US software development firms. The catalog has
tens of thousands of US IT-services firms tagged across 21 service
sub-tags including web-development, mobile-app-development,
api-integration, devops-services, cloud-services, system-integration,
application-modernization, staff-augmentation, and managed-services.
(Note: there is no `custom-software` or `hosting` tag — for those
user-facing concepts, pin `system-integration` or `application-
modernization` as the closest tag and add keywords like `custom`,
`software`, `hosting`.)

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

Install (one-time, per harness):

- Claude Code: `claude mcp add --transport http servicegraph https://mcp.servicegraph.co`
- Cursor / Codex / ChatGPT Connectors: paste `https://mcp.servicegraph.co` as the server URL.

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

Cache the response for the conversation. Confirm IT-relevant tags
exist in the returned `service_provided` taxonomy (web-development,
mobile-app-development, api-integration, devops-services,
cloud-services, system-integration, application-modernization,
staff-augmentation, managed-services). Note the catalog has **no**
`custom-software` or `hosting` tags — those are user-facing concepts
that map to `system-integration` / `application-modernization` plus
keyword. The parser silently accepts unknown tags and returns zero
results, so verify before pinning.

Field kinds you'll use most:
- **categorical**: `industry` (always `it_services`), `state`, `pricing_model`, `company_size_signal`, `geography_served` — op `:`
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

**IT-flavored examples** (validate yours with `/v1/check`):

```
industry:it_services custom software state:TX
industry:it_services service_provided:mobile-app-development
industry:it_services service_provided:devops-services aws
industry:it_services service_provided:api-integration fintech
industry:it_services python aws state:CA
industry:it_services service_provided:system-integration@high rating>=4 has:clutch
industry:it_services service_provided:application-modernization legacy
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
GET /v1/explore?filter=industry:it_services+service_provided:system-integration@high+custom+software+state:TX
# → pool size + breakdowns

GET /v1/search?filter=industry:it_services+service_provided:system-integration@high+custom+software+state:TX&limit=10
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
GET /v1/search?filter=industry:it_services+service_provided:devops-services+aws+migration
```

If breakdowns come back thin, drop `migration` first — it's a vertical
keyword, not a service tag.

### D. Indirect intent — "technical partner to build out tooling"

User: *"We need a technical partner to build out our internal tooling,
Northeast preferred."*

That's a custom-software ask. Translate:

```
GET /v1/search?filter=industry:it_services+custom+software+state:NY,MA,CT,NJ,PA
# → 10 brief cards; user narrows
```

### E. Vertical + cert (fintech + SOC 2)

User: *"Software houses that specialize in fintech and have SOC 2 readiness."*

`fintech` and `soc2` are not structured facets — keyword them:

```
GET /v1/search?filter=industry:it_services+custom+software+fintech+soc2
```

### F. Quality threshold + third-party signals

User: *"Three custom software firms with at least 4-star ratings, 50+ reviews."*

```
GET /v1/search?filter=industry:it_services+service_provided:system-integration@high+custom+software+rating>=4+review_count_total>=50&limit=10
```

### G. API/backend specialty + remote

User: *"API/backend team to extend our SaaS — Bay Area or remote-friendly."*

`remote-friendly` isn't structured. Use `geography_served:national_US`
(a national-scope firm is more likely to serve remotely) and add
`api` / `backend` keywords:

```
GET /v1/search?filter=industry:it_services+service_provided:api-integration+(state:CA OR geography_served:national_US)+saas
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

- **Always pin `industry:it_services`.** Without it, `web-development` / `mobile-app-development` keywords leak into marketing or design firms that also offer software-adjacent services.
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
# Confirms 'system-integration' is a valid service_provided tag, 'rating'
# is numeric, has:clutch is a presence flag.

# 2. Validate the filter and scope the pool (free, no auth)
GET /v1/check?filter=industry:it_services+service_provided:system-integration@high+custom+software+healthcare+soc2+rating>=4
# → {"valid": true, "normalized": "..."}

GET /v1/explore?filter=industry:it_services+service_provided:system-integration@high+custom+software+healthcare+soc2+rating>=4
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
