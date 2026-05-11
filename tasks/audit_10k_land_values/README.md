# Audit 10-K Land Values

This task audits the first-pass preferred 10-K land values and panel.

Run from `tasks/audit_10k_land_values/code`:

```bash
make
```

Outputs:

- `tenk_land_sanity_summary.csv`: per-variable coverage, distributions, source-method counts, and flag counts.
- `tenk_land_sanity_flags.csv`: row-level preferred-value flags for unit, scale, confidence, range, source-period, and provenance problems.
- `tenk_land_sanity_sample.csv`: deterministic large sample across all variables, including extremes and all flagged preferred values.
- `tenk_land_panel_sanity_flags.csv`: panel-level identity/range checks for derived ratios and component totals.
- `tenk_land_panel_column_coverage.csv`: nonmissing coverage for every final panel column.
- `tenk_land_benchmark_status.csv`: compact pass/fail summary for the named benchmark filings.
