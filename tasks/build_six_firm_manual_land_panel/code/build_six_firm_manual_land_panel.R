# setwd("/Users/jacobherbstman/Desktop/homebuilder_10ks/tasks/build_six_firm_manual_land_panel/code")

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(tibble)
  library(tidyr)
})

source("../../_lib/homebuilder_pipeline_utils.R")

pilot_firms <- tribble(
  ~ticker, ~pilot_builder_name, ~firm_sort,
  "DHI", "D.R. Horton", 1L,
  "LEN", "Lennar", 2L,
  "PHM", "PulteGroup", 3L,
  "KBH", "KB Home", 4L,
  "HOV", "Hovnanian", 5L,
  "NVR", "NVR", 6L
)

expected_panel <- crossing(
  ticker = pilot_firms$ticker,
  fiscal_year = 2006:2025
)

dhi_len_phm <- read_csv(
  "../input/dhi_len_phm_2006_2025_manual_land_panel.csv",
  show_col_types = FALSE,
  na = c("", "NA")
) |>
  mutate(
    fiscal_year = as.integer(fiscal_year),
    across(
      c(approximate_flag, manual_review_flag, panel_use_flag, source_file_exists, components_reconcile_to_reported_total),
      \(x) if_else(is.na(x), NA, as.character(x) %in% c("TRUE", "true", "True", "1"))
    )
  ) |>
  transmute(
    ticker,
    fiscal_year,
    unit_type,
    measure_definition = comparable_share_definition,
    disclosure_basis,
    source_table_index = as.character(source_table_index),
    source_row_label = NA_character_,
    owned_physical_count = suppressWarnings(as.numeric(as.character(owned_physical_count))),
    nonowned_controlled_physical_count = suppressWarnings(as.numeric(as.character(nonowned_controlled_physical_count))),
    optioned_physical_count = suppressWarnings(as.numeric(as.character(optioned_physical_count))),
    jv_physical_count = suppressWarnings(as.numeric(as.character(jv_physical_count))),
    construction_to_perm_physical_count = NA_real_,
    separate_unconsolidated_jv_physical_count = NA_real_,
    total_physical_count = suppressWarnings(as.numeric(as.character(total_physical_count))),
    nonowned_controlled_share = suppressWarnings(as.numeric(as.character(nonowned_controlled_share))),
    optioned_share = suppressWarnings(as.numeric(as.character(optioned_share))),
    owned_share = suppressWarnings(as.numeric(as.character(owned_share))),
    conservative_lpa_only_share = NA_real_,
    exact_component_identity = components_reconcile_to_reported_total,
    approximate_flag,
    manual_review_flag,
    manual_review_reason,
    hand_code_quality_tier,
    panel_use_flag,
    panel_use_note,
    source_task = "hand_code_dhi_len_phm_land_disclosures",
    source_note,
    cik10,
    sec_company_name,
    report_date = as.Date(report_date),
    filing_date = as.Date(filing_date),
    accession_number,
    primary_document,
    source_url,
    source_local_path,
    source_file_exists
  )

