# extract_brookfield_homes_land_disclosures

This task extracts Brookfield Homes Corp. (`BHS`, CIK `0001202157`) land-control rows for fiscal 2004-2010.

Brookfield reports a recurring `Lots controlled` table. For this project, the task codes:

- owned lots as the table subtotal for directly owned lots plus Brookfield's share of joint-venture or unconsolidated-entity owned lots
- nonowned controlled lots as the `Lots under option` row
- total lots as the table's `Total` controlled-lots row
- omega as `Lots under option / Total controlled lots`

The values are main-panel eligible because the owned subtotal plus the option row reconciles exactly to the disclosed total in every year. The main comparability caveat is that Brookfield's owned bucket is a proportionate-share land-position measure, not strictly consolidated owned lots.
