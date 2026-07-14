# setwd("/Users/jacobherbstman/Desktop/homebuilder_10ks/tasks/audits/audit_five_firm_annual_operating_disclosures/code")

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(tidyr)
})

source("../../../_lib/homebuilder_pipeline_utils.R")

panel <- read_csv("../input/five_firm_2006_2025_annual_operating_panel.csv", show_col_types = FALSE)

expected <- tribble(
  ~ticker, ~fiscal_year, ~orders_units, ~deliveries_units, ~backlog_units,
  "BZH", 2006L, 14538, 18669, 5102,
  "BZH", 2024L, 4221, 4450, 1482,
  "MDC", 2006L, 10229, 13123, 3638,
  "MDC", 2012L, 4342, 3740, 1645,
  "MDC", 2024L, 8098, 9598, 390,
  "MHO", 2006L, 2825, 4109, 1523,
  "MHO", 2024L, 8584, 9055, 2531,
  "MTH", 2006L, 7778, 10487, 3685,
  "MTH", 2024L, 14606, 15611, 1544,
  "TOL", 2006L, 6164, 8601, 6533,
  "TOL", 2012L, 4159, 3286, 2569,
  "TOL", 2024L, 10231, 10813, 5996
) |>
  pivot_longer(
    cols = c(orders_units, deliveries_units, backlog_units),
    names_to = "metric",
    values_to = "expected_value"
  )

audit <- panel |>
  select(ticker, fiscal_year, orders_units, deliveries_units, backlog_units, accession_number, filing_url, source_table_text) |>
  pivot_longer(
    cols = c(orders_units, deliveries_units, backlog_units),
    names_to = "metric",
    values_to = "extracted_value"
  ) |>
  inner_join(expected, by = c("ticker", "fiscal_year", "metric"), relationship = "one-to-one") |>
  mutate(
    difference = extracted_value - expected_value,
    pass = !is.na(extracted_value) & difference == 0
  ) |>
  arrange(ticker, fiscal_year, metric)

write_csv_if_changed(audit, "../output/five_firm_annual_operating_benchmark_audit.csv")

cat("Wrote five-firm annual operating benchmark audit to ../output\n")
