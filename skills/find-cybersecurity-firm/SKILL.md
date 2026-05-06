---
name: find-cybersecurity-firm
description: Use whenever the user wants to find, shortlist, vet, or enrich US cybersecurity firms — pen-testing/red team, security audits, vCISO, SOC 2 readiness, incident response, managed SOC, IAM, cloud security, and AppSec. Triggers on "find me a pen-testing firm for our SOC 2 audit", "shortlist three vCISO services for our healthcare-tech startup", "we need an incident response retainer", or "pull contact info for these 8 security firm domains", even when described indirectly (we got breached, prepare us for the compliance audit, get us SOC 2 ready). Drives the ServiceGraph API (api.servicegraph.co) — a 100k+ US firm catalog filterable by industry, services, location, size, ratings. Skip in-house security hires, "how do I patch CVE-X" or "configure firewall Y" DIY questions, security-product reviews (CrowdStrike vs SentinelOne, etc.), generic security knowledge questions, consumer/personal security advice, non-US firms, individual freelancers and bug-bounty hunters.
license: MIT
metadata:
  api_base: https://api.servicegraph.co
  industry: cybersecurity
  version: "0.2"
---

# find-cybersecurity-firm

Drive the **ServiceGraph API** (`https://api.servicegraph.co`) to find,
shortlist, and enrich US cybersecurity firms.

**Always pin `service_provided:cybersecurity`** — that's the only
relevant structured tag in the live catalog. Older skill docs and
the catalog source mention sub-tags like `pen-testing` and
`security-audit`, but in the current release **none of those exist
as separate tags** — `cybersecurity` is the broad catch-all and
every sub-type (pen-testing, red-team, vCISO, SOC 2 readiness, IR
retainer, IAM, cloud security, AppSec) is a keyword substring search
on firm text. Confirm via `/v1/tags?include_values=1` once per
session.

The industry tag also drifts between releases — newer catalogs use
`industry:cybersecurity`, older ones used `industry:security`.
Confirm the value via `/v1/tags` and pin both `industry` and
`service_provided:cybersecurity` for safety.

Any HTTP client works (curl, fetch, requests). Examples below use curl.

## When NOT to use this skill

