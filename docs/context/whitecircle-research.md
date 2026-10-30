# White Circle: company research for ICP definition

Researched 2026-10-30 (Tavily worked). Tags: [C] = confirmed on a cited page, [I] = inferred by me.
Sources are numbered, listed at the bottom.

## 1. What the product does

- One line: an "AI control" layer. Customers write plain-language policies, and White Circle's own models check every input, output and tool call against them in real time, then block, rewrite or escalate. [C] S1, S4, S5
- Four modules on the homepage: Test (find failure modes before users do, i.e. red teaming), Control (runtime guardrails across inputs, outputs, tools), Analyze (user and model behaviour over time, monitoring), Improve (tune prompts and models from live signals, labelled-feedback loop). [C] S1
- Also: audit logs and explanations of which policy fired, per-region/jurisdiction policies, user strike/ban system with appeals, user-level risk scoring, human review queue, custom natural-language metrics, Slack and webhook alerts. [C] S1, S2, S3
- Deployment: hosted SaaS API (single event endpoint, EU and US regions, `wceu-`/`wcus-` keys), "5 mins to integrate", 99.99% uptime claim, 150+ languages, text and image checking. Docs show integration guides for an AI support chatbot, a vibe-coding app and a coding assistant. [C] S1, S2, S3
- Self-hosting: the Test product page FAQ says on-prem/VPC is supported for strict-compliance enterprises. [C] S8 (older page, treat as less certain)
- Threats covered: prompt injection, jailbreaks, PII/data leakage, hallucination, harmful/illegal content, tool abuse and destructive agent actions, token drain, abuse/anomalous users, model drift, compliance policy checks. Brand safety and tone are covered on the Test page. [C] S1, S3, S8, S9
- Security attestations: SOC 2 Type I and II, HIPAA. [C] S1, S5
- Own research: CircleGuardBench (moderation benchmark), KillBench (bias study), Halo (open-source training framework); they train their own models for the job. [C] S1, S4

## 2. Who they sell to

Named customers
- Lovable (vibe-coding platform): the only named logo. Full case study plus CISO quote (Igor Andriushchenko). Lovable sends every session event to White Circle; use case is user abuse (phishing sites, malware, explicit content, unsafe commands, multi-step jailbreaks) and agent supervision. [C] S1, S3. Technical partnership announced on LinkedIn. [C] S10
- "Two of the world's largest digital banks" (unnamed) and, per Fortune, "several fintech and legal companies". [C] S5, S6. The company's own job post says "multiple neobanks". [C] S7. None are named anywhere I found. [C]

Industries marketing calls out
- Homepage "one control layer, every industry" tabs: Government, Healthcare, Education. [C] S1
- SEO landing pages exist for finance, insurance, healthcare, government, education, HR, e-commerce, gaming, creative tools, real estate, plus use-case pages (agentic AI security, chatbot guardrails, hallucination detection, content moderation API, data-leak prevention, prompt injection). [C] S11
- Every vertical page is framed as "what AI system do you run" (chatbot, copilot, underwriting AI, claims assistant, fraud assistant). So the trigger is a deployed AI system, not the vertical. [C] S11, S12

Buyer persona
- Only named buyer: a CISO (Lovable). [C] S3
- No persona page exists. Docs and the 5-minute API pitch imply engineers/AI platform teams as users and champions; trust and safety/moderation fits the content-moderation and strike-system features. Compliance/risk is plausible for banks. [I]

Company size and stage of customers
- Lovable is a fast-growing AI-native scale-up; neobanks are large fintechs. Smaller prospects are reachable self-serve ("Get Started" login), larger via "Contact Sales". [I from S1]

Pricing and packaging
- No public pricing found on the site or docs. Self-serve signup plus Contact Sales and Request a Demo. Packaging language: "unlimited custom policies". Usage/cost API exists in docs ("Usage & Cost"), suggesting usage-based billing. [C that no price is public; usage-based is I] S1, S2
- Traction: multi-million-dollar run rate, 100M+ API calls a month (job post) and 1B+ requests cumulative (press). [C] S7, S5

## 3. Regulatory angle

- The philosophy page argues deployers carry the legal responsibility: "A bank is responsible for what its assistant tells a customer about their mortgage... under the EU AI Act, deployers carry their own obligations." That is the only EU AI Act mention I found on their own pages. [C] S13
- Product regulation hooks: per-country/state policies, audit logs "for compliance and incident review", compliance checks in the control flow, EU data region, GDPR mention on the insurance page, HIPAA. [C] S1, S3, S12
- DORA: no mention found anywhere. [C that I did not find it]
- No compliance-reporting module (no EU AI Act dashboard or report) found; compliance is delivered as policies plus audit trail. [I]
- Does it target non-AI/traditional companies? Only as deployers. Every example involves an LLM or agent talking to end users or taking actions (finance chatbot, underwriting AI, claims assistant). Internal-only AI is mentioned in one place: careers says it ships to companies deploying AI "for customers and inside their own systems". [C] S12, S14. The regulatory pitch (deployer liability) would extend to a bank with an internal copilot, but no evidence of such a sale. [I]

