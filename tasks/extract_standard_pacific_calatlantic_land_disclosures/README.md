# extract_standard_pacific_calatlantic_land_disclosures

This task extracts Standard Pacific / CalAtlantic CIK `0000878560` fiscal 2004-2016 land-position disclosures.

The main series uses the recurring owned plus optioned/subject-to-contract land table. Joint venture lots are excluded from the main omega denominator and retained separately. For 2007-2009, discontinued-operation lots are excluded because the filings disclose them only as a total without an owned/optioned split.

Fiscal 2015 and 2016 are main-eligible but flagged for the Ryland merger / CalAtlantic transition because the firm scope changes sharply.

Outputs:

- `output/spf_caa_2004_2016_land_panel.csv`
- `output/spf_caa_2004_2016_extraction_audit.csv`
- `output/spf_caa_2004_2016_source_notes.csv`
