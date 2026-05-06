---
name: find-engineering-firm
description: Use whenever the user wants to find, shortlist, vet, or enrich US engineering firms — civil, structural, MEP, mechanical, electrical, geotechnical, transportation, environmental, and manufacturing. **For real-world engineering (buildings, infrastructure, manufacturing) — NOT software engineering.** Triggers on "find civil engineering firms in Florida for transportation", "shortlist three structural engineering firms with high-rise experience", "MEP consultancy for a hospital project", or "pull contact info for these 12 engineering firm domains", even when described indirectly (PE-stamped drawings, building-permit review). Drives the ServiceGraph API (api.servicegraph.co) — a 100k+ US firm catalog filterable by industry, services, location, size, ratings. Defer software-dev / "engineering team" / SaaS-architecture asks to find-software-developer. Skip in-house engineering-manager hires, DIY questions, software-product comparisons (Revit, AutoCAD), non-US firms, individual freelancers.
license: MIT
metadata:
  api_base: https://api.servicegraph.co
  industry: engineering_services
  version: "0.2"
---

# find-engineering-firm

Drive the **ServiceGraph API** (`https://api.servicegraph.co`) to find,
shortlist, and enrich US **real-world** engineering firms — buildings,
infrastructure, energy, manufacturing. The catalog tags firms with
`industry:engineering_services` and a 23-tag service sub-taxonomy spanning
civil, structural, MEP, mechanical, electrical, geotechnical,
surveying, transportation, environmental, manufacturing, energy,
aerospace, biomedical, materials-testing, and more.

**This is NOT for software engineering.** "Software engineering firm",
"engineering team", "engineering manager hire", "system architecture
review" — those are all software-developer territory. The first thing
this skill confirms is that the user means real engineering, not
software.

**Always pin `industry:engineering_services`.** Sub-disciplines are typically
structured `service_provided` tags (`civil-engineering`,
`structural-engineering`, `mep-engineering`, etc.) — confirm exact
names via `/v1/tags`.

Any HTTP client works (curl, fetch, requests). Examples below use curl.

## When NOT to use this skill

The dominant failure mode is firing on software-engineering asks. Refuse those.

- **Software / SaaS / app-development asks** — even when phrased as
  "software engineering firm", "engineering team partner", "build our
  platform" → defer to `find-software-developer`.
- **In-house "engineering manager" hires** — in modern B2B usage this
  is almost always software-engineering recruiting. Refuse.