kbh_hov <- read_csv(
  "../input/kbh_hov_2006_2025_manual_land_panel.csv",
  show_col_types = FALSE,
  na = c("", "NA")
) |>
  mutate(
    fiscal_year = as.integer(fiscal_year),
    across(
      c(manual_review_flag, panel_use_flag, source_file_exists, components_reconcile_to_reported_total),
      \(x) if_else(is.na(x), NA, as.character(x) %in% c("TRUE", "true", "True", "1"))
    )
  ) |>
  transmute(
    ticker,
    fiscal_year,
    unit_type,
    measure_definition = comparable_share_definition,
    disclosure_basis,
    source_table_index = as.character(source_table_index),
    source_row_label,
    owned_physical_count = suppressWarnings(as.numeric(as.character(owned_lots))),
    nonowned_controlled_physical_count = suppressWarnings(as.numeric(as.character(optioned_lots))),
    optioned_physical_count = suppressWarnings(as.numeric(as.character(optioned_lots))),
    jv_physical_count = NA_real_,
    construction_to_perm_physical_count = suppressWarnings(as.numeric(as.character(construction_to_perm_lots))),
    separate_unconsolidated_jv_physical_count = suppressWarnings(as.numeric(as.character(unconsolidated_jv_lots))),
    total_physical_count = suppressWarnings(as.numeric(as.character(total_controlled_lots))),
    nonowned_controlled_share = suppressWarnings(as.numeric(as.character(optioned_share_of_total))),
    optioned_share = suppressWarnings(as.numeric(as.character(optioned_share_of_total))),
    owned_share = suppressWarnings(as.numeric(as.character(owned_share_of_total))),
    conservative_lpa_only_share = NA_real_,
    exact_component_identity = components_reconcile_to_reported_total,
    approximate_flag = FALSE,
    manual_review_flag,
    manual_review_reason,
    hand_code_quality_tier,
    panel_use_flag,
    panel_use_note,
    source_task = "hand_code_kbh_hov_land_disclosures",
    source_note,
    cik10,
    sec_company_name,
    report_date = as.Date(report_date),
    filing_date = as.Date(filing_date),
    accession_number,
    primary_document,
    source_url,
    source_local_path,
    source_file_exists
  )

nvr <- read_csv(
  "../input/nvr_2006_2025_manual_land_panel.csv",
  show_col_types = FALSE,
  na = c("", "NA")
) |>
  mutate(
    fiscal_year = as.integer(fiscal_year),
    across(
      c(manual_review_flag, panel_use_flag, source_file_exists, components_reconcile_to_reported_total),
      \(x) if_else(is.na(x), NA, as.character(x) %in% c("TRUE", "true", "True", "1"))
    )
  ) |>
  transmute(
    ticker,
    fiscal_year,
    unit_type = "lots",
    measure_definition = "NVR LPA plus NVR-controlled JV lots / total controlled lots; owned lots are not separately disclosed",
    disclosure_basis = "lpa_jv_land_under_development_disclosures",
    source_table_index = NA_character_,
    source_row_label = NA_character_,
    owned_physical_count = NA_real_,
    nonowned_controlled_physical_count = suppressWarnings(as.numeric(as.character(nonowned_controlled_lots_lpa_plus_jv))),
    optioned_physical_count = suppressWarnings(as.numeric(as.character(lpa_lots))),
    jv_physical_count = suppressWarnings(as.numeric(as.character(jv_controlled_by_nvr_lots))),
    construction_to_perm_physical_count = NA_real_,
    separate_unconsolidated_jv_physical_count = NA_real_,
    total_physical_count = suppressWarnings(as.numeric(as.character(total_controlled_lots))),
    nonowned_controlled_share = suppressWarnings(as.numeric(as.character(nonowned_controlled_share_lpa_plus_jv))),
    optioned_share = suppressWarnings(as.numeric(as.character(lpa_share_of_total_controlled))),
    owned_share = NA_real_,
    conservative_lpa_only_share = suppressWarnings(as.numeric(as.character(conservative_lpa_only_share))),
    exact_component_identity = components_reconcile_to_reported_total,
    approximate_flag = total_controlled_lots_precision == "rounded",
    manual_review_flag,
    manual_review_reason,
    hand_code_quality_tier,
    panel_use_flag,
    panel_use_note,
    source_task = "hand_code_nvr_land_disclosures",
    source_note,
    cik10,
    sec_company_name,
    report_date = as.Date(report_date),
    filing_date = as.Date(filing_date),
    accession_number,
    primary_document,
    source_url,
    source_local_path,
    source_file_exists
  )

