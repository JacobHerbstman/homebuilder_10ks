# Public-Builder 10-K Land Panel

This task is downstream of `extract_10k_land_candidates`. It turns auditable 10-K extraction candidates into preferred firm-year values, segment-year rows, and benchmark checks.

Selection rule: prefer explicit current-period total or consolidated table values. Use snippet values when the disclosure is prose-heavy or when no structured table candidate is available. Do not sum regional or segment rows into firm totals unless there is no explicit total row; such cases should remain lower confidence and visible in the selection audit. The preferred-value table carries provenance flags for exact table values, rounded prose, scale use, physical unit type, contract type, and manual-review reasons.

Concept rule: preserve firm terminology. Lots, homesites, LPAs, optioned lots, and controlled lots are not collapsed into one generic measure before the preferred-value layer. Dollar scale factors apply only to dollar variables, not lot counts, homesites, closings, communities, or percentages.

The task writes:

- `output/public_builder_10k_land_panel.csv`: one row per downloaded public-builder 10-K filing with preferred firm-year values and derived ratios.
- `output/tenk_land_preferred_values.csv`: long preferred-value table with source provenance.
- `output/tenk_land_segment_year_panel.csv`: retained segment-year land, inventory, and risk-accounting values.
- `output/tenk_land_value_selection_audit.csv`: all firm-year candidates with selection scores and conflict flags.
- `output/tenk_land_benchmark_audit.csv`: benchmark pass/fail checks for Pulte 2011, D.R. Horton 2024, Lennar 2024, and NVR 2024, including explicit identity checks where the filings provide owned-plus-controlled or option-component totals.

Run:

```sh
cd tasks/build_10k_land_panel/code
make
```

The benchmark audit is not a proof of full historical coverage. It checks whether the parser and preferred-value rules recover known high-value disclosures from representative filings. Low-confidence, conflicting, or missing firm-years should be reviewed through `tenk_land_value_selection_audit.csv` before being used in analysis.
