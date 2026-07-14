# Plot six-firm manual land panel

This task plots the hand-read six-firm pilot series from
`build_six_firm_manual_land_panel`.

The plotted outcome is the selected non-owned/controlled share for firm-years
where `panel_use_flag == TRUE`. NVR 2006-2009 are retained in the underlying
manual panel but omitted from this plot because the early filings do not cleanly
reconcile LPA, JV, and development-lot overlap.

Run from `code/`:

```sh
make
```

Outputs:

- `output/six_firm_nonowned_controlled_share_timeseries.png`
- `output/six_firm_nonowned_controlled_share_timeseries.pdf`
- `output/six_firm_nonowned_controlled_share_plot_data.csv`
