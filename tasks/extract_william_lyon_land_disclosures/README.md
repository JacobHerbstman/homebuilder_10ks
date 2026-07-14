# extract_william_lyon_land_disclosures

This task extracts William Lyon Homes lot-control disclosures for fiscal years 2004-2018.

The coded main series begins in 2006, using the recurring table with `Lots Owned`, `Lots Controlled`, and `Total Lots Owned and Controlled`. The controlled measure is retained as nonowned controlled lots rather than pure optioned lots because later filings describe land-banking and joint-venture purchase structures.

Fiscal 2004 and 2005 are kept as audited missing rows. Those filings include active-project owned lot counts but do not disclose a company-wide owned/nonowned controlled split, so the task does not infer omega from them.

Outputs:

- `output/wlh_2004_2018_land_panel.csv`
- `output/wlh_2004_2018_extraction_audit.csv`
- `output/wlh_2004_2018_source_notes.csv`
