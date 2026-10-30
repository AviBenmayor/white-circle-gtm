# Dash0 (dash0.com): account brief

**Verdict: buyer first, partner second, adjacent competitor risk.** Rank #4 of 3,000. Generated 2026-10-30.

## Summary
Dash0 is a New York/Berlin OpenTelemetry-native observability vendor, a unicorn since its $110M Series B (Mar 2026), whose Agent0 AI agents read customer telemetry and act on it (root cause, alerts, deployments, security response). It is a strong buyer-fit because agents with tool access on customers' production data need runtime control, but it is also an observability vendor that has signalled acquisitions in LLM/agent observability and AI security, so it could be a partner or an adjacent competitor to White Circle's Analyze module.

## Why now
On 2026-03-23 Dash0 raised a $110M Series B at $1B, earmarked for expanding Agent0 autonomous agents, letting customers build their own agents, and US enterprise go-to-market; on 2026-08-17 it bought Polar Signals, and it has said it will acquire in AI security and LLM/agent observability. Agents that act on production for 750+ customers are scaling now, and the Aug 2026 security overview shows the security team is documenting agent controls.

## Product and AI
Agentic observability platform on OpenTelemetry: SignalStore (logs, metrics, traces, profiles, events, RUM), PromQL/SQL query, AI trace triage, MCP server/CLI/API for agents, and Agent0, a set of specialized agents (AI SRE, observability toil, migration, cost, security, deployment) plus customer-built agents and Automations with configurable guardrails. 750+ customers incl. Zalando, Taco Bell, The Telegraph, Vercel users.

Agent0 agents run in ephemeral sandboxes on customer telemetry, using models on AWS Bedrock/GCP Vertex (zero data retention); tools are scoped and mostly read-only, writes go via pull request; automations trigger from Slack/webhooks/checks and can post to Slack, Linear, GitHub. Also AI-powered trace triage and an MCP server so customers' own coding agents query the same data.

Surfaces: Agent0 AI SRE / root-cause agents, Agent0 Automations (Slack, webhook, check triggers), MCP server, CLI and API for third-party agents, AI trace triage, Customer-built custom agents on Dash0 infrastructure.

## Company
- Funding: Series B $110M (2026-03-23, Balderton lead), total about $154.5M, $1B valuation. Investors: Balderton Capital (lead), Accel, Cherry Ventures, DIG Ventures, DTCP Growth, July Fund, T.Capital (Deutsche Telekom).
- Headcount: 101-250 (Crunchbase range). Hired a CRO (Nov 2025) and a Head of Growth (Jul 2025); Series B funds aggressive US go-to-market. Careers page could not be fetched, so open roles are unconfirmed.
- Customers: Zalando, Taco Bell, The Telegraph, Bridgestone, EVgo, NextRoll, Tessl, Linearity, Azuga, Vercel (user quote).
- Compliance: SOC 2 Type II, HIPAA BAA, GDPR; ISO 27001 and PCI DSS in progress. Low to moderate. Not a high-risk use case itself; EU-founded (Berlin) with EU customers such as Zalando, so deployer/transparency duties for Agent0 and GDPR on telemetry apply.

