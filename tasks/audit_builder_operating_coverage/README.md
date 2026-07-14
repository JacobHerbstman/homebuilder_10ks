# Builder Operating Coverage Audit

Run `make` from `code/`.

This task defines the operating-extraction queue around the 33 firms with usable 2006-2025 land-share observations. D.R. Horton, Lennar, PulteGroup, KB Home, Hovnanian, and NVR now enter from the filing-driven 2006-2025 operating extractor. The earlier manually assembled pilot remains only as a benchmark input to that upstream task.

WRECO is included as a supplemental historical operating series. Its 2004-2013 operating tables are now extracted and audited programmatically, but it is not part of the 33-firm omega mechanism sample because Weyerhaeuser does not report a comparable annual owned-versus-optioned physical denominator for WRECO.

The queue keeps mergers and deaths as distinct firm episodes. Successor firms are not back-spliced into predecessors.

The current queue contains the remaining 27 core firms. Metric coverage distinguishes unavailable disclosures from firms that have not yet received a firm-era extraction script.
