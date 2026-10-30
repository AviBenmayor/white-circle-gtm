# Shapes (shapes.co) - account brief
Generated 2026-10-30 | Tel Aviv | founded 2020 | ranked #2 of 3,000 (v4 score)

**Summary.** Shapes (formerly DreamTeam, Tel Aviv, founded by ex-monday.com leaders) sells an AI-native, agentic HR/PeopleOS covering HR, IT and Finance processes, with an employee-facing AI chat, AI-generated workflows, agents that run admin work, and a build-your-own app/agent layer. It raised $24M combined seed and Series A (Series A $15M led by Entree Capital, 10 Dec 2025) and plans to more than double headcount. Its agents and chat read and act on sensitive employee data (salary, performance, leave) for hundreds of B2B customers in 79 countries, which is a high-risk AI use under the EU AI Act.

**Why now.** On 10 Dec 2025 Shapes closed a $15M Series A ($24M total) to double headcount, and by Oct 2026 it markets itself as 'the only HR platform actually built on AI', with agents and describe-to-build apps running on salary, performance and leave data while EU AI Act high-risk employment obligations are landing (subject to the Digital Omnibus delay); no AI or security hire is visible, so guardrails are needed before enterprise and EU deals scale.

## Product and AI
Modular PeopleOS: core HR, performance cycles, comp cycles, time off, attendance, surveys, people analytics, docs and eSign, plus AI foundations (build any view/tool by describing it, agents that run admin, AI-generated workflows, people data exposed to external AI).

- AI use: Employee-facing AI chat that answers policy and HR questions from company docs; AI agents that carry admin load; natural-language generation of workflows, views, apps and agents on live people data; AI insights in performance, surveys and analytics. Verified in company_review.csv (ships_customer_facing_llm=yes, agentic=true, confidence medium).
- Agentic: yes. Surfaces:
- Employee AI chat (policies, time off, docs)
- Agents running HR/IT/finance admin
- AI-generated workflows (onboarding, offboarding, leave)
- Describe-to-build apps, views and agents
- AI performance, survey and analytics insights
- People data exposed to external AI tools
- Customers: Quantum Machines, NextSilicon, Healthee, Arena Entertainment, Imagen, Papaya Global, WeWork 2.0, Fnatic, Callers.ai, Ineos, MSC, LayerX, Scytale

## Funding and size
- Series A ($15M; $24M combined with seed), 2025-12-10; total $24,000,000
- Investors: Entree Capital (Series A lead), NFX, F2 Venture Capital (seed lead), Magnolia Ventures
- Headcount: 11-50 (Crunchbase); a third-party tracker lists 51-100. Company says Series A funds will more than double headcount within a year and expand in Europe and North America.

## Compliance
- SOC 2: unknown (not confirmed on pages checked; a Scytale logo appears among 'trusted by', which suggests a compliance-tooling relationship, unverified)
- HIPAA: not claimed
- EU AI Act: high: AI used in employment (worker management, performance evaluation, pay) is an Annex III high-risk category; Shapes is a provider and its customers are deployers, with 79-country reach including the EU.
- Notes: Site footer shows GDPR and ISO badges (exact ISO standard not confirmed); homepage cites continuous audits, strict access controls, privacy safeguards. /security page returned 404.

