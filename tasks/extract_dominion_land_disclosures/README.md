# Extract Dominion Homes Land Disclosures

This task extracts audited Dominion Homes land-position rows for fiscal 2004-2007.

Dominion defines owned land inventory as land titled in its name plus its pro rata share of joint-venture land. Controlled land is land it has committed to purchase or has the right to acquire under contingent purchase or option contracts. The filings include controlled land only when it is zoned for Dominion's needs or otherwise reasonably likely to result in purchase.

The extractor reads the local SEC 10-K documents from the upstream filing-measures task, extracts the owned and controlled lot sentences, reconciles owned plus controlled to total land inventory, and writes a task-local panel and audit.

ChatGPT second-read review agreed that all four years are main-panel eligible. Fiscal 2006 and 2007 are flagged as `split_from_prose_following_table` because the owned/controlled split appears in prose after the land inventory table rather than as a separate table row. They are not denominator-only cases.
