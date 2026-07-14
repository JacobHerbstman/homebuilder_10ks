# Hand-coded KBH and HOV land disclosures

This task builds a 2006-2025 hand-coded pilot panel for KB Home (`KBH`) and Hovnanian (`HOV`) from cached SEC 10-K HTML files.

The task is intentionally downstream of `build_six_firm_pilot_skeleton`. It uses the skeleton only for selected annual 10-K metadata and source paths, then applies a tracked manual coding file.

## Definitions

- KBH optioned share: `Land Under Option / Total Land Owned or Under Option`.
- HOV optioned share: `Optioned Home Sites / Consolidated Total Home Sites`.
- HOV unconsolidated joint venture lots are retained as a separate field and are not added to the consolidated denominator.

## Outputs

- `output/kbh_hov_2006_2025_manual_land_panel.csv`
- `output/kbh_hov_2006_2025_manual_land_audit.csv`
- `output/kbh_hov_2006_2025_source_notes.csv`

Run from `code/` with:

```bash
make
```
