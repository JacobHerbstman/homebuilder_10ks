# WRECO Operating Disclosures

This task extracts the Weyerhaeuser Real Estate Company single-family operating series from Weyerhaeuser parent-company 10-K HTML files. Run `make` from `code/`.

The task writes a preferred 2004-2013 firm-year panel, all overlapping table candidates, and a row-level benchmark audit. It preserves WRECO as a standalone builder through 2013 and does not splice its history into Tri Pointe after the 2014 transaction.

## Disclosure eras and source priority

- Fiscal 2004 unit counts come from the fiscal 2008 five-year unit table. Fiscal 2004-2006 revenue and average price come from the fiscal 2006 key-data table.
- Fiscal 2005-2008 unit statistics come from the later fiscal 2009 comparative table. Fiscal 2007-2008 revenue comes from the fiscal 2008 key-data table.
- Fiscal 2009-2013 unit statistics and single-family housing revenue come from the fiscal 2013 five-year tables.
- When comparable tables overlap, the latest selected disclosure is preferred and every earlier value remains in `wreco_2004_2013_operating_candidates.csv`.

This source rule matters in 2008. The fiscal 2008 filing reports 2,545 homes sold and backlog of 581, while the fiscal 2009 comparative table reports 2,522 homes sold and backlog of 558. The later comparative values are selected and the earlier values remain auditable.

## Harmonization

`Homes closed` maps directly to deliveries. `Homes sold` is retained as the raw label and mapped to harmonized orders units with medium concept confidence because the table does not explicitly call the measure net new orders. Backlog, cancellation rate, average price, homebuilding revenue, and gross margins retain the filing terminology and scope.

The manually reviewed benchmark file is used only to test the programmatic table extraction. It is not used to construct the preferred panel.