panel <- bind_rows(dhi_len_phm, kbh_hov, nvr) |>
  left_join(pilot_firms, by = "ticker", relationship = "many-to-one") |>
  mutate(
    selected_share_nonmissing = !is.na(nonowned_controlled_share),
    selected_share_in_range = selected_share_nonmissing &
      nonowned_controlled_share >= 0 &
      nonowned_controlled_share <= 1,
    share_missing_or_in_range = !selected_share_nonmissing | selected_share_in_range,
    total_physical_count_positive = !is.na(total_physical_count) & total_physical_count > 0,
    panel_use_flag = coalesce(panel_use_flag, FALSE),
    manual_review_flag = coalesce(manual_review_flag, FALSE),
    approximate_flag = coalesce(approximate_flag, FALSE)
  ) |>
  select(
    ticker,
    pilot_builder_name,
    fiscal_year,
    unit_type,
    measure_definition,
    owned_physical_count,
    nonowned_controlled_physical_count,
    optioned_physical_count,
    jv_physical_count,
    construction_to_perm_physical_count,
    separate_unconsolidated_jv_physical_count,
    total_physical_count,
    nonowned_controlled_share,
    optioned_share,
    owned_share,
    conservative_lpa_only_share,
    exact_component_identity,
    approximate_flag,
    manual_review_flag,
    manual_review_reason,
    hand_code_quality_tier,
    panel_use_flag,
    panel_use_note,
    disclosure_basis,
    source_table_index,
    source_row_label,
    source_task,
    source_note,
    cik10,
    sec_company_name,
    report_date,
    filing_date,
    accession_number,
    primary_document,
    source_url,
    source_local_path,
    source_file_exists,
    selected_share_nonmissing,
    selected_share_in_range,
    share_missing_or_in_range,
    total_physical_count_positive,
    firm_sort
  ) |>
  arrange(firm_sort, fiscal_year) |>
  select(-firm_sort)

missing_panel <- expected_panel |>
  anti_join(panel |> select(ticker, fiscal_year), by = c("ticker", "fiscal_year"))

duplicate_panel <- panel |>
  count(ticker, fiscal_year) |>
  filter(n > 1)

trend_summary <- panel |>
  group_by(ticker, pilot_builder_name, measure_definition, unit_type) |>
  summarise(
    firm_years = n(),
    usable_firm_years = sum(panel_use_flag, na.rm = TRUE),
    first_usable_year = if_else(
      usable_firm_years > 0,
      min(fiscal_year[panel_use_flag], na.rm = TRUE),
      NA_integer_
    ),
    last_usable_year = if_else(
      usable_firm_years > 0,
      max(fiscal_year[panel_use_flag], na.rm = TRUE),
      NA_integer_
    ),
    first_usable_share = if_else(
      usable_firm_years > 0,
      nonowned_controlled_share[which(panel_use_flag)[1]],
      NA_real_
    ),
    last_usable_share = if_else(
      usable_firm_years > 0,
      nonowned_controlled_share[tail(which(panel_use_flag), 1)],
      NA_real_
    ),
    min_usable_share = if_else(
      usable_firm_years > 0,
      min(nonowned_controlled_share[panel_use_flag], na.rm = TRUE),
      NA_real_
    ),
    max_usable_share = if_else(
      usable_firm_years > 0,
      max(nonowned_controlled_share[panel_use_flag], na.rm = TRUE),
      NA_real_
    ),
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
    status = if_else(all(panel$source_file_exists), "ok", "fail"),
    value = as.character(sum(panel$source_file_exists, na.rm = TRUE)),
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
    status = if_else(
      all(!is.na(panel$nonowned_controlled_share) | !panel$panel_use_flag),
      "ok",
      "fail"
    ),
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

write_csv_if_changed(panel, "../output/six_firm_2006_2025_manual_land_panel.csv")
write_csv_if_changed(audit, "../output/six_firm_2006_2025_manual_land_audit.csv")
write_csv_if_changed(trend_summary, "../output/six_firm_2006_2025_manual_land_trends.csv")

cat("Wrote six-firm hand-coded 2006-2025 land panel outputs to ../output\n")
