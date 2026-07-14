# Comstock Land Disclosures

This task extracts Comstock Homebuilding / Comstock Holding Companies land-pipeline counts for fiscal years 2006-2016 from the downloaded SEC 10-K files.

The main omega denominator is:

`owned unsold lots or units + nonowned lots or units under option/control`

Backlog is excluded from the main denominator because it is already sold but unsettled. Backlog-inclusive table totals are retained in the task output as audit fields.

Coding choices:

- 2006-2008 use the `Total Active & Development` row with `Lots Owned Unsold` and `Lots under Option Agreement Unsold`.
- 2009 is retained as a review-only restructuring year. The table discloses 940 owned unsold lots, 0 option lots, and 382 foreclosed lots, but foreclosure and bankruptcy-transfer language makes the going-forward denominator non-comparable.
- 2010-2012 disclose owned unsold lots but no physical nonowned option/control count, so omega is missing.
- 2013-2016 use the company total row from the pipeline report. For 2014-2016, `Units Under Control` is defined as under land option purchase contract and not owned.
- The output flags the 2014-2016 lot/unit label change, the 2009 distressed denominator conflict, and the 2010-2012 missing nonowned count.

Outputs:

- `output/chci_2006_2016_land_panel.csv`
- `output/chci_2006_2016_extraction_audit.csv`
- `output/chci_2006_2016_source_notes.csv`
