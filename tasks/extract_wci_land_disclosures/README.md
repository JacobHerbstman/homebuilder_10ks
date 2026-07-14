# extract_wci_land_disclosures

This task extracts WCI Communities land-control disclosures for two separate public episodes:

- old WCI Communities Inc. (`WCI`, CIK `0001137778`), fiscal 2004-2008
- post-reorganization WCI / WCIC (`WCIC`, CIK `0001574532`), fiscal 2013-2015

Old WCI does not report a standard lots/home-sites table. It reports approximate remaining entitled units and a footnote identifying the portion not owned but controlled through options or contracts. Those rows are retained as an alternate, review-coded land-control series with `unit_type = entitled_units`, not as fully comparable main-panel lots/home-sites rows. The key comparability issue is that entitled units are maximum approved capacity, include single-family, multi-family, mid-rise, and high-rise residences, and the filing says WCI usually builds fewer than the maximum entitled units.

Post-reorganization WCIC reports owned and controlled home sites in the `Home Sites by Development Status` table. These rows are main-panel eligible. For fiscal 2015, the task uses the development-status controlled total because it reconciles the 191 controlled sites grouped with active and other communities in the `Our Communities` table. The fiscal 2015 reported total also includes 1,027 owned tower sites, so the output flags that caveat.
