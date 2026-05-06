---
name: find-pr-agency
description: Use whenever the user wants to find, shortlist, vet, or enrich US public-relations and communications agencies — media relations, crisis comms, investor relations (IR), product-launch PR, tech/startup PR, healthcare PR, B2B PR, public affairs, brand reputation, and internal communications. Triggers on "find me a tech PR agency in NY", "shortlist three IR firms for our IPO", "we need crisis comms help for a brand reputation issue", or "pull contact info for these 10 PR firm domains", even when described indirectly (we need press, get us into TechCrunch, manage our brand reputation). Drives the ServiceGraph API (api.servicegraph.co) — a 100k+ US firm catalog filterable by industry, services, location, size, ratings. Defer to find-marketing-agency when scope is broader marketing beyond PR/comms. Skip in-house PR/comms hires, "write me a press release" DIY asks, PR-software comparisons (Cision, Muck Rack), influencer-marketplace questions, non-US firms, individual freelance PR people.
license: MIT
metadata:
  api_base: https://api.servicegraph.co
  industry: pr_comms
  service: public-relations
  version: "0.2"
---

# find-pr-agency

Drive the **ServiceGraph API** (`https://api.servicegraph.co`) to find,
shortlist, and enrich US public-relations and communications agencies.

**Always pin `service_provided:public-relations`.** Note: the
catalog's nominal `industry:pr_comms` value returns zero firms in
the live release — PR/comms firms are tagged with
`service_provided:public-relations` instead, typically under
adjacent industries (marketing_agency, other_pro_services). Pin the
service tag, not the industry. Sub-types (media relations, crisis,
IR, public affairs, healthcare PR, tech PR, B2B PR, internal comms,
brand reputation) are NOT separate tags — sub-type specialization is
a keyword substring search on firm text.

Any HTTP client works (curl, fetch, requests). Examples below use curl.

## Sibling skills — defer when scope is broader

If the user wants a **multi-service marketing engagement** (PR plus
content plus paid plus social), defer to `find-marketing-agency` —
that skill covers full-service shops where PR is one of several
service lines.

This skill is correct when PR/comms is the primary deliverable —
launches, media relations, crisis, IR, public affairs.

## When NOT to use this skill

