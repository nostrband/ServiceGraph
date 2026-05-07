---
name: find-design-agency
description: Use whenever the user wants to find, shortlist, vet, or enrich US design and creative agencies — graphic design, UX/UI, product design, brand identity, packaging, illustration, motion design, and creative direction. Triggers on "find me a UX/UI design agency for our SaaS product", "shortlist three brand-identity studios in NY", "packaging design firm for a CPG launch", or "pull contact info for these 10 design studio domains", even when described indirectly (brand refresh, design our app, build our visual system). Drives the ServiceGraph API (api.servicegraph.co) — a 100k+ US firm catalog filterable by industry, services, location, size, ratings. Defer to find-marketing-agency for marketing-led engagements where design is one of several services. Defer to find-web-developer when the deliverable is a built website. Skip in-house designer hires, "design me a logo" DIY asks, design-software comparisons, consumer/personal-design (weddings, hobby projects), non-US firms, individual freelancers.
license: MIT
metadata:
  api_base: https://api.servicegraph.co
  industry: design_creative
  version: "0.2"
---

# find-design-agency

Drive the **ServiceGraph API** (`https://api.servicegraph.co`) to find,
shortlist, and enrich US design and creative agencies. The catalog
tags firms with `industry:design_creative` and a 13-tag service
sub-taxonomy spanning graphic design, UX/UI, product design,
industrial design, brand identity, packaging, illustration, motion,
and creative direction.

**Always pin `industry:design_creative`.** Sub-disciplines are
typically structured `service_provided` tags (`graphic-design`,
`ui-ux-design`, `product-design`, `branding`, etc.) — confirm exact
names via `/v1/tags`.

Any HTTP client works (curl, fetch, requests). Examples below use curl.

## Sibling skills — defer when scope is different

- **Marketing-led engagements** where design is one of several
  services (PR + content + paid + design) → `find-marketing-agency`.
  This skill is for **design-led** engagements where the design work
  IS the primary deliverable.
- **Build-the-website work** (coded marketing site, ecommerce store,
  custom CMS) → `find-web-developer`. Design agencies often partner
  with web devs on builds; if the user wants someone to ship the
  built artifact, fire web-developer.
- **Custom software with design needs** (SaaS app, internal tool with
  UX work) → `find-software-developer` is the right fire when the
  deliverable is software. Pure design (Figma files, brand systems,
  print collateral) stays here.

If the deliverable is **design output** (visual systems, UX
prototypes, brand guidelines, packaging artwork, motion frames, print
files) and the user is procuring a firm to produce it, this skill
applies.

## When NOT to use this skill

- **Consumer/personal design** — weddings, hobby projects, Etsy side
  projects, custom holiday cards, personal portfolio sites for an
  individual. The catalog is B2B procurement only.
- **DIY** — "design me a logo", "make me a hero illustration",
  "redesign my app's onboarding flow". Refuse and offer to find a
  firm if they want to engage one.
- **In-house designer hires** (Lead Designer, UX Researcher, Brand
  Designer).
- **Design-software product comparisons** (Figma vs Sketch vs Adobe
  XD vs Penpot, Webflow vs Framer, etc.).
