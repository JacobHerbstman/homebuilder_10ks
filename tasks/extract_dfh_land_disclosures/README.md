# Dream Finders Homes land disclosures

This task extracts Dream Finders Homes lot-control disclosures from annual 10-Ks.

Dream Finders uses two disclosure schemas in the current SEC file set:

- 2020-2023: an `Owned and Controlled Lots` table with owned, controlled, and total lots.
- 2024-2025: a `Controlled Lot Pipeline` table with controlled lots through option contracts, but no comparable owned-lot count.

The task computes nonowned controlled share only when the owned and total lot denominator is disclosed. For 2020-2023, this is a current physical split: table controlled lots divided by table owned plus controlled lots. This is separate from broader firm language about lots sourced through finished-lot option contracts or land-bank option contracts. For example, the 2020 filing reports that 99% of owned and controlled lots were controlled through those contracts; this is retained as a contract-sourced asset-light metric, not used as the current physical omega.

Controlled-lot-only rows are retained for pipeline-level analysis and marked as denominator-missing. The task does not impute 2024-2025 owned lots, carry forward the 2023 owned count, or treat the controlled-lot pipeline as the omega denominator.

Run from `code/`:

```sh
make
```
