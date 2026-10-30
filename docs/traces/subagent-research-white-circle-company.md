# Subagent trace: Research White Circle company

A delegated subagent (general-purpose). Its prompt, its tool calls and results, and its final report. Same redaction rules as the main session.

## Turn 1 - User (2026-10-30 13:37:10 UTC)

Research the company White Circle (https://whitecircle.com/, also whitecircle.ai) for a GTM Engineer take-home. The candidate needs to define White Circle's ideal customer profile (ICP) accurately. Read white_circle/docs/assignment.md first. It says they have "customers like Lovable and neobanks", they sell an "AI-safety platform sold to companies deploying LLMs", and they use Attio and Clay.

Tools: first try the Tavily MCP tools (load them via ToolSearch "select:mcp__claude_ai_Tavily__tavily_search,mcp__claude_ai_Tavily__tavily_extract,mcp__claude_ai_Tavily__tavily_map"). The plan may be over its limit (error 432). If so, don't retry. Use WebFetch and WebSearch (load via ToolSearch) instead. Start by mapping the site (homepage, product pages, docs, pricing, blog, case studies, careers, about), then search the press (funding, founders, HQ) and check LinkedIn/X if they're reachable.

Answer, citing a source URL for every claim and marking anything inferred:
1. What exactly the product does. Products/modules (guardrails, red teaming, monitoring, evals, policy enforcement, compliance reporting?), deployment model (API/SDK/proxy, self-hosted?), and what threats they cover (prompt injection, jailbreaks, PII leakage, hallucination, brand safety, regulatory).
2. Who they sell to. Named customers and logos, case studies, the industries their marketing calls out, the buyer persona (CTO, Head of AI, CISO, compliance, trust & safety), company size, and pricing/packaging.
3. Regulatory angle. EU AI Act, DORA, financial-services or health language. Does any of it target traditional/non-AI companies, or only companies shipping LLM features to end users?
4. Company facts. HQ, founding year, founders and their backgrounds, funding and investors, headcount, open roles (especially GTM).
5. Competitors they position against (Lakera, Protect AI, Guardrails AI, Arize, Patronus, CalypsoAI, Prompt Security, etc.) and how they differentiate.
6. ICP implications for scoring a Crunchbase list. Concretely: should companies that don't ship LLM features count at all? Should traditional banks or insurers with internal-only AI count? Do AI-native app builders (like Lovable) or fintechs with customer-facing chatbots matter more? Do geography and size matter? List the signals that would show an account is a fit.

Write the findings to white_circle/docs/whitecircle-research.md. Keep it concise: sections for 1–6, a "confirmed vs inferred" note, and a source list. Touch nothing else and don't commit. Final reply, max 15 lines: the product in one line, the named customers, the target industries and personas as stated on their site, the answer to "do non-AI or traditional-finance companies fit?" with evidence, and the 3 ICP signals you'd weight most. Also say whether Tavily worked.

Tool call `Read`
```
{
 "file_path": "white_circle/docs/assignment.md"
}
```

Result of `Read`
```
1	# GTM Engineer — Take-Home Exercise
2	
3	> Source: https://whitecircle.notion.site/GTM-Engineer-Take-Home-Exercise-38fc3dbe97908031bd22cb2d027b3f23 (copied 2026-10-29)
4	
5	
6	We’re at a critical juncture - revenue and customers, but no repeatability or playbook. Right now we have customers like Lovable and neobanks. Sales were founder-led till recently. We have started using Attio, Clay and are open to other tools as they become needed (eg. Granola for meetings where Attio cannot record, but don’t fixate on this).
7	
8	Customer segmentation is not defined and we have SDRs and AEs joining soon. SDRs will be almost solely focused on cold calling, other channels should be automated for them. We want to prevent AEs from having to hunt so they can just focus on closing. Paid ads will be running in a few weeks and RB2B has been installed on our website.
9	
10	
11	---
12	
13	
14	#### Part 1 - Segmentation
15	*(Attachment: gtm-takehome-dataset.zip — the three CSVs in `data/raw/`)*
16	We've given you a slice of Crunchbase company data. It's raw and a little messy, on purpose.
17	
18	Load it using the tool/tech of your choice, explore it, and use SQL to answer one question: *which companies should our AEs prioritize, and how would you group them into segments?*
19	
20	- This is open-ended. You decide what "good fit" means for an AI-safety platform sold to companies deploying LLMs, and you defend it. There is no answer key.
21	- We want to see your SQL, not just conclusions. Show how
... [truncated 2345 chars]
```

Tool call `ToolSearch`
```
{
 "query": "select:mcp__claude_ai_Tavily__tavily_search,mcp__claude_ai_Tavily__tavily_extract,mcp__claude_ai_Tavily__tavily_map,WebFetch,WebSearch",
 "max_results": 10
}
```

Result of `ToolSearch`
```
[omitted: tool-schema lookup]
```

Tool call `mcp__claude_ai_Tavily__tavily_map`
```
{
 "url": "https://whitecircle.ai",
 "limit": 80
}
```

Tool call `mcp__claude_ai_Tavily__tavily_search`
```
{
 "query": "White Circle AI safety funding founders",
 "max_results": 10,
 "search_depth": "advanced"
}
```

Result of `mcp__claude_ai_Tavily__tavily_map`
```
{"base_url":"https://whitecircle.ai","results":["https://whitecircle.ai/","https://whitecircle.ai/company","https://whitecircle.ai/terms","https://whitecircle.ai/cookies","https://whitecircle.ai/privacy","https://whitecircle.ai/contact","https://whitecircle.ai/dpa","https://whitecircle.ai/careers","https://whitecircle.ai/research","https://whitecircle.ai/philosophy","https://whitecircle.ai/research/circleguardbench","https://whitecircle.ai/case-study/lovable","https://whitecircle.ai/research/killbench","https://whitecircle.ai/research/glm-4-7-flash-coder","https://whitecircle.ai/research/halo","https://whitecircle.ai/research/rise","https://whitecircle.ai/?scrollTo=features","https://docs.whitecircle.com/","https://status.whitecircle.com/","https://whitecircle.md/"],"response_time":0.35,"request_id":"a1c9e916-a69d-48b6-8444-b7e860cae50b","auth_mode":"keyed"}
```

Result of `mcp__claude_ai_Tavily__tavily_search`
```
{"query":"White Circle AI safety funding founders","follow_up_questions":null,"answer":null,"images":[],"results":[{"title":"White Circle’s AI Control Platform Closes $11M in Funding from Industry Giants After Founder Goes Viral for Exposing Safety Flaw in Biggest AI Models","url":"https://theaiinsider.tech/2026/05/14/white-circles-ai-control-platform-closes-11m-in-funding-from-industry-giants-after-founder-goes-viral-for-exposing-safety-flaw-in-biggest-ai-models","content":"White Circle, an AI monitoring and safety platform, has raised $11 million in seed funding from a roster of prominent industry angels including executives from OpenAI, Anthropic, Mistral, Hugging Face, and Datadog, with capital earmarked for product development and team expansion across the US, UK, and Europe.\n Founded by Denis Shilov, who went viral in 2024 after bypassing the safety filters of every major AI model with a single prompt, the platform monitors AI inputs and outputs in real time, detecting harmful content, hallucinations, prompt injection attacks, and model drift through a single API with support for 150 languages. [...] PRESS RELEASE — White Circle — the platform trusted by global brands to keep their AI models in check — has raised $11m from some of the biggest names in the industry including Romain Huet (OpenAI); Dirk Kingma (ex-OpenAI, now Anthropic); Guillaume Lample (Mistral); Thomas Wolf (Hugging Face); Olivier Pomel (Datadog); François Chollet (Keras); Mehdi Ghissassi (ex-DeepMind)
... [truncated 14899 chars]
```

Tool call `mcp__claude_ai_Tavily__tavily_extract`
```
{
 "urls": [
  "https://whitecircle.com",
  "https://whitecircle.com/case-study/lovable",
  "https://whitecircle.com/careers",
  "https://whitecircle.com/company",
  "https://whitecircle.com/philosophy"
 ],
 "extract_depth": "advanced"
}
```

Tool call `mcp__claude_ai_Tavily__tavily_extract`
```
{
 "urls": [
  "https://docs.whitecircle.com/",
  "https://techfundingnews.com/french-startup-white-circle-secures-11m-from-openai-anthropic-deepmind-leaders-to-monitor-and-secure-enterprise-ai",
  "https://cybercompanyprofiles.com/companies/white-circle"
 ]
}
```

Tool call `mcp__claude_ai_Tavily__tavily_search`
```
{
 "query": "White Circle Fortune $70M Denis Shilov raise Series A",
 "max_results": 8,
 "time_range": "month"
}
```

Tool call `mcp__claude_ai_Tavily__tavily_search`
```
{
 "query": "White Circle vs Lakera Prompt Security Guardrails AI alternatives comparison",
 "max_results": 8
}
```

Result of `mcp__claude_ai_Tavily__tavily_extract`
```
{"results":[{"url":"https://whitecircle.com","title":"White Circle","raw_content":"If you're an LLM or agent, please use https://whitecircle.mdto explore our website as Markdown.\n\nIf you're an LLM, you can read this page as Markdown at <https://whitecircle.md/index>.\n\n![](/_next/image?url=%2F_next%2Fstatic%2Fmedia%2Fring-mobile-menu.3mvw5zdp0qve3.png&w=3840&q=100)\n\n[Get Started](https://us.whitecircle.com/login)[Contact Sales](/contact)\n\n# Control user and model behavior in real timeControl user and model behavior in real time\n\n[Get Started](https://us.whitecircle.com/login)[Request a Demo](/contact)\n\n### Test\n\nDiscover failure modes before your users do\n\n### Control\n\nEnforce behavior across inputs, outputs, and tools\n\n### Analyze\n\nUnderstand how your users and AI behave over time\n\n### Improve\n\nTune prompts and models from live signals\n\n# Control user and model behavior in real timeControl user and model behavior in real time\n\n[Get Started](https://us.whitecircle.com/login)[Request a Demo](/contact)\n\nDiscover failure modes before your users do\n\nEnforce behavior across inputs, outputs, and tools\n\nUnderstand how your users and AI behave over time\n\nTune prompts and models from live signals\n\n# Control user and model behavior in real timeControl user and model behavior in real time\n\n[Get Started](https://us.whitecircle.com/login)[Request a Demo](/contact)\n\n### Test\n\nDiscover failure modes before your users do\n\n### Control\n\nEnforce 
... [truncated 41887 chars]
```

Result of `mcp__claude_ai_Tavily__tavily_extract`
```
[redacted: outside project scope]
```

Result of `mcp__claude_ai_Tavily__tavily_search`
```
{"query":"White Circle vs Lakera Prompt Security Guardrails AI alternatives comparison","follow_up_questions":null,"answer":null,"images":[],"results":[{"url":"https://www.cbinsights.com/company/lakera-ai/alternatives-competitors","title":"Top Lakera Alternatives, Competitors","content":"Technology Vendors\n Recent Research\n Newsletter\n Media Support\n Login\n\nCB Insights\n\nLakera company logo\n\n# Lakera\n\nAnalyst Briefing Submitted\n\nlakera.ai\n\n## Lakera's alternatives and competitors\n\nSee how Lakeracompares to similar products. Lakera's top competitors include Guardrails AI, HiddenLayer, and Lasso Security.\n\nGuardrails AI Logo\n\nGuardrails AI [...] Guardrails AI\n HiddenLayer\n Lasso Security\n Molt AI\n Mindgard\n Arthur\n Straiker\n RunLayer\n MindFort\n ZeroPath\n\n## Compare Lakera to Competitors\n\nProtect AI Logo\n\nProtect AI [...] Guardrails AI\n\nGuardrails AI operates within the artificial intelligence and technology sectors. It offers a platform for building, governing, and scaling production-grade generative …\n\nLakera vs. Guardrails AI\n\nView Lakera's entire Analyst Briefing\n\nLakera's Analyst Briefing includes information on:\n\n Pricing\n Customer references\n Products\n\nCompare Lakera and Guardrails AI\n\nNew call-to-action\n\n HiddenLayer Logo\n\n  HiddenLayer\n\n  Analyst Briefing Submitted","score":0.6469293,"raw_content":null,"id":"23ac4a-00"},{"url":"https://www.cbinsights.com/company/guardrails-ai/alternatives-competitors","title":"To
... [truncated 8964 chars]
```

Result of `mcp__claude_ai_Tavily__tavily_search`
```
{"query":"White Circle Fortune $70M Denis Shilov raise Series A","follow_up_questions":null,"answer":null,"images":[],"results":[{"url":"https://www.aol.co.uk/articles/10-rare-coins-hiding-change-103000000.html","title":"10 Rare Coins Hiding in Your Change Jar That Could Be ...","content":"Discover 10 very rare United States coins that collectors chase that could fetch hundreds, with updated market values and expert insights for savvy buyers.","score":0.018965354,"raw_content":null,"id":"d3242e-00"},{"url":"https://www.greysheet.com/prices/nc/united-states-dimes/8242","title":"Collectible Dime Values & Prices","content":"Find the current Dimes values by year, coin varieties, and specific grade. A Saturday, August 1, Call: (757) 656-1055 Email: support@greysheet.com","score":0.011518178,"raw_content":null,"id":"c25dde-01"},{"url":"https://www.greysheet.com/prices/sp/ten-cent-dime-coin-rolls-proof?nodeid=12183","title":"Dime, Proof 1964– Values & Prices","content":"Find the current Dimes, Proof (1964– ) values by year, coin varieties, and specific grade.","score":0.011411925,"raw_content":null,"id":"3ee568-02"}],"response_time":2.64,"request_id":"8e1b5cf1-2768-4bd5-bf0b-94649c6bec1f","auth_mode":"keyed"}
```

Tool call `Bash`
```
[redacted line: outside-scope]
import json,re
d=json.load(open('toolu_01FReeeHeZ4gy17taqvoHe4p.txt'))
for r in d['results']:
    t=r['raw_content']
    print('=====',r['url'],len(t))
    if 'docs.white' in r['url']:
        print(t[1800:7000])
    elif 'techfunding' in r['url']:
        print(t[:3500])
    else:
        print(t[:6000])
E
```

Tool call `mcp__claude_ai_Tavily__tavily_extract`
```
{
 "urls": [
  "https://whitecircle.com/careers/founding-gtm-engineer-4c2cfdd6-e7fc-4c39-84d8-517b7d52c5de",
  "https://whitecircle.com/careers/founding-account-executive-da7257e0-940f-474c-82af-81fe95b3dd67"
 ]
}
```

Tool call `mcp__claude_ai_Tavily__tavily_search`
```
{
 "query": "White Circle Denis Shilov Fortune AI control startup customers banks Lovable",
 "max_results": 8,
 "search_depth": "advanced"
}
```

Tool call `mcp__claude_ai_Tavily__tavily_search`
```
{
 "query": "whitecircle.com pricing EU AI Act guardrails compliance",
 "max_results": 8,
 "include_domains": [
  "whitecircle.com",
  "docs.whitecircle.com",
  "whitecircle.ai"
 ]
}
```

Result of `Bash`
```
[redacted: outside project scope]
```

Result of `mcp__claude_ai_Tavily__tavily_extract`
```
{"results":[{"url":"https://whitecircle.com/careers/founding-gtm-engineer-4c2cfdd6-e7fc-4c39-84d8-517b7d52c5de","title":"Founding GTM Engineer — Careers at White Circle","raw_content":"If you're an LLM, you can read this page as Markdown at <https://whitecircle.md/careers/founding-gtm-engineer-4c2cfdd6-e7fc-4c39-84d8-517b7d52c5de>.\n\n# Founding GTM Engineer\n\nWe’re looking for a GTM Engineer to automate low-value commercial work and build the systems that generate qualified pipeline at scale. You’ll own the GTM infrastructure end to end: design the data model, keep the CRM reliable, connect the stack, deploy AI agents, automate outbound and inbound workflows, and continuously improve how we acquire and retain customers.\n\n## About White Circle\n\n[White Circle](https://whitecircle.ai/) is an AI Safety company building the safety, reliability, and optimization layer for AI systems. At the core of our platform are policies – simple natural-language rules that define what an AI model should and shouldn’t do. We automatically test, enforce, and continuously improve these policies at scale.\n\nWe’ve recently raised our Series A funding round, taking our total funding to $70M. Our investors include top funds, founders, and senior leaders at OpenAI, Anthropic, HuggingFace, Mistral, DeepMind, Datadog, Sentry, and others\n\nWe process over 100M+ API calls every month\n\nWe fine-tune and train our own LLMs so they run faster and cheaper than any open or proprietary model\n\nWe’re at
... [truncated 3930 chars]
```

Result of `mcp__claude_ai_Tavily__tavily_search`
```
{"query":"whitecircle.com pricing EU AI Act guardrails compliance","follow_up_questions":null,"answer":null,"images":[],"results":[{"url":"https://whitecircle.com/careers","title":"White Circle","content":"White Circle platform ships guardrails, monitoring and red-teaming to companies deploying AI systems for customers and inside their own systems. Our own models, state of the art for this one job, check every input, output and action against custom rules and stop what should not happen in the time it takes the AI to act. We process tens of millions of requests every month. [...] If you're an LLM, you can read this page as Markdown at .\n\nGet StartedContact Sales\n\n# Come build with us. We’re building the independent control layer for AI.\n\nView open roles\n\nSmall team with big ambitions\n\nUS, Europe\n\nA truly international team\n\n## About White Circle\n\nWhite Circle is building the most advanced independent control layer for AI. [...] Behind the product is a research team building adversarial environments, behavioral evaluations and multi-agent testbeds to find out how AI systems fail before they fail in production. What we find goes into the models we train, and we publish it.\n\nWe are a Public Benefit Corporation based in Paris and London, and have raised $70 million from senior leaders and researchers at Hugging Face, OpenAI, Anthropic, DeepMind, Mistral, Datadog and other AI companies.","score":0.4635177,"raw_content":null,"id":"80acf0-00"}],"response_time":1.28
... [truncated 73 chars]
```

Result of `mcp__claude_ai_Tavily__tavily_search`
```
{"query":"White Circle Denis Shilov Fortune AI control startup customers banks Lovable","follow_up_questions":null,"answer":null,"images":[],"results":[{"url":"https://cybercompanyprofiles.com/companies/white-circle","title":"White Circle: Funding, Competitors and Strategy","content":"White Circle sells companies an AI control platform for the models and agents in their products. It checks inputs, outputs and agent actions in real time against policies each customer writes in plain language. Its named customer is the coding startup Lovable, whose CISO says the product protects millions of AI interactions a day. The company says it has a multi-million-dollar run rate, with digital banks and fintech and legal companies as customers. Leaders at OpenAI, Anthropic and DeepMind backed its $11 million seed round. Fortune reports a team of 20, almost all engineers. White Circle bets that model providers will not solve AI safety through training alone. Buyers could drop White Circle if those providers or monitoring vendors such as Datadog add per-customer policy checks. [...] White Circle names a rival itself. It publishes a comparison page titled “Why teams choose White Circle over Lakera” and a second page contrasting its custom policies with the fixed detector sets of typical guardrail vendors. Both pages are the company’s own positioning.\n\nThe product works independently of any one model provider. The Lovable case study says White Circle is model-agnostic and that Lovable can sw
... [truncated 15132 chars]
```

Tool call `mcp__claude_ai_Tavily__tavily_extract`
```
{
 "urls": [
  "https://whitecircle.md/",
  "https://docs.whitecircle.com/llms.txt",
  "https://cybercompanyprofiles.com/companies/white-circle"
 ],
 "query": "pricing, customers, competitors Lakera, EU AI Act, banks, industries, sales motion"
}
```

Tool call `mcp__claude_ai_Tavily__tavily_search`
```
{
 "query": "White Circle Series A $70 million AI control Shilov",
 "max_results": 8,
 "start_date": "2026-06-01"
}
```

Result of `mcp__claude_ai_Tavily__tavily_search`
```
{"query":"White Circle Series A $70 million AI control Shilov","follow_up_questions":null,"answer":null,"images":[],"results":[{"url":"https://www.mckinsey.com/mgi/our-research/the-ai-economy-interconnected-forces-feedback-loops-and-speeds-of-change","title":"The AI economy: Interconnected forces and feedback loops | McKinsey","content":"to keep up.8As noted by C. C. Wei, TSMC’s CEO, in the company’s second-quarter earnings call, July 20, 2023. Buyers reportedly faced lead times of up to 11 months for a finished H100-based server.9Anton Shilov, “Wait times for Nvidia’s AI GPUs ease to three to four months, suggesting peak in near-term growth—the wait list for an H100 was previously eleven months: UBS,” Tom’s Hardware, February 16, 2024. The fix was more capacity, and TSMC built faster than it ever had.10“TSMC announces the [...] that control these choke points may capture outsize value even when they play only a small role in producing the underlying product or service. As a result, businesses that develop or make the best use of AI may not always capture the greatest economic gains from it. [...] As models improve and spread, access to the best technology may provide only a temporary edge because today’s leading model can be quickly overtaken or matched. AI can also commoditize capabilities, making skills that once distinguished companies widely available. That could shift advantage toward things AI cannot easily replicate or bypass—critical workflows, customer relationships
... [truncated 1503 chars]
```

Result of `mcp__claude_ai_Tavily__tavily_extract`
```
{"results":[{"url":"https://docs.whitecircle.com/llms.txt","title":null,"raw_content":"- Create Strike: Create a user strike for a Policy violation and get the resulting effective action.\n- Create Appeal: Create a strike appeal for reviewer workflow and downstream action updates.\n- Get Appeal: Retrieve strike appeal status and current appeal review outcome details.\n- Usage & Cost\n- Getting Started: Set up text and image moderation rules for your application in minutes\n- Policies: Define content moderation rules for your application\n- Deployments: Group policies for different use cases and environments\n- Metrics: Build product analytics for AI applications using natural language\n- Strike System: Set up strike severity, actions, metadata, and appeals [...] - Metrics: Build product analytics for AI applications using natural language\n- Strike System: Set up strike severity, actions, metadata, and appeals\n- AI Support Chatbot: Integrate White Circle into your AI-powered customer support chatbot to moderate conversations in real-time\n- Vibe Coding App: Integrate White Circle into your AI-powered code generation app to moderate prompts and generated code in real-time\n- Slack: Receive real-time notifications in Slack when policy violations occur\n- Webhooks: Receive real-time event notifications via HTTP webhooks\n- Check Content\n- Get Results by ID\n- Checking Text: Send text content for policy analysis\n- Checking Images: Analyze images alongside text for combined pol
... [truncated 4750 chars]
```

Tool call `mcp__claude_ai_Tavily__tavily_search`
```
{
 "query": "White Circle AI safety for finance insurance healthcare landing page",
 "include_domains": [
  "whitecircle.com",
  "whitecircle.md"
 ],
 "max_results": 10,
 "search_depth": "advanced"
}
```

Tool call `mcp__claude_ai_Tavily__tavily_search`
```
{
 "query": "Why teams choose White Circle over Lakera",
 "include_domains": [
  "whitecircle.com",
  "whitecircle.md"
 ],
 "max_results": 5,
 "search_depth": "advanced"
}
```

Result of `mcp__claude_ai_Tavily__tavily_search`
```
{"query":"Why teams choose White Circle over Lakera","follow_up_questions":null,"answer":null,"images":[],"results":[{"url":"https://whitecircle.com/company","title":"Company — White Circle","content":"## Why White Circle\n\n White Circle is a point of light against a dark background. Most companies building powerful AI are focused on increasing capabilities. We are focused on keeping AI safe and under control.\n White Circle is the light at the end of a tunnel. We expect the transition to a world of capable AI systems to be long and uncertain, and whether it ends well will depend in part on whether people keep the ability to stop and correct these systems along the way.\n Circle represents containment, a boundary. An AI system should act within clearly defined limits, and be stopped before it crosses them.\n\n## Backed by leading investors\n\n## Open roles\n\n Creative\n Operations\n Product\n Research\n Sales\n\n17\n\n Paris officeParis\n London officeLondon\n US officeUS\n Remote officeRemote [...] ### Come build with us.\n\nView open roles\n\nThe White Circle team\n\nUse the arrow keys to explore team members, then Tab to their social profile. Press Escape to close.\n\n## What it’s like at White Circle\n\nMission. White Circle builds independent control over AI so that we prevent catastrophic outcomes.\n\nCulture. We are a team of people that want to work hard on challenging problems that matter, and few matter more than the future of AI. We move fast, work in person, and
... [truncated 10003 chars]
```

Result of `mcp__claude_ai_Tavily__tavily_search`
```
{"query":"White Circle AI safety for finance insurance healthcare landing page","follow_up_questions":null,"answer":null,"images":[],"results":[{"url":"https://whitecircle.com/privacy","title":"White Circle","content":"Visit our website at  or any website of ours that links to this Privacy Notice\n Use White Circle Platform. A security solution designed to protect and monitor generative AI applications. It includes both pre-production testing tools and runtime safeguards to identify and mitigate risks related to prompt injection, data leakage, and policy violations in AI systems.\n Engage with us in other related ways, including any sales, marketing, or events [...] As part of our Services, we offer products, features, or tools powered by artificial intelligence, machine learning, or similar technologies (collectively, \"AI Products\"). These tools are designed to enhance your experience and provide you with innovative solutions. The terms in this Privacy Notice govern your use of the AI Products within our Services.\n\nUse of AI Technologies [...] How We Process Your Data Using AI\n\nAll personal information processed using our AI Products is handled in line with our Privacy Notice and our agreement with third parties. This ensures high security and safeguards your personal information throughout the process, giving you peace of mind about your data's safety.\n\n## 7. HOW DO WE HANDLE YOUR SOCIAL LOGINS?\n\nIn Short: If you choose to register or log in to our Services using 
... [truncated 11804 chars]
```

Tool call `mcp__claude_ai_Tavily__tavily_extract`
```
{
 "urls": [
  "https://www.whitecircle.md/industries/finance",
  "https://www.whitecircle.md/industries/insurance",
  "https://whitecircle.com/alternatives/lakera",
  "https://whitecircle.com/compare/lakera"
 ]
}
```

Result of `mcp__claude_ai_Tavily__tavily_extract`
```
{"results":[{"url":"https://whitecircle.com/compare/lakera","title":"White Circle vs. Lakera | White Circle","raw_content":"If you're an LLM, explore available Markdown pages at <https://whitecircle.md>.\n\n# Why teams choose White Circle over Lakera\n\n## Get in touch\n\nLearn how White Circle helps AI teams control user and model behavior in real time.\n\n### Test\n\nDiscover failure modes before your users do\n\n### Control\n\nEnforce behavior across inputs, outputs, and tools\n\n### Analyze\n\nUnderstand how your users and AI behave over time\n\n### Improve\n\nTune prompts and models from live signals\n\n“White Circle protects millions of AI interactions every day while helping us move faster.”\n\n![Lovable](/lovable.svg)\n\n## White Circle vs. Lakera\n\nWhite Circle vs. Lakera\n\n| Lakera |  |\n| --- | --- |\n| Policies | |\n| --- | --- |\n| only 7 | ∞ unlimited |\n| Geo-specific policies | |\n| --- | --- |\n| — | can be set up to a particular country or state |\n| Audit decisions | |\n| --- | --- |\n| — | discover what happened exactly |\n| Accuracy | |\n| --- | --- |\n| max F1 score is 0.639 on 7 policies, min is 0.058; please reach out to us for the test set and reproduction steps | max F1 score is 0.991 on 7 policies, min is 0.910 |\n| Policy type | |\n| --- | --- |\n| Safety, Prompt Injection | Safety, Security, Compliance, Reliability, Quality, and literally just anything else |\n| Content length | |\n| --- | --- |\n| up to 10k tokens | managed dynamically to suppo
... [truncated 10706 chars]
```

Tool call `Write`
```
{
 "file_path": "white_circle/docs/whitecircle-research.md",
 "content": "# White Circle: company research for ICP definition\n\nResearched 2026-10-30 (Tavily worked). Tags: [C] = confirmed on a cited page, [I] = inferred by me.\nSources are numbered, listed at the bottom.\n\n## 1. What the product does\n\n- One line: an \"AI control\" layer. Customers write plain-language policies, and White Circle's own models check every input, output and tool call against them in real time, then block, rewrite or escalate. [C] S1, S4, S5\n- Four modules on the homepage: Test (find failure modes before users do, i.e. red teaming), Control (runtime guardrails across inputs, outputs, tools), Analyze (user and model behaviour over time, monitoring), Improve (tune prompts and models from live signals, labelled-feedback loop). [C] S1\n- Also: audit logs and explanations of which policy fired, per-region/jurisdiction policies, user strike/ban system with appeals, user-level risk scoring, human review queue, custom natural-language metrics, Slack and webhook alerts. [C] S1, S2, S3\n- Deployment: hosted SaaS API (single event endpoint, EU and US regions, `wceu-`/`wcus-` keys), \"5 mins to integrate\", 99.99% uptime claim, 150+ languages, text and image checking. Docs show integration guides for an AI support chatbot, a vibe-coding app and a coding assistant. [C] S1, S2, S3\n- Self-hosting: the Test product page FAQ says on-prem/VPC is supported for strict-compliance enterprises. [C] S8 (older page, treat as less certain)\n- Threats covered: prompt injection, jailbreaks, PII/data leakage, hallucination, harmful/illegal content, tool abuse and destructive agent actions, token drain, abuse/anomalous users, model drift, compliance policy checks. Brand safety and tone are covered on the Test page. [C] S1, S3, S8, S9\n- Security attestations: SOC 2 Type I and II, HIPAA. [C] S1, S5\n- Own research: CircleGuardBench (moderation benchmark), KillBench (bias study), Halo (open-source training framework); they train their own models for the job. [C] S1, S4\n\n## 2. Who they sell to\n\nNamed customers\n- Lovable (vibe-coding platform): the only named logo. Full case study plus CISO quote (Igor Andriushchenko). Lovable sends every session event to White Circle; use case is user abuse (phishing sites, malware, explicit content, unsafe commands, multi-step jailbreaks) and agent supervision. [C] S1, S3. Technical partnership announced on LinkedIn. [C] S10\n- \"Two of the world's largest digital banks\" (unnamed) and, per Fortune, \"several fintech and legal companies\". [C] S5, S6. The company's own job post says \"multiple neobanks\". [C] S7. None are named anywhere I found. [C]\n\nIndustries marketing calls out\n- Homepage \"one control layer, every industry\" tabs: Government, Healthcare, Education. [C] S1\n- SEO landing pages exist for finance, insurance, healthcare, government, education, HR, e-commerce, gaming, creative tools, real estate, plus use-case pages (agentic AI security, chatbot guardrails, hallucination detection, content moderation API, data-leak prevention, prompt injection). [C] S11\n- Every vertical page is framed as \"what AI system do you run\" (chatbot, copilot, underwriting AI, claims assistant, fraud assistant). So the trigger is a deployed AI system, not the vertical. [C] S11, S12\n\nBuyer persona\n- Only named buyer: a CISO (Lovable). [C] S3\n- No persona page exists. Docs and the 5-minute API pitch imply engineers/AI platform teams as users and champions; trust and safety/moderation fits the content-moderation and strike-system features. Compliance/risk is plausible for banks. [I]\n\nCompany size and stage of customers\n- Lovable is a fast-growing AI-native scale-up; neobanks are large fintechs. Smaller prospects are reachable self-serve (\"Get Started\" login), larger via \"Contact Sales\". [I from S1]\n\nPricing and packaging\n- No public pricing found on the site or docs. Self-serve signup plus Contact Sales and Request a Demo. Packa
... [truncated 11021 chars]
```

Result of `Write`
```
File created successfully at: white_circle/docs/whitecircle-research.md (file state is current in your context — no need to Read it back)
```

**Final report (hand-back)**

Wrote white_circle/docs/whitecircle-research.md (not committed, nothing else touched). Tavily worked with no 432, so I used it throughout. I did not need WebFetch or WebSearch. LinkedIn and X were not read directly; I only saw snippets of LinkedIn posts and Denis Shilov's profile through Tavily.

- Product: a hosted-API "AI control" layer. Customers write plain-language policies, and White Circle's own models check every input, output and tool call in real time and block, rewrite or escalate. The modules are Test (red teaming), Control (guardrails), Analyze (monitoring) and Improve. It has SOC 2 and HIPAA, EU and US regions, and 150+ languages.
- Named customers: only Lovable (full case study, CISO quote). Press says "two of the world's largest digital banks" plus "several fintech and legal companies"; the careers post says "multiple neobanks". None of the banks are named anywhere.
- Industries and personas on the site: the homepage tabs show Government, Healthcare and Education. Landing pages also cover finance, insurance, HR, e-commerce, gaming, creative tools and real estate. The only buyer named is a CISO (Lovable). There is no persona page, so engineers, AI platform and trust and safety buyers are my inference.
- Non-AI or traditional finance: they don't fit unless they ship an LLM or agent. Every vertical page is framed around "what AI system do you run" (chatbot, underwriting AI, claims assistant). The philosophy page cites EU AI Act deployer liability, with a bank as the example. DORA appears nowhere, and I found no incumbent-bank customer. Incumbents with internal-only AI should be low priority, not zero.
- Top 3 ICP signals to weight:
  1. A customer-facing LLM feature or agent, especially one that takes actions (coding agents, tool use). Lovable is the proof.
  2. Regulated or high-PII customer exposure, mainly neobanks and fintechs with chatbots. Insurance, health and legal come next.
  3. Scale and security maturity: AI/ML and security hiring or a named CISO, a high-volume open-signup user base, a US/UK/EU base, and recent funding.
- Funding: press reports an $11M seed on 12 May 2026. Their own site now says a Series A taking the total to $70M, and I found no press for that round. Treat the $70M as unverified.
- Company facts: Paris HQ with London and US presence, a PBC, founded 2025 by Denis Shilov, 20 staff in May 2026, 17 open roles including a Founding AE and the Founding GTM Engineer role from this take-home.
- Competitors: the only rival they name is Lakera, on a comparison page that claims unlimited policies vs 7 and F1 0.991 vs 0.639 on their own test. No public pricing found.

Result of `SubagentHandback`
```
{"success":true,"message":"Report delivered to your caller."}
```
