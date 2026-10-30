# Botpress (botpress.com), account brief

Rank #3 of 3,000 (v4 score). Generated 2026-10-30.

## Summary
Botpress (Quebec, ~51-100 staff, $40M raised, $25M Series B June 2025) is an AI agent platform whose customer-support agents issue refunds and update accounts for clients in any sector. It is the strongest 'channel partner' candidate in the list: embedding White Circle controls would cover every customer's agents at once. It is also a possible competitor, since its own content already pitches 'guardrails' and a security suite, so the first call should find out whether guardrails are built in-house.

**Buyer, partner or competitor?** Primarily a **channel partner** (embed White Circle for all customer agents), secondarily a direct **buyer** for its own helpdesk agents, with real **competitor** risk because it already markets guardrails.

## Product and AI use
Agent Studio plus Autonomous Engine (LLM-reasoned agents that call tools and APIs, with fallback and escalation rules), AI-native Helpdesk, Knowledge Bases and Tables. Self-serve and enterprise; claims use by 35% of the Fortune 500 (company claim).

AI use: Customer-facing LLM agents built on its platform by thousands of customers; per the verified review, support agents that issue refunds and update accounts, with escalation rules and fallback logic. Agentic: yes. Surfaces: Agent Studio (builder), Autonomous Engine (tool-calling agents), AI-native Helpdesk, Customer-built web/WhatsApp/voice chat agents, Knowledge Bases and Tables.

## Funding and size
Total $40M. Series B $25M on 2025-06-23, led by Framework Venture Partners; also Decibel, Inovia, HubSpot Ventures, Deloitte Ventures Canada. Headcount 51-100. Montreal and Quebec City.

