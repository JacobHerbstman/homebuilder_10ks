# Meritage Land Disclosure Extraction

This task extracts Meritage Homes land-control measures from SEC 10-K filings for fiscal years 2004 through 2025.

The task is firm-specific because Meritage changes disclosure format over time:

- 2004 uses a business land table with split columns for land owned and land under contract or option.
- 2005 through 2017 use business land-supply tables with a Total or Total Company row.
- 2018 onward reports total lots under control and owned lots in prose, while Note 3 separately reports committed and uncommitted purchase/option contract lots.

For the physical land-control share, the output uses committed purchase/option contract lots as nonowned controlled lots in 2018 onward. The broader Note 3 total lots under contract or option is preserved as a separate check/exposure field because it includes uncommitted refundable lots.

Run from `tasks/extract_mth_land_disclosures/code` with:

```sh
make
```

Main outputs:

- `output/mth_2004_2025_land_panel.csv`
- `output/mth_2004_2025_segment_land_rows.csv`
- `output/mth_2004_2025_extraction_audit.csv`
- `output/mth_2004_2025_source_notes.csv`