## 4. Company facts

- Name: White Circle, PBC (Public Benefit Corporation); also seen as "Pumpkin Intelligence". [C] S4, S15
- HQ: Paris, with London office and a US presence/hiring (NY, SF, LA remote). [C] S4, S14
- Founded: 2025 per Tracxn; CEO's LinkedIn dates the role from Jan 2025. [C] S16, S17
- Founder and CEO: Denis Shilov. Went viral in 2024 with a universal jailbreak (1.4M views), then Anthropic independent safety researcher (Nov 2024 to Jan 2025). Earlier: co-founder/CEO Synthical, head of product and tech at Nim, senior engineer at Deepnote, co-founder Phraser. LSE degree. [C] S5, S6, S17, S18. Head of Design: Elena Iumagulova. [C] S19
- Funding: conflicting figures.
  - Seed of $11M announced 12 May 2026 (Fortune, TechFundingNews, Business Wire). Angels: Romain Huet (OpenAI), Durk Kingma, Guillaume Lample (Mistral), Thomas Wolf (Hugging Face), Olivier Pomel (Datadog), Francois Chollet, Mehdi Ghissassi, Paige Bailey, David Cramer (Sentry). [C] S5, S6, S20
  - Their own site (company page, careers, job posts) now says "raised $70M" and "recently raised our Series A", total $70M. No press article for the Series A found. [C that the site says it; the round itself is unverified by press] S4, S7, S14
  - Institutional investors listed on the company page: Hummingbird, Abstract, Saga VC, Box Group, SVA, BOND, QuantumLight, Factorial Capital, Drysdale, Ritual Capital, Kima Ventures, Moonfire and others. [C] S4. Tracxn lists Moonfire as seed investor. [C] S16
- Headcount: 20 as of May 2026 (Fortune), almost all engineers, across London, France, Amsterdam. Now 17 open roles. [C] S6, S4
- Open GTM roles (careers page): Founding Account Executive (NY, SF, London, Remote) and Founding GTM Engineer (London, remote). The GTM Engineer post says: own the CRM and data model, outbound/inbound automation, AI agents, tooling like Claude Code, Clay, Apollo, Instantly, n8n; success in 6 months means identifying the highest-converting early segments and one or two messaging wedges. This is the take-home's role. [C] S7, S14. The Founding AE page returned 404 on direct fetch but is listed. [C] S14
- Also hiring DevRel Lead, Content Lead, Talent Lead, red team engineer, research roles. [C] S14

## 5. Competitors and differentiation

- Explicit comparison page vs Lakera. Claims: unlimited custom policies vs 7 fixed, geo-specific policies, audit trail, F1 0.991 vs 0.639 (their own test, reproduction on request), longer context, auto-adjusting policies from FP/FN labels, agent and tool-call coverage. [C] S9
- Another page contrasts custom policies with "fixed detector sets" of typical guardrail vendors. [C] per S15 (secondary)
- Positioning pillars (philosophy page): independence from model labs, deployer-owned control, context-specific alignment, own fast specialised models (latency is the product), control across the lifecycle and agent actions. [C] S13
- Third-party-named adjacent players: Lakera (now Check Point), Protect AI, Prompt Security, Guardrails AI, HiddenLayer, Lasso, CalypsoAI, Arthur AI, WhyLabs; monitoring vendors Datadog and Scale AI. [C that these appear in third-party lists] S15, S21, S22. White Circle itself names only Lakera in what I found. [C]
- Differentiation in one line: custom, natural-language policies over fixed detectors, enforced by its own low-latency models, covering agents and tool calls, from an independent vendor. [I summary]

## 6. ICP implications for scoring a Crunchbase list

All of this is inferred from sources above. Evidence quality is thin (one named customer, two unnamed bank logos).

