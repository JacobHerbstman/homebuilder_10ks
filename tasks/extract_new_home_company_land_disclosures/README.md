# Extract New Home Company Land Disclosures

This task extracts New Home Company fiscal 2013-2020 land-position disclosures.

The main series uses the Company/Wholly-Owned owned and controlled lot split. Fee-building lots are excluded because the 10-K footnotes define them as third-party-owned lots for which NWHM performs general contracting or construction management services. Unconsolidated joint venture lots are retained as auxiliary fields when the same summary table discloses them, but they are not mixed into the main omega denominator.

Run from `tasks/extract_new_home_company_land_disclosures/code`:

```bash
make
```

Outputs:

- `../output/nwhm_2013_2020_land_panel.csv`
- `../output/nwhm_2013_2020_extraction_audit.csv`
- `../output/nwhm_2013_2020_source_notes.csv`
