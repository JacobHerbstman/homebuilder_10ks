# setwd("/Users/jacobherbstman/Desktop/homebuilder_10ks/tasks/audits/audit_nine_firm_annual_operating_disclosures/code")

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(tidyr)
})

source("../../../_lib/homebuilder_pipeline_utils.R")

panel <- read_csv("../input/nine_firm_2018_2025_annual_operating_panel.csv", show_col_types = FALSE)

if (nrow(panel) != 54 || panel |> count(ticker, fiscal_year) |> filter(n != 1) |> nrow() > 0) {
  stop("Expected 54 unique annual public firm-years.")
}

if (panel |> filter(is.na(orders_units) | is.na(deliveries_units) | is.na(backlog_units)) |> nrow() > 0) {
  stop("At least one annual public firm-year is missing orders, deliveries, or backlog units.")
}

if (panel |> filter(orders_units <= 0 | deliveries_units <= 0 | backlog_units <= 0) |> nrow() > 0) {
  stop("At least one annual operating count is nonpositive.")
}

expected <- tribble(
  ~ticker, ~fiscal_year, ~orders_units, ~deliveries_units, ~backlog_units,
  "CCS", 2018L, 5657, 6099, 2181,
  "CCS", 2024L, 10676, 11007, 850,
  "DFH", 2021L, 6804, 4874, 6381,
  "DFH", 2024L, 6727, 8583, 2599,
  "GRBK", 2018L, 1397, 1287, 582,
  "GRBK", 2024L, 3681, 3783, 668,
  "LGIH", 2018L, 6320, 6512, 624,
  "LGIH", 2024L, 6037, 6028, 599,
  "LGIH", 2025L, 5549, 4685, 1394,
  "LSEA", 2021L, 1471, 1640, 998,
  "LSEA", 2024L, 2634, 2831, 390,
  "SDHC", 2024L, 2649, 2867, 694,
  "TMHC", 2018L, 8400, 8760, 4158,
  "TMHC", 2024L, 12248, 12896, 4742,
  "TPH", 2018L, 4686, 5071, 1335,
  "TPH", 2024L, 5657, 6460, 1517,
  "UHG", 2023L, 1296, 1383, 189,
  "UHG", 2024L, 1399, 1431, 157
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

write_csv_if_changed(audit, "../output/nine_firm_annual_operating_benchmark_audit.csv")

cat("Wrote nine-firm annual operating benchmark audit to ../output\n")
