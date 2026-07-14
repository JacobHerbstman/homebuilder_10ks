# setwd("/Users/jacobherbstman/Desktop/homebuilder_10ks/tasks/hand_code_dhi_len_phm_land_disclosures/code")

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
})

source("../../_lib/homebuilder_pipeline_utils.R")

manual <- read_csv("manual_dhi_len_phm_land_disclosures.csv", show_col_types = FALSE, na = c("", "NA")) |>
  mutate(
    fiscal_year = as.integer(fiscal_year),
    approximate_flag = if_else(
      is.na(approximate_flag),
      NA,
      approximate_flag %in% c(TRUE, "TRUE", "true", "True", "1", 1)
    ),
    manual_review_flag = if_else(
      is.na(manual_review_flag),
      NA,
      manual_review_flag %in% c(TRUE, "TRUE", "true", "True", "1", 1)
    )
  )

skeleton <- read_csv("../input/six_firm_2006_2025_skeleton.csv", show_col_types = FALSE, na = c("", "NA")) |>
  filter(ticker %in% c("DHI", "LEN", "PHM")) |>
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
    skeleton_disclosure_recovery_status = disclosure_recovery_status
  )

expected_years <- tidyr::expand_grid(
  ticker = c("DHI", "LEN", "PHM"),
  fiscal_year = 2006:2025
)

missing_manual <- expected_years |>
  anti_join(manual |> select(ticker, fiscal_year), by = c("ticker", "fiscal_year"))

if (nrow(missing_manual) > 0) {
  stop(paste(
    "Manual DHI/LEN/PHM disclosure file is missing rows:",
    paste(paste(missing_manual$ticker, missing_manual$fiscal_year, sep = "-"), collapse = ", ")
  ))
}

if (manual |> count(ticker, fiscal_year) |> filter(n > 1) |> nrow() > 0) {
  stop("Manual DHI/LEN/PHM disclosure file has duplicate firm-years.")
}

panel <- manual |>
  left_join(skeleton, by = c("ticker", "fiscal_year"), relationship = "one-to-one") |>
  mutate(
    source_file_exists = file.exists(source_local_path),
    component_sum_physical_count = owned_physical_count + nonowned_controlled_physical_count,
    component_sum_minus_total = component_sum_physical_count - total_physical_count,
    component_rounding_tolerance = if_else(approximate_flag, 100, 0),
    components_reconcile_to_reported_total =
      !is.na(component_sum_minus_total) &
        abs(component_sum_minus_total) <= component_rounding_tolerance,
    split_sum_nonowned = optioned_physical_count + coalesce(jv_physical_count, 0),
    split_sum_minus_nonowned = split_sum_nonowned - nonowned_controlled_physical_count,
    split_reconciles_to_nonowned = case_when(
      is.na(optioned_physical_count) ~ NA,
      !is.na(jv_physical_count) ~ split_sum_minus_nonowned == 0,
      TRUE ~ optioned_physical_count == nonowned_controlled_physical_count
    ),
    nonowned_controlled_share = nonowned_controlled_physical_count / total_physical_count,
    optioned_share = optioned_physical_count / total_physical_count,
    owned_share = owned_physical_count / total_physical_count,
    comparable_share_definition = case_when(
      ticker == "DHI" ~ "lots_controlled_under_land_lot_contracts / total_land_lots_owned_and_controlled",
      ticker == "LEN" ~ "controlled_homesites / total_homesites",
      ticker == "PHM" ~ "optioned_lots / controlled_lots",
      TRUE ~ NA_character_
    ),
    exact_nonowned_share_available =
      components_reconcile_to_reported_total &
      !is.na(nonowned_controlled_share) &
      nonowned_controlled_share >= 0 &
      nonowned_controlled_share <= 1,
    optioned_jv_split_available = !is.na(optioned_physical_count) & !is.na(jv_physical_count),
    hand_code_quality_tier = case_when(
      manual_review_flag ~ "manual_review",
      !components_reconcile_to_reported_total ~ "component_identity_review",
      approximate_flag ~ "rounded_component_identity_pass",
      exact_nonowned_share_available ~ "component_identity_pass",
      TRUE ~ "review"
    ),
    panel_use_flag = exact_nonowned_share_available & !manual_review_flag,
    panel_use_note = case_when(
      ticker == "DHI" ~ "Usable for DHI non-owned controlled-lot share.",
      ticker == "LEN" & optioned_jv_split_available ~ "Usable for Lennar controlled-homesite share with optioned/JV split.",
      ticker == "LEN" ~ "Usable for Lennar controlled-homesite share; optioned/JV split not disclosed.",
      ticker == "PHM" ~ "Usable for Pulte optioned-lot share.",
      TRUE ~ NA_character_
    )
  ) |>
  arrange(ticker, fiscal_year)

if (any(!panel$source_file_exists)) {
  missing_sources <- panel |>
    filter(!source_file_exists) |>
    transmute(row_id = paste(ticker, fiscal_year, source_local_path, sep = ":")) |>
    pull(row_id)
  stop(paste("Missing source files for DHI/LEN/PHM firm-years:", paste(missing_sources, collapse = ", ")))
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
      value = as.character(component_sum_minus_total),
      detail = paste0(
        "component_sum=", component_sum_physical_count,
        "; total=", total_physical_count,
        "; tolerance=", component_rounding_tolerance
      )
    ),
  panel |>
    transmute(
      ticker,
      fiscal_year,
      audit_check = "nonowned_share_range",
      status = if_else(
        !is.na(nonowned_controlled_share) &
          nonowned_controlled_share >= 0 &
          nonowned_controlled_share <= 1,
        "ok",
        "fail"
      ),
      value = as.character(nonowned_controlled_share),
      detail = comparable_share_definition
    ),
  panel |>
    transmute(
      ticker,
      fiscal_year,
      audit_check = "optioned_jv_split_reconciliation",
      status = case_when(
        is.na(split_reconciles_to_nonowned) ~ "not_applicable",
        split_reconciles_to_nonowned ~ "ok",
        TRUE ~ "fail"
      ),
      value = as.character(split_sum_minus_nonowned),
      detail = paste0(
        "optioned=", coalesce(as.character(optioned_physical_count), "NA"),
        "; jv=", coalesce(as.character(jv_physical_count), "NA"),
        "; nonowned=", nonowned_controlled_physical_count
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
    source_note,
    approximate_flag,
    hand_code_quality_tier,
    panel_use_flag,
    panel_use_note
  )

write_csv_if_changed(panel, "../output/dhi_len_phm_2006_2025_manual_land_panel.csv")
write_csv_if_changed(audit, "../output/dhi_len_phm_2006_2025_manual_land_audit.csv")
write_csv_if_changed(source_notes, "../output/dhi_len_phm_2006_2025_source_notes.csv")
