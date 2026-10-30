# Kinfolk (kinfolkhq.com)
Rank #5 of 3,000 (v4). London, seed, founded 2023, 1-10 employees. Generated 2026-10-30.

Kinfolk is a London seed-stage startup (founded 2023, 1-10 employees per Crunchbase) selling AI agents that resolve employee HR requests inside Slack and Microsoft Teams, with a ticketing system behind them. The agents act, not just answer: they draft documents, update HRIS records and manage lifecycle changes, so they touch sensitive employee data in customer HRIS systems. It raised a $7.2M seed in Feb 2026 to scale enterprise readiness and expand into payroll and IT workflows.

**Why now:** Kinfolk closed a $7.2M seed on 2026-02-25/26 (AlbionVC) explicitly to 'expand enterprise readiness' and extend agents into payroll and IT workflows, which widens write access to the most sensitive employee data; with Deliveroo live (5,000 requests in five months) and 5x YoY growth, enterprise security reviews and EU AI Act employment-AI scrutiny are arriving now while the team is still 1-10 people with no dedicated security or AI-safety hire visible.

## What it ships (verified)
Customer-facing LLM agents answering employee HR requests in Slack/Teams and executing workflows (drafting documents, updating HRIS records, lifecycle changes) with approval gates, audit trail and cited answers. Verified in seed review: ships_customer_facing_llm=yes, agentic=true, confidence high.

Surfaces: Slack agent, Microsoft Teams agent, HR request/ticket queues, HRIS write actions (Workday, ADP, UKG, HiBob, BambooHR), Knowledge-base retrieval (Drive, Confluence, SharePoint, Notion).
Customers: Deliveroo (5,000 HR requests resolved in five months, 50% fewer Jira tickets); Hudl; Retail Next (CPO quoted).

## Funding
Seed $7.2M, 2026-02-26 (AlbionVC lead; PROfounders, Ascension, Emerge, Tony Jamous, Saurav Chopra). Press says $8.5M total raised. 5x YoY growth reported.

## Compliance
SOC 2 Type II, ISO 27001:2022, GDPR, CCPA (self-reported). No HIPAA claim. EU AI Act: High. Annex III treats AI used in employment and workers management (task allocation, monitoring, decisions affecting work terms) as high-risk. Kinfolk is a provider and its customers are deployers; its agents handle employee requests and change HRIS records rather than screen candidates, so classification depends on use case, but customers will ask for human oversight, logging and risk controls.

## Likely pains
- Prompt injection through employee messages or ingested docs (Confluence, SharePoint, Notion) steering an agent that can write to HRIS
- Data leaking across tenants or across departments inside a customer (salary, performance, medical leave, disciplinary cases) via retrieval or shared queues
- Agents taking destructive or unauthorized actions (wrong record update, wrong employee, payroll change) beyond the approval gates
- Employee-facing answers that are wrong or harmful on legal topics (leave, pay, dismissal), creating liability for the HR customer
- Enterprise buyers demanding evidence of runtime guardrails and red-team results during security review
- EU AI Act and UK/GDPR exposure from employment-related AI: logging, human oversight and automated decision rules

## MEDDPICC hypothesis
- **metrics** (medium): Time to pass enterprise security reviews, number of blocked/escalated risky agent actions, zero cross-tenant or PII incidents; supports Kinfolk's own 70% auto-resolution metric.
- **economic_buyer** (medium): CEO Jeet Mukerji at this size, possibly with CTO Kim Hellbom; budget is small and founder-controlled.
- **decision_criteria** (medium): Fast API integration (minutes), low latency in Slack/Teams flows, EU data region, SOC 2, per-customer-tenant policy flexibility, audit logs that map to Kinfolk's existing audit trail.
- **decision_process** (low): Founder-led technical evaluation by CTO, trial on a staging agent, then sign; likely 2-4 weeks.
- **paper_process** (low): Light: MSA/order form plus DPA; EU region matters for UK/EU customer base.
- **identify_pain** (medium): Enterprise prospects ask how agent actions are controlled; founders built approval gates in-house and may see runtime policy checks as undifferentiated work.
- **champion** (medium): CTO Kim Hellbom (ex-Beamery AI scaling) as technical champion.
- **competition** (medium): Build in-house (approval gating already exists), general guardrail vendors and model-provider filters; status quo of no runtime layer.

## Persona angles
- **CTO / technical co-founder**: Your agents already gate sensitive actions behind approvals; we add a runtime layer that checks every Slack message, retrieved doc and HRIS write against plain-language policies so you do not have to build and maintain that yourselves.
- **CEO / economic buyer**: As you push into payroll and IT, every enterprise security review will ask how agent actions are controlled; we give you red-team results and live guardrails to hand them.
- **Security / compliance lead (not yet identified)**: HR AI is high-risk under the EU AI Act, and we log which policy fired on each agent call so your customers get the oversight evidence they will ask for.

## Contacts
1. Kim Hellbom, CTO & Co-Founder ([LinkedIn](https://www.linkedin.com/in/kimhellbom)): Owns the agent architecture and security posture; most likely champion and technical evaluator.
2. Jeet Mukerji, CEO & Co-Founder ([LinkedIn](https://www.linkedin.com/in/jeetmukerji)): Founder-led company; controls budget and drives the enterprise-readiness push.

No other buyer personas (security, AI, legal) found publicly. No job postings found (careers page 404).

## Risks
- Tiny team (1-10 employees) with limited budget and possible build-in-house preference
- Already has SOC 2 Type II, ISO 27001 and approval/audit controls, so the gap is narrower than at a typical AI startup
- No security, AI-safety or CISO role identified; buyer is probably a founder
- EU AI Act classification of its agents (employee support, not hiring decisions) is uncertain
- Funding totals conflict across sources (7.2M vs 8.5M vs a mis-scraped 72M)

## Sources
- [Kinfolk homepage](https://www.kinfolkhq.com)
- [Kinfolk approach page](https://www.kinfolkhq.com/approach)
- [Tech.eu: Kinfolk closes $7M seed](https://tech.eu/2026/02/25/kinfolk-closes-7m-seed-round-for-ai-driven-hr-platform)
- [AlbionVC: Kinfolk secures $7m seed](https://albion.vc/spotlight/portfolio-news/kinfolk-secures-7m-seed-to-transform-hr-operations-with-agentic-ai)
- [Grishin Robotics LinkedIn post (customers, 5x growth)](https://www.linkedin.com/posts/grishinrobotics_kinfolk-has-raised-7-million-in-seed-funding-activity-7434569227048685568-PLzY)
- [Startup Intros: Kinfolk](https://startupintros.com/orgs/kinfolk)
