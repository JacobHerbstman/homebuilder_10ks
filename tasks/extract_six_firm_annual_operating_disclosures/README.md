# Six-Firm Annual Operating Disclosures

Run `make` from `code/`.

This task reads every annual 10-K for D.R. Horton, Lennar, PulteGroup, KB Home, Hovnanian, and NVR for fiscal years 2006-2025. It extracts annual orders, deliveries, backlog, cancellation rates, communities, selling prices, and homebuilding revenue from firm-specific operating tables.

The reviewed 2012-2023 pilot CSV is an audit input only. Production values come from the downloaded SEC HTML files.

The task writes:

- `six_firm_2006_2025_operating_panel.csv`: one production row for each of the 120 firm-years.
- `six_firm_2006_2025_operating_candidates.csv`: the same extracted values with filing paths, checksums, source table text, methods, and review fields.
- `six_firm_2012_2023_operating_benchmark_audit.csv`: cell-level comparisons with the reviewed pilot values.
- `six_firm_2006_2025_operating_coverage_audit.csv`: metric coverage by firm.

The script stops if any reviewed benchmark fails, any core annual operating measure is missing, or a unit, cancellation-rate, or average-price value falls outside conservative magnitude bounds. This specifically prevents malformed SEC HTML from concatenating adjacent year columns into a plausible-looking production value.

Disclosure formats are handled by firm and era. KB Home's 2006-2011 regional tables are accepted only after the reported consolidated total is found to equal the sum of regional rows. Its malformed 2024-2025 HTML is parsed by table cell rather than flattened text. Pulte's detailed supplemental tables are preferred to five-year summaries when both are present. NVR's 2006 regional table is summed because no explicit consolidated row is present; later filings use the consolidated operating table.

Hovnanian reports annual net-contract value but does not consistently report comparable annual net-contract units. Its order-unit field therefore remains missing rather than being inferred from backlog changes or quarterly dollar tables.

For Hovnanian through 2019, the annual order-dollar measure is the sum of the four consolidated quarterly net-contract flows reported in the 10-K, matching the reviewed pilot definition. From 2020 onward, it is the filing's explicit consolidated annual net-contract value.

Lennar values include unconsolidated entities where the filing's homebuilding tables use that scope. Firm and scope labels are retained in the panel.