1. Companies that do not ship LLM features: do not count in the fit score. The product has nothing to attach to without an LLM or agent in production, and every page frames the trigger as "what AI system do you run". Treat as zero, or keep only as a long-watch nurture tier for companies with strong signs of a first AI launch (new AI hires, AI roadmap posts). [I from S11, S12]
2. Traditional banks and insurers with internal-only AI: low priority, not zero. The regulatory deployer-liability pitch applies to them in principle, and the finance/insurance pages exist, but the proven wins are neobanks/digital banks, not incumbents. Incumbents also mean long procurement and a Founding AE-sized motion. Score only if they have a customer-facing assistant, claims/underwriting AI or agentic workflow, otherwise tier 3. [I from S5, S11, S12]
3. AI-native app builders (Lovable-like) vs fintechs with customer chatbots: both are validated. AI-native builders have the highest pain (agents executing code, millions of sessions, abuse) and the only public logo, so rank them first for the "agentic/vibe-coding/creative tools" wedge. Fintechs/neobanks with customer-facing LLM assistants are the second validated wedge with larger contract potential. [C that both are customers; ranking is I] S3, S5, S6
4. Size: need real LLM traffic and a security/engineering function. Sweet spot is Series A to growth-stage companies with meaningful users plus enterprises' fintech arms; tiny pre-seed teams are likely self-serve only. Funding recency matters because it signals AI roadmap investment and budget. [I]
5. Geography: White Circle has EU and US regions, a Paris/London base, and is hiring AEs in NY/SF/London. Prioritise US and UK/EU first. EU companies carry an extra AI Act/GDPR hook. Other regions low. [I from S2, S6, S14]
6. Signals that show an account is a fit (rank roughly in this order):
   - Ships a customer-facing LLM feature, chatbot or agent (product page, changelog, docs mention of "AI assistant", "copilot", "agent")
   - Agentic action-taking: coding agents, tool use, MCP, browser or workflow agents (higher blast radius)
   - High-volume, consumer or open-signup user base (abuse and jailbreak exposure)
   - Regulated customers or data: fintech/neobank, insurance, health, legal, HR, government/education (PII, advice and bias risk)
   - Hiring for AI/ML engineers, AI security, trust and safety, or "AI governance"; named CISO or head of AI
   - Uses OpenAI/Anthropic/Gemini APIs, or other model-provider signals (job posts, tech stack, public integrations)
   - Recent funding round (to fund AI rollout), US/UK/EU base, 20+ employees
   - Public AI incident, jailbreak or safety complaint about their product
   - Counter-signals: AI is only a back-office tool, no end-user exposure, existing vendor like Lakera/Prompt Security already deployed (competitive displacement possible but harder)

## Confirmed vs inferred

- Confirmed on first-party or press pages: product modules, hosted-API deployment, SOC 2/HIPAA, Lovable customer, unnamed digital-bank/fintech/legal customers, $11M seed, $70M claim on own site, Paris/London base, CEO background, 20 staff in May 2026, GTM job posts, Lakera comparison.
- Inferred: buyer personas beyond the Lovable CISO, usage-based pricing, size sweet spot, treatment of incumbents, relative ranking of wedges, all of section 6.
- Not found: public pricing, DORA language, named bank customers, press coverage of the Series A, a named competitor besides Lakera on their own pages, an EU AI Act compliance-reporting module. A $70M total is unreconciled with the $11M seed, so cite both with caveats.
- The Notion assignment says "customers like Lovable and neobanks" and "AI-safety platform sold to companies deploying LLMs"; both statements match the public record.

## Sources

- S1 https://whitecircle.com (homepage)
- S2 https://docs.whitecircle.com/ and https://docs.whitecircle.com/llms.txt
- S3 https://whitecircle.com/case-study/lovable
- S4 https://whitecircle.com/company
- S5 https://techfundingnews.com/french-startup-white-circle-secures-11m-from-openai-anthropic-deepmind-leaders-to-monitor-and-secure-enterprise-ai
- S6 https://fortune.com/2026/05/12/exclusive-white-circle-raises-11-million-to-stop-ai-models-from-going-rogue-in-the-workplace
- S7 https://whitecircle.com/careers/founding-gtm-engineer-4c2cfdd6-e7fc-4c39-84d8-517b7d52c5de
- S8 https://whitecircle.com/test
- S9 https://whitecircle.com/compare/lakera
- S10 https://www.linkedin.com/posts/nikita-andersson-2a1b77165_safe-secure-and-reliable-ai-has-been-top-activity-7483195694107955200-E3ms
- S11 https://whitecircle.md/ (page index with industry and landing pages)
- S12 https://www.whitecircle.md/industries/finance and https://www.whitecircle.md/industries/insurance
- S13 https://whitecircle.com/philosophy
- S14 https://whitecircle.com/careers
- S15 https://cybercompanyprofiles.com/companies/white-circle (third-party, auto-generated)
- S16 https://tracxn.com/d/companies/white-circle/__aEVJKuAYNI_FbiDFk55HJQj48fohn4eFEc7eXqasZSg
- S17 https://fr.linkedin.com/in/mixeden (Denis Shilov profile)
- S18 https://theaiinsider.tech/2026/05/14/white-circles-ai-control-platform-closes-11m-in-funding-from-industry-giants-after-founder-goes-viral-for-exposing-safety-flaw-in-biggest-ai-models
- S19 https://fintech.global/2026/05/14/white-circles-11m-bet-on-real-time-ai-control
- S20 https://www.businesswire.com/news/home/20260512448166/en/White-Circles-AI-Control-Platform-Raises-%2411m-from-Industry-Giants-After-Founder-Goes-Viral-for-Exposing-Safety-Flaw-in-Biggest-AI-Models
- S21 https://www.cbinsights.com/company/lakera-ai/alternatives-competitors
- S22 https://www.respan.ai/market-map/robust-intelligence
- Also read: https://whitecircle.com/privacy (platform description), https://www.startupmag.co.uk/funding/white-circle-2026-growth-funding
