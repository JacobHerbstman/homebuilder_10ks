# setwd("/Users/jacobherbstman/Desktop/homebuilder_10ks/tasks/hand_code_nvr_land_disclosures/code")

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
})

source("../../_lib/homebuilder_pipeline_utils.R")

manual <- read_csv("manual_nvr_land_disclosures.csv", show_col_types = FALSE, na = c("", "NA")) |>
  mutate(
    fiscal_year = as.integer(fiscal_year),
    report_date = as.Date(report_date),
    filing_date = as.Date(filing_date),
    manual_review_flag = if_else(
      is.na(manual_review_flag),
      NA,
      manual_review_flag %in% c(TRUE, "TRUE", "true", "True", "1", 1)
    ),
    raw_land_contract_excluded_from_total = if_else(
      is.na(raw_land_contract_excluded_from_total),
      NA,
      raw_land_contract_excluded_from_total %in% c(TRUE, "TRUE", "true", "True", "1", 1)
    )
  )

skeleton <- read_csv("../input/six_firm_2006_2025_skeleton.csv", show_col_types = FALSE, na = c("", "NA")) |>
  filter(ticker == "NVR") |>
  transmute(
    fiscal_year = as.integer(fiscal_year),
    skeleton_accession_number = downloaded_accession_number,
    skeleton_primary_document_status = primary_document_status,
    skeleton_annual_10k_downloaded = annual_10k_downloaded,
    skeleton_disclosure_recovery_status = disclosure_recovery_status
  )

if (nrow(manual) != 20) {
  stop("NVR manual disclosure file must contain exactly 20 fiscal years.")
}

if (manual |> count(fiscal_year) |> filter(n > 1) |> nrow() > 0) {
  stop("NVR manual disclosure file has duplicate fiscal years.")
}

if (!identical(sort(manual$fiscal_year), 2006:2025)) {
  stop("NVR manual disclosure file must cover fiscal years 2006 through 2025.")
}

panel <- manual |>
  left_join(skeleton, by = "fiscal_year", relationship = "one-to-one") |>
  mutate(
    source_file_exists = file.exists(source_local_path),
    indexed_in_six_firm_skeleton = !is.na(skeleton_accession_number),
    component_sum_lots = if_else(
      !is.na(lpa_lots) & !is.na(jv_controlled_by_nvr_lots) & !is.na(land_under_development_lots),
      lpa_lots + jv_controlled_by_nvr_lots + land_under_development_lots,
      NA_real_
    ),
    component_sum_minus_total_lots = component_sum_lots - total_controlled_lots,
    component_rounding_tolerance_lots = pmax(100, 0.0025 * total_controlled_lots),
    components_reconcile_to_reported_total = !is.na(component_sum_minus_total_lots) &
      abs(component_sum_minus_total_lots) <= component_rounding_tolerance_lots,
    lpa_share_of_total_controlled = lpa_lots / total_controlled_lots,
    jv_controlled_share_of_total = jv_controlled_by_nvr_lots / total_controlled_lots,
    land_under_development_share_of_total = land_under_development_lots / total_controlled_lots,
    nonowned_controlled_lots_lpa_plus_jv = if_else(
      fiscal_year >= 2010,
      lpa_lots + jv_controlled_by_nvr_lots,
      NA_real_
    ),
    nonowned_controlled_share_lpa_plus_jv = nonowned_controlled_lots_lpa_plus_jv / total_controlled_lots,
    conservative_lpa_only_share = lpa_share_of_total_controlled,
    raw_land_contracts_relative_to_total = raw_land_contract_expected_lots_excluded / total_controlled_lots,
    deposit_rate_current_lpa_cash_to_contract_purchase_price = lpa_cash_deposits_millions / aggregate_purchase_price_millions,
    net_contract_land_deposits_per_total_controlled_lot = contract_land_deposits_net_millions * 1000000 / total_controlled_lots,
    hand_code_quality_tier = case_when(
      fiscal_year <= 2009 ~ "early_prose_overlap_review",
      components_reconcile_to_reported_total ~ "component_identity_or_rounding_pass",
      is.na(component_sum_lots) ~ "incomplete_component_sum",
      TRUE ~ "component_identity_review"
    ),
    panel_use_flag = fiscal_year >= 2010 & components_reconcile_to_reported_total,
    panel_use_note = case_when(
      fiscal_year <= 2009 ~ "Use for disclosure history only unless early JV overlap is resolved.",
      panel_use_flag ~ "Usable for NVR LPA-plus-JV land-light share.",
      TRUE ~ "Review component identity before use."
    )
  ) |>
  arrange(fiscal_year)

if (any(!panel$source_file_exists)) {
  missing_years <- paste(panel$fiscal_year[!panel$source_file_exists], collapse = ", ")
  stop(paste("Missing source files for NVR fiscal years:", missing_years))
}

audit <- bind_rows(
  panel |>
    transmute(
      fiscal_year,
      audit_check = "source_file_exists",
      status = if_else(source_file_exists, "ok", "fail"),
      value = as.character(source_file_exists),
      detail = source_local_path
    ),
  panel |>
    transmute(
      fiscal_year,
      audit_check = "indexed_in_six_firm_skeleton",
      status = case_when(
        indexed_in_six_firm_skeleton ~ "ok",
        fiscal_year == 2008 ~ "known_gap",
        TRUE ~ "fail"
      ),
      value = as.character(indexed_in_six_firm_skeleton),
      detail = if_else(
        fiscal_year == 2008 & !indexed_in_six_firm_skeleton,
        "2008 SEC filing was recovered from filing directory but is missing from the current filing index.",
        coalesce(skeleton_accession_number, "")
      )
    ),
  panel |>
    transmute(
      fiscal_year,
      audit_check = "component_reconciliation",
      status = case_when(
        fiscal_year <= 2009 ~ "manual_review",
        components_reconcile_to_reported_total ~ "ok",
        TRUE ~ "review"
      ),
      value = as.character(component_sum_minus_total_lots),
      detail = paste0(
        "component_sum=", coalesce(as.character(component_sum_lots), "NA"),
        "; total=", total_controlled_lots,
        "; tolerance=", round(component_rounding_tolerance_lots, 2)
      )
    ),
  panel |>
    transmute(
      fiscal_year,
      audit_check = "manual_review_flag",
      status = if_else(manual_review_flag, "review", "ok"),
      value = as.character(manual_review_flag),
      detail = coalesce(manual_review_reason, "")
    )
) |>
  arrange(fiscal_year, audit_check)

source_notes <- panel |>
  transmute(
    ticker, fiscal_year, accession_number, primary_document,
    source_local_path, source_url, source_note, hand_code_quality_tier,
    panel_use_flag, panel_use_note
  )

write_csv_if_changed(panel, "../output/nvr_2006_2025_manual_land_panel.csv")
write_csv_if_changed(audit, "../output/nvr_2006_2025_manual_land_audit.csv")
write_csv_if_changed(source_notes, "../output/nvr_2006_2025_source_notes.csv")
