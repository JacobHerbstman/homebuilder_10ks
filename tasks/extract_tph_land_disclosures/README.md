# Tri Pointe Land Disclosure Extractor

This task extracts Tri Pointe Homes owned and controlled lot counts from its
recurring 10-K land tables.

The firm-year panel uses the company-wide `Total` row whenever Tri Pointe
reports `Lots Owned`, `Lots Controlled`, and `Lots Owned or Controlled`. The
2014 and 2015 filings present the same totals in year-over-year comparison
tables, so the extractor reads only the current-year column from those tables.

Known caveats:

- 2012 controlled lots include land option contracts, purchase contracts, and
  non-binding letters of intent.
- 2014 is a large portfolio/scope jump after the 2014 WRECO transaction.
- 2019 controlled lots include 135 Trendmaker lots representing Tri Pointe's
  expected share of an unconsolidated land development joint venture.
- 2021 changes segment rows from market/brand rows to West/Central/East rows.
- Controlled lots are coded as nonowned controlled lots, not as pure optioned
  lots.

Run from `tasks/extract_tph_land_disclosures/code`:

```sh
make
```
