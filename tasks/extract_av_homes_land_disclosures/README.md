# extract_av_homes_land_disclosures

This task audits AV Homes / Avatar Holdings (`AVHI`, CIK `0000039677`) 10-K land-position disclosures for fiscal 2004-2017.

The filings do not disclose a physical owned-versus-nonowned lot split, so this task does not compute an omega / land-light share for AV Homes. It keeps the firm-year rows visible in the expanded panel with `main_panel_eligible = FALSE`.

Coding choices:

- Fiscal 2004-2008 disclose broad real-estate assets in acres. The task records the lower-bound acres statements and does not convert acres to lots.
- Fiscal 2009-2010 disclose all-residential planned lots/units and consolidated LLC lots. These are retained as lower-comparability auxiliary land-position totals.
- Fiscal 2011-2015 disclose principal-community remaining lots, plus inactive or held-for-sale buckets in some years. The principal-community total is retained as the main auxiliary land-stock total.
- Fiscal 2016-2017 explicitly say the land-holdings table includes land under option contracts, but the filings still do not split owned from optioned lots. The total is retained and option deposits are recorded as option-economics evidence, not as a physical numerator.

This follows the conservative second-read decision that AV Homes should not enter main omega plots unless a physical optioned/nonowned lot count is found later.
