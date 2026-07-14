# Build six-firm manual land panel

This task combines the hand-read 2006-2025 land-disclosure panels for D.R.
Horton, Lennar, PulteGroup, KB Home, Hovnanian, and NVR.

The task is intentionally downstream of the hand-coding tasks. It does not use
the generic extraction candidates as final values. The generic extraction is
useful for search and triage, but the pilot panel uses hand-read values with
firm-specific definitions and audit flags.

## Outputs

- `output/six_firm_2006_2025_manual_land_panel.csv`: balanced six-firm by year
  panel with raw owned, optioned, JV, total, and selected share fields.
- `output/six_firm_2006_2025_manual_land_audit.csv`: row-count, duplicate,
  source-file, and range checks.
- `output/six_firm_2006_2025_manual_land_trends.csv`: first/last/min/max
  selected share by firm.

## Important definitions

- D.R. Horton: lots controlled under land/lot contracts divided by total land
  lots owned and controlled.
- Lennar: controlled homesites divided by total homesites. Lennar stops
  disclosing the optioned/JV split in the same way after 2022.
- PulteGroup: optioned lots divided by controlled lots. 2006 and 2007 are
  rounded prose disclosures.
- KB Home: land under option divided by total land owned or under option.
- Hovnanian: optioned home sites divided by consolidated total home sites.
  Unconsolidated JV lots are retained separately and are not added to the
  consolidated denominator.
- NVR: LPA plus NVR-controlled JV lots divided by total controlled lots. NVR
  does not disclose owned lots in the same way as the other builders, so 2006
  through 2009 are retained for history but excluded from the pilot plot until
  the early overlap problem is resolved.

Run from `code/`:

```sh
make
```
