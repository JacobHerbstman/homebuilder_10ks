# Extract Orleans Land Disclosures

This task extracts Orleans Homebuilders fiscal 2004-2008 owned and nonowned controlled lot counts from its 10-K land-position disclosures.

The main numerator is the recurring firm-level count labeled as lots under option agreement, lots under agreement of sale, or contracted-to-purchase-or-under-option lots. This is broader than strict pure cancellable options, so the output preserves the source note. Undeveloped-land-only counts in the MD&A are not used for the main numerator because the firm-level table includes both undeveloped land and improved lots.

Run from `tasks/extract_orleans_land_disclosures/code`:

```bash
make
```

Outputs:

- `../output/ohb_2004_2008_land_panel.csv`
- `../output/ohb_2004_2008_extraction_audit.csv`
- `../output/ohb_2004_2008_source_notes.csv`
