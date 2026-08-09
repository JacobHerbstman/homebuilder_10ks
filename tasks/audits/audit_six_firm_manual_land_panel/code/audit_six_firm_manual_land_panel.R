# setwd("/Users/jacobherbstman/Desktop/homebuilder_10ks/tasks/audits/audit_six_firm_manual_land_panel/code")

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(tibble)
  library(tidyr)
})

source("../../../_lib/homebuilder_pipeline_utils.R")

pilot_firms <- tribble(
  ~ticker, ~pilot_builder_name, ~firm_sort,
  "DHI", "D.R. Horton", 1L,
  "LEN", "Lennar", 2L,
  "PHM", "PulteGroup", 3L,
  "KBH", "KB Home", 4L,
  "HOV", "Hovnanian", 5L,
  "NVR", "NVR", 6L
)

panel <- read_csv(
  "../input/six_firm_2006_2025_manual_land_panel.csv",
  show_col_types = FALSE,
  na = c("", "NA"),
  col_types = cols(cik10 = col_character(), accession_number = col_character())
)

source_files_exist <- file.exists(file.path("..", panel$source_local_path))

missing_panel <- crossing(ticker = pilot_firms$ticker, fiscal_year = 2006:2025) |>
  anti_join(panel |> select(ticker, fiscal_year), by = c("ticker", "fiscal_year"))

duplicate_panel <- panel |>
  count(ticker, fiscal_year) |>
  filter(n > 1)

trend_summary <- panel |>
  group_by(ticker, pilot_builder_name, measure_definition, unit_type) |>
  summarise(
    firm_years = n(),
    usable_firm_years = sum(panel_use_flag, na.rm = TRUE),
    first_usable_year = if_else(usable_firm_years > 0, min(fiscal_year[panel_use_flag], na.rm = TRUE), NA_integer_),
    last_usable_year = if_else(usable_firm_years > 0, max(fiscal_year[panel_use_flag], na.rm = TRUE), NA_integer_),
    first_usable_share = if_else(usable_firm_years > 0, nonowned_controlled_share[which(panel_use_flag)[1]], NA_real_),
    last_usable_share = if_else(usable_firm_years > 0, nonowned_controlled_share[tail(which(panel_use_flag), 1)], NA_real_),
    min_usable_share = if_else(usable_firm_years > 0, min(nonowned_controlled_share[panel_use_flag], na.rm = TRUE), NA_real_),
    max_usable_share = if_else(usable_firm_years > 0, max(nonowned_controlled_share[panel_use_flag], na.rm = TRUE), NA_real_),
    manual_review_rows = sum(manual_review_flag, na.rm = TRUE),
    approximate_rows = sum(approximate_flag, na.rm = TRUE),
    .groups = "drop"
  ) |>
  arrange(match(ticker, pilot_firms$ticker))

firm_counts <- panel |>
  count(ticker, pilot_builder_name, name = "firm_years") |>
  mutate(
    audit_check = "firm_year_count",
    status = if_else(firm_years == 20L, "ok", "fail"),
    value = as.character(firm_years),
    detail = "Expected 20 firm-years for each pilot firm."
  ) |>
  select(ticker, pilot_builder_name, audit_check, status, value, detail)

audit <- bind_rows(
  tibble(
    ticker = NA_character_,
    pilot_builder_name = NA_character_,
    audit_check = "balanced_panel_rows",
    status = if_else(nrow(panel) == 120L, "ok", "fail"),
    value = as.character(nrow(panel)),
    detail = "Expected six firms times fiscal years 2006-2025."
  ),
  tibble(
    ticker = NA_character_,
    pilot_builder_name = NA_character_,
    audit_check = "missing_firm_years",
    status = if_else(nrow(missing_panel) == 0L, "ok", "fail"),
    value = as.character(nrow(missing_panel)),
    detail = paste(paste(missing_panel$ticker, missing_panel$fiscal_year, sep = "-"), collapse = "; ")
  ),
  tibble(
    ticker = NA_character_,
    pilot_builder_name = NA_character_,
    audit_check = "duplicate_firm_years",
    status = if_else(nrow(duplicate_panel) == 0L, "ok", "fail"),
    value = as.character(nrow(duplicate_panel)),
    detail = paste(paste(duplicate_panel$ticker, duplicate_panel$fiscal_year, sep = "-"), collapse = "; ")
  ),
  tibble(
    ticker = NA_character_,
    pilot_builder_name = NA_character_,
    audit_check = "source_files_exist",
    status = if_else(all(source_files_exist), "ok", "fail"),
    value = as.character(sum(source_files_exist)),
    detail = "Count of firm-years whose local SEC source file exists."
  ),
  tibble(
    ticker = NA_character_,
    pilot_builder_name = NA_character_,
    audit_check = "share_values_in_range",
    status = if_else(all(panel$share_missing_or_in_range), "ok", "fail"),
    value = paste0(
      sum(panel$selected_share_in_range, na.rm = TRUE),
      "/",
      sum(panel$selected_share_nonmissing, na.rm = TRUE)
    ),
    detail = "Non-missing selected shares between zero and one; missing shares are allowed only when panel_use_flag is false."
  ),
  tibble(
    ticker = NA_character_,
    pilot_builder_name = NA_character_,
    audit_check = "missing_selected_shares",
    status = if_else(all(!is.na(panel$nonowned_controlled_share) | !panel$panel_use_flag), "ok", "fail"),
    value = as.character(sum(is.na(panel$nonowned_controlled_share))),
    detail = "Rows with no selected share. These should not be marked usable."
  ),
  tibble(
    ticker = NA_character_,
    pilot_builder_name = NA_character_,
    audit_check = "usable_panel_rows",
    status = "ok",
    value = as.character(sum(panel$panel_use_flag, na.rm = TRUE)),
    detail = "Firm-years currently safe for the six-firm pilot plot."
  ),
  firm_counts
) |>
  arrange(coalesce(match(ticker, pilot_firms$ticker), 0L), audit_check)

if (any(audit$status == "fail")) {
  print(audit |> filter(status == "fail"))
  stop("At least one six-firm manual land audit failed.")
}

write_csv_if_changed(audit, "../output/six_firm_2006_2025_manual_land_audit.csv")
write_csv_if_changed(trend_summary, "../output/six_firm_2006_2025_manual_land_trends.csv")

cat("Wrote six-firm manual land audits to ../output\n")
