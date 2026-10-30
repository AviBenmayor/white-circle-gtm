# Part 1 memo: who White Circle should call first

Of 3,000 Crunchbase companies, 590 are real candidates and 31 are Tier 1. My top five are Replit, Shapes, Botpress, Dash0 and Kinfolk. Below is how I got there. The full ranking is in [top50.csv](top50.csv) and the [dashboard](../dashboard/index.html).

## 1. What "good fit" means

White Circle sells runtime protection for companies that ship LLMs and agents to their own customers. Its public pages all start from the same question: what AI system do you run? The only named customer is Lovable, which sends every session through White Circle to catch abuse and supervise agents. The company also cites digital banks and neobanks, and its own philosophy page says that under the EU AI Act deployers carry their own obligations.

So a good fit is a company that ships a language-AI product to its own users, ideally one that acts (agents), in a place where a bad answer is expensive. It must also be able to buy: alive, independent, funded and big enough. A company that merely carries an "AI" tag, or one that sells AI services to others, is not a fit. I treat that as a requirement, not a bonus.

## 2. The data and how I handled it

The data was cleaner than "messy" suggested: no duplicates, no orphan records, consistent codes. The traps were about meaning:

- 73% of companies have no funding rows, so every join is a LEFT JOIN.
- 106 "active" companies had been acquired, and 29 were public giants.
- Two-thirds carry an "AI" tag, so the tag says almost nothing.
- Debt and grants are not "fresh funding".

All of it is plain SQL in [src/white_circle/sql](../../src/white_circle/sql/). Files 57 (master table), 58 (gates), 60 (score) and 70 (segments) carry the logic. Each has a header explaining the why, and every point value is looked up in a weights table rather than typed into the query. [approach-evolution.md](approach-evolution.md) shows how the model changed from v1 to v4 after I looked at real rows.

## 3. The model: gates first, then a fixed rubric

Exclusions are pass/fail and come before any points. Nobody is dropped silently; every company keeps a reason.

| Gate (in order) | Removed |
|---|---|
| Closed | 72 |
| Acquired | 106 |
| Non-profit | 17 |
| Public (kept as an Enterprise segment) | 26 |
| Competitor | 7 |
| Services firm | 495 |
| Dead or hijacked site | 34 |
| No language-AI product | 1,584 |
| Industry not matched | 69 |
| **Pass** | **590** |

The survivors get a fixed rubric out of 80, plus a fit bonus of up to 10 (90 in all):

| Component | Max | Why |
|---|---|---|
| Funding recency (equity only) | 40 | A fresh round means budget and new hires |
| Revenue | 25 | Can afford a contract |
| Headcount | 15 | Enough scale to run agents in production |
| Fit bonus | up to 10 | Taken from White Circle's own landing pages and named customers: the verticals it markets, plus agents that take actions |

Region (Europe plus North America) breaks ties only, because of shared time zones and selling customs. It earns no points.

**The ideal setup.** In a fuller version of this model, headcount growth over 3, 6 and 12 months, pulled from Apollo or PDL, would be a 20-point factor. It matters most for companies that are growing headcount without a new funding round, which the funding-recency score cannot see. I left it out of this version because I had no enrichment data, and I preferred leaving it out to scoring it as zero for everyone. I would add it back once the data is flowing, then recalibrate all the weights against realized meetings and wins.

## 4. Segments and tiers

Segment is who they are, and decides the play. Tier is how soon to work them.

| Segment | Count | Tier | Total /90 | Count |
|---|---|---|---|---|
| AI-native builders | 453 | Tier 1 | 40 and above | 31 |
| Marketed verticals | 111 | Tier 2 | 25 to 39 | 75 |
| Regulated GenAI | 26 | Tier 3 | 14 to 24 | 135 |
| | | Nurture | below 14 | 349 |

Public companies sit in a separate Enterprise segment because they run a different sales motion.

## 5. Top 50 and top 5

Every company in the top 50 was checked against its live website, with a quote as evidence. In total 201 companies were verified through Tavily. Two high scorers, Centrical and Audion, failed that check and were removed. Account briefs are in [accounts/](accounts/).

- **Replit (77):** a $400M Series D at $9B, and an agent that writes code and touches live infrastructure. The most agentic account here, and a close match to Lovable.
- **Shapes (72):** an AI-native HR platform with agents running on salary and leave data, fresh from a Series A, in the EU AI Act's high-risk employment area.
- **Botpress (64):** its support agents issue refunds. It is partner-first, since embedding White Circle would cover all its customers, but it already markets guardrails, so competitor risk is real.
- **Dash0 (57):** a $110M Series B and tool-using Agent0 agents. Buyer first, with some competitor risk because it has said it will acquire in AI security.
- **Kinfolk (57):** a seed-stage company whose HR agents write to HRIS records at Deliveroo. It is raising for payroll and IT access, which widens the risk.

## 6. Enrichment

Enrichment runs in two stages. First is a baseline for everyone: a website check (does it ship customer-facing AI, what is its real industry, is the site live) and headcount history. These are only the fields the gates and rubric need, at cents per company. Second is a deep dive for the top 5: contacts joined in and a full report per company that an AE can act on, as step 2 of Part 1 asks. I did not want to spend deep-research effort before knowing a company fits, or to pad the CRM with stale detail. The score decides who earns the deep dive. Total Tavily spend was about 85 credits across verification and the deep dives. The CRM side is in the [CRM model](../part1-crm-model/crm-data-model.md).

## 7. What I'd refine

- **The weights are priors.** 40/25/15 and the bonus are my stated assumptions, not findings. Once meetings, opportunities and wins come in, I would test each component against them. 
- **Rescore on a schedule.** Every company is rescored periodically and whenever a new signal arrives (a round, a headcount change, a verification). Each score carries a `score_version` and a scored-at date, so any past ranking can be reproduced.
- **Narrow "AI-native".** At 471 it is too broad to be a single play.
- **Work the verify_next queue.** Only 65 of the 590 are verified so far. The rest of the list leans on tags until that queue is worked.
- The data is a June 2026 snapshot, so every score is as of that date.
