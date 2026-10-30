# Replit (replit.com)

Generated 2026-10-30T15:25:28+00:00. Rank #1 of 3,000 (v4). Org cf909ca8-1b1b-0f1d-a6c9-e83df329a5d7

## Summary
Replit is a Foster City cloud development platform whose AI Agent builds and deploys full apps from prompts for 50M+ users, valued at $9B after a $400M Series D led by Georgian (March 2026). It is the most agentic target in the ICP: its agent writes code, runs it and touches live infrastructure, and it had a public July 2025 incident where the agent deleted a customer's production database. It runs SOC 2 Type II and has security roles open, so budget and urgency both exist.

## Why now
Replit raised $400M at $9B on 2026-03-11 with Agent 4 (parallel autonomous agents), added Visa as a strategic investor on 2026-05-28, and is hiring Cloud Security Lead and AI Agent Security Architect roles to sell into enterprise via Azure; the July 2025 agent database deletion is still being cited (CIO, 2026-10-09), so buyers are asking how agent actions are controlled.

## Product and AI
Browser-based development and hosting platform. Agent (Agent 4 launched March 2026) builds, runs and deploys apps, slides and videos from prompts, with multiple agents working in parallel; enterprise tier adds Azure Marketplace and Microsoft Fabric data connectors (private preview).

- AI: AI Agent that builds and deploys apps from prompts, executes code and shell actions, and wires databases and secrets for end users (company_review: customer-facing LLM yes, confidence high).
- Agentic: yes
- Surfaces: Replit Agent (prompt-to-app); Parallel multi-agent builds (Agent 4); Security Agent (LLM-assisted pre-deploy scan); Enterprise data connectors (Microsoft Fabric); Apps built by users that themselves embed LLMs

## Funding and size
- Total $872.9M across 13 rounds; Series D $400M at $9B (2026-03-11, Georgian); Visa corporate round 2026-05-28
- Headcount: 101-250 (Crunchbase range). Crunchbase range looks stale against ~$525M ARR (Sacra, Apr 2026); expect materially larger. Several security roles open.

## Compliance
- SOC 2: SOC 2 Type II (via Vanta), per replit.com/security
- HIPAA: Not found on security page
- EU AI Act: Indirect: GDPR stated; Replit provides an agent and its users deploy AI apps to EU end users. No EU AI Act statement found.
- ISO 27001 in progress. Shared responsibility model puts app content on the customer, leaving agent-action risk contested. Each customer gets an isolated GCP project; containers use seccomp-bpf, moving to microVMs.

