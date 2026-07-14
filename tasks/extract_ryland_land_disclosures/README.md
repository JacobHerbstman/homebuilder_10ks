# Extract Ryland Land Disclosures

This task extracts Ryland fiscal 2004-2014 owned and optioned lot disclosures.

The main series uses Ryland's recurring reporting-segment table of lots owned, lots optioned, and total lots owned and controlled. Separately disclosed joint venture lots are retained as auxiliary exposure where the 10-K prose discloses them, but they are excluded from the main omega denominator.

Fiscal 2005 is recovered from the exact comparative row in the 2006 10-K because the 2005 10-K does not disclose the owned/optioned lot-count table. Fiscal 2004 remains intentionally missing: the filing reports dollar exposure for option and land purchase contracts but no owned/optioned lot-count denominator.

Run from `tasks/extract_ryland_land_disclosures/code`:

```bash
make
```

Outputs:

- `../output/ryl_2004_2014_land_panel.csv`
- `../output/ryl_2004_2014_extraction_audit.csv`
- `../output/ryl_2004_2014_source_notes.csv`
