# Six-Firm Boom/Bust Response Diagnostic

This task joins the hand-read six-firm land-light panel to a narrow, hand-audited set of 2012-2023 operating-scale disclosures from the firms' 10-Ks.

The purpose is a quick qualitative diagnostic: do high-`omega` firms, where `omega` is the non-owned controlled land share, appear to ramp order volume less in the 2021 boom and cut differently in the 2022 rate-shock period? The task now also produces the same diagnostic for the slower 2013-2019 recovery period.

## Inputs

- `../input/six_firm_2006_2025_manual_land_panel.csv`: upstream hand-read land-control panel.
- `code/manual_six_firm_operating_scale_2012_2023.csv`: reviewed 10-K operating values for DHI, LEN, PHM, KBH, HOV, and NVR.

Hovnanian is treated carefully. Its reviewed 10-K tables provide consolidated net-contract value and deliveries, but not a comparable annual net-contract unit series. It is therefore omitted from the order-unit growth plot and retained in the delivery-growth plot.

## Outputs

- `output/six_firm_boom_bust_response_panel.csv`: firm-year panel with `omega`, order units/value, deliveries, backlog, and growth rates.
- `output/six_firm_boom_bust_response_summary.csv`: firm-period growth summaries and period-level correlations with lagged `omega`.
- `output/six_firm_boom_bust_response_summary_wide.csv`: compact firm-level growth summary.
- `output/six_firm_boom_bust_response_audit.csv`: row-count and missingness audit.
- `output/six_firm_order_unit_growth_vs_lagged_omega.png` and `.pdf`: 2021-2023 order-unit growth diagnostic.
- `output/six_firm_delivery_growth_vs_lagged_omega.png` and `.pdf`: 2021-2023 delivery growth diagnostic.
- `output/six_firm_order_unit_growth_vs_lagged_omega_2013_2019.png` and `.pdf`: 2013-2019 order-unit growth diagnostic.
- `output/six_firm_delivery_growth_vs_lagged_omega_2013_2019.png` and `.pdf`: 2013-2019 delivery growth diagnostic.

## Run

From this task's `code/` folder:

```bash
make -n
make
```

The diagnostic is not a final research panel. The `omega` definition still follows each firm's own disclosure convention, so this task is meant to guide whether the six-firm pilot has an economically interesting pattern worth deeper harmonization.
