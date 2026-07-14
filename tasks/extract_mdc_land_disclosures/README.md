# MDC Land Disclosure Extraction

This task extracts M.D.C. Holdings annual lot-control values from its 10-K land tables.

Disclosure eras:

- Older tables report sections for `Lots Owned` and `Lots Under Option` or `Lots Controlled Under Option`.
- Newer tables report rows with columns `Lots Owned`, `Lots Optioned`, and `Total`.

Firm-year rule:

- Unit is `lots`.
- Use the current fiscal-year value only.
- Use only explicit total rows for the firm-year panel.
- `owned_lots` is the total owned-lots value.
- `optioned_lots` is `Lots Under Option`, `Lots Controlled Under Option`, or `Lots Optioned`.
- `total_lots` is explicit `Total Lots Owned and Controlled` or the table's `Total`; if the old table omits the total row, use `owned_lots + optioned_lots`.
- `nonowned_controlled_share = optioned_lots / total_lots`.

Audit checks:

- One row is expected for each fiscal year from 2004 through 2025.
- `owned_lots + optioned_lots = total_lots`.
- The optioned share must be between zero and one.
- Segment rows are preserved as provenance but are not used to build the firm-year value when a total row exists.
