# setwd("/Users/jacobherbstman/Desktop/homebuilder_10ks/tasks/build_six_firm_manual_land_panel/code")

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(tibble)
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

if (nrow(panel) != 120L || panel |> count(ticker, fiscal_year) |> filter(n != 1L) |> nrow() > 0L) {
  stop("Six-firm land panel is not unique and complete for 2006-2025.")
}

if (any(!panel$source_file_exists)) {
  stop("At least one six-firm land row points to a missing SEC filing.")
}

if (any(!is.na(panel$nonowned_controlled_share) & (panel$nonowned_controlled_share < 0 | panel$nonowned_controlled_share > 1)) ||
    any(panel$panel_use_flag & is.na(panel$nonowned_controlled_share))) {
  stop("Six-firm land shares are out of range or missing on a usable row.")
}

write_csv_if_changed(panel, "../output/six_firm_2006_2025_manual_land_panel.csv")

cat("Wrote six-firm hand-coded 2006-2025 land panel to ../output\n")
