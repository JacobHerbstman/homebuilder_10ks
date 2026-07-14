# Hand-coded DHI, LEN, and PHM land disclosures

This task builds a 2006-2025 hand-coded pilot panel for D.R. Horton (`DHI`), Lennar (`LEN`), and PulteGroup (`PHM`) from cached SEC 10-K HTML files.

The task is downstream of `build_six_firm_pilot_skeleton` and uses that task only for the selected annual 10-K metadata and source paths. The physical land-control counts live in the tracked manual coding file.

## Definitions

- DHI share: lots controlled under land/lot option or purchase contracts divided by total land/lots owned and controlled.
- LEN share: controlled homesites divided by total homesites. Where disclosed, controlled homesites are split into optioned and JV homesites.
- PHM share: optioned lots divided by controlled lots.

Pulte 2006 and 2007 are rounded prose disclosures. The task marks those rows with `approximate_flag`.

## Outputs

- `output/dhi_len_phm_2006_2025_manual_land_panel.csv`
- `output/dhi_len_phm_2006_2025_manual_land_audit.csv`
- `output/dhi_len_phm_2006_2025_source_notes.csv`

Run from `code/` with:

```bash
make
```
