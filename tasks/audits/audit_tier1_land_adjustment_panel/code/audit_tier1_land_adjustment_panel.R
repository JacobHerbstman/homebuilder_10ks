# setwd("/Users/jacobherbstman/Desktop/homebuilder_10ks/tasks/audits/audit_tier1_land_adjustment_panel/code")

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(tidyr)
})

source("../../../_lib/homebuilder_pipeline_utils.R")

panel <- read_csv("../input/tier1_2021_2023_land_adjustment_panel.csv", show_col_types = FALSE)

expected <- tribble(
  ~ticker, ~fiscal_year, ~owned_count, ~nonowned_controlled_count, ~option_labeled_count, ~total_controlled_count,
  "BZH", 2021L, 11995, 9992, 9992, 21987,
  "BZH", 2023L, 11699, 14490, 14490, 26189,
  "CCS", 2021L, 32855, 47004, NA, 79859,
  "CCS", 2023L, 30623, 43097, NA, 73720,
  "DFH", 2021L, 5345, 38495, NA, 43840,
  "DFH", 2023L, 6929, 29748, NA, 36677,
  "DHI", 2021L, 127800, 402500, NA, 530300,
  "DHI", 2023L, 141100, 427300, NA, 568400,
  "GRBK", 2021L, 20239, 8382, NA, 28621,
  "GRBK", 2023L, 23801, 4880, NA, 28681,
  "HOV", 2021L, 10451, 20423, 20423, 31243,
  "HOV", 2023L, 7337, 24389, 24389, 31754,
  "KBH", 2021L, 48525, 38243, 38243, 86768,
  "KBH", 2023L, 40800, 15176, 15176, 55976,
  "LEN", 2021L, 181961, 257509, 251423, 439470,
  "LEN", 2023L, 99815, 309700, NA, 409515,
  "LGIH", 2021L, 54867, 36978, NA, 91845,
  "LGIH", 2023L, 55331, 15750, NA, 71081,
  "LSEA", 2021L, 5148, 3592, NA, 8740,
  "LSEA", 2023L, 4568, 6608, NA, 11176,
  "MDC", 2021L, 26932, 11148, 11148, 38080,
  "MDC", 2023L, 17999, 4416, 4416, 22415,
  "MHO", 2021L, 24593, 19364, NA, 43957,
  "MHO", 2023L, 24374, 21286, NA, 45660,
  "MTH", 2021L, 48554, 26495, NA, 75049,
  "MTH", 2023L, 46294, 18019, NA, 64313,
  "NVR", 2021L, NA, 124700, NA, 124900,
  "NVR", 2023L, NA, 139750, NA, 141500,
  "PHM", 2021L, 109078, 119218, 119218, 228296,
  "PHM", 2023L, 104515, 118115, 118115, 222630,
  "TMHC", 2021L, 53311, 28762, NA, 82073,
  "TMHC", 2023L, 34077, 38285, NA, 72362,
  "TOL", 2021L, 36100, 44800, 44800, 80900,
  "TOL", 2023L, 35900, 34700, 34700, 70700,
  "TPH", 2021L, 22136, 19539, NA, 41675,
  "TPH", 2023L, 18739, 13221, NA, 31960
) |>
  pivot_longer(
    cols = c(owned_count, nonowned_controlled_count, option_labeled_count, total_controlled_count),
    names_to = "metric",
    values_to = "expected_value"
  ) |>
  filter(!is.na(expected_value))

actual <- panel |>
  select(
    ticker,
    owned_count_2021, owned_count_2023,
    nonowned_controlled_count_2021, nonowned_controlled_count_2023,
    option_labeled_count_2021, option_labeled_count_2023,
    total_controlled_count_2021, total_controlled_count_2023
  ) |>
  pivot_longer(
    -ticker,
    names_to = c("metric", "fiscal_year"),
    names_pattern = "(.+)_(2021|2023)$",
    values_to = "extracted_value"
  ) |>
  mutate(fiscal_year = as.integer(fiscal_year))

benchmark_audit <- expected |>
  left_join(actual, by = c("ticker", "fiscal_year", "metric"), relationship = "one-to-one") |>
  mutate(
    difference = extracted_value - expected_value,
    pass = !is.na(extracted_value) & difference == 0
  ) |>
  arrange(ticker, fiscal_year, metric)

coverage_audit <- panel |>
  transmute(
    ticker,
    unit_definition_continuous,
    land_measure_definition_continuous,
    option_measure_continuous,
    component_reconciliation_2021 = case_when(
      ticker == "HOV" ~ component_residual_count_2021 == 369,
      ticker == "TOL" ~ abs(component_residual_count_2021) <= 100,
      is.na(owned_count_2021) ~ TRUE,
      TRUE ~ component_residual_count_2021 == 0
    ),
    component_reconciliation_2023 = case_when(
      ticker == "HOV" ~ component_residual_count_2023 == 28,
      ticker == "TOL" ~ abs(component_residual_count_2023) <= 100,
      is.na(owned_count_2023) ~ TRUE,
      TRUE ~ component_residual_count_2023 == 0
    ),
    share_identity_2021 = abs(nonowned_controlled_count_2021 / total_controlled_count_2021 - nonowned_controlled_share_2021) < 1e-8,
    share_identity_2023 = abs(nonowned_controlled_count_2023 / total_controlled_count_2023 - nonowned_controlled_share_2023) < 1e-8,
    source_provenance_present = !is.na(accession_number_2021) & !is.na(accession_number_2023) &
      !is.na(source_url_2021) & !is.na(source_url_2023),
    pass = land_adjustment_analysis_ready & component_reconciliation_2021 & component_reconciliation_2023 &
      share_identity_2021 & share_identity_2023 & source_provenance_present
  ) |>
  arrange(ticker)

write_csv_if_changed(benchmark_audit, "../output/tier1_land_adjustment_benchmark_audit.csv")
write_csv_if_changed(coverage_audit, "../output/tier1_land_adjustment_coverage_audit.csv")

cat("Wrote Tier-1 land-adjustment audits to ../output\n")
