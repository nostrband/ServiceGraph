---
name: find-recruiting-firm
description: Use whenever the user wants to find, shortlist, vet, or enrich US recruiting and staffing firms — executive search/retained search, RPO, tech/sales/healthcare recruiting, contingent/contract staffing, and temp staffing. Triggers on "find me an executive search firm for a CFO search", "shortlist three retained-search boutiques in NY focused on tech", "we need RPO support for a 50-engineer hiring push", or "pull contact info for these 8 staffing firm domains", even when described indirectly (need help hiring at scale, executive recruiter for senior roles). Drives the ServiceGraph API (api.servicegraph.co) — a 100k+ US firm catalog filterable by industry, services, location, size, ratings. Skip when the user wants to hire someone as their own employee (job-board questions, in-house recruiter hires, "where should I post the role"), individual job-seekers looking for recruiters to represent them, candidate-side career coaching, non-US firms, individual freelance recruiters.
license: MIT
metadata:
  api_base: https://api.servicegraph.co
  industry: hr_recruiting_staffing
  version: "0.1"
---

# find-recruiting-firm

Drive the **ServiceGraph API** (`https://api.servicegraph.co`) to find,
shortlist, and enrich US recruiting and staffing firms.

**This skill is for procuring an external recruiting/staffing firm**
to do hiring on the user's behalf. It is NOT for:
- recruiting an in-house employee (the user wants to hire someone for
  their own team — that's job-posting, not procurement),
- candidate-side asks (an individual job-seeker looking for someone
  to represent them).

Both cases share keyword overlap with the positive case ("recruiter",
"hire") so the boundary matters.

**Always pin `industry:hr_recruiting_staffing`.** Sub-types
(executive search, RPO, contingent staffing, temp, vertical
specializations) are NOT separate tags — sub-type specialization is a
keyword substring search on firm text.

Any HTTP client works (curl, fetch, requests). Examples below use curl.

## When NOT to use this skill

- "I want to hire a [role] for my team — where should I post the job?"
  → that's recruiting-an-employee, not procuring a firm.
- "Find me a recruiter to represent me in my job search" → candidate side.
- "Hire an in-house recruiter / Head of Talent" → recruiting an employee.
- "Help me write a job description" → DIY/do-the-work.
- ATS or HR-software comparisons (Greenhouse vs Lever, Workday, etc.).
- Career coaching for individual job-seekers.
- Non-US firms.
- Individual freelance recruiters.

If the user is a *business* procuring external recruiting/staffing
services (executive search, RPO, contingent staffing), this skill
applies — defaults to fire on B2B procurement intent.

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

Cache the response for the conversation. Confirm
`hr_recruiting_staffing` is in the `industry` value list (the exact
value name may vary slightly in different catalog releases).

Field kinds you'll use most:
- **categorical**: `industry` (always `hr_recruiting_staffing`), `state`, `pricing_model`, `company_size_signal`, `geography_served` — op `:`
- **numeric**: `rating`, `review_count_total`, `founded_year` — ops `= >= <= > <`
- **presence**: `has:phone`, `has:clutch`, `has:rating`, `has:linkedin_company`, …
- **keyword**: free-text substring across firm name / brand / title / meta / legal_name. **This is how you specialize on sub-type** (executive, retained, RPO, contingent, temp, tech, healthcare, sales, etc.).

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

**Recruiting-flavored examples** (validate yours with `/v1/check`):

```
industry:hr_recruiting_staffing executive search
industry:hr_recruiting_staffing retained search state:NY tech
industry:hr_recruiting_staffing rpo state:CA
industry:hr_recruiting_staffing contingent staffing
industry:hr_recruiting_staffing healthcare state:TX,FL
industry:hr_recruiting_staffing sales saas
industry:hr_recruiting_staffing rating>=4 has:clutch
```

When in doubt, hit `/v1/check?filter=...` first.

**Sub-type → keyword mapping**:

| User asks for | Add as keyword(s) |
|---|---|
| Executive search / retained search | `executive`, `retained` |
| RPO (recruitment process outsourcing) | `rpo`, `recruitment process outsourcing` |
| Contingent / contract staffing | `contingent`, `contract` |
| Temp / temporary staffing | `temp`, `temporary` |
| Tech recruiting | `tech`, `technical`, `engineering` |
| Sales recruiting | `sales` |
| Healthcare recruiting | `healthcare`, `clinical`, `nursing` |
| Finance / accounting recruiting | `finance`, `accounting` |
| Legal recruiting | `legal`, `attorney` |

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
echo -n "korn-ferry.com" | tr 'A-Z' 'a-z' \
  | openssl dgst -sha256 -hex | awk '{print substr($2,1,12)}'
```

## Recipes

### A. Executive search for a CFO

User: *"Executive search firm for a CFO search."*

```
GET /v1/explore?filter=industry:hr_recruiting_staffing+executive+search
GET /v1/search?filter=industry:hr_recruiting_staffing+executive+search&limit=10
GET /v1/get/<firm_id>     # ×3
```

### B. Retained boutique in a state, vertical

User: *"Retained-search boutiques in NY focused on tech executives."*

```
GET /v1/search?filter=industry:hr_recruiting_staffing+retained+state:NY+tech+-company_size_signal:large_50plus&limit=10
```

### C. RPO for a hiring surge

User: *"RPO support for a 50-engineer hiring push."*

```
GET /v1/search?filter=industry:hr_recruiting_staffing+rpo+(tech OR engineering)
```

### D. Indirect intent — "scaling fast, need help hiring"

User: *"We're scaling fast and need help hiring at scale — looking for
a partner."*

That's RPO or volume contingent staffing:

```
GET /v1/search?filter=industry:hr_recruiting_staffing+(rpo OR contingent)
```

If the user names a function (engineering, sales, customer success),
add it as a keyword.

### E. Vertical: healthcare staffing

User: *"Healthcare staffing firms in the Midwest."*

```
GET /v1/search?filter=industry:hr_recruiting_staffing+healthcare+state:OH,IL,MI,IN,WI,MN
```

### F. Quality threshold + tech-sector

User: *"Three executive search firms with 4-star ratings and tech-sector
experience."*

```
GET /v1/search?filter=industry:hr_recruiting_staffing+executive+search+tech+rating>=4&limit=10
```

### G. BYO apex list — enrich domains

User pastes 8–20 staffing/recruiting firm domains. For each:

1. Compute `firm_id` locally.
2. `GET /v1/get/<firm_id>` — full bundle if in catalog, 404 if not.
3. Aggregate, present, flag the not-found ones.

## Gotchas

- **Always pin `industry:hr_recruiting_staffing`.** Without it, "recruiter" or "executive search" as keywords leak into other industries.
- **Distinguish "find me a recruiting firm" (procurement, fires) from "find me a recruiter / hire a recruiter for our team" (recruiting-an-employee, refuses).** When ambiguous, lean on context: explicit firm/agency/RPO language or volume framing → procurement; "for our team" / "to post the job" / "I want to hire" → in-house hire.
- **Candidate-side asks** ("represent me as a candidate", "find me a job") are out of scope. Refuse politely.
- **Career coaching for individuals** is a different need (and shares the executive-coaching keyword with management consulting). Refuse — this skill is firm-procurement.
- **Sub-types are keyword-only.** Multi-word sub-types split into ANDed barewords (`executive search` = `executive` AND `search`).
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

User: *"Three retained executive search firms in NY focused on tech
CFOs, ideally with 4-star ratings and a Clutch profile."*

```
GET /v1/tags?include_values=1
GET /v1/check?filter=industry:hr_recruiting_staffing+retained+executive+state:NY+tech+rating>=4+has:clutch
GET /v1/explore?filter=industry:hr_recruiting_staffing+retained+executive+state:NY+tech+rating>=4+has:clutch
GET /v1/search?filter=...&limit=10
GET /v1/get/<firm_id>     # ×3
```

End of session: report `X-Quota-Remaining-Month`.
