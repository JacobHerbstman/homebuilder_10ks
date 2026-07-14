# NVR Early Land Disclosure Extractor

This task extracts NVR's 2004-2009 prose-era controlled-lot disclosures from
10-K filings. NVR did not yet report the clean controlled-lot component table
used by the 2010+ hand-coded NVR task.

The main output treats the early NVR land pipeline as an all-controlled
pipeline: reported purchase-agreement/deposit-controlled lots plus separately
disclosed JV-controlled lots where the filing language says those lots are
additional. The resulting nonowned controlled share is therefore one by
construction, and the rows are flagged as prose-era observations.

For 2009, the main harmonized total uses the 2010 filing's restated prior-year
controlled-lot value of 46,337 rather than the originally filed rounded prose
value of 46,300. The original value and the 760 disclosed LLC lots are retained
as audit fields.

Run from `tasks/extract_nvr_early_land_disclosures/code`:

```sh
make
```