- **System / cloud / database architecture questions** ("Postgres vs
  DynamoDB", "monolith vs microservices") — software topics, not
  engineering firms.
- **Architecture (buildings)** — `find-architecture-firm` covers that
  industry. This skill covers engineering disciplines that *work
  with* architects (structural, MEP, civil) but the architect-of-record
  procurement goes to that skill.
- **Consumer/residential** ("architect for a residential remodel",
  "engineer to inspect my house") — the catalog is B2B procurement
  only.
- **Non-US firms / individual freelance engineers / DIY questions /
  engineering-software product comparisons (Revit, AutoCAD,
  SolidWorks, Ansys).**

If the user is a *business* (real-estate developer, contractor,
property owner, manufacturer, energy company, public agency, etc.)
procuring real-world engineering services, this skill applies —
defaults to fire on B2B procurement intent.

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

Cache the response for the conversation. Confirm `engineering` is in
the `industry` value list and that the relevant sub-discipline tags
(`civil-engineering`, `structural-engineering`, `mep-engineering`,
`mechanical-engineering`, `electrical-engineering`, etc.) are in
`service_provided`. Tag names sometimes drift (e.g. `mep` vs
`mep-engineering`); verify before constructing filters.

Field kinds you'll use most:
- **categorical**: `industry` (always `engineering`), `state`, `pricing_model`, `company_size_signal`, `geography_served` — op `:`
- **tag_set_with_evidence**: `service_provided` (e.g. `civil-engineering`, `structural-engineering`, `mep-engineering`) — op `:` with optional `@evidence`
- **numeric**: `rating`, `review_count_total`, `founded_year` — ops `= >= <= > <`
- **presence**: `has:phone`, `has:clutch`, `has:rating`, `has:linkedin_company`, …
- **keyword**: free-text substring across firm name / brand / title / meta / legal_name. **Verticals (hospital, high-rise, retail, transportation, semiconductor, etc.) and credentials (PE, LEED, etc.) are keyword-only.**

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

**Engineering-flavored examples** (validate yours with `/v1/check`):

```
industry:engineering_services service_provided:civil-engineering state:FL transportation
industry:engineering_services service_provided:structural-engineering high-rise
industry:engineering_services service_provided:mep-engineering hospital
industry:engineering_services service_provided:mechanical-engineering hvac industrial
industry:engineering_services service_provided:environmental-engineering remediation
industry:engineering_services service_provided:geotechnical-engineering state:CA seismic
industry:engineering_services service_provided:civil-engineering@high rating>=4 has:clutch
industry:engineering_services service_provided:electrical-engineering manufacturing
```

When in doubt, hit `/v1/check?filter=...` first.

**Sub-discipline → tag mapping** (verify exact names via `/v1/tags`;
the catalog has 23 sub-tags so this isn't exhaustive):

| User asks for | Use |
|---|---|
| Civil engineering / sitework / transportation | `service_provided:civil-engineering` |
| Structural engineering / building structure | `service_provided:structural-engineering` |
| MEP (mechanical/electrical/plumbing) | `service_provided:mep-engineering` |
| Mechanical engineering / HVAC | `service_provided:mechanical-engineering` |
| Electrical engineering | `service_provided:electrical-engineering` |
| Geotechnical / soils / foundations | `service_provided:geotechnical-engineering` |
| Surveying / land surveys / mapping | `service_provided:surveying-mapping` |
| Transportation engineering | `service_provided:transportation-engineering` |
| Environmental / remediation | `service_provided:environmental-engineering` |
| Manufacturing / process | `service_provided:manufacturing-engineering` |
| Aerospace | `service_provided:aerospace-engineering` |
| Energy (oil/gas/renewables) | `service_provided:energy-engineering` |
| Industrial automation / controls | `service_provided:industrial-automation` |
| Materials testing | `service_provided:materials-testing` |
| Acoustic / vibration | `service_provided:acoustic-engineering` |
| Biomedical | `service_provided:biomedical-engineering` |

Verticals (hospital, high-rise, semiconductor, retail, datacenter,
etc.) and credentials (PE-licensed, LEED, AICP) are keyword-only.

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
echo -n "aecom.com" | tr 'A-Z' 'a-z' \
  | openssl dgst -sha256 -hex | awk '{print substr($2,1,12)}'
```

## Recipes

### A. Civil engineering for transportation, in a state

User: *"Civil engineering firms in Florida that focus on transportation
infrastructure."*

```
GET /v1/explore?filter=industry:engineering_services+service_provided:civil-engineering+state:FL+transportation
GET /v1/search?filter=industry:engineering_services+service_provided:civil-engineering+state:FL+transportation&limit=10
GET /v1/get/<firm_id>     # ×3
```

### B. Structural engineering + commercial high-rise

User: *"Structural engineering firms with high-rise commercial
building experience."*

```
GET /v1/search?filter=industry:engineering_services+service_provided:structural-engineering+(high-rise OR commercial)
```

### C. MEP for a hospital project

User: *"MEP engineering consultancy for a hospital project."*

```
GET /v1/search?filter=industry:engineering_services+service_provided:mep-engineering+hospital
```

### D. Mechanical / HVAC for industrial facility

User: *"Mechanical engineering firms specializing in HVAC for industrial
facilities."*

```
GET /v1/search?filter=industry:engineering_services+service_provided:mechanical-engineering+hvac+industrial
```

### E. Indirect intent — "stamp the drawings"

User: *"We're building a 10-story office and need a structural engineer
to stamp the drawings."*

That's structural engineering for commercial-building permitting:

```
GET /v1/search?filter=industry:engineering_services+service_provided:structural-engineering+commercial
```

The "PE stamp" angle isn't structured — surface PE-license details
from `/get` after picking briefs. If the user wants only PE-licensed
firms, add `pe` as a keyword.

### F. Geotechnical + seismic for California

User: *"Geotechnical engineering firms in California with seismic-design
experience."*

```
GET /v1/search?filter=industry:engineering_services+service_provided:geotechnical-engineering+state:CA+seismic
```

### G. Quality threshold + PE-licensed

User: *"Three civil engineering firms with at least 4-star ratings and
PE-licensed engineers."*

```
GET /v1/search?filter=industry:engineering_services+service_provided:civil-engineering@high+rating>=4+pe&limit=10
```

`pe` as a bareword catches "PE License", "PE-licensed", "Professional
Engineer" via substring.

### H. BYO apex list — enrich domains

User pastes 8–20 engineering firm domains. For each:

1. Compute `firm_id` locally.
2. `GET /v1/get/<firm_id>` — full bundle if in catalog, 404 if not.
3. Aggregate, present, flag the not-found ones to the user. A 404
   here often means the domain is a software firm tagged
   `industry:it_services` instead of real engineering.

## Gotchas

- **Always pin `industry:engineering_services`.** Without it, `civil-engineering` / `mep-engineering` / `electrical-engineering` keywords could leak into other industries (architecture firms sometimes list MEP coordination as a sub-service).
- **The hardest boundary is software-engineering.** "Engineering firm" / "engineering team" in modern B2B usage almost always means software in tech contexts. Defer those to `find-software-developer`. Real engineering is for buildings, infrastructure, energy, manufacturing — not for SaaS apps.
- **"Engineering manager" hires are recruiting**, not procurement. Refuse.
- **Architecture firms are a separate industry.** When the user wants the architect-of-record (the firm that designs the building's form and aesthetics), defer to `find-architecture-firm`. This skill is for the engineering disciplines that work with architects (structural, MEP, civil).
- **Consumer/residential is out of scope** ("architect for my house remodel", "engineer to inspect my deck"). The catalog is B2B-only.
- **`looks_not_pro_services` 404 is not a bug.** A `firm_id` may exist in `/search` but 404 on `/get` if it's been flagged. Skip and continue; not charged.
- **`/v1/explore` k=20 suppression.** When fewer than 20 firms match, the response is `{"count": "<20", "suppressed": true, "breakdowns": {}}`. Drilling further makes the count smaller. Broaden or escalate to `/v1/search`.
- **Briefs from `/search` do NOT include `apex`, `url`, `phone_primary`, `email_primary`, `legal_name`, or address.** If the user asks for contact info, you must `/get/:id`.
- **Engineering-software product comparisons (Revit, AutoCAD, SolidWorks, Ansys, Bentley)** are NOT procurement.
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

User: *"Three civil engineering firms in Florida focused on
transportation infrastructure, ideally with PE-licensed engineers
and 4-star ratings."*

```
GET /v1/tags?include_values=1
GET /v1/check?filter=industry:engineering_services+service_provided:civil-engineering+state:FL+transportation+pe+rating>=4
GET /v1/explore?filter=industry:engineering_services+service_provided:civil-engineering+state:FL+transportation+pe+rating>=4
GET /v1/search?filter=...&limit=10
GET /v1/get/<firm_id>     # ×3
```

End of session: report `X-Quota-Remaining-Month`.
