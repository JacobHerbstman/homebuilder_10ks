# Extract TOUSA Land Disclosures

This task extracts TOUSA / Technical Olympic USA homesite-control disclosures for fiscal 2004-2007.

TOUSA is handled separately because its early filings mix consolidated homesites, unconsolidated joint ventures, and the Transeastern JV. The main series uses the company-disclosed combined optioned homesites divided by combined total homesites. For 2006, the main row uses the contemporaneous 2006 10-K excluding Transeastern; the broader 2007 comparative recast including Transeastern is retained as an alternate field.

Run from `code/`:

```bash
make
```

Outputs:

- `output/toa_2004_2007_land_panel.csv`
- `output/toa_2004_2007_extraction_audit.csv`
- `output/toa_2004_2007_source_notes.csv`
