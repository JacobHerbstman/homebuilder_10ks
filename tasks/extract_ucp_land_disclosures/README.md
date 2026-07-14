# Extract UCP Land Disclosures

This task extracts UCP fiscal 2013-2016 land-position disclosures.

Fiscal 2013-2015 use recurring tables with owned lots, controlled lots, and total lots owned and controlled. UCP defines controlled lots as lots subject to a purchase or option contract.

Fiscal 2016 is intentionally denominator-only. The 2016 10-K reports 6,638 total owned-or-controlled residential lots and segment totals for West and Southeast, but those segment totals do not split owned from controlled lots. The task preserves the total and marks the split unresolved rather than imputing from prior years or from the total change.

Run from `tasks/extract_ucp_land_disclosures/code`:

```bash
make
```

Outputs:

- `../output/ucp_2013_2016_land_panel.csv`
- `../output/ucp_2013_2016_extraction_audit.csv`
- `../output/ucp_2013_2016_source_notes.csv`
