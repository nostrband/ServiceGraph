---
name: find-ai-consultancy
description: Use whenever the user wants to find, shortlist, vet, or enrich US AI/ML/data consulting firms (consultancies) — AI/ML development, MLOps, generative AI / LLM apps (RAG, chatbots, agents), computer vision, NLP, recommendation systems, data engineering, BI/analytics. Triggers on "find an AI/ML consulting firm to build our recommendation engine", "shortlist three RAG/LLM consultancies for an enterprise chatbot", "compare three AI/ML consulting firms with strong ratings", or "pull contact info for these 8 AI consultancy domains", even when described indirectly (we want to use AI for X, deploy ML to production). Drives the ServiceGraph API (api.servicegraph.co) — a 100k+ US firm catalog filterable by industry, services, location, size, ratings. Defer to find-software-developer for general app/backend work where AI is just a feature. Skip in-house ML/data hires, LLM/AI-tool comparisons (ChatGPT vs Claude), "how do I fine-tune X" DIY questions, AI courses for individuals, non-US firms, individual freelancers.
license: MIT
metadata:
  api_base: https://api.servicegraph.co
  industry: data_ai_consulting
  version: "0.2"
---

# find-ai-consultancy

Drive the **ServiceGraph API** (`https://api.servicegraph.co`) to find,
shortlist, and enrich US AI/ML and data consultancies. The catalog
tags firms with `industry:data_ai_consulting` and a 4-tag service
sub-taxonomy: `ai-ml-development` (the largest at ~12k firms),
`data-analytics`, `cloud-services`, and `api-integration`. Confirm
exact tag names via `/v1/tags` since taxonomy can drift between
catalog releases.

**Always pin `industry:data_ai_consulting`.** This skill exists to do
that automatically — the user shouldn't have to think about catalog
taxonomy.

Any HTTP client works (curl, fetch, requests). Examples below use curl.

## Sibling skills — defer when scope is different

- **General application or backend dev that just uses AI as a feature**
  (e.g. "build us a SaaS with an AI chatbot tab") → `find-software-developer`.
  This skill is for engagements where the AI/ML/data work IS the deliverable.
- **Web/site projects that include some AI** → `find-web-developer`.
- **AI-related marketing or content** → `find-marketing-agency`.

If the user wants AI/ML/data engineering as the primary deliverable
(model building, pipelines, agents, MLOps, BI), this skill applies.

## When NOT to use this skill

