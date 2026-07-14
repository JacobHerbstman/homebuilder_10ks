# Landsea Homes land disclosures

This task extracts Landsea Homes owned, controlled, and total lot counts from its SEC 10-K disclosures.

The 2018 and 2019 filings are LF Capital Acquisition Corp. SPAC filings before the Landsea operating-builder business combination. They are written to the pre-builder exclusion output so downstream panels do not treat them as missing Landsea land-disclosure observations.

For fiscal 2020, the originally filed 2020 10-K reports total lots owned or controlled and approximate prose counts. The exact owned / controlled split is taken from the 2021 10-K comparative December 31, 2020 row and flagged in the source note.

`Lots Controlled` is treated as non-owned controlled lots, not pure optioned lots, because the table does not label the controlled bucket as optioned.

Run from `code/`:

```sh
make
```
