# Taylor Morrison Land Disclosure Extraction

This task extracts Taylor Morrison land-control measures from SEC 10-K filings for fiscal years 2013 through 2025.

Taylor Morrison is handled as a firm-specific task because its disclosure format changes:

- 2013 through 2015 use detailed owned-lot and controlled-lot columns.
- 2016 through 2021 use compact owned, controlled, and owned-and-controlled land portfolio totals.
- 2022 is a transition year. The 2022 filing reports owned and controlled lots in an older classification, while the 2023 filing restates 2022 in the newer owned/controlled/homes-in-inventory table format.
- 2023 through 2025 use a recurring owned and controlled lots table with land option purchase contracts, land banking arrangements, other controlled lots, and homes in inventory.

The main panel uses issuer-level totals. For 2013, this includes Canada and proportionate joint-venture lots; U.S.-only subtotals are retained as alternate fields. For 2022, the main panel uses the 2023 restated comparative values for consistency with 2023 through 2025, while the originally filed 2022 values are retained as audit fields.

Run from `tasks/extract_tmhc_land_disclosures/code` with:

```sh
make
```

Main outputs:

- `output/tmhc_2013_2025_land_panel.csv`
- `output/tmhc_2013_2025_segment_land_rows.csv`
- `output/tmhc_2013_2025_extraction_audit.csv`
- `output/tmhc_2013_2025_source_notes.csv`
