# How the approach changed

Short version: every change to the scoring came from looking at real rows. Either the data showed
a problem, or what White Circle actually sells did.
1. **Profile first.** The data was cleaner than "messy" suggested: no duplicates, no orphan records,
   consistent codes. The real traps were about meaning. 73% of companies have no funding rows,
   106 "active" companies had actually been acquired, 29 were public giants, and two-thirds carry an
   "AI" tag, so the tag tells you almost nothing.
2. **v1: one additive score.** It mixed AI signal, regulated industry, funding, size, region and
   contacts. The top of the list exposed the problems. "Regulated" swept in crypto, fitness and
   government. Dev shops ranked high. Debt rounds counted as fresh funding.
3. **v2: fix the definitions.** Regulated narrowed to banking, insurance, health and legal. Agencies
   were capped. Recency counts equity rounds only. Then the sharper question: *do traditional
   finance or non-AI companies fit at all?* Research on White Circle's site said no. Every page
   starts from "what AI system do you run". So shipping AI became a requirement, not a bonus.
4. **v3: check the websites.** Crunchbase tags couldn't tell a carbon-reduction startup from a
   fintech. We read the live homepage of the 180 strongest candidates and labelled each one with a
   verbatim quote: does it ship customer-facing AI, what is its real industry. That replaced 29 of
   the top 50: 9 didn't actually ship an LLM, 7 had dead or hijacked sites, and the rest were
   outranked. It also surfaced 3 competitors (agent control planes, AI gateways). Rule from then
   on: **no company enters the top 50 unverified.**
5. **v4: gates, then a fixed rubric.** Exclusions are now pass/fail, applied before any points:
   closed, acquired, non-AI, wrong industry, competitor, services firm, dead site. The survivors
   are scored on a fixed rubric: recent funding 40, revenue 25, headcount 15.
   A fit bonus of up to 10 is anchored on the industries and use cases White Circle already
   markets. Region (Europe and North America) breaks ties only. On the real data, 590 of 3,000 companies
   pass all nine gates (no language-AI product removes 1,584 and services firms 495). 10 of the v3.1 top 50
   changed: 3 now fail the industry gate and 7 pass but score too low to stay.

**What stays open.** The weights are starting assumptions. Once meetings and deals come in, each
component gets checked against real outcomes. Headcount growth (3/6/12 months from Apollo or PDL, 20 points) is left out for now, for lack
of enrichment data, and would be added back with the weights recalibrated. Scores are versioned and rescored on
a schedule, so every past ranking can be reproduced.