- "Write me a press release / draft these talking points" → DIY work.
- In-house comms/PR hires (Head of Comms, PR Manager).
- PR-software comparisons (Cision, Muck Rack, Prowly).
- Influencer-marketplace asks ("find me an influencer for our DTC
  product") — that's not PR; PR is earned media.
- "Explain how earned media works" → knowledge question.
- Non-US firms.
- Individual freelance PR people / publicists.

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

Cache the response for the conversation. Confirm `public-relations`
is in the `service_provided` value list — that's the pin this skill
relies on. The nominal `pr_comms` industry value is empty in the
current release; don't pin it.

Field kinds you'll use most:
- **tag_set_with_evidence**: `service_provided` (always include `public-relations`) — op `:` with optional `@evidence`
- **categorical**: `state`, `pricing_model`, `company_size_signal`, `geography_served` — op `:`
- **numeric**: `rating`, `review_count_total`, `founded_year` — ops `= >= <= > <`
- **presence**: `has:phone`, `has:clutch`, `has:rating`, `has:linkedin_company`, …
- **keyword**: free-text substring across firm name / brand / title / meta / legal_name. **This is how you specialize on sub-type and vertical** (tech, healthcare, IR, crisis, public affairs, B2B, etc.).

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

**PR-flavored examples** (validate yours with `/v1/check`):

```
service_provided:public-relations tech state:NY
service_provided:public-relations healthcare
service_provided:public-relations b2b saas
service_provided:public-relations crisis
service_provided:public-relations investor relations
service_provided:public-relations ipo state:NY,CA
service_provided:public-relations public affairs state:DC
service_provided:public-relations rating>=4 has:clutch
```

When in doubt, hit `/v1/check?filter=...` first.

**Sub-type / vertical → keyword mapping**:

| User asks for | Add as keyword(s) |
|---|---|
| Tech / startup PR | `tech`, `startup`, `saas` |
| Healthcare / pharma PR | `healthcare`, `pharma`, `biotech` |
| Crisis comms | `crisis` |
| Investor relations / IR | `investor relations`, `ir`, `ipo` |
| B2B PR | `b2b` |
| Public affairs | `public affairs` |
| Brand reputation | `brand reputation`, `reputation` |
| Internal communications | `internal communications`, `internal comms` |
| Earned media / media relations | `earned media`, `media relations` |

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
echo -n "edelman.com" | tr 'A-Z' 'a-z' \
  | openssl dgst -sha256 -hex | awk '{print substr($2,1,12)}'
```

## Recipes

### A. Tech PR for a Series-B announcement

User: *"Tech PR agency in NY for our Series-B announcement."*

```
GET /v1/explore?filter=service_provided:public-relations+tech+state:NY
GET /v1/search?filter=service_provided:public-relations+tech+state:NY&limit=10
GET /v1/get/<firm_id>     # ×3
```

### B. IR firms for an IPO

User: *"Three IR firms for our upcoming IPO roadshow."*

```
GET /v1/search?filter=service_provided:public-relations+(investor relations OR ir)+ipo
```

### C. Crisis comms (urgent)

User: *"Crisis comms help — brand reputation issue blowing up online."*

```
GET /v1/search?filter=service_provided:public-relations+crisis&limit=10&order_by=relevance
```

Surface as urgent: skip `/v1/explore`, jump straight to `/v1/search`,
present briefs immediately.

### D. Healthcare / regulatory PR

User: *"Healthcare PR agency familiar with FDA regulatory comms."*

```
GET /v1/search?filter=service_provided:public-relations+healthcare+(fda OR regulatory)
```

### E. Indirect intent — "we need press"

User: *"We need press for our Series-B — get us into TechCrunch, WSJ,
and the trade press."*

That's product-launch / tech PR. Translate:

```
GET /v1/search?filter=service_provided:public-relations+(tech OR startup)+(launch OR series-b)&limit=10
```

If thin, drop the launch/series-b keyword — most tech PR firms do
launches as a default.

### F. Public affairs (state government)

User: *"Public affairs firms with state-government experience in
California."*

```
GET /v1/search?filter=service_provided:public-relations+public affairs+state:CA
```

### G. BYO apex list — enrich domains

User pastes 8–20 PR-firm domains. For each:

1. Compute `firm_id` locally.
2. `GET /v1/get/<firm_id>` — full bundle if in catalog, 404 if not.
3. Aggregate, present, flag the not-found ones.

## Gotchas

- **Always pin `service_provided:public-relations`.** Don't pin `industry:pr_comms` — it's empty in the live catalog. PR firms are tagged with the service tag across adjacent industries (marketing_agency, other_pro_services). Without the service pin, "tech PR" / "crisis" / "investor relations" as keywords leak into general marketing.
- **Defer to `find-marketing-agency` for full-service marketing engagements.** When PR is one of several service lines (PR + content + paid + social), the marketing-agency skill is the right fire.
- **Sub-types are keyword-only.** Multi-word sub-types split into ANDed barewords (`investor relations` → `investor` AND `relations`).
- **"Write me a press release" / "draft talking points" is do-the-work.** Refuse and offer to find a firm if the user wants to engage one.
- **Influencer marketing is NOT PR.** Influencer marketplaces (Aspire, Grin, etc.) and influencer outreach are paid-media work; defer to `find-marketing-agency` or refuse for marketplace questions.
- **PR-software comparisons** (Cision, Muck Rack, Prowly) are NOT procurement.
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

User: *"Three tech PR agencies in NY for a Series-B announcement,
ideally with 4-star ratings and Fortune 500 client experience."*

```
GET /v1/tags?include_values=1
GET /v1/check?filter=service_provided:public-relations+tech+state:NY+rating>=4
GET /v1/explore?filter=service_provided:public-relations+tech+state:NY+rating>=4
GET /v1/search?filter=...&limit=10
GET /v1/get/<firm_id>     # ×3
```

End of session: report `X-Quota-Remaining-Month`.
