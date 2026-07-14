# Five-Firm Annual Operating Disclosures

Run `make` from `code/`.

This task extracts annual operating outcomes from the 10-K filings of Beazer Homes, M/I Homes, Meritage Homes, Toll Brothers, and M.D.C. Holdings. The panel covers fiscal years 2006-2025 for the first four firms and 2006-2024 for M.D.C. Holdings. M.D.C. Holdings' 2025 filing is excluded because it follows the Sekisui House acquisition and reports a changed operating scope outside the public-firm episode used in this project.

The task writes one firm-year panel. Filing accessions, checksums, extraction methods, reporting scope, and source text are stored in the panel itself. Benchmark comparisons and coverage diagnostics belong in `tasks/audits/audit_five_firm_annual_operating_disclosures`.
