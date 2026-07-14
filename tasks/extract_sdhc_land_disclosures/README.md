# Smith Douglas Land Disclosures

This task extracts Smith Douglas Homes owned, optioned, and total controlled lot disclosures from SEC 10-K HTML.

Treatment:
- Fiscal 2022 is coded from the exact December 31, 2022 comparative row in the 2023 10-K and flagged as a pre-IPO operating-builder observation from a later comparative table.
- Fiscal 2023 is coded from the 2023 10-K but flagged as a pre-IPO fiscal year reported in a post-IPO filing.
- Fiscal 2024 and 2025 are coded as public-company rows.
- `Optioned` is treated as the non-owned controlled lot bucket because the table explicitly reports `Owned`, `Optioned`, and `Total Controlled`, and the identity holds.
- Deposits/investments and remaining purchase price are taken from the `Total option contracts` row and scaled from thousands of dollars.
- Option-dollar disclosures are retained as exposure variables but are not used to compute the lot-count omega measure.

Outputs:
- `sdhc_2022_2025_land_panel.csv`
- `sdhc_2022_2025_segment_land_rows.csv`
- `sdhc_2022_2025_extraction_audit.csv`
- `sdhc_2022_2025_source_notes.csv`
