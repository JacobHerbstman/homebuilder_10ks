# Five-firm quarterly operating disclosures

Extracts quarterly operating disclosures for BZH, MHO, MTH, TOL, and MDC from filed 10-Q HTML. The output preserves reported current-quarter or fiscal-year-to-date flow bases, period-end backlog, source accessions, and table text. Fiscal Q4 is constructed downstream in `build_tier1_quarterly_operating_panel`.

MDC’s independently public quarterly episode ends with its March 31, 2024 report, immediately before the Sekisui acquisition. Later MDC subsidiary filings are retained by the download task but excluded here.

Run from `code/` with `make`.
