# setwd("/Users/jacobherbstman/Desktop/homebuilder_10ks/tasks/audits/audit_six_firm_annual_operating_disclosures/code")

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(tidyr)
})

source("../../../_lib/homebuilder_pipeline_utils.R")

panel <- read_csv(
  "../input/six_firm_2006_2025_operating_panel.csv",
  show_col_types = FALSE,
  na = c("", "NA"),
  col_types = cols(cik10 = col_character(), accession_number = col_character())
)

if (nrow(panel) != 120 || n_distinct(panel$ticker) != 6 || panel |> count(ticker, fiscal_year) |> filter(n != 1) |> nrow() > 0) {
  stop("Expected 120 unique firm-years in the six-firm annual operating panel.")
}

source_files <- file.path("..", panel$source_local_path)
if (any(!file.exists(source_files))) {
  stop("At least one six-firm annual operating source file is missing.")
}

source_hashes <- vapply(
  source_files,
  digest::digest,
  character(1),
  algo = "sha256",
  file = TRUE,
  serialize = FALSE
)

benchmarks <- read_csv(
  "../input/manual_six_firm_operating_scale_2012_2023.csv",
  show_col_types = FALSE,
  na = c("", "NA")
) |>
  select(ticker, fiscal_year, orders_units, orders_value_thousands, deliveries_units, backlog_units, backlog_value_thousands, cancellation_rate_pct, active_communities, average_community_count) |>
  pivot_longer(-c(ticker, fiscal_year), names_to = "metric_name", values_to = "expected_value") |>
  filter(!is.na(expected_value))

benchmark_audit <- benchmarks |>
  left_join(
    panel |>
      select(ticker, fiscal_year, orders_units, orders_value_thousands, deliveries_units, backlog_units, backlog_value_thousands, cancellation_rate_pct, active_communities, average_community_count, accession_number, extraction_method, extraction_confidence) |>
      pivot_longer(
        cols = c(orders_units, orders_value_thousands, deliveries_units, backlog_units, backlog_value_thousands, cancellation_rate_pct, active_communities, average_community_count),
        names_to = "metric_name",
        values_to = "extracted_value"
      ),
    by = c("ticker", "fiscal_year", "metric_name"),
    relationship = "one-to-one"
  ) |>
  mutate(
    tolerance = if_else(metric_name == "cancellation_rate_pct", 0.05, 0),
    absolute_difference = abs(extracted_value - expected_value),
    status = if_else(!is.na(extracted_value) & absolute_difference <= tolerance, "pass", "fail")
  ) |>
  arrange(ticker, fiscal_year, metric_name)

implausible_values <- panel |>
  filter(
    if_any(c(orders_units, deliveries_units, backlog_units), ~ !is.na(.x) & (.x <= 0 | .x > 200000)) |
      (!is.na(cancellation_rate_pct) & (cancellation_rate_pct < 0 | cancellation_rate_pct > 100)) |
      (!is.na(average_selling_price_dollars) & (average_selling_price_dollars < 50000 | average_selling_price_dollars > 2000000))
  )

missing_core_values <- panel |>
  filter(
    is.na(deliveries_units) |
      is.na(backlog_units) |
      (ticker == "HOV" & fiscal_year < 2018 & is.na(orders_value_thousands)) |
      (is.na(orders_units) & (ticker != "HOV" | fiscal_year >= 2018))
  )

coverage_audit <- panel |>
  group_by(ticker, company) |>
  summarise(
    filing_years = n(),
    first_year = min(fiscal_year),
    last_year = max(fiscal_year),
    orders_units_years = sum(!is.na(orders_units)),
    orders_value_years = sum(!is.na(orders_value_thousands)),
    deliveries_years = sum(!is.na(deliveries_units)),
    backlog_units_years = sum(!is.na(backlog_units)),
    backlog_value_years = sum(!is.na(backlog_value_thousands)),
    cancellation_rate_years = sum(!is.na(cancellation_rate_pct)),
    active_community_years = sum(!is.na(active_communities) | !is.na(average_community_count)),
    manual_review_years = sum(manual_review_flag),
    .groups = "drop"
  ) |>
  arrange(ticker)

if (
  any(benchmark_audit$status != "pass") ||
  nrow(implausible_values) > 0 ||
  nrow(missing_core_values) > 0 ||
  any(source_hashes != panel$source_checksum_sha256)
) {
  print(benchmark_audit |> filter(status != "pass"))
  print(implausible_values)
  print(missing_core_values)
  stop("At least one six-firm annual operating audit failed.")
}

write_csv_if_changed(benchmark_audit, "../output/six_firm_2012_2023_operating_benchmark_audit.csv")
write_csv_if_changed(coverage_audit, "../output/six_firm_2006_2025_operating_coverage_audit.csv")

cat("Wrote six-firm annual operating audits to ../output\n")
