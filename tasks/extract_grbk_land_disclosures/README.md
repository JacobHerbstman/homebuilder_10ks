# Extract Green Brick Land Disclosures

This task extracts Green Brick Partners land-control counts from its builder-era 10-K tables.

Green Brick is a reverse-merger/splice case. The same SEC CIK has BioFuel Energy filings before the Green Brick homebuilding business appears. This task treats 2007-2013 BioFuel Energy filings as pre-builder predecessor/shell filings and excludes them from the builder land-control panel rather than coding them as missing builder disclosures.

The firm-year panel begins in fiscal year 2014. It uses explicit company-wide total rows for owned lots, controlled/under-contract lots, and total lots. Segment rows are retained for provenance and arithmetic checks only.