## Why now
Botpress closed a $25M Series B on 2025-06-23 to expand engineering and go-to-market, and by 2026-01-12 was publishing guardrail-and-security content for chatbot buyers. Its agents are tool-calling (refunds, account updates), and the Sept 2026 industry framing (NVIDIA's Open Agent Safety Platform, 2026-09-28, citing agents circumventing app-layer controls) makes runtime control a live buying topic for platforms like this.

## Likely pains
- Prompt injection in customer-built support agents causing unauthorized refunds or account changes
- Data leaking across tenants or end users through shared knowledge bases and tool outputs
- Agents taking destructive or irreversible actions via the Autonomous Engine's tool calls
- Abuse and token-drain on free and self-serve tiers
- Brand-safety and hallucination incidents that its customers blame on the platform
- Enterprise security reviews (HIPAA, DORA, GDPR) demanding evidence of runtime controls and audit logs per customer agent

## Compliance
SOC 2 Type 2, HIPAA, GDPR, CCPA, DORA listed on its [Trust Center](https://trust.botpress.com). As a provider/enabler of customer-facing agents with EU customers, plus deployer duties flowing to its customers (transparency, human oversight). Not confirmed in this pass whether Botpress publishes an AI Act position.

## MEDDPICC hypotheses
- **metrics** (low): Fewer agent incidents per customer, faster enterprise security-review close, and guardrails as a paid tier or margin line.
- **economic_buyer** (low): Sylvain Perron (co-founder and CEO) for a platform/channel deal; CTO or product lead for an embed. A CISO was not found.
- **decision_criteria** (medium): Latency overhead, multi-tenant policy isolation, API fit with Agent Studio, price per call at its volume, EU/US residency.
- **decision_process** (low): Product and engineering evaluation, then CEO sign-off on a partnership or resale; likely a pilot on one workflow.
- **paper_process** (low): Partnership or reseller agreement plus DPA; SOC 2/HIPAA on both sides.
- **identify_pain** (medium): Customers' agents act on live systems and any injection or leak is attributed to Botpress; enterprise buyers ask for guardrail evidence.
- **champion** (low): Head of product or engineering for agent safety; a trust/security lead if one exists. Unnamed so far.
- **competition** (medium): Possible in-house guardrails (its own content already claims them), plus Lakera, Protect AI, NVIDIA NeMo Guardrails, Guardrails AI and model-provider filters.

## Persona openers
- **CEO / co-founder**: Your customers' agents issue refunds and touch accounts, so one injected agent becomes your incident; could we show you a runtime layer you can offer every Botpress agent without building it yourselves?
- **CTO / VP Engineering**: How do you stop an Autonomous Engine agent from calling a destructive tool on a hostile prompt today, and what would a policy check in that call path cost you in latency?
- **Head of Security / CISO**: When an enterprise security review asks for evidence of runtime controls on customer-built agents, what do you hand them beyond the SOC 2 report?
- **Head of Product / AI**: If guardrails shipped as a per-agent policy toggle in Agent Studio, which customers would turn it on first, and are you building that or buying it?
- **Compliance / Legal**: Your customers in regulated sectors carry deployer duties under the EU AI Act and DORA, so audit logs showing which policy fired per agent action could become a feature you sell.

## Contacts
| Name | Title | Priority | Why |
|---|---|---|---|
| [Sylvain Perron](https://linkedin.com/in/slvnperron) | Co-founder and Chief Executive Officer | high | Platform-level partnership or embed decision sits with the founder CEO; led the Series B. |
| [Justin Watson](https://www.linkedin.com/in/justin-watson-6b232316) | Co-Founder and Investor | medium | Co-founder who fronted the Series B announcement; useful second path into the CEO's circle. |
| [Jean-Bernard Perron](https://www.linkedin.com/in/jean-bernard-perron/) | COO and CFO | medium | Owns commercial terms and vendor/partner agreements; relevant to resale or margin structure. |
| [Jim Texier](https://www.linkedin.com/in/texierjm/) | Board of Director (also CTO at Framework Venture Partners) | low | Board member from the lead investor; not a buyer. Could give a warm introduction at most. |
| [Jeff Yoshimura](https://www.linkedin.com/in/jeff-yoshimura-4055/) | Advisor | low | Advisor, not a buyer. |
| [Evan Kaplan](https://www.linkedin.com/in/kaplanevan) | Advisor | low | Advisor, not a buyer. |
| [Marjorie Janiewicz](https://www.linkedin.com/in/marjorietoucas/) | Advisor | low | Advisor, not a buyer. |
| [Francois Dufour](https://www.linkedin.com/in/fdufour/) | Advisor | low | Advisor, not a buyer. |

No CISO, head of security or head of AI was found publicly; do not guess one.

## Risks
- Competitor risk: Botpress already markets 'guardrails' and a security suite, and may build or acquire its own control layer; check before investing selling time.
- Channel risk: a partnership is a longer, lower-control sale than a direct deal, and Botpress may want white-label pricing that compresses margin.
- Buyer fit: Botpress is a platform, not an end deployer; direct value is limited to its own helpdesk and internal agents.
- No named security or AI-safety leader found; entry point is the CEO or an unconfirmed engineering lead.
- Evidence gaps: no AI incident, security hiring, or customer list verified in this pass (careers page extract was thin; security/guardrails URLs guessed returned 404).
- Company is in Quebec/Canada; White Circle's EU/US regions may need a Canadian data-residency conversation.

## News
- 2025-06-24: [Botpress secures $25M Series B to scale infrastructure for production-ready AI agents](https://opendatascience.com/botpress-secures-25m-to-scale-infrastructure-for-production-ready-ai-agents)
- 2026-01-12: [Botpress publishes 'Chatbot Security Guide: Risks & Guardrails (2026)', positioning its security suite](https://botpress.com/blog/chatbot-security)
- 2026-09-11: [CX Network report on AI agents for the helpdesk, with Botpress and guardrails as a theme](https://www.cxnetwork.com/voice-of-the-customer/news/every-vc-cx-deal-you-need-to-know-september-11)

## Sources
- [Botpress Series B coverage (Open Data Science, 2025-06-24)](https://opendatascience.com/botpress-secures-25m-to-scale-infrastructure-for-production-ready-ai-agents)
- [Botpress Trust Center](https://trust.botpress.com)
- [Botpress chatbot security guide (Jan 2026)](https://botpress.com/blog/chatbot-security)
- [Botpress Autonomous Engine](https://botpress.com/features/gpt-native-engine)
- [Botpress careers](https://botpress.com/careers)
- [Botpress homepage](https://botpress.com)
- [Private Capital Journal on Series B (LinkedIn)](https://www.linkedin.com/posts/private-capital-journal_botpress-secures-us-25m-series-b-activity-7342907945992495104-J3qk)
- Crunchbase export (organizations, funding_rounds, contacts) (data/raw/*.csv)
