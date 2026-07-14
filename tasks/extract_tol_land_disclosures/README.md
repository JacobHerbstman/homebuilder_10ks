# Toll Brothers Land Disclosure Extraction

This task extracts Toll Brothers' annual home-site land-control disclosures from
its 10-K filings.

Toll reports the relevant object as home sites, not lots. The preferred
firm-year measure is:

`nonowned_controlled_home_sites / total_home_sites_owned_or_controlled`

Rules:

- Prefer the structured Housing Data table when it reports `Home sites: Owned,
  Controlled, Total`.
- If the table is absent, use company-wide prose saying total home sites owned
  or controlled through options, owned home sites, and controlled/optioned home
  sites.
- If company-wide total and owned home sites are disclosed but controlled is not
  directly disclosed, compute controlled as total minus owned and flag the row as
  residual/rounded.
- Do not use future-communities-only controlled home sites as the company-wide
  numerator. Preserve those values only as a check in the source notes.
- Do not add joint venture home sites unless the filing says they are included
  in the company-wide controlled-through-options count.

These rules were checked against public SEC excerpt text and reviewed with
ChatGPT as a second read during implementation.