## Likely pains
- Prompt injection through HR documents, tickets or employee free text steering the AI chat or agents
- Cross-tenant and cross-employee data leakage (one employee's salary or review shown to another, or across customer tenants) via chat and agents
- Agents taking destructive or unauthorised actions (changing comp, offboarding the wrong person, sending e-signature docs)
- User-built agents and apps ('describe it and build it') bypassing policy and access rules
- Biased or unlawful output in performance insights; hallucinated policy answers (leave, pay) creating legal exposure
- EU AI Act high-risk duties (logging, human oversight, risk management) plus GDPR on employee data, demanded by enterprise security reviews

## MEDDPICC hypothesis
- **metrics** (low): Time to pass enterprise security questionnaires and EU AI Act readiness; zero cross-tenant leaks or unsafe agent actions; share of AI chat answers policy-compliant
- **economic_buyer** (medium): CEO Arnon Nir; budget is founder-controlled at a 11-100 person company
- **decision_criteria** (medium): 5-minute API integration, low latency in chat, EU data region, SOC 2, customisable per-customer policies
- **decision_process** (low): Founder-led; short engineering pilot on the AI chat, then extend to agents
- **paper_process** (low): Light legal at this size; DPA and security addendum, EU region needed
- **identify_pain** (medium): Selling agentic HR to larger customers whose security teams ask about AI risk and EU AI Act high-risk status
- **champion** (low): Head of R&D / lead AI engineer building the agent layer (not yet identified); CPO Shirley Baumer as product-side sponsor
- **competition** (low): Build in-house with LLM-provider moderation or open-source guardrails; other AI security vendors

## Persona openers
- **CEO / Co-founder:** As Shapes lands bigger customers, security teams will ask how your HR agents are stopped from leaking salary data or acting on a prompt injection, and we give you a provable answer in days, not a quarter.
- **CPO / Product:** You let customers build their own agents by describing them, so what stops one of those agents from doing something your product never intended, and can you show customers an audit trail of what was blocked?
- **CTO / Head of Engineering or AI:** We sit in front of your AI chat and agent tool calls with plain-language policies, checking every input, output and action in real time, so you ship agent features without building your own safety stack.
- **CISO / Security & Compliance:** Employment AI is high-risk under the EU AI Act, and White Circle gives you logging, policy enforcement and human escalation as evidence for your customers' audits.

## Contacts
1. **Arnon Nir**, CEO & Co-founder (Economic buyer; priority 1; crunchbase) - [LinkedIn](https://www.linkedin.com/in/arnon-nir-72b22b76). Founder-led company of this size; owns budget and the enterprise-readiness story. Ex-monday.com.
2. **Shirley Baumer**, CPO & Co-founder (Product champion; priority 2; crunchbase) - [LinkedIn](https://www.linkedin.com/in/shirleyjb). Owns the agent and describe-to-build product surface where unsafe actions would originate.
3. **Adam Horne**, Advisor (Non-buyer (advisor); priority 5; crunchbase) - [LinkedIn](https://www.linkedin.com/in/adam-open-org). Advisor only; possible warm intro, not a buyer.

No CTO, security or AI lead could be verified publicly; a "Vicky Sehrawat, CTO at Shape" result is a different company and was excluded.

## Hiring
- [Software Engineer / Full Stack Engineer (core infrastructure) on Ashby; no AI/ML or security role found](https://jobs.ashbyhq.com/shapes/413e974a-a0e3-4cfb-a253-e1f32931c4e0)
- [Careers page live ('We're hiring!'), roles not listed in extract](https://shapes.co/careers)

## Risks
- Small team (11-50) and no visible security or AI-safety hire, so buying capacity and priority may be low
- SOC 2 status unconfirmed; may treat guardrails as a later concern
- Israel-based: EU AI Act exposure comes via customers, not HQ; data-region needs unconfirmed
- AI may be a thin layer over a mostly deterministic HR app, so the AI attack surface could be smaller than the agentic marketing implies
- Crunchbase headcount and third-party counts disagree; Crunchbase shows duplicate seed rows
- No leader beyond founders could be verified publicly; no AI-safety incident found

## News
- 2025-12-10: [Shapes Raises $24 Million to Redefine How Organizations Manage People in the Age of AI](https://www.accessnewswire.com/newsroom/en/computers-technology-and-internet/shapes-raises-24-million-to-redefine-how-organizations-manage-peo-1115305)
- 2025-12-10: [Ex-monday.com execs land $24M for Shapes to reinvent HR (TFN)](https://techfundingnews.com/shapes-raises-24m-ai-native-peopleos-hr-platform)
- 2025-12-23: [Shapes (formerly DreamTeam) Raises $15m for its AI native HR Platform (Entree Capital)](https://entreecap.com/resource-type/news)

## Sources
- [Shapes homepage](https://shapes.co/)
- [Shapes careers](https://shapes.co/careers)
- [Shapes funding press release (ACCESS Newswire)](https://www.accessnewswire.com/newsroom/en/computers-technology-and-internet/shapes-raises-24-million-to-redefine-how-organizations-manage-peo-1115305)
- [TechFundingNews coverage](https://techfundingnews.com/shapes-raises-24m-ai-native-peopleos-hr-platform)
- [Entree Capital news](https://entreecap.com/resource-type/news)
- [FundedIQ profile](https://fundediq.co/shapes-shapes-co-funding)
- [Shapes Ashby job posting](https://jobs.ashbyhq.com/shapes/413e974a-a0e3-4cfb-a253-e1f32931c4e0)
