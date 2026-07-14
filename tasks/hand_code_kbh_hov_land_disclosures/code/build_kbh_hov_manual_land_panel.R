# setwd("/Users/jacobherbstman/Desktop/homebuilder_10ks/tasks/hand_code_kbh_hov_land_disclosures/code")

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
})

source("../../_lib/homebuilder_pipeline_utils.R")

manual <- read_csv("manual_kbh_hov_land_disclosures.csv", show_col_types = FALSE, na = c("", "NA")) |>
  mutate(
    fiscal_year = as.integer(fiscal_year),
    manual_review_flag = if_else(
      is.na(manual_review_flag),
      NA,
      manual_review_flag %in% c(TRUE, "TRUE", "true", "True", "1", 1)
    )
  )

skeleton <- read_csv("../input/six_firm_2006_2025_skeleton.csv", show_col_types = FALSE, na = c("", "NA")) |>
  filter(ticker %in% c("KBH", "HOV")) |>
  transmute(
    ticker,
    fiscal_year = as.integer(fiscal_year),
    cik10,
    sec_company_name,
    report_date = as.Date(downloaded_report_date),
    filing_date = as.Date(downloaded_filing_date),
    accession_number = downloaded_accession_number,
    accession_number_no_dashes = gsub("-", "", downloaded_accession_number),
    primary_document,
    source_url = filing_url,
    source_local_path = primary_document_local_path,
    primary_document_status,
    annual_10k_downloaded,
    skeleton_disclosure_recovery_status = disclosure_recovery_status,
    skeleton_total_lots = as.numeric(total_lots),
    skeleton_optioned_lots = as.numeric(optioned_lots)
  )

expected_years <- tidyr::expand_grid(
  ticker = c("KBH", "HOV"),
  fiscal_year = 2006:2025
)

missing_manual <- expected_years |>
  anti_join(manual |> select(ticker, fiscal_year), by = c("ticker", "fiscal_year"))

if (nrow(missing_manual) > 0) {
  stop(paste(
    "Manual KBH/HOV disclosure file is missing rows:",
    paste(paste(missing_manual$ticker, missing_manual$fiscal_year, sep = "-"), collapse = ", ")
  ))
}

if (manual |> count(ticker, fiscal_year) |> filter(n > 1) |> nrow() > 0) {
  stop("Manual KBH/HOV disclosure file has duplicate firm-years.")
}

panel <- manual |>
  left_join(skeleton, by = c("ticker", "fiscal_year"), relationship = "one-to-one") |>
  mutate(
    source_file_exists = file.exists(source_local_path),
    component_sum_lots = case_when(
      ticker == "KBH" ~ owned_lots + optioned_lots,
      ticker == "HOV" ~ owned_lots + optioned_lots + coalesce(construction_to_perm_lots, 0),
      TRUE ~ NA_real_
    ),
    component_sum_minus_total_lots = component_sum_lots - total_controlled_lots,
    components_reconcile_to_reported_total = !is.na(component_sum_minus_total_lots) &
      component_sum_minus_total_lots == 0,
    optioned_share_of_total = optioned_lots / total_controlled_lots,
    owned_share_of_total = owned_lots / total_controlled_lots,
    construction_to_perm_share_of_total = construction_to_perm_lots / total_controlled_lots,
    unconsolidated_jv_relative_to_consolidated_total =
      unconsolidated_jv_lots / total_controlled_lots,
    exact_optioned_share_available =
      components_reconcile_to_reported_total &
      !is.na(optioned_share_of_total) &
      optioned_share_of_total >= 0 &
      optioned_share_of_total <= 1,
    comparable_share_definition = case_when(
      ticker == "KBH" ~ "land_under_option / total_land_owned_or_under_option",
      ticker == "HOV" ~ "optioned_home_sites / consolidated_total_home_sites",
      TRUE ~ NA_character_
    ),
    hand_code_quality_tier = case_when(
      manual_review_flag ~ "manual_review",
      !components_reconcile_to_reported_total ~ "component_identity_review",
      exact_optioned_share_available ~ "component_identity_pass",
      TRUE ~ "review"
    ),
    panel_use_flag = exact_optioned_share_available & !manual_review_flag,
    panel_use_note = case_when(
      ticker == "KBH" ~ "Usable for KBH optioned-lot share with KBH table definition.",
      ticker == "HOV" ~ "Usable for HOV consolidated optioned-home-site share. JV lots are retained separately.",
      TRUE ~ NA_character_
    ),
    skeleton_total_matches_manual_total = case_when(
      ticker == "KBH" & !is.na(skeleton_total_lots) ~ skeleton_total_lots == total_controlled_lots,
      TRUE ~ NA
    ),
    skeleton_optioned_matches_manual_optioned = case_when(
      ticker == "HOV" & !is.na(skeleton_optioned_lots) ~ skeleton_optioned_lots == optioned_lots,
      TRUE ~ NA
    )
  ) |>
  arrange(ticker, fiscal_year)

