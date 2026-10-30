# GTM Engineer — Take-Home Exercise

> Source: https://whitecircle.notion.site/GTM-Engineer-Take-Home-Exercise-38fc3dbe97908031bd22cb2d027b3f23 (copied 2026-10-29)


We’re at a critical juncture - revenue and customers, but no repeatability or playbook. Right now we have customers like Lovable and neobanks. Sales were founder-led till recently. We have started using Attio, Clay and are open to other tools as they become needed (eg. Granola for meetings where Attio cannot record, but don’t fixate on this).

Customer segmentation is not defined and we have SDRs and AEs joining soon. SDRs will be almost solely focused on cold calling, other channels should be automated for them. We want to prevent AEs from having to hunt so they can just focus on closing. Paid ads will be running in a few weeks and RB2B has been installed on our website.


---


#### Part 1 - Segmentation
*(Attachment: gtm-takehome-dataset.zip — the three CSVs in `data/raw/`)*
We've given you a slice of Crunchbase company data. It's raw and a little messy, on purpose.

Load it using the tool/tech of your choice, explore it, and use SQL to answer one question: *which companies should our AEs prioritize, and how would you group them into segments?*

- This is open-ended. You decide what "good fit" means for an AI-safety platform sold to companies deploying LLMs, and you defend it. There is no answer key.
- We want to see your SQL, not just conclusions. Show how you handle data quality issues, inconsistent categories, etc. Derive at least a few meaningful cuts (e.g. by funding stage, size, sector, recency of raise, or a fit score you construct).
- Land on a defensible set of segments (a tiered ICP, priority tiers, or similar) with rough counts for each, straight from the data.
**What to deliver:**

1. Segment the companies and build a scoring model to output a ranked top-50 account list
1. Enrich the top 5 accounts however you like (scraping, LLMs etc - your choice)
1. Write a short memo showcasing your logic for how you went about 1
1. Design the CRM data-model that you will inject those data into
1. We expect all the artifacts you wrote to be included in the submission: code, SQL, schema, notes, and we also expect you to provide your AI traces/logs

---


#### Part 2 - Systems Design
Now build the system that acts on those segments.

Build a system that automates as much of the manual work of the SDRs and AEs as you think sensible, through to close (ignore expansion etc). They qualify using MEDDPICC. Be opinionated and practical, you own this.

**Things to think about**

1. Customer segmentation
1. Enrichment of buyer personas
1. Signals
1. The tools and data sources you would connect, and what would sync back to the CRM
1. What becomes automated vs what stays human-led (and why)
1. How to keep progress transparent (so stakeholders can see what is blocked, what is next, and owners)
**What are we testing?**

- Ability to make messy reality legible, measurable, and action-driven
- Systems thinking across the GTM lifecycle
- A technical, curious mindset: comfort with data flows, automation logic, and edge cases
- Strong judgement about automation vs human decision-making
**What to deliver?**

1. A workflow diagram showing the end-to-end automation: tools, triggers, data flows, and decision points. Format is up to you.
1. A short written note (max 500 words) on what you would build first, what you would leave for later, and why.
If you have any specific questions that would potentially help you deliver a better assignment, don’t hesitate to reach out to [stefan@whitecircle.ai](mailto:stefan@whitecircle.ai).

This should take up to 3 hours.


