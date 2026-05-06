<p align="center">
  <img src="assets/icon.svg" alt="ServiceGraph" width="64" height="64" />
</p>

# ServiceGraph Agent Skills

> Stop scraping. Your agent's directory of US service firms is here.

Agent Skills for [**ServiceGraph**](https://servicegraph.co) — a structured
catalog of **100k+ US professional-services firms** (law, marketing, design,
consulting, accounting, IT services, AI/ML, web development, engineering,
HR, PR, cybersecurity, and more) with filters for industry, services
offered, location, size, ratings, and third-party listing presence.

<p align="center">
  <img src="assets/servicegraph.png" alt="What you get for each firm — name, URL, phone, email, services, ratings, listings" width="800" />
</p>

Compatible with **19+ AI agents** including Claude Code, Codex, Cursor, GitHub
Copilot, Gemini, Cline, Goose, Windsurf, and any other harness that supports
the [Agent Skills](https://agentskills.io/) format.

## Installation

### Install a specific skill

```bash
npx skills add nostrband/servicegraph --skill find-service-providers
```

### Install all skills

```bash
npx skills add nostrband/servicegraph
```

No signup is needed for catalog discovery (`/v1/tags`, `/v1/check`,
`/v1/explore`). Skills prompt the user for an email + one-time code only when
they reach the contact-info tier (`/v1/search`, `/v1/get`).

## Available Skills

<details open>
<summary><strong>find-service-providers</strong> — the umbrella skill</summary>

Find, shortlist, vet, or enrich US professional-services firms across all 22
industries in the catalog — law, marketing, consulting, accounting, IT
services, architecture, engineering, HR, PR, design, and more.

**Use when:**
- "Find me three boutique IP law firms in California"
- "Build a longlist of 50 mid-size US management consultancies"
- "Here are 12 agency domains — pull contact info and confirm which are US-based"
- The user's intent doesn't fit a more specific skill below

</details>

<details>
<summary><strong>find-marketing-agency</strong></summary>

Find US marketing agencies — branding, content marketing, PPC/paid media,
social, email, performance/demand-gen, video production, full-service digital.
Auto-pins `industry:marketing_agency` so the agent doesn't have to.

**Use when:**
- "Shortlist three B2B branding agencies in California"
- "Find a PPC shop with ecommerce experience"
- "We need a content marketing partner for a SaaS launch"

</details>

<details>
<summary><strong>find-seo-agency</strong></summary>

Find US SEO agencies — technical, on-page/off-page, link-building,
content-led, local, ecommerce, B2B SEO, audits. Auto-pins
`industry:marketing_agency service_provided:seo`.

**Use when:**
- "Find me an SEO agency in Texas"
- "Shortlist three technical SEO consultancies for SaaS"
- Indirect phrasings: "organic traffic is flat", "improve our Google rankings"

</details>

<details>
<summary><strong>find-design-agency</strong></summary>

Find US design and creative agencies — graphic design, UX/UI, product
design, brand identity, packaging, illustration, motion design, creative
direction. Auto-pins `industry:design_creative`. Defers to
`find-marketing-agency` for marketing-led engagements where design is one
of several services, and to `find-web-developer` when the deliverable is a
built website rather than design assets.

**Use when:**
- "Find me a UX/UI design agency for our SaaS product"
- "Shortlist three brand-identity studios in NY for our rebrand"
- "Packaging design firm for a CPG launch"

</details>

<details>
<summary><strong>find-software-developer</strong></summary>

Find US software development firms — custom software, web/mobile development,
backend/API, DevOps/cloud consulting, system integration, hosting. Auto-pins
`industry:it_services`. Defers to `find-web-developer` for strictly
website/landing-page projects, and to `find-ai-consultancy` for AI/ML
modeling and data-engineering work.

**Use when:**
- "Find me a software dev shop in Austin"
- "Shortlist three custom-software firms with healthcare experience"
- "We need a mobile app developer for our iOS launch"

</details>

<details>
<summary><strong>find-web-developer</strong></summary>

Find US web development firms — building, refreshing, or rebuilding
marketing sites, landing pages, ecommerce, WordPress/Webflow/Shopify,
headless CMS, microsites, and web frontend work. Auto-pins
`industry:it_services service_provided:web-development`. Defers to
`find-software-developer` for backend/API/mobile work, and to
`find-marketing-agency` when scope spans broader marketing.

**Use when:**
- "Find a web developer for our marketing landing page"
- "Shortlist three Webflow agencies in California"
- "Rebuild our ecommerce site on Shopify with custom theme work"

</details>

<details>
<summary><strong>find-ai-consultancy</strong></summary>

Find US AI/ML and data consulting firms — AI/ML development, MLOps,
generative AI / LLM apps (RAG, chatbots, agents), computer vision, NLP,
recommendation systems, data engineering, BI/analytics. Auto-pins
`industry:data_ai_consulting`. Defers to `find-software-developer` for
general app/backend work where AI is just a feature.

**Use when:**
- "Find an AI/ML consulting firm to build our recommendation engine"
- "Three RAG/LLM consultancies for an enterprise chatbot project"
- Indirect: "we want to use AI to predict customer churn — who can help?"

</details>

<details>
<summary><strong>find-law-firm</strong></summary>

Find US **B2B** law firms — corporate, IP/patent, M&A and securities,
employment, commercial litigation, regulatory/compliance, data privacy/
cyber, real estate, tax. Auto-pins `industry:legal`. The catalog is
B2B-only — consumer-personal matters (divorce, personal injury, criminal
defense, estate planning, family law, wills) are explicitly out of scope.

**Use when:**
- "Find three boutique IP law firms in California for patent prosecution"
- "Shortlist M&A counsel for a Series-B fundraise"
- Indirect: "outside counsel for GDPR / SOC 2 oversight"

</details>

<details>
<summary><strong>find-cpa-firm</strong></summary>

Find US accounting and tax firms (CPA firms) — financial-statement audit,
SOC 1/2, corporate tax, bookkeeping for businesses, advisory/fractional
CFO, M&A diligence, 409A valuations, R&D tax credits, IPO readiness,
sales-and-use tax. Auto-pins `industry:accounting_tax`. B2B-only —
personal tax prep (1040, individual estate, retirement planning) is
out of scope.

**Use when:**
- "Find me a CPA firm for our Delaware C-corp Series A audit"
- "Shortlist three audit firms with SaaS experience"
- Indirect: "our books are a mess and we need someone to clean them up
  before the audit"

</details>

<details>
<summary><strong>find-management-consultant</strong></summary>

Find US management consultancies — strategy, operations, executive
coaching, leadership development, org-development/change management,
PMO/program management, sales/revenue ops. Auto-pins
`industry:management_consulting` and uses the `service_provided`
sub-tags (`strategy-consulting`, `operations-consulting`, etc.).

**Use when:**
- "Find me three top strategy consultancies in California for a Series-B SaaS"
- "We need an executive coach for our new CEO"
- Indirect: "change-management partners for a post-merger integration"

</details>

<details>
<summary><strong>find-engineering-firm</strong></summary>

Find US **real-world** engineering firms — civil, structural, MEP,
mechanical, electrical, geotechnical, transportation, environmental,
manufacturing. Auto-pins `industry:engineering_services`. **NOT for
software engineering** — defers software-dev / "engineering team" /
SaaS-architecture asks to `find-software-developer`. Skips residential
or consumer architecture asks.

**Use when:**
- "Find civil engineering firms in Florida for transportation infrastructure"
- "Shortlist three structural engineering firms with high-rise experience"
- Indirect: "we're building a 10-story office and need a structural engineer
  to stamp the drawings"

</details>

<details>
<summary><strong>find-recruiting-firm</strong></summary>

Find US recruiting and staffing firms — executive search/retained search,
RPO, tech/sales/healthcare recruiting, contingent/contract staffing, temp
staffing. Auto-pins `industry:hr_recruiting_staffing`. **Procures an
external recruiting firm** — does NOT fire on recruiting-an-employee
asks ("hire a recruiter for our team", "where should I post the job"),
candidate-side asks, or in-house recruiter hires.

**Use when:**
- "Find me an executive search firm for a CFO search"
- "We need RPO support for a 50-engineer hiring push"
- Indirect: "we're scaling fast and need help hiring at scale"

</details>

<details>
<summary><strong>find-pr-agency</strong></summary>

Find US public-relations and communications agencies — media relations,
crisis comms, investor relations (IR), product-launch PR, tech/startup
PR, healthcare PR, B2B PR, public affairs, brand reputation, internal
communications. Auto-pins `industry:pr_comms`. Defers to
`find-marketing-agency` when scope spans broader marketing beyond
PR/comms.

**Use when:**
- "Find me a tech PR agency in NY for our Series-B announcement"
- "Three IR firms for our upcoming IPO roadshow"
- Indirect: "we need press — get us into TechCrunch, WSJ, the trade press"

</details>

<details>
<summary><strong>find-cybersecurity-firm</strong></summary>

Find US cybersecurity firms — pen-testing/red team, security audits,
vCISO, SOC 2 readiness, incident response, managed SOC, IAM, cloud
security, AppSec. Auto-pins the cybersecurity industry tag. B2B-only
— consumer-personal cybersecurity ("my Gmail got hacked", "secure my
home wifi") is out of scope.

**Use when:**
- "Find me a pen-testing firm for our SOC 2 audit"
- "We need an incident response retainer"
- Indirect: "we got hit with ransomware last week — we need help fast"

</details>

## Prefer MCP? Use the hosted server.

If your harness speaks the [Model Context Protocol](https://modelcontextprotocol.io/),
skip the skill install and point it at the hosted MCP server:

```
https://mcp.servicegraph.co
```

- **Transport:** Streamable HTTP
- **Auth:** OAuth 2.1 + PKCE with Dynamic Client Registration — your
  harness opens a browser tab on first use; the user enters their email +
  one-time code on `api.servicegraph.co` and is bounced back. No client
  ID or secret to copy around.

### Claude Code

```bash
claude mcp add --transport http servicegraph https://mcp.servicegraph.co
```

### Claude Desktop

**Settings → Connectors → Add custom connector**, then paste:

```
https://mcp.servicegraph.co
```

The OAuth handshake runs in your browser on first use.

### Codex CLI

`~/.codex/config.toml`:

```toml
[mcp_servers.servicegraph]
url = "https://mcp.servicegraph.co"
```

### Cursor and other JSON-config clients

`.cursor/mcp.json` (or the equivalent for your harness):

```json
{
  "mcpServers": {
    "servicegraph": {
      "url": "https://mcp.servicegraph.co"
    }
  }
}
```

## Usage

Skills are automatically available once installed. The agent will pick the
right one when it detects a relevant task.

**Examples:**

```
Find me three boutique IP law firms in California that handle patent
prosecution for hardware startups.
```

```
Need a shortlist of mid-size SEO agencies in NY or NJ with a strong B2B
SaaS portfolio.
```

```
We're hiring a CPA firm for a Delaware C-corp Series A audit.
Recommend 5 options under 50 people.
```

```
Here are 12 marketing agency domains I scraped — pull contact info and
confirm which are in the US.
```

## How it works — the four-tier funnel

```
GET /v1/tags         →  field catalog · free · anonymous
GET /v1/check        →  validate filter · free · anonymous
GET /v1/explore      →  counts + breakdowns · free · anonymous
GET /v1/search       →  brief firm cards · 200/month free
GET /v1/get/{id}     →  full bundle (url, phone, email) · 50/month free
```

Skills know to walk down the funnel: cheap tiers first, expensive tiers only
on shortlisted firms. Re-pages and overlapping queries are free — the quota
counts only **unique** firm-views per calendar month.

### Filter DSL

One query parameter, GitHub-search-style. AND binds tighter than OR;
`-x` / `NOT x` for negation; `tag@evidence` for the `service_provided` field.
Any bareword is a free-text keyword search across firm name, brand, title,
meta description, and legal name.

```
industry:legal state:CA,NY -company_size_signal:solo
industry:management_consulting service_provided:strategy-consulting@high
dental industry:marketing_agency
rating>=4 review_count_total>=20 has:clutch
(web3 OR blockchain) state:CA
```

Field catalog (kinds, operators, allowed values) is discoverable at runtime
via [`/v1/tags`](https://api.servicegraph.co/v1/tags).

## Why structured beats search

- **Filter, don't grep.** Industry, services, location, size, rating,
  third-party listings — all queryable as a single filter string. Not a wall
  of fuzzy web results.
- **Try before you sign up.** `/v1/explore` is fully anonymous. Get counts
  and breakdowns for any filter to size the candidate pool before spending an
  API call.
- **Quota rewards focus.** 200 unique firm-views per month free. Re-paging
  or overlapping queries are free; only new firms count.

## Skill structure

Each skill follows the [Agent Skills Open Standard](https://agentskills.io/):

- `SKILL.md` — required manifest with frontmatter (name, description, metadata)

The skills in this repo are single-file. No bundled scripts or references
yet — the API is small enough that the agent does fine with prose +
copy-pasteable curl examples.

## Links

- [API console & docs](https://docs.servicegraph.co)
- [OpenAPI 3.1 spec](https://api.servicegraph.co/openapi.json)
- [Field catalog](https://api.servicegraph.co/v1/tags) — live list of every
  filterable field, kind, and allowed value
- [llms.txt](https://servicegraph.co/llms.txt)
- [Site](https://servicegraph.co)

## License

MIT

## Contact

[artur@servicegraph.co](mailto:artur@servicegraph.co)