- **Knowledge questions** ("explain the difference between UX and
  UI").
- **Non-US firms** / **individual freelance designers**.

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

Cache the response for the conversation. Confirm `design_creative` is
in the `industry` value list and that the relevant sub-discipline tags
(`graphic-design`, `ui-ux-design`, `product-design`, `branding`,
`packaging-design`, `motion-design`, `illustration`, etc.) are in
`service_provided`. Tag names sometimes drift; verify before
constructing filters.

Field kinds you'll use most:
- **categorical**: `industry` (always `design_creative`), `state`, `pricing_model`, `company_size_signal`, `geography_served` — op `:`
- **tag_set_with_evidence**: `service_provided` (e.g. `graphic-design`, `ui-ux-design`, `branding`) — op `:` with optional `@evidence`
- **numeric**: `rating`, `review_count_total`, `founded_year` — ops `= >= <= > <`
- **presence**: `has:phone`, `has:clutch`, `has:rating`, `has:linkedin_company`, …
- **keyword**: free-text substring across firm name / brand / title / meta / legal_name. **Verticals (SaaS, fintech, healthcare, CPG, hospitality) and credentials (AIGA, Awwwards) are keyword-only.**

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

**Design-flavored examples** (validate yours with `/v1/check`):

```
industry:design_creative service_provided:ui-ux-design saas
industry:design_creative service_provided:branding state:NY
industry:design_creative service_provided:packaging-design cpg
industry:design_creative service_provided:product-design hardware
industry:design_creative service_provided:graphic-design annual report
industry:design_creative motion animation
industry:design_creative service_provided:branding@high rating>=4 has:clutch
industry:design_creative service_provided:ui-ux-design@high fortune
```

When in doubt, hit `/v1/check?filter=...` first.

**Sub-discipline → tag mapping** (verify exact names via `/v1/tags`):

| User asks for | Use |
|---|---|
| Graphic design (logos, print, layouts) | `service_provided:graphic-design` |
| Logo design specifically | `service_provided:logo-design` |
| UX/UI design (digital products) | `service_provided:ui-ux-design` |
| Product design (digital + research) | `service_provided:product-design` |
| Brand identity / visual identity | `service_provided:branding` |
| Packaging design | `service_provided:packaging-design` |
| Print design / collateral | `service_provided:print-design` |
| Web design (visual) | `service_provided:web-design` (distinct from `service_provided:web-development` which is build) |
| Interior design | `service_provided:interior-design` |
| Illustration / motion design / creative direction | **no structured tag** — keyword-only (`illustration`, `motion`, `animation`, `creative direction`) |
| Industrial design (physical products) | **no structured tag** — closest is `service_provided:product-design` plus keyword `hardware` / `industrial` |

Verticals (SaaS, fintech, healthcare-tech, CPG, hospitality, etc.)
and design-system credentials (AIGA, Awwwards-recognized) are
keyword-only.

## firm_id contract

`firm_id` is a stable 12-hex-char handle:

```
firm_id = sha256(apex.lower().rstrip(".")).hexdigest()[:12]
```

```python
import hashlib
def firm_id(apex):
    return hashlib.sha256(apex.lower().rstrip(".").encode()).hexdigest()[:12]
```

```bash
echo -n "ideo.com" | tr 'A-Z' 'a-z' \
  | openssl dgst -sha256 -hex | awk '{print substr($2,1,12)}'
```

## Recipes

### A. UX/UI for a SaaS product

User: *"UX/UI design agency for our SaaS product."*

```
GET /v1/explore?filter=industry:design_creative+service_provided:ui-ux-design+saas
GET /v1/search?filter=industry:design_creative+service_provided:ui-ux-design+saas&limit=10
GET /v1/get/<firm_id>     # ×3
```

### B. Brand-identity studio in a state

User: *"Three brand-identity studios in NY for our rebrand."*

```
GET /v1/search?filter=industry:design_creative+service_provided:branding+state:NY+-company_size_signal:large_50plus&limit=10
```

`-large_50plus` keeps the result list to studio-size shops (rebranding
typically happens with boutique studios, not 100-person agencies).

### C. Packaging for CPG

User: *"Packaging design firm for a CPG launch."*

```
GET /v1/search?filter=industry:design_creative+service_provided:packaging-design+(cpg OR consumer)
```

### D. Product design with hardware experience

User: *"Product design consultancy with hardware experience."*

```
GET /v1/search?filter=industry:design_creative+service_provided:product-design+hardware+industrial
```

### E. Indirect intent — "design our visual identity and packaging"

User: *"We need someone to design the visual identity and packaging
for our new line of beverages."*

That's a brand+packaging engagement:

```
GET /v1/search?filter=industry:design_creative+(service_provided:branding+service_provided:packaging-design)+(beverage OR cpg)
```

If the result list is thin, drop one of the structured tags (start
with packaging-design) — many brand-identity studios deliver
packaging as part of the system.

### F. Graphic design for corporate use cases

User: *"Graphic design firms experienced with annual reports and
investor decks."*

```
GET /v1/search?filter=industry:design_creative+service_provided:graphic-design+(annual OR investor OR corporate)
```

### G. Quality threshold + Fortune 500 clients

User: *"Three UX/UI agencies with at least 4-star ratings and Fortune
500 clients."*

```
GET /v1/search?filter=industry:design_creative+service_provided:ui-ux-design@high+rating>=4+fortune&limit=10
```

### H. Brand-system overhaul

User: *"Creative agency for a brand system overhaul — logo,
typography, color, voice."*

```
GET /v1/search?filter=industry:design_creative+service_provided:branding@high
```

If find-marketing-agency seems closer (the user mentioned "voice" /
copywriting), the line is fuzzy — branding firms usually deliver voice
guidelines as part of brand system. Stay here unless the user
explicitly asks for marketing strategy / campaigns.

### I. BYO apex list — enrich domains

User pastes 8–20 design firm domains. For each:

1. Compute `firm_id` locally.
2. `GET /v1/get/<firm_id>` — full bundle if in catalog, 404 if not.
3. Aggregate, present, flag the not-found ones to the user.

A 404 here often means the firm is tagged under
`industry:marketing_agency` instead — design and marketing overlap
heavily in the catalog, and some shops self-classify as marketing.

## Gotchas

- **Always pin `industry:design_creative`.** Without it, design-related keywords (branding, ui-ux-design) appear in marketing_agency rows too.
- **Defer to `find-marketing-agency` for marketing-led engagements.** If the user wants brand + content + paid + social as one engagement, that's marketing-agency territory. This skill is for design-primary engagements.
- **Defer to `find-web-developer` for the build phase.** Design agencies make Figma files; web devs ship code. If the user wants the built artifact, fire web-developer.
- **Refuse consumer-personal design.** Weddings, custom holiday cards, hobby Etsy logos, personal portfolio sites — not in catalog. Tell the user the catalog is B2B-only.
- **DIY asks** ("design me a logo", "make a hero image") are NOT procurement.
- **Design-software comparisons** (Figma vs Sketch, Adobe vs Affinity) are NOT procurement.
- **`looks_not_pro_services` 404 is not a bug.** A `firm_id` may exist in `/search` but 404 on `/get` if it's been flagged. Skip and continue; not charged.
- **`/v1/explore` k=20 suppression.** When fewer than 20 firms match, the response is `{"count": "<20", "suppressed": true, "breakdowns": {}}`. Drilling further makes the count smaller. Broaden or escalate to `/v1/search`.
- **Briefs from `/search` do NOT include `apex`, `url`, `phone_primary`, `email_primary`, `legal_name`, or address.** If the user asks for contact info, you must `/get/:id`.
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

User: *"Three UX/UI design agencies for our SaaS product, ideally with
4-star ratings and healthcare-tech experience."*

```
GET /v1/tags?include_values=1
GET /v1/check?filter=industry:design_creative+service_provided:ui-ux-design@high+saas+healthcare+rating>=4
GET /v1/explore?filter=industry:design_creative+service_provided:ui-ux-design@high+saas+healthcare+rating>=4
GET /v1/search?filter=...&limit=10
GET /v1/get/<firm_id>     # ×3
```

End of session: report `X-Quota-Remaining-Month`.
