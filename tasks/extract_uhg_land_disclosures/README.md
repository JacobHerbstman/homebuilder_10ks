# UHG Land Disclosures

This task extracts United Homes Group / Great Southern Homes owned and controlled lot disclosures from SEC 10-K HTML.

Treatment:
- Fiscal 2020 and 2021 are DiamondHead Holdings SPAC filings before the operating-builder business combination. They are marked as pre-builder shell filings and excluded from the operating land panel.
- Fiscal 2022 is coded from the exact December 31, 2022 comparative row in the 2023 UHG 10-K. This is a predecessor-business disclosure for Great Southern Homes, not a contemporaneous DiamondHead operating-builder 10-K.
- Fiscal 2023 through 2025 are coded from UHG's recurring owned/controlled lot tables.
- The table label `Controlled` is treated as non-owned controlled lots because it is paired with `Owned` and sums to `Total`. It is not coded as pure optioned lots unless the filing separately defines that label as option-only.

Outputs:
- `uhg_2022_2025_land_panel.csv`
- `uhg_2022_2025_segment_land_rows.csv`
- `uhg_2020_2021_prebuilder_filing_exclusions.csv`
- `uhg_2022_2025_extraction_audit.csv`
- `uhg_2022_2025_source_notes.csv`
