# M/I Homes Land Disclosure Extraction

This task extracts M/I Homes annual lot-control values from the recurring 10-K table titled `Lots Owned`.

Firm-year rule:

- Unit is `lots`.
- Use only the explicit `Total` row for the firm-year panel.
- `owned_lots` is the `Total Lots Owned` column.
- `nonowned_controlled_lots` is the `Lots Under Contract` column.
- `total_lots` is the table's final `Total` column.
- `nonowned_controlled_share = Lots Under Contract / Total`.

Important caveat:

`Lots Under Contract` is a conservative nonowned land-control measure. It should not be relabeled as `optioned_lots` because the table does not identify cancellation rights, takedown obligations, deposits, or option terms.

Audit checks:

- The task requires one row for each fiscal year from 2004 through 2025.
- The total row must satisfy `Total Lots Owned + Lots Under Contract = Total`.
- The share must be between zero and one.
- Segment rows are preserved as provenance and arithmetic checks, but are not summed into the firm-year panel while an explicit total row exists.