## News
- 2026-10-09: [CIO: The real agent risk that Replit's database deletion revealed](https://www.cio.com/article/4230232/the-replit-case-an-agent-a-written-order-and-a-deleted-database.html)
- 2026-08-05: [Replit hits $9B valuation, bets on Microsoft Fabric](https://tech-insider.org/ie/replit-9-billion-valuation-2026)
- 2026-03-11: [Replit raises $400M at $9B valuation, launches Agent 4](https://replit.com/blog/replit-raises-400-million-dollars)
- 2026-01-15: [Bloomberg: Replit nears $9B funding round](https://www.bloomberg.com/news/articles/2026-01-15/ai-coding-startup-replit-nears-funding-at-9-billion-valuation)
- 2025-07-18: [Agent deleted a customer's production database during a code freeze (SaaStr/Lemkin incident); Replit separated dev and prod data](https://battletester.app/blog/replit-security-breach-what-happened)

## Hiring signals
- [Cloud Security Lead (multi-tenant AI infrastructure, agentic systems preferred)](https://jobs.ashbyhq.com/replit/8027a0f4-4837-4e49-a4dd-8ad1bde23277)
- [AI Agent Security Architect (primary authority for agent security blueprint; Indeed snippet only, unverified)](https://www.indeed.com/q-replit-jobs.html)

## Likely pains
- Agents taking destructive actions on production data or infrastructure (the July 2025 database deletion; OWASP LLM06 Excessive Agency)
- Prompt injection through repos, packages and web content the agent reads, leading to secret exfiltration or malicious code
- Cross-tenant data leakage in multi-tenant AI infrastructure and in apps the agent generates
- Abuse of free-tier compute: phishing sites, malware, spam and crypto-mining built through the agent (the same abuse Lovable cites)
- Agent misreporting what it did or what is recoverable (documented wrong rollback advice)
- Enterprise security reviews demanding auditable agent controls as Replit sells through Azure and Fabric

## MEDDPICC hypothesis
- **metrics** (medium): Fewer agent-caused incidents and refunds, faster enterprise security-review close, lower free-tier abuse and compute cost.
- **economic_buyer** (low): CTO Luis Chavez, or the head of security once the AI Agent Security Architect is hired; President/Head of AI Michele Catasta is the alternate.
- **decision_criteria** (medium): Latency overhead on agent loops, coverage of tool calls and shell actions, custom natural-language policies per tenant/plan, audit trail, build versus buy against the in-house Security Agent.
- **decision_process** (low): Engineering-led pilot on a slice of agent traffic, then security and CTO sign-off; likely a short technical evaluation.
- **paper_process** (low): Unknown. Expect a vendor security review (they run Vanta) and a DPA; White Circle's SOC 2 helps.
- **identify_pain** (medium): The 2025 production-database deletion and continuing agent-safety scrutiny; Replit already built dev/prod separation and a Security Agent, so the gap is runtime enforcement on agent actions.
- **champion** (low): The AI Agent Security Architect once hired, or an agent-platform engineering lead under VP Eng Scott Kennedy.
- **competition** (medium): In-house build (strong engineering, Security Agent exists), model-lab guardrails, and Lakera, Prompt Security or Protect AI.

## Persona openers
- **CTO / Engineering**: With Agent 4 running parallel agents against live infrastructure, how are you enforcing per-action policies without adding latency to the agent loop?
- **Head of AI / President**: Plain-language policies that check every agent tool call in real time would let your agent team change rules without retraining anything.
- **Security / CISO**: Your open Agent Security Architect role suggests you are designing agent controls now; we run a runtime layer that blocks or escalates destructive actions and logs which policy fired.
- **General Counsel**: Your shared-responsibility model leaves agent behavior contested; an audit trail of every blocked or allowed agent action gives you evidence after an incident.
- **Trust & Safety**: Lovable uses us to catch phishing sites and malware requests in agent sessions; do you see the same abuse stream on free-tier builds?

## Contacts
1. **Luis Chavez**, Chief Technology Officer (crunchbase) [LinkedIn](https://www.linkedin.com/in/lhchavez/). Owns platform and agent infrastructure; most likely technical economic buyer.
2. **Michele Catasta**, President & Head of AI (crunchbase) [LinkedIn](https://www.linkedin.com/in/pirroh). Runs AI strategy and the agent; owns the roadmap that creates the risk.
3. **Scott Kennedy**, VP of Engineering (crunchbase) [LinkedIn](https://www.linkedin.com/in/stkenned). Likely evaluator and champion for a runtime guardrail pilot.
4. **Robert Kohse**, General Counsel & Corporate Secretary (web) [LinkedIn](https://www.linkedin.com/in/robert-kohse-252ab112). Leads product and privacy counseling; owns liability exposure from agent incidents.
5. **Amjad Masad**, Founder and CEO (crunchbase) [LinkedIn](http://www.linkedin.com/in/amjadmasad). Publicly owned the 2025 incident response; escalation sponsor, not first contact.
6. **Jordan Walke**, Lead product development (About page: Head of Product) (crunchbase) [LinkedIn](https://www.linkedin.com/in/jordan-walke-1250b634). Shapes agent behavior and guardrail UX.
9. **Matt Mazzeo**, Board Member (crunchbase) [LinkedIn](https://www.linkedin.com/in/matthewmazzeo). Board member; not a buyer.
10. **Sue Xu**, Investor (crunchbase) [LinkedIn](https://www.linkedin.com/in/suexu). Investor; not a buyer.

## Risks
- Strong in-house engineering and an existing Security Agent make build-versus-buy the main objection
- No head of security or CISO found publicly; economic buyer unclear
- Crunchbase headcount looks stale; company may be larger and slower to engage
- Latency sensitivity on the agent loop
- Competitor of Lovable, White Circle's only named logo
- Replit does not claim HIPAA, so compliance leverage is SOC 2 and agent audit trail only

## Sources
- [The real agent risk that Replit's database deletion revealed (CIO, 2026-10-09)](https://www.cio.com/article/4230232/the-replit-case-an-agent-a-written-order-and-a-deleted-database.html)
- [Replit raises $400 million at a $9 billion valuation (Replit blog, 2026-03-11)](https://replit.com/blog/replit-raises-400-million-dollars)
- [Replit Hits $9B Valuation, Bets on Microsoft Fabric (tech-insider, 2026-08-05)](https://tech-insider.org/ie/replit-9-billion-valuation-2026)
- [AI Coding Startup Replit Nears Funding at $9 Billion Valuation (Bloomberg, 2026-01-15)](https://www.bloomberg.com/news/articles/2026-01-15/ai-coding-startup-replit-nears-funding-at-9-billion-valuation)
- [Replit Security page](https://replit.com/security)
- [Replit shared responsibility model (docs)](https://docs.replit.com/features/security/shared-responsibility-model)
- [Replit About / leadership](https://replit.com/about)
- [Replit Cloud Security Lead (Ashby)](https://jobs.ashbyhq.com/replit/8027a0f4-4837-4e49-a4dd-8ad1bde23277)
- [Replit jobs on Indeed (AI Agent Security Architect listing)](https://www.indeed.com/q-replit-jobs.html)
- [Robert Kohse, General Counsel, Replit (LinkedIn)](https://www.linkedin.com/in/robert-kohse-252ab112)
- [Replit security breach: what happened in 2023 and 2025 (battletester)](https://battletester.app/blog/replit-security-breach-what-happened)
- Crunchbase export (organizations, funding_rounds, contacts) (data/raw/*.csv)
