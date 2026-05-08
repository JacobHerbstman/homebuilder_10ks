# Builder Public-Firm Harmonization

This task is downstream of `stage_builder_panel` and `build_builder_sec_crosswalk`. It preserves the 53 Builder-public name keys and adds conservative firm identifiers for over-time counting and firm-year panel construction.

Collapse rule: default to no collapse. Collapse only when a browser-verified source shows a same-registrant name change, or when Builder's label and SEC text clearly identify the same public parent/division. Acquisition targets and merger partners remain separate historical firms unless a later design explicitly wants successor-parent consolidation.

Firm-year coding rule: keep each acquired target as its own firm through its last standalone activity year, then let it disappear. Record the acquirer or successor in separate successor fields. This means Centex is Centex through the 2009 activity year and PulteGroup is PulteGroup separately; WCI is not recoded to Lennar; UCP is not recoded to Century; William Lyon is not recoded to Taylor Morrison; MDC is not recoded to Sekisui. Same-registrant name changes are the exception.

Verified collapses in the first pass:

- Pulte Homes / PulteGroup: SEC 2010 10-K says Pulte Homes, Inc. changed its name to PulteGroup, Inc.
- Meritage Corp. / Meritage Homes Corp. / Meritage Homes: Meritage investor release says Meritage Corporation changed its name to Meritage Homes Corporation.
- Avatar Holdings / AV Homes: company release says Avatar Holdings Inc. became AV Homes, Inc. and kept ticker `AVHI`.
- Standard Pacific / CalAtlantic: CalAtlantic release says Standard Pacific changed its name to CalAtlantic Group after the Ryland merger.
- Technical Olympic USA / Engle Homes division of TOUSA Homes: TOUSA 10-K and Builder label support a public-parent/division collapse, but this remains flagged for manual review.
- St. Joe Co. / St. Joe Towns & Resorts: St. Joe source identifies Towns & Resorts as JOE's residential and resort development segment. The group remains non-comparable for the SEC production-builder land panel.

Known non-collapses/review cases are tracked in `code/manual_builder_public_firm_harmonization_pairs.csv`. In particular, Centex is not collapsed into Pulte, Ryland is not collapsed into Standard Pacific/CalAtlantic, and lookalikes such as William Lyon Homes/WL Homes, Brookfield, and Taylor/Morrison lineage are left for review.

Lifecycle and successor decisions are tracked in `code/manual_builder_public_firm_lifecycle.csv`. That file covers every Builder-public firm that disappears from the list or stops being marked public before the latest Builder year. It records event dates, successor/acquirer names, coding decisions, source URLs, and manual-review flags. Update that file when a better source changes a decision.

Run:

```sh
cd tasks/harmonize_builder_public_firms/code
make
```

Key outputs:

- `output/builder_public_firm_harmonized.csv`: one row per original Builder-public name key with harmonized ID/name and evidence fields.
- `output/builder_public_harmonization_groups.csv`: one row per harmonized public builder group.
- `output/builder_public_harmonization_review.csv`: no-collapse and manual-review pairs.
- `output/builder_public_lifecycle_events.csv`: acquisition, bankruptcy, going-private, name-change, and business-model-shift decisions for disappearing public firms.
- `output/builder_public_firm_year_identifiers.csv`: Builder firm-year identifier table with harmonized IDs, successor fields, post-event flags, and standalone SEC-panel eligibility.
- `output/builder_public_harmonization_qc.csv`: row counts and warnings.
