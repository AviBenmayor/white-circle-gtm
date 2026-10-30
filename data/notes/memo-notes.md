# Memo notes — points the owner wants made

Collected during the build; the memo draft must cover each one.

## Scoring model is a set of stated assumptions, refined by results (owner, 2026-10-30)

> "i think we can call out our assumption but mention we would refine over time with realized
> results. if we are consistently performing better for companies that have recent headcount
> growht despite no new funding, we can rebalance the scoring model. also worth calling out that
> we would rescore companies periodically"

- The 40/25/15/20 weights and the fit bonus are **priors**, chosen up front and stated openly.
- Once we have results, we check each component against what actually happened (meetings booked,
  opportunities, wins). Example: if companies with recent headcount growth but no new round keep
  converting better, growth gets more weight and funding recency gets less.
- **Rescoring runs periodically.** Every company is rescored on a schedule and whenever a new signal
  arrives (new round, headcount change, verification). Each score carries `score_version` and a
  scored-at date, so a past ranking can always be reproduced.

## Two-stage enrichment: baseline for everyone, deep dive for the top 5 (owner, 2026-10-30)

> "i think its worth also calling out that we want to have a baseline enrichment to score
> properly and then do a deep dive - with contact data joined in and a full report on each
> company - for the top 5 (like they ask for in step 2 of part 1)"

- **Baseline enrichment (broad, cheap, feeds the score):** a website check (does the company ship
  customer-facing AI, its real industry, is the site live) and headcount history. These are only
  the fields the gates and rubric need, run on every candidate. Cost per company is cents.
- **Deep dive (narrow, expensive, feeds the AE):** the top 5 only. Contacts are joined in, and each
  company gets a full report the AE can act on. This is Part 1 step 2.
- Why split it: spending deep-research effort on a company before we know it's a fit wastes money
  and pads the CRM with stale detail. The score decides who earns the deep dive.

## Model shape (owner, 2026-10-30)

- Gates first: closed, non-AI, poorly matched industries (plus acquired/nonprofit/public/
  competitor/services/dead site).
- Rubric: recent funding 40, revenue 25, headcount 15, headcount growth 20.
- Fit bonus ≤10, based on what White Circle already signals publicly: "we want to use what they
  have already done as baseline for how we shape our response".
- Region (Europe + North America) is a **tie-breaker only**. Same time zones and selling customs.