- **Consumer AI courses or learning** ("find me an online course to learn
  ML") — out of scope; the catalog is firm-procurement.
- **AI/LLM product comparisons** ("ChatGPT vs Claude vs Gemini",
  "Cursor vs Copilot") — software-product questions, not procurement.
- **DIY/code tasks** ("how do I fine-tune Llama", "review this PyTorch
  training loop").
- **In-house ML/data hires** (Machine Learning Engineer, Data Scientist,
  ML Platform Engineer).
- **Generic AI knowledge** ("explain how transformers work").
- **Non-US firms.**
- **Individual freelance ML engineers / data scientists.**

If the user is a *business* procuring external AI/ML/data services,
this skill applies — defaults to fire on B2B procurement intent.

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

Cache the response for the conversation. Confirm `data_ai_consulting`
is present in the `industry` value list. The relevant sub-tags under
`service_provided` are `ai-ml-development`, `data-analytics`,
`cloud-services`, and `api-integration` — verify exact names before
constructing filters with `service_provided:` predicates.

Field kinds you'll use most:
- **categorical**: `industry` (always `data_ai_consulting`), `state`, `pricing_model`, `company_size_signal`, `geography_served` — op `:`
- **tag_set_with_evidence**: `service_provided` (e.g. `ai-ml-development`, `data-analytics`, `cloud-services`, `api-integration`) — op `:` with optional `@evidence`
- **numeric**: `rating`, `review_count_total`, `founded_year` — ops `= >= <= > <`
- **presence**: `has:phone`, `has:clutch`, `has:rating`, `has:linkedin_company`, …
- **keyword**: free-text substring across firm name / brand / title / meta / legal_name. **Sub-niches like RAG, LLM, MLOps, computer vision, NLP, recommendation systems are typically keyword-only.**

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

**AI-flavored examples** (validate yours with `/v1/check`):

```
industry:data_ai_consulting service_provided:ai-ml-development
industry:data_ai_consulting service_provided:ai-ml-development@high state:CA
industry:data_ai_consulting service_provided:data-analytics pipelines
industry:data_ai_consulting llm rag
industry:data_ai_consulting computer vision healthcare
industry:data_ai_consulting mlops
industry:data_ai_consulting (service_provided:ai-ml-development OR service_provided:data-analytics)
industry:data_ai_consulting service_provided:ai-ml-development@high rating>=4 has:clutch
```

When in doubt, hit `/v1/check?filter=...` first.

**Sub-niche → keyword/tag mapping**:

| User asks for | Use |
|---|---|
| AI/ML model building | `service_provided:ai-ml-development` |
| Data engineering / pipelines | `service_provided:data-analytics` + keywords `pipelines`/`engineering` (no `data-engineering` tag exists) |
| BI / analytics | `service_provided:data-analytics` (covers BI too — no separate `business-intelligence` tag) |
| Cloud architecture for data/ML | `service_provided:cloud-services` |
| API integration / data integration | `service_provided:api-integration` |
| LLM apps / RAG / agents | `llm`, `rag`, `agent` (keywords) |
| Generative AI | `generative ai`, `genai` (keywords) |
| Computer vision | `computer vision`, `cv` (keywords) |
| NLP / IDP / document understanding | `nlp`, `idp`, `document understanding` |
| MLOps / model deployment | `mlops`, `deployment` |
| Recommendation systems | `recommendation`, `recsys` |
| Predictive analytics / churn / forecasting | `predictive`, `forecasting`, `churn` |

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
echo -n "scaleai.com" | tr 'A-Z' 'a-z' \
  | openssl dgst -sha256 -hex | awk '{print substr($2,1,12)}'
```

## Recipes

### A. AI/ML consultancy for a recommendation engine

User: *"AI/ML consultancy to build our recommendation engine for an
ecommerce site."*

```
GET /v1/explore?filter=industry:data_ai_consulting+service_provided:ai-ml-development+(recommendation OR recsys)+ecommerce
GET /v1/search?filter=industry:data_ai_consulting+service_provided:ai-ml-development+recommendation+ecommerce&limit=10
GET /v1/get/<firm_id>     # ×3
```

### B. RAG / LLM consultancies for a chatbot

User: *"Three RAG/LLM consultancies for an enterprise chatbot."*

```
GET /v1/search?filter=industry:data_ai_consulting+(rag OR llm)+chatbot+enterprise
```

If thin, drop `enterprise` and surface client-tier signals from
`/get` after.

### C. Data engineering partner

User: *"Data-engineering partner to build our analytics pipelines."*

The catalog has no `data-engineering` tag — `data-analytics` is the
closest sub-tag and it covers both BI and engineering work. Pin the
tag and add keywords for the engineering flavor:

```
GET /v1/search?filter=industry:data_ai_consulting+service_provided:data-analytics+(pipelines OR engineering)
```

### D. MLOps for model deployment

User: *"MLOps consultancy to help us deploy models to production."*

```
GET /v1/search?filter=industry:data_ai_consulting+mlops
```

### E. Indirect intent — "use AI to predict customer churn"

User: *"We want to use AI to predict customer churn — who can help us
build that?"*

That's a custom-ML consulting ask in the predictive-analytics niche:

```
GET /v1/search?filter=industry:data_ai_consulting+service_provided:ai-ml-development+(churn OR predictive)
```

If the user gave a vertical (SaaS, retail, telco), add it as a
keyword.

### F. Computer vision + healthcare vertical

User: *"AI consultancies specializing in computer vision for healthcare."*

```
GET /v1/search?filter=industry:data_ai_consulting+computer vision+healthcare
```

### G. Quality threshold + Fortune 500 clients

User: *"Three AI/ML consulting firms with 4-star ratings and Fortune
500 clients."*

```
GET /v1/search?filter=industry:data_ai_consulting+service_provided:ai-ml-development@high+rating>=4&limit=10
```

The "Fortune 500" angle isn't structured — surface from briefs and
let the user pick, or add `fortune` as a keyword.

### H. Custom LLM agent for customer service

User: *"Custom LLM agent for our customer-service workflows."*

```
GET /v1/search?filter=industry:data_ai_consulting+(llm OR agent)+(customer service OR support)
```

### I. BYO apex list — enrich domains the user already has

User pastes 8–20 AI consultancy domains. For each:

1. Compute `firm_id` locally.
2. `GET /v1/get/<firm_id>` — full bundle if in catalog, 404 if not.
3. Aggregate, present, flag the not-found ones to the user.

A 404 here often means the firm is actually a SaaS product company
(many AI vendors brand as "AI services" but operate as a product) —
not in the consulting catalog.

## Gotchas

- **Always pin `industry:data_ai_consulting`.** Without it, `ai-ml-development` as a service tag could surface IT firms that list AI as a sub-service.
- **Defer to `find-software-developer` for general dev that uses AI as a feature.** When the deliverable is a SaaS product or app and AI is one of several features, that's software-dev work; this skill is for engagements where AI/ML/data work IS the deliverable.
- **Catalog audit notes**: AI/ML-tagged firms have a higher historical rate of mis-classification (some are SaaS products, some are B2C ed-tech). The catalog has been audited but residual leakage is possible. If a `/get` returns a SaaS product, the agent should flag this and skip rather than recommend.
- **Many sub-niches are keyword-only.** Multi-word sub-niches split into ANDed barewords (`computer vision` → `computer` AND `vision`).
- **LLM-product comparisons (ChatGPT vs Claude vs Gemini, etc.) are NOT procurement** — refuse those.
- **AI courses for individuals (Coursera, fast.ai, Andrew Ng courses) are NOT in the catalog** — refuse those.
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

User: *"Three AI/ML consultancies to build a recommendation engine for
an ecommerce site, ideally with 4-star ratings and Fortune 500 clients."*

```
GET /v1/tags?include_values=1
GET /v1/check?filter=industry:data_ai_consulting+service_provided:ai-ml-development@high+(recommendation OR recsys)+ecommerce+rating>=4
GET /v1/explore?filter=industry:data_ai_consulting+service_provided:ai-ml-development@high+(recommendation OR recsys)+ecommerce+rating>=4
GET /v1/search?filter=...&limit=10
GET /v1/get/<firm_id>     # ×3
```

End of session: report `X-Quota-Remaining-Month`.