## News
- 2026-03-23: [Dash0 raises $110M Series B at $1B valuation, led by Balderton; funds Agent0 and US go-to-market](https://www.dash0.com/blog/dash0-raises-usd110m-series-b)
- 2026-08-17: [Dash0 acquires Polar Signals (continuous profiling incl. GPU/CUDA) into SignalStore and Agent0](https://www.dash0.com/blog/dash0-acquires-polar-signals)
- 2026-03-23: [TFN: Dash0 becomes a unicorn, plans acquisitions in LLM/agent observability, AI SRE and AI security](https://techfundingnews.com/dash0-becomes-a-unicorn-after-balderton-led-110m-round-counts-zalando-and-taco-bell-as-customers)

## Likely pains
- Prompt injection through telemetry: logs, traces and error messages are attacker-influenced text that Agent0 reads and could treat as instructions
- Cross-tenant data leakage if an agent or MCP session sees another customer's dataset
- Agents taking destructive or out-of-scope actions (Slack posts, GitHub or Linear writes, rollout and deployment decisions) via automations
- Customer security reviews demanding proof of agent runtime controls beyond sandboxing, as enterprise US deals grow
- Third-party coding agents hitting the MCP server with unvetted queries and exfiltrating data
- Hallucinated root causes or fixes in customer-visible outputs

## MEDDPICC hypotheses
- **metrics** (low): Fewer unsafe agent actions, faster enterprise security reviews and shorter sales cycles for Agent0; zero cross-tenant incidents.
- **economic_buyer** (medium): CTO (Benjamin Blackmore) or CEO Mirko Novakovic for a platform-level control layer; a CISO or security lead if one exists (not found).
- **decision_criteria** (medium): Latency inside agent loops, data residency (EU/US), SOC 2/HIPAA, ability to enforce per-tenant policy on tool calls, and no training on customer data.
- **decision_process** (low): Engineering-led evaluation by Agent0/product team, then security review and an exec sign-off; likely a bake-off against building in-house.
- **paper_process** (low): Vendor security review via trust center (SafeBase), DPA and BAA; startup procurement should be fast.
- **identify_pain** (medium): Agents acting on production for 750+ customers, with prompt injection via telemetry and tool-call safety as the core exposure.
- **champion** (low): Michele Mancioppi (Head of Product) or the Agent0 engineering lead who owns the agent security whitepaper.
- **competition** (medium): In-house guardrails and sandboxing (already built), cloud guardrails on Bedrock/Vertex, other AI security vendors; also Dash0's own planned AI-security acquisitions.

## Openers by persona
- **CTO / engineering**: Agent0 reads logs and traces that attackers can write into, so can I show you how White Circle checks every agent tool call in real time before it touches a customer's Slack, GitHub or deploy pipeline?
- **Head of Product**: Your Automations let customers set guardrails in settings; White Circle lets them write those policies in plain language and enforces them on every input, output and tool call.
- **CRO / sales leadership**: As you push Agent0 into US enterprises, security reviews will ask how autonomous agents are controlled, and a named runtime control layer with SOC 2 and HIPAA can shorten that review.
- **CEO**: You said the platform will not just monitor but act on production, and the company that can prove those actions are controlled wins the enterprise trust race against Datadog.
- **Security / compliance lead**: Your Agent0 whitepaper covers sandboxing and read-only tools; White Circle adds red-team testing and real-time policy checks on what the agent says and does, with an audit trail for your customers.

## Contacts
- **Benjamin Blackmore**, CTO (high): Owns the platform and Agent0 architecture; likely economic buyer or sign-off for runtime agent control. [LinkedIn](https://www.linkedin.com/in/benripkens/)
- **Michele Mancioppi**, Head of Product (high): Owns Agent0 product and Automations guardrails, the closest feature overlap and likely champion. [LinkedIn](https://www.linkedin.com/in/michelemancioppi)
- **Mirko Novakovic**, CEO and co-founder (medium): Founder and serial observability founder; sets the acquisition and partnership direction on AI security. [LinkedIn](https://www.linkedin.com/in/mirkonovakovic/)
- **Oliver Manojlovic**, CRO (medium): Joined Nov 2025 to drive US enterprise sales, where agent-security reviews will arise. [LinkedIn](https://www.linkedin.com/in/olivermanojlovic/)
- **Benedikt Körling**, Head of Growth (low): Possible route for a co-marketing or integration partnership conversation. [LinkedIn](https://www.linkedin.com/in/korling)
- **Rana Yared**, Board Member (low): Board member added with the Series B; not a buyer, do not prospect. [LinkedIn](https://www.linkedin.com/in/ranayared)

## Risks
- Possible competitor: Dash0 plans acquisitions in LLM/agent observability and AI security, and White Circle's Analyze module overlaps with LLM observability
- Possible partner instead of buyer: AI observability plus AI guardrails is a natural integration (OTel traces of White Circle decisions in Dash0), which may be a better first motion than a sale
- Strong in-house controls already (ephemeral sandboxes, scoped read-only tools, PR-gated writes, ZDR models), which weakens urgency
- No security leader, CISO or head of AI found publicly, so the buying persona is unclear
- Careers page unreachable and no job signals confirmed
- Customers are mainly engineering teams, not regulated end users, so EU AI Act and compliance pull is weak

## Sources
- [Dash0 raises $110M Series B at $1B valuation](https://www.dash0.com/blog/dash0-raises-usd110m-series-b)
- [Dash0 acquires Polar Signals](https://www.dash0.com/blog/dash0-acquires-polar-signals)
- [Dash0 Security & Trust](https://www.dash0.com/security)
- [Dash0 homepage](https://www.dash0.com)
- [Agent0 automations: guardrails](https://www.dash0.com/docs/dash0/ai/agent0/automations/create/set-guardrails)
- [TFN: Dash0 becomes a unicorn](https://techfundingnews.com/dash0-becomes-a-unicorn-after-balderton-led-110m-round-counts-zalando-and-taco-bell-as-customers)
- Crunchbase export (organizations, funding, contacts) (local: data/raw/*.csv)
