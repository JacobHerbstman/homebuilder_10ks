# setwd("/Users/jacobherbstman/Desktop/homebuilder_10ks/tasks/audits/audit_tier1_annual_operating_panel/code")

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(tidyr)
})

source("../../../_lib/homebuilder_pipeline_utils.R")

panel <- read_csv("../input/tier1_2018_2025_annual_operating_panel.csv", show_col_types = FALSE)

expected_rows <- tribble(
  ~ticker, ~expected_first_year, ~expected_last_year, ~expected_rows,
  "BZH", 2018L, 2025L, 8L,
  "CCS", 2018L, 2025L, 8L,
  "DFH", 2021L, 2025L, 5L,
  "DHI", 2018L, 2025L, 8L,
  "GRBK", 2018L, 2025L, 8L,
  "HOV", 2018L, 2025L, 8L,
  "KBH", 2018L, 2025L, 8L,
  "LEN", 2018L, 2025L, 8L,
  "LGIH", 2018L, 2025L, 8L,
  "LSEA", 2021L, 2024L, 4L,
  "MDC", 2018L, 2024L, 7L,
  "MHO", 2018L, 2025L, 8L,
  "MTH", 2018L, 2025L, 8L,
  "NVR", 2018L, 2025L, 8L,
  "PHM", 2018L, 2025L, 8L,
  "SDHC", 2024L, 2025L, 2L,
  "TMHC", 2018L, 2025L, 8L,
  "TOL", 2018L, 2025L, 8L,
  "TPH", 2018L, 2025L, 8L,
  "UHG", 2023L, 2025L, 3L
)

coverage_audit <- panel |>
  group_by(ticker) |>
  summarise(
    observed_first_year = min(fiscal_year),
    observed_last_year = max(fiscal_year),
    observed_rows = n(),
    orders_complete_rows = sum(!is.na(orders_units)),
    deliveries_complete_rows = sum(!is.na(deliveries_units)),
    backlog_complete_rows = sum(!is.na(backlog_units)),
    source_files_present = sum(file.exists(file.path("..", source_local_path))),
    .groups = "drop"
  ) |>
  left_join(expected_rows, by = "ticker", relationship = "one-to-one") |>
  mutate(
    pass = observed_first_year == expected_first_year &
      observed_last_year == expected_last_year &
      observed_rows == expected_rows &
      orders_complete_rows == expected_rows &
      deliveries_complete_rows == expected_rows &
      backlog_complete_rows == expected_rows &
      source_files_present == expected_rows
  ) |>
  arrange(ticker)

expected_2024 <- tribble(
  ~ticker, ~orders_units, ~deliveries_units, ~backlog_units,
  "BZH", 4221, 4450, 1482,
  "CCS", 10676, 11007, 850,
  "DFH", 6727, 8583, 2599,
  "DHI", 86561, 89690, 12180,
  "GRBK", 3681, 3783, 668,
  "HOV", 5186, 5348, 1649,
  "KBH", 13093, 14169, 4434,
  "LEN", 76951, 80210, 11633,
  "LGIH", 6037, 6028, 599,
  "LSEA", 2634, 2831, 390,
  "MDC", 8098, 9598, 390,
  "MHO", 8584, 9055, 2531,
  "MTH", 14606, 15611, 1544,
  "NVR", 22560, 22836, 9953,
  "PHM", 29226, 31219, 10153,
  "SDHC", 2649, 2867, 694,
  "TMHC", 12248, 12896, 4742,
  "TOL", 10231, 10813, 5996,
  "TPH", 5657, 6460, 1517,
  "UHG", 1399, 1431, 157
) |>
  pivot_longer(
    cols = c(orders_units, deliveries_units, backlog_units),
    names_to = "metric",
    values_to = "expected_value"
  )

benchmark_audit <- panel |>
  filter(fiscal_year == 2024) |>
  select(ticker, fiscal_year, orders_units, deliveries_units, backlog_units, accession_number, filing_url) |>
  pivot_longer(
    cols = c(orders_units, deliveries_units, backlog_units),
    names_to = "metric",
    values_to = "extracted_value"
  ) |>
  inner_join(expected_2024, by = c("ticker", "metric"), relationship = "one-to-one") |>
  mutate(
    difference = extracted_value - expected_value,
    pass = !is.na(extracted_value) & difference == 0
  ) |>
  arrange(ticker, metric)

write_csv_if_changed(coverage_audit, "../output/tier1_annual_operating_coverage_audit.csv")
write_csv_if_changed(benchmark_audit, "../output/tier1_annual_operating_benchmark_audit.csv")

if (any(!coverage_audit$pass) || any(!benchmark_audit$pass)) {
  stop("Tier-1 annual operating audit has one or more failed checks.")
}

cat("Wrote Tier-1 annual operating audits to ../output\n")