- **Consumer/personal cybersecurity** ("my Gmail got hacked", "how do
  I secure my home wifi") — the catalog is B2B procurement only.
- In-house security hires (Security Engineer, CISO, SOC analyst).
- DIY/configuration questions ("how do I patch CVE-X", "configure
  firewall rules", "review this nginx config").
- Security-product comparisons (CrowdStrike vs SentinelOne, EDR
  vendors, SIEM vendors).
- Generic security knowledge ("explain zero-trust", "what is OWASP
  Top 10").
- Non-US firms.
- Individual freelance pen-testers / bug-bounty hunters / contract
  CISOs.

If the user is a *business* procuring external cybersecurity
services (pen test, audit, vCISO, IR retainer, SOC 2 prep), this
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

Cache the response for the conversation. Confirm the cybersecurity
industry tag value name (`cybersecurity` or older `security`) and
that `cybersecurity` is in the `service_provided` value list. The
live catalog has only the broad `service_provided:cybersecurity`
tag — there are no separate `pen-testing` / `security-audit` /
`appsec` tags despite older docs sometimes mentioning them.

Field kinds you'll use most:
- **categorical**: `industry` (cybersecurity), `state`, `pricing_model`, `company_size_signal`, `geography_served` — op `:`
- **tag_set_with_evidence**: `service_provided` — Map<tag, evidence∈{low,medium,high}>. Op `:` with optional `@evidence`
- **numeric**: `rating`, `review_count_total`, `founded_year` — ops `= >= <= > <`
- **presence**: `has:phone`, `has:clutch`, `has:rating`, `has:linkedin_company`, …
- **keyword**: free-text substring across firm name / brand / title / meta / legal_name. **Many sub-types (vCISO, SOC 2, IR retainer, IAM, AppSec) are keyword-only.**

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

**Cybersecurity examples** (validate yours with `/v1/check`; replace
`cybersecurity` with whatever `/v1/tags` returns as the industry value):

```
industry:cybersecurity service_provided:cybersecurity
service_provided:cybersecurity pen-testing
service_provided:cybersecurity security audit soc 2
service_provided:cybersecurity vciso
service_provided:cybersecurity incident response retainer
service_provided:cybersecurity cloud aws
service_provided:cybersecurity application security sast
service_provided:cybersecurity rating>=4 has:clutch
service_provided:cybersecurity hipaa
```

When in doubt, hit `/v1/check?filter=...` first. (Note: the live
catalog has no separate `pen-testing` / `security-audit` /
`appsec` tags. Pin `service_provided:cybersecurity` and treat all
sub-types as keywords.)

**Sub-type → keyword mapping** (all sub-types are keyword-only —
the live catalog has only the broad `service_provided:cybersecurity`
tag):

| User asks for | Use |
|---|---|
| Pen test / red team / penetration testing | keywords `pen-testing`, `red team` |
| Security audit / assessment | keywords `audit`, `assessment` |
| vCISO / fractional CISO | `vciso`, `fractional ciso` |
| SOC 2 readiness / preparation | `soc 2`, `readiness` |
| Incident response / forensics | `incident response`, `forensics`, `ir retainer` |
| Cloud security (AWS/GCP/Azure) | `cloud security`, `aws`, `gcp`, `azure` |
| Identity / IAM | `iam`, `identity` |
| Application security / SAST/DAST | `application security`, `appsec`, `sast`, `dast` |
| Compliance frameworks | `pci`, `hipaa`, `iso 27001`, `nist` |

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
echo -n "mandiant.com" | tr 'A-Z' 'a-z' \
  | openssl dgst -sha256 -hex | awk '{print substr($2,1,12)}'
```

## Recipes

### A. Pen test for SOC 2

User: *"Pen-testing firm for our SOC 2 audit."*

```
GET /v1/explore?filter=industry:cybersecurity+service_provided:cybersecurity+pen-testing+soc 2
GET /v1/search?filter=industry:cybersecurity+service_provided:cybersecurity+pen-testing+soc 2&limit=10
GET /v1/get/<firm_id>     # ×3
```

### B. vCISO for a healthcare-tech startup

User: *"vCISO services for our healthcare-tech startup."*

```
GET /v1/search?filter=industry:cybersecurity+vciso+(healthcare OR hipaa)
```

### C. Incident response retainer

User: *"Incident response retainer in case we get breached."*

```
GET /v1/search?filter=industry:cybersecurity+incident response+retainer
```

If thin, drop `retainer` — most IR firms also offer retainer engagements.

### D. Cloud security + AWS + HIPAA

User: *"Cloud security consultancy familiar with AWS and HIPAA."*

```
GET /v1/search?filter=industry:cybersecurity+cloud+aws+hipaa
```

### E. Indirect intent — "we got breached"

User: *"We got hit with a ransomware attack last week — we need help fast."*

That's an emergency IR ask:

```
GET /v1/search?filter=industry:cybersecurity+incident response+ransomware&limit=10&order_by=relevance
```

Surface as urgent: skip `/v1/explore`, jump to `/v1/search`, present
briefs immediately.

### F. AppSec / SAST

User: *"Application security firms experienced with code review and SAST."*

```
GET /v1/search?filter=industry:cybersecurity+application security+(sast OR code review)
```

### G. SOC 2 readiness ahead of enterprise sales

User: *"SOC 2 readiness partner ahead of our enterprise sales push."*

```
GET /v1/search?filter=industry:cybersecurity+soc 2+(readiness OR preparation)
```

### H. BYO apex list — enrich domains

User pastes 8–20 cybersecurity firm domains. For each:

1. Compute `firm_id` locally.
2. `GET /v1/get/<firm_id>` — full bundle if in catalog, 404 if not.
3. Aggregate, present, flag the not-found ones.

## Gotchas

- **Always pin the cybersecurity industry tag.** Without it, `pen-testing` / `vciso` / `appsec` keywords leak into IT-services or other industries that mention security.
- **Confirm the industry value name via `/v1/tags`** — older catalog releases used `industry:security`, newer ones may use `industry:cybersecurity`. Don't hardcode; check once per session.
- **Refuse consumer-personal asks.** "My Gmail got hacked", "how do I secure my home wifi", "should I use a VPN" — none of these are B2B procurement. The catalog is for businesses procuring security services.
- **DIY/configuration questions** ("patch CVE-X", "configure firewall rules", "review this Terraform") are NOT procurement.
- **Security-product comparisons** (EDR, SIEM, identity providers) are NOT procurement either.
- **"Hire a security engineer / CISO" is recruiting**, not procurement of a firm. Refuse.
- **Bug-bounty / freelance pen-testers** are out of scope (catalog is firm-level only).
- **Many sub-types are keyword-only.** Multi-word sub-types split into ANDed barewords (`incident response` → `incident` AND `response`).
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

User: *"Three pen-testing firms for our SOC 2 audit, 4-star ratings,
ideally with HIPAA experience for a healthcare-tech context."*

```
GET /v1/tags?include_values=1
GET /v1/check?filter=industry:cybersecurity+service_provided:cybersecurity+pen-testing+soc 2+hipaa+rating>=4
GET /v1/explore?filter=industry:cybersecurity+service_provided:cybersecurity+pen-testing+soc 2+hipaa+rating>=4
GET /v1/search?filter=...&limit=10
GET /v1/get/<firm_id>     # ×3
```

End of session: report `X-Quota-Remaining-Month`.