if (any(!panel$source_file_exists)) {
  missing_sources <- panel |>
    filter(!source_file_exists) |>
    transmute(row_id = paste(ticker, fiscal_year, source_local_path, sep = ":")) |>
    pull(row_id)
  stop(paste("Missing source files for KBH/HOV firm-years:", paste(missing_sources, collapse = ", ")))
}

audit <- bind_rows(
  panel |>
    transmute(
      ticker,
      fiscal_year,
      audit_check = "source_file_exists",
      status = if_else(source_file_exists, "ok", "fail"),
      value = as.character(source_file_exists),
      detail = source_local_path
    ),
  panel |>
    transmute(
      ticker,
      fiscal_year,
      audit_check = "component_reconciliation",
      status = if_else(components_reconcile_to_reported_total, "ok", "fail"),
      value = as.character(component_sum_minus_total_lots),
      detail = paste0(
        "component_sum=", component_sum_lots,
        "; total=", total_controlled_lots
      )
    ),
  panel |>
    transmute(
      ticker,
      fiscal_year,
      audit_check = "optioned_share_range",
      status = if_else(
        !is.na(optioned_share_of_total) &
          optioned_share_of_total >= 0 &
          optioned_share_of_total <= 1,
        "ok",
        "fail"
      ),
      value = as.character(optioned_share_of_total),
      detail = comparable_share_definition
    ),
  panel |>
    transmute(
      ticker,
      fiscal_year,
      audit_check = "skeleton_total_match",
      status = case_when(
        is.na(skeleton_total_matches_manual_total) ~ "not_applicable",
        skeleton_total_matches_manual_total ~ "ok",
        TRUE ~ "review"
      ),
      value = as.character(skeleton_total_matches_manual_total),
      detail = paste0("skeleton_total=", coalesce(as.character(skeleton_total_lots), "NA"))
    ),
  panel |>
    transmute(
      ticker,
      fiscal_year,
      audit_check = "skeleton_optioned_match",
      status = case_when(
        is.na(skeleton_optioned_matches_manual_optioned) ~ "not_applicable",
        skeleton_optioned_matches_manual_optioned ~ "ok",
        TRUE ~ "expected_difference"
      ),
      value = as.character(skeleton_optioned_matches_manual_optioned),
      detail = paste0(
        "skeleton_optioned=", coalesce(as.character(skeleton_optioned_lots), "NA"),
        "; manual_optioned=", optioned_lots
      )
    ),
  panel |>
    transmute(
      ticker,
      fiscal_year,
      audit_check = "manual_review_flag",
      status = if_else(manual_review_flag, "review", "ok"),
      value = as.character(manual_review_flag),
      detail = coalesce(manual_review_reason, "")
    )
) |>
  arrange(ticker, fiscal_year, audit_check)

source_notes <- panel |>
  transmute(
    ticker,
    fiscal_year,
    accession_number,
    primary_document,
    source_local_path,
    source_url,
    unit_type,
    disclosure_basis,
    source_table_index,
    source_row_label,
    source_note,
    hand_code_quality_tier,
    panel_use_flag,
    panel_use_note
  )

write_csv_if_changed(panel, "../output/kbh_hov_2006_2025_manual_land_panel.csv")
write_csv_if_changed(audit, "../output/kbh_hov_2006_2025_manual_land_audit.csv")
write_csv_if_changed(source_notes, "../output/kbh_hov_2006_2025_source_notes.csv")
