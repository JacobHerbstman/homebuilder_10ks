# setwd("/Users/jacobherbstman/Desktop/homebuilder_10ks/tasks/build_expanded_builder_land_panel/code")

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(tibble)
  library(tidyr)
})

source("../../_lib/homebuilder_pipeline_utils.R")

builder_universe <- read_csv("../input/builder_universe_sec_crosswalk.csv", show_col_types = FALSE, na = c("", "NA")) |>
  mutate(
    tier = as.integer(tier),
    builder_panel_eligible = builder_panel_eligible %in% c(TRUE, "TRUE", "true", "True", "1", 1),
    selected_for_sec_download = selected_for_sec_download %in% c(TRUE, "TRUE", "true", "True", "1", 1),
    public_parent_no_comparable_us_10k = public_parent_no_comparable_us_10k %in% c(TRUE, "TRUE", "true", "True", "1", 1),
    candidate_cik10 = as.character(candidate_cik10),
    valid_from_year = as.integer(valid_from_year),
    valid_to_year = as.integer(valid_to_year)
  ) |>
  filter(builder_panel_eligible, selected_for_sec_download) |>
  select(
    universe_episode_id, universe_firm_id, company, ticker, tier, status,
    candidate_cik10, candidate_sec_company_name, filing_window, fye_month,
    fye_month_number, valid_from_year, valid_to_year,
    fiscal_year_warning, merger_splice_flag,
    recent_ipo_flag, low_omega_anchor_flag, high_omega_prior_flag,
    fate_and_splicing_notes, omega_prior_and_relevance, universe_review_status
  )

if (nrow(builder_universe) != n_distinct(builder_universe$universe_episode_id)) {
  stop("builder_universe_sec_crosswalk.csv must be unique by universe_episode_id for selected builder rows.")
}

generic_land <- read_csv("../input/land_light_firm_year_measures.csv", show_col_types = FALSE, na = c("", "NA")) |>
  mutate(
    cik10 = as.character(cik10),
    fiscal_year = as.integer(fiscal_year),
    eligible_nonowned_share = eligible_nonowned_share %in% c(TRUE, "TRUE", "true", "True", "1", 1),
    analysis_ready_with_review = analysis_ready_with_review %in% c(TRUE, "TRUE", "true", "True", "1", 1),
    analysis_ready_explicit_identity = analysis_ready_explicit_identity %in% c(TRUE, "TRUE", "true", "True", "1", 1),
    main_plot_eligible = main_plot_eligible %in% c(TRUE, "TRUE", "true", "True", "1", 1),
    robustness_plot_eligible = robustness_plot_eligible %in% c(TRUE, "TRUE", "true", "True", "1", 1),
    manual_review_flag = manual_review_flag %in% c(TRUE, "TRUE", "true", "True", "1", 1),
    provenance_review_flag = provenance_review_flag %in% c(TRUE, "TRUE", "true", "True", "1", 1)
  ) |>
  filter(fiscal_year >= 2004, fiscal_year <= 2025) |>
  select(
    cik10, fiscal_year, generic_ticker = ticker, accession_number, form,
    filing_date, report_date, primary_document, filing_url,
    primary_document_local_path, generic_sec_company_name = sec_company_name,
    generic_owned_physical_count = owned_physical_count,
    generic_nonowned_physical_count = nonowned_physical_count,
    generic_total_physical_count = total_controlled_physical_count,
    generic_physical_unit_type = physical_unit_type,
    generic_nonowned_controlled_share = nonowned_controlled_share,
    generic_harmonization_rule = harmonization_rule,
    generic_share_comparability_tier = share_comparability_tier,
    generic_eligible_nonowned_share = eligible_nonowned_share,
    generic_analysis_ready_with_review = analysis_ready_with_review,
    generic_analysis_ready_explicit_identity = analysis_ready_explicit_identity,
    generic_main_plot_eligible = main_plot_eligible,
    generic_robustness_plot_eligible = robustness_plot_eligible,
    generic_manual_review_flag = manual_review_flag,
    generic_manual_review_reason = manual_review_reason,
    generic_provenance_review_flag = provenance_review_flag,
    generic_provenance_review_reason = provenance_review_reason,
    generic_not_eligible_reason = not_eligible_reason,
    generic_financial_deposit_balance = financial_deposit_balance,
    generic_financial_purchase_obligation_balance = financial_purchase_obligation_balance,
    generic_financial_deposit_rate = financial_deposit_rate,
    public_builder_closings_weight
  )

if (generic_land |>
    count(cik10, fiscal_year) |>
    filter(n > 1) |>
    nrow() > 0) {
  stop("land_light_firm_year_measures.csv must be unique by cik10/fiscal_year.")
}

six_firm_manual <- read_csv("../input/six_firm_2006_2025_manual_land_panel.csv", show_col_types = FALSE, na = c("", "NA")) |>
  mutate(
    fiscal_year = as.integer(fiscal_year),
    panel_use_flag = panel_use_flag %in% c(TRUE, "TRUE", "true", "True", "1", 1),
    manual_review_flag = manual_review_flag %in% c(TRUE, "TRUE", "true", "True", "1", 1),
    approximate_flag = approximate_flag %in% c(TRUE, "TRUE", "true", "True", "1", 1),
    exact_component_identity = exact_component_identity %in% c(TRUE, "TRUE", "true", "True", "1", 1),
    source_file_exists = source_file_exists %in% c(TRUE, "TRUE", "true", "True", "1", 1)
  ) |>
  filter(!(ticker == "NVR" & fiscal_year <= 2009L)) |>
  transmute(
    ticker, fiscal_year,
    firm_specific_land_source = "hand_read_six_firm",
    manual_unit_type = unit_type,
    manual_measure_definition = measure_definition,
    manual_owned_physical_count = owned_physical_count,
    manual_nonowned_physical_count = nonowned_controlled_physical_count,
    manual_optioned_physical_count = optioned_physical_count,
    manual_jv_physical_count = jv_physical_count,
    manual_total_physical_count = total_physical_count,
    manual_nonowned_controlled_share = nonowned_controlled_share,
    manual_optioned_share = optioned_share,
    manual_owned_share = owned_share,
    manual_conservative_lpa_only_share = conservative_lpa_only_share,
    manual_exact_component_identity = exact_component_identity,
    manual_approximate_flag = approximate_flag,
    manual_review_flag,
    manual_review_reason,
    manual_hand_code_quality_tier = hand_code_quality_tier,
    manual_panel_use_flag = panel_use_flag,
    manual_panel_use_note = panel_use_note,
    manual_disclosure_basis = disclosure_basis,
    manual_source_table_index = as.character(source_table_index),
    manual_source_row_label = source_row_label,
    manual_source_task = source_task,
    manual_source_note = source_note,
    manual_cik10 = cik10,
    manual_sec_company_name = sec_company_name,
    manual_report_date = report_date,
    manual_filing_date = filing_date,
    manual_accession_number = accession_number,
    manual_primary_document = primary_document,
    manual_source_url = source_url,
    manual_source_local_path = source_local_path,
    manual_source_file_exists = source_file_exists
  )

toll_manual <- read_csv("../input/tol_2004_2025_land_panel.csv", show_col_types = FALSE, na = c("", "NA")) |>
  mutate(
    fiscal_year = as.integer(fiscal_year),
    panel_use_flag = panel_use_flag %in% c(TRUE, "TRUE", "true", "True", "1", 1),
    manual_review_flag = manual_review_flag %in% c(TRUE, "TRUE", "true", "True", "1", 1),
    component_identity_pass = component_identity_pass %in% c(TRUE, "TRUE", "true", "True", "1", 1)
  ) |>
  transmute(
    ticker, fiscal_year,
    firm_specific_land_source = "firm_specific_toll_extractor",
    manual_unit_type = unit_type,
    manual_measure_definition = "Toll company-wide controlled home sites / total home sites owned or controlled through options",
    manual_owned_physical_count = owned_homesites,
    manual_nonowned_physical_count = nonowned_controlled_homesites,
    manual_optioned_physical_count = nonowned_controlled_homesites,
    manual_jv_physical_count = NA_real_,
    manual_total_physical_count = total_homesites,
    manual_nonowned_controlled_share = nonowned_controlled_share,
    manual_optioned_share = nonowned_controlled_share,
    manual_owned_share = owned_share,
    manual_conservative_lpa_only_share = NA_real_,
    manual_exact_component_identity = component_identity_pass,
    manual_approximate_flag = precision %in% c("rounded_prose", "rounded_residual"),
    manual_review_flag,
    manual_review_reason,
    manual_hand_code_quality_tier = if_else(manual_review_flag, "review_residual", "programmatic_firm_rule"),
    manual_panel_use_flag = panel_use_flag,
    manual_panel_use_note = "",
    manual_disclosure_basis = extraction_method,
    manual_source_table_index = as.character(source_table_index),
    manual_source_row_label = source_row_label,
    manual_source_task = "extract_tol_land_disclosures",
    manual_source_note = source_note,
    manual_cik10 = cik10,
    manual_sec_company_name = sec_company_name,
    manual_report_date = report_date,
    manual_filing_date = filing_date,
    manual_accession_number = accession_number,
    manual_primary_document = primary_document,
    manual_source_url = source_url,
    manual_source_local_path = source_local_path,
    manual_source_file_exists = TRUE
  )

mho_manual <- read_csv("../input/mho_2004_2025_land_panel.csv", show_col_types = FALSE, na = c("", "NA")) |>
  mutate(
    fiscal_year = as.integer(fiscal_year),
    panel_use_flag = panel_use_flag %in% c(TRUE, "TRUE", "true", "True", "1", 1),
    manual_review_flag = manual_review_flag %in% c(TRUE, "TRUE", "true", "True", "1", 1),
    component_identity_pass = component_identity_pass %in% c(TRUE, "TRUE", "true", "True", "1", 1)
  ) |>
  transmute(
    ticker, fiscal_year,
    firm_specific_land_source = "firm_specific_mho_extractor",
    manual_unit_type = unit_type,
    manual_measure_definition = "M/I Homes lots under contract divided by total lots in recurring Lots Owned table",
    manual_owned_physical_count = owned_lots,
    manual_nonowned_physical_count = nonowned_controlled_lots,
    manual_optioned_physical_count = NA_real_,
    manual_jv_physical_count = NA_real_,
    manual_total_physical_count = total_lots,
    manual_nonowned_controlled_share = nonowned_controlled_share,
    manual_optioned_share = NA_real_,
    manual_owned_share = owned_share,
    manual_conservative_lpa_only_share = NA_real_,
    manual_exact_component_identity = component_identity_pass,
    manual_approximate_flag = FALSE,
    manual_review_flag,
    manual_review_reason,
    manual_hand_code_quality_tier = if_else(manual_review_flag, "review_missing_table", "programmatic_firm_rule"),
    manual_panel_use_flag = panel_use_flag,
    manual_panel_use_note = "Lots Under Contract is a nonowned land-control measure and is not labeled as optioned lots.",
    manual_disclosure_basis = extraction_method,
    manual_source_table_index = as.character(source_table_index),
    manual_source_row_label = source_row_label,
    manual_source_task = "extract_mho_land_disclosures",
    manual_source_note = source_note,
    manual_cik10 = cik10,
    manual_sec_company_name = sec_company_name,
    manual_report_date = report_date,
    manual_filing_date = filing_date,
    manual_accession_number = accession_number,
    manual_primary_document = primary_document,
    manual_source_url = source_url,
    manual_source_local_path = source_local_path,
    manual_source_file_exists = TRUE
  )

mdc_manual <- read_csv("../input/mdc_2004_2025_land_panel.csv", show_col_types = FALSE, na = c("", "NA")) |>
  mutate(
    fiscal_year = as.integer(fiscal_year),
    panel_use_flag = panel_use_flag %in% c(TRUE, "TRUE", "true", "True", "1", 1),
    manual_review_flag = manual_review_flag %in% c(TRUE, "TRUE", "true", "True", "1", 1),
    component_identity_pass = component_identity_pass %in% c(TRUE, "TRUE", "true", "True", "1", 1)
  ) |>
  transmute(
    ticker, fiscal_year,
    firm_specific_land_source = "firm_specific_mdc_extractor",
    manual_unit_type = unit_type,
    manual_measure_definition = "MDC optioned lots divided by total owned and optioned/controlled lots",
    manual_owned_physical_count = owned_lots,
    manual_nonowned_physical_count = nonowned_controlled_lots,
    manual_optioned_physical_count = optioned_lots,
    manual_jv_physical_count = NA_real_,
    manual_total_physical_count = total_lots,
    manual_nonowned_controlled_share = nonowned_controlled_share,
    manual_optioned_share = nonowned_controlled_share,
    manual_owned_share = owned_share,
    manual_conservative_lpa_only_share = NA_real_,
    manual_exact_component_identity = component_identity_pass,
    manual_approximate_flag = FALSE,
    manual_review_flag,
    manual_review_reason,
    manual_hand_code_quality_tier = if_else(manual_review_flag, "review_missing_table", "programmatic_firm_rule"),
    manual_panel_use_flag = panel_use_flag,
    manual_panel_use_note = "MDC option terminology is internally comparable; exact cross-firm contract terms remain comparability-limited.",
    manual_disclosure_basis = extraction_method,
    manual_source_table_index = as.character(source_table_index),
    manual_source_row_label = source_row_label,
    manual_source_task = "extract_mdc_land_disclosures",
    manual_source_note = source_note,
    manual_cik10 = cik10,
    manual_sec_company_name = sec_company_name,
    manual_report_date = report_date,
    manual_filing_date = filing_date,
    manual_accession_number = accession_number,
    manual_primary_document = primary_document,
    manual_source_url = source_url,
    manual_source_local_path = source_local_path,
    manual_source_file_exists = TRUE
  )

grbk_manual <- read_csv("../input/grbk_2014_2025_land_panel.csv", show_col_types = FALSE, na = c("", "NA")) |>
  mutate(
    fiscal_year = as.integer(fiscal_year),
    panel_use_flag = panel_use_flag %in% c(TRUE, "TRUE", "true", "True", "1", 1),
    manual_review_flag = manual_review_flag %in% c(TRUE, "TRUE", "true", "True", "1", 1),
    component_identity_pass = component_identity_pass %in% c(TRUE, "TRUE", "true", "True", "1", 1)
  ) |>
  transmute(
    ticker, fiscal_year,
    firm_specific_land_source = "firm_specific_grbk_extractor",
    manual_unit_type = unit_type,
    manual_measure_definition = "Green Brick controlled/under-contract lots divided by total lots owned and controlled/under contract",
    manual_owned_physical_count = owned_lots,
    manual_nonowned_physical_count = nonowned_controlled_lots,
    manual_optioned_physical_count = NA_real_,
    manual_jv_physical_count = NA_real_,
    manual_total_physical_count = total_lots,
    manual_nonowned_controlled_share = nonowned_controlled_share,
    manual_optioned_share = NA_real_,
    manual_owned_share = owned_share,
    manual_conservative_lpa_only_share = NA_real_,
    manual_exact_component_identity = component_identity_pass,
    manual_approximate_flag = FALSE,
    manual_review_flag,
    manual_review_reason,
    manual_hand_code_quality_tier = if_else(manual_review_flag, "review_missing_table", "programmatic_firm_rule"),
    manual_panel_use_flag = panel_use_flag,
    manual_panel_use_note = if_else(
      fiscal_year == 2025,
      "2025 includes Green Brick's updated-definition controlled-lot adjustment; use definition-change flag in robustness checks.",
      "Uses Green Brick explicit company-wide controlled/under-contract lot total rows."
    ),
    manual_disclosure_basis = extraction_method,
    manual_source_table_index = as.character(source_table_index),
    manual_source_row_label = source_row_label,
    manual_source_task = "extract_grbk_land_disclosures",
    manual_source_note = source_note,
    manual_cik10 = cik10,
    manual_sec_company_name = sec_company_name,
    manual_report_date = report_date,
    manual_filing_date = filing_date,
    manual_accession_number = accession_number,
    manual_primary_document = primary_document,
    manual_source_url = source_url,
    manual_source_local_path = source_local_path,
    manual_source_file_exists = TRUE
  )

mth_manual <- read_csv("../input/mth_2004_2025_land_panel.csv", show_col_types = FALSE, na = c("", "NA")) |>
  mutate(
    fiscal_year = as.integer(fiscal_year),
    panel_use_flag = panel_use_flag %in% c(TRUE, "TRUE", "true", "True", "1", 1),
    manual_review_flag = manual_review_flag %in% c(TRUE, "TRUE", "true", "True", "1", 1),
    component_identity_pass = component_identity_pass %in% c(TRUE, "TRUE", "true", "True", "1", 1)
  ) |>
  transmute(
    ticker, fiscal_year,
    firm_specific_land_source = "firm_specific_mth_extractor",
    manual_unit_type = unit_type,
    manual_measure_definition = "Meritage lots under contract or committed purchase/option contracts divided by total lots under control",
    manual_owned_physical_count = owned_lots,
    manual_nonowned_physical_count = nonowned_controlled_lots,
    manual_optioned_physical_count = NA_real_,
    manual_jv_physical_count = NA_real_,
    manual_total_physical_count = total_lots,
    manual_nonowned_controlled_share = nonowned_controlled_share,
    manual_optioned_share = NA_real_,
    manual_owned_share = owned_share,
    manual_conservative_lpa_only_share = NA_real_,
    manual_exact_component_identity = component_identity_pass,
    manual_approximate_flag = FALSE,
    manual_review_flag,
    manual_review_reason,
    manual_hand_code_quality_tier = if_else(manual_review_flag, "review_missing_table", "programmatic_firm_rule"),
    manual_panel_use_flag = panel_use_flag,
    manual_panel_use_note = "For 2018 onward, uncommitted refundable lots from Note 3 are excluded from omega and retained in the Meritage task as a broader contract-pipeline check.",
    manual_disclosure_basis = extraction_method,
    manual_source_table_index = as.character(source_table_index),
    manual_source_row_label = source_row_label,
    manual_source_task = "extract_mth_land_disclosures",
    manual_source_note = source_note,
    manual_cik10 = cik10,
    manual_sec_company_name = sec_company_name,
    manual_report_date = report_date,
    manual_filing_date = filing_date,
    manual_accession_number = accession_number,
    manual_primary_document = primary_document,
    manual_source_url = source_url,
    manual_source_local_path = source_local_path,
    manual_source_file_exists = TRUE
  )

tmhc_manual <- read_csv("../input/tmhc_2013_2025_land_panel.csv", show_col_types = FALSE, na = c("", "NA")) |>
  mutate(
    fiscal_year = as.integer(fiscal_year),
    panel_use_flag = panel_use_flag %in% c(TRUE, "TRUE", "true", "True", "1", 1),
    manual_review_flag = manual_review_flag %in% c(TRUE, "TRUE", "true", "True", "1", 1),
    component_identity_pass = component_identity_pass %in% c(TRUE, "TRUE", "true", "True", "1", 1)
  ) |>
  transmute(
    ticker, fiscal_year,
    firm_specific_land_source = "firm_specific_tmhc_extractor",
    manual_unit_type = unit_type,
    manual_measure_definition = "Taylor Morrison controlled lots divided by total owned and controlled lots",
    manual_owned_physical_count = owned_lots,
    manual_nonowned_physical_count = nonowned_controlled_lots,
    manual_optioned_physical_count = NA_real_,
    manual_jv_physical_count = NA_real_,
    manual_total_physical_count = total_lots,
    manual_nonowned_controlled_share = nonowned_controlled_share,
    manual_optioned_share = NA_real_,
    manual_owned_share = owned_share,
    manual_conservative_lpa_only_share = NA_real_,
    manual_exact_component_identity = component_identity_pass,
    manual_approximate_flag = FALSE,
    manual_review_flag,
    manual_review_reason,
    manual_hand_code_quality_tier = if_else(manual_review_flag, "review_missing_table", "programmatic_firm_rule"),
    manual_panel_use_flag = panel_use_flag,
    manual_panel_use_note = case_when(
      fiscal_year == 2013L ~ "Issuer-level total includes Canada and proportionate unconsolidated JV lots; U.S. subtotal is retained in the Taylor Morrison task output.",
      fiscal_year == 2022L ~ "Main series uses the 2023 restated 2022 comparative owned/controlled-lot definition; originally filed 2022 values are retained in the Taylor Morrison task output.",
      TRUE ~ ""
    ),
    manual_disclosure_basis = extraction_method,
    manual_source_table_index = as.character(source_table_index),
    manual_source_row_label = source_row_label,
    manual_source_task = "extract_tmhc_land_disclosures",
    manual_source_note = source_note,
    manual_cik10 = cik10,
    manual_sec_company_name = sec_company_name,
    manual_report_date = report_date,
    manual_filing_date = filing_date,
    manual_accession_number = source_accession_number,
    manual_primary_document = primary_document,
    manual_source_url = source_url,
    manual_source_local_path = source_local_path,
    manual_source_file_exists = TRUE
  )

tph_manual <- read_csv("../input/tph_2012_2025_land_panel.csv", show_col_types = FALSE, na = c("", "NA")) |>
  mutate(
    fiscal_year = as.integer(fiscal_year),
    panel_use_flag = panel_use_flag %in% c(TRUE, "TRUE", "true", "True", "1", 1),
    manual_review_flag = manual_review_flag %in% c(TRUE, "TRUE", "true", "True", "1", 1),
    component_identity_pass = component_identity_pass %in% c(TRUE, "TRUE", "true", "True", "1", 1)
  ) |>
  transmute(
    ticker, fiscal_year,
    firm_specific_land_source = "firm_specific_tph_extractor",
    manual_unit_type = unit_type,
    manual_measure_definition = "Tri Pointe controlled lots divided by total lots owned or controlled",
    manual_owned_physical_count = owned_lots,
    manual_nonowned_physical_count = nonowned_controlled_lots,
    manual_optioned_physical_count = NA_real_,
    manual_jv_physical_count = NA_real_,
    manual_total_physical_count = total_lots,
    manual_nonowned_controlled_share = nonowned_controlled_share,
    manual_optioned_share = NA_real_,
    manual_owned_share = owned_share,
    manual_conservative_lpa_only_share = NA_real_,
    manual_exact_component_identity = component_identity_pass,
    manual_approximate_flag = FALSE,
    manual_review_flag,
    manual_review_reason,
    manual_hand_code_quality_tier = if_else(manual_review_flag, "review_missing_table", "programmatic_firm_rule"),
    manual_panel_use_flag = panel_use_flag,
    manual_panel_use_note = case_when(
      fiscal_year == 2012L ~ "Tri Pointe 2012 controlled lots include land option contracts, purchase contracts, and non-binding letters of intent.",
      fiscal_year == 2019L ~ "Tri Pointe 2019 controlled lots include 135 Trendmaker expected-share lots from an unconsolidated land development joint venture.",
      TRUE ~ "Tri Pointe controlled lots are coded as nonowned controlled lots, not as pure optioned lots."
    ),
    manual_disclosure_basis = extraction_method,
    manual_source_table_index = as.character(source_table_index),
    manual_source_row_label = source_row_label,
    manual_source_task = "extract_tph_land_disclosures",
    manual_source_note = source_note,
    manual_cik10 = cik10,
    manual_sec_company_name = sec_company_name,
    manual_report_date = report_date,
    manual_filing_date = filing_date,
    manual_accession_number = accession_number,
    manual_primary_document = primary_document,
    manual_source_url = source_url,
    manual_source_local_path = source_local_path,
    manual_source_file_exists = TRUE
  )

nvr_early_manual <- read_csv("../input/nvr_2004_2009_early_land_panel.csv", show_col_types = FALSE, na = c("", "NA")) |>
  mutate(
    fiscal_year = as.integer(fiscal_year),
    panel_use_flag = panel_use_flag %in% c(TRUE, "TRUE", "true", "True", "1", 1),
    manual_review_flag = manual_review_flag %in% c(TRUE, "TRUE", "true", "True", "1", 1),
    component_identity_pass = component_identity_pass %in% c(TRUE, "TRUE", "true", "True", "1", 1)
  ) |>
  transmute(
    ticker, fiscal_year,
    firm_specific_land_source = "firm_specific_nvr_early_extractor",
    manual_unit_type = unit_type,
    manual_measure_definition = "NVR early prose all-controlled land pipeline",
    manual_owned_physical_count = owned_lots,
    manual_nonowned_physical_count = nonowned_controlled_lots,
    manual_optioned_physical_count = NA_real_,
    manual_jv_physical_count = jv_controlled_lots,
    manual_total_physical_count = total_lots,
    manual_nonowned_controlled_share = nonowned_controlled_share,
    manual_optioned_share = NA_real_,
    manual_owned_share = owned_share,
    manual_conservative_lpa_only_share = 1,
    manual_exact_component_identity = component_identity_pass,
    manual_approximate_flag = TRUE,
    manual_review_flag,
    manual_review_reason,
    manual_hand_code_quality_tier = "early_prose_controlled_pipeline",
    manual_panel_use_flag = panel_use_flag,
    manual_panel_use_note = "NVR 2004-2009 uses prose-era controlled-lot disclosures. The row is usable for NVR's all-controlled land pipeline but should be flagged in strict table-comparability checks.",
    manual_disclosure_basis = extraction_method,
    manual_source_table_index = NA_character_,
    manual_source_row_label = "prose",
    manual_source_task = "extract_nvr_early_land_disclosures",
    manual_source_note = source_note,
    manual_cik10 = cik10,
    manual_sec_company_name = sec_company_name,
    manual_report_date = report_date,
    manual_filing_date = filing_date,
    manual_accession_number = accession_number,
    manual_primary_document = primary_document,
    manual_source_url = source_url,
    manual_source_local_path = source_local_path,
    manual_source_file_exists = TRUE
  )

lsea_manual <- read_csv("../input/lsea_2020_2024_land_panel.csv", show_col_types = FALSE, na = c("", "NA")) |>
  mutate(
    fiscal_year = as.integer(fiscal_year),
    panel_use_flag = panel_use_flag %in% c(TRUE, "TRUE", "true", "True", "1", 1),
    manual_review_flag = manual_review_flag %in% c(TRUE, "TRUE", "true", "True", "1", 1),
    component_identity_pass = component_identity_pass %in% c(TRUE, "TRUE", "true", "True", "1", 1),
    uses_later_comparative_prior_year_row = uses_later_comparative_prior_year_row %in% c(TRUE, "TRUE", "true", "True", "1", 1)
  ) |>
  transmute(
    ticker, fiscal_year,
    firm_specific_land_source = "firm_specific_lsea_extractor",
    manual_unit_type = unit_type,
    manual_measure_definition = "Landsea Lots Controlled divided by total Lots Owned plus Lots Controlled",
    manual_owned_physical_count = owned_lots,
    manual_nonowned_physical_count = nonowned_controlled_lots,
    manual_optioned_physical_count = NA_real_,
    manual_jv_physical_count = NA_real_,
    manual_total_physical_count = total_lots,
    manual_nonowned_controlled_share = nonowned_controlled_share,
    manual_optioned_share = NA_real_,
    manual_owned_share = owned_share,
    manual_conservative_lpa_only_share = NA_real_,
    manual_exact_component_identity = component_identity_pass,
    manual_approximate_flag = FALSE,
    manual_review_flag,
    manual_review_reason,
    manual_hand_code_quality_tier = if_else(manual_review_flag, "comparative_prior_year_source", "programmatic_firm_rule"),
    manual_panel_use_flag = panel_use_flag,
    manual_panel_use_note = case_when(
      fiscal_year == 2020L ~ "Uses exact 2021 comparative prior-year row for the 2020 owned/controlled split; the 2020 10-K exact total and approximate prose split are retained in the Landsea task output.",
      TRUE ~ "Lots Controlled is coded as nonowned controlled lots; broader phrases such as lots under control are treated as owned plus controlled."
    ),
    manual_disclosure_basis = extraction_method,
    manual_source_table_index = as.character(source_table_index),
    manual_source_row_label = source_row_label,
    manual_source_task = "extract_lsea_land_disclosures",
    manual_source_note = source_note,
    manual_cik10 = cik10,
    manual_sec_company_name = sec_company_name,
    manual_report_date = report_date,
    manual_filing_date = filing_date,
    manual_accession_number = source_accession_number,
    manual_primary_document = primary_document,
    manual_source_url = source_url,
    manual_source_local_path = source_local_path,
    manual_source_file_exists = TRUE
  )

dfh_manual <- read_csv("../input/dfh_2020_2025_land_panel.csv", show_col_types = FALSE, na = c("", "NA")) |>
  mutate(
    fiscal_year = as.integer(fiscal_year),
    panel_use_flag = panel_use_flag %in% c(TRUE, "TRUE", "true", "True", "1", 1),
    manual_review_flag = manual_review_flag %in% c(TRUE, "TRUE", "true", "True", "1", 1),
    component_identity_pass = component_identity_pass %in% c(TRUE, "TRUE", "true", "True", "1", 1),
    controlled_lots_only = controlled_lots_only %in% c(TRUE, "TRUE", "true", "True", "1", 1),
    denominator_not_disclosed_after_table_schema_change = denominator_not_disclosed_after_table_schema_change %in% c(TRUE, "TRUE", "true", "True", "1", 1)
  ) |>
  transmute(
    ticker, fiscal_year,
    firm_specific_land_source = "firm_specific_dfh_extractor",
    manual_unit_type = unit_type,
    manual_measure_definition = if_else(
      controlled_lots_only,
      "Dream Finders controlled-lot pipeline level; owned-lot denominator not disclosed",
      "Dream Finders controlled lots divided by total owned and controlled lots"
    ),
    manual_owned_physical_count = owned_lots,
    manual_nonowned_physical_count = nonowned_controlled_lots,
    manual_optioned_physical_count = nonowned_controlled_lots,
    manual_jv_physical_count = NA_real_,
    manual_total_physical_count = total_lots,
    manual_nonowned_controlled_share = nonowned_controlled_share,
    manual_optioned_share = nonowned_controlled_share,
    manual_owned_share = owned_share,
    manual_conservative_lpa_only_share = NA_real_,
    manual_exact_component_identity = component_identity_pass,
    manual_approximate_flag = FALSE,
    manual_review_flag,
    manual_review_reason,
    manual_hand_code_quality_tier = if_else(controlled_lots_only, "controlled_pipeline_denominator_missing", "programmatic_firm_rule"),
    manual_panel_use_flag = panel_use_flag,
    manual_panel_use_note = case_when(
      denominator_not_disclosed_after_table_schema_change ~ "DFH 2024-2025 changed to a controlled-lot-pipeline-only table. Controlled lots are retained, but owned lots and omega are missing.",
      TRUE ~ "Uses DFH Owned and Controlled Lots Grand Total row as the current physical owned/control split; broader contract-sourced asset-light percentages are not used as omega."
    ),
    manual_disclosure_basis = extraction_method,
    manual_source_table_index = NA_character_,
    manual_source_row_label = source_row_label,
    manual_source_task = "extract_dfh_land_disclosures",
    manual_source_note = source_note,
    manual_cik10 = cik10,
    manual_sec_company_name = sec_company_name,
    manual_report_date = report_date,
    manual_filing_date = filing_date,
    manual_accession_number = accession_number,
    manual_primary_document = primary_document,
    manual_source_url = source_url,
    manual_source_local_path = source_local_path,
    manual_source_file_exists = TRUE
  )

sdhc_manual <- read_csv("../input/sdhc_2022_2025_land_panel.csv", show_col_types = FALSE, na = c("", "NA")) |>
  mutate(
    fiscal_year = as.integer(fiscal_year),
    panel_use_flag = panel_use_flag %in% c(TRUE, "TRUE", "true", "True", "1", 1),
    main_panel_eligible = main_panel_eligible %in% c(TRUE, "TRUE", "true", "True", "1", 1),
    manual_review_flag = manual_review_flag %in% c(TRUE, "TRUE", "true", "True", "1", 1),
    component_identity_pass = component_identity_pass %in% c(TRUE, "TRUE", "true", "True", "1", 1),
    pre_ipo_operating_builder_observation = pre_ipo_operating_builder_observation %in% c(TRUE, "TRUE", "true", "True", "1", 1)
  ) |>
  transmute(
    ticker, fiscal_year,
    firm_specific_land_source = "firm_specific_sdhc_extractor",
    manual_unit_type = unit_type,
    manual_measure_definition = "Smith Douglas optioned lots divided by total controlled lots",
    manual_owned_physical_count = owned_lots,
    manual_nonowned_physical_count = optioned_lots,
    manual_optioned_physical_count = optioned_lots,
    manual_jv_physical_count = NA_real_,
    manual_total_physical_count = total_controlled_lots,
    manual_nonowned_controlled_share = optioned_share,
    manual_optioned_share = optioned_share,
    manual_owned_share = owned_share,
    manual_conservative_lpa_only_share = NA_real_,
    manual_exact_component_identity = component_identity_pass,
    manual_approximate_flag = FALSE,
    manual_review_flag,
    manual_review_reason,
    manual_hand_code_quality_tier = if_else(pre_ipo_operating_builder_observation, "pre_ipo_operating_history", "programmatic_firm_rule"),
    manual_panel_use_flag = panel_use_flag,
    manual_main_plot_eligible = main_panel_eligible,
    manual_panel_use_note = case_when(
      pre_ipo_operating_builder_observation ~ "Uses SDHC pre-IPO operating history reported in SEC filings; retained as auxiliary history, not a public-company main row.",
      TRUE ~ "Uses SDHC Owned / Optioned / Total Controlled total row; Total Controlled means owned plus optioned for this firm."
    ),
    manual_disclosure_basis = extraction_method,
    manual_source_table_index = as.character(land_source_table_index),
    manual_source_row_label = source_row_label,
    manual_source_task = "extract_sdhc_land_disclosures",
    manual_source_note = source_note,
    manual_cik10 = cik10,
    manual_sec_company_name = sec_company_name,
    manual_report_date = report_date,
    manual_filing_date = filing_date,
    manual_accession_number = source_accession_number,
    manual_primary_document = primary_document,
    manual_source_url = source_url,
    manual_source_local_path = source_local_path,
    manual_source_file_exists = TRUE
  )

uhg_manual <- read_csv("../input/uhg_2022_2025_land_panel.csv", show_col_types = FALSE, na = c("", "NA")) |>
  mutate(
    fiscal_year = as.integer(fiscal_year),
    panel_use_flag = panel_use_flag %in% c(TRUE, "TRUE", "true", "True", "1", 1),
    manual_review_flag = manual_review_flag %in% c(TRUE, "TRUE", "true", "True", "1", 1),
    component_identity_pass = component_identity_pass %in% c(TRUE, "TRUE", "true", "True", "1", 1),
    uses_later_comparative_prior_year_row = uses_later_comparative_prior_year_row %in% c(TRUE, "TRUE", "true", "True", "1", 1),
    pre_public_predecessor_business_disclosure = pre_public_predecessor_business_disclosure %in% c(TRUE, "TRUE", "true", "True", "1", 1)
  ) |>
  transmute(
    ticker, fiscal_year,
    firm_specific_land_source = "firm_specific_uhg_extractor",
    manual_unit_type = unit_type,
    manual_measure_definition = "UHG controlled lots divided by total owned and controlled lots",
    manual_owned_physical_count = owned_lots,
    manual_nonowned_physical_count = nonowned_controlled_lots,
    manual_optioned_physical_count = NA_real_,
    manual_jv_physical_count = NA_real_,
    manual_total_physical_count = total_lots,
    manual_nonowned_controlled_share = nonowned_controlled_share,
    manual_optioned_share = NA_real_,
    manual_owned_share = owned_share,
    manual_conservative_lpa_only_share = NA_real_,
    manual_exact_component_identity = component_identity_pass,
    manual_approximate_flag = FALSE,
    manual_review_flag,
    manual_review_reason,
    manual_hand_code_quality_tier = if_else(
      pre_public_predecessor_business_disclosure,
      "pre_public_predecessor_comparative_row",
      "programmatic_firm_rule"
    ),
    manual_panel_use_flag = panel_use_flag,
    manual_panel_use_note = case_when(
      uses_later_comparative_prior_year_row ~ "Uses UHG 2023 10-K comparative row for Great Southern Homes' December 31, 2022 land position.",
      TRUE ~ "Uses UHG Owned and Controlled Lots Total row; Controlled is non-owned controlled lots, not necessarily pure optioned lots."
    ),
    manual_disclosure_basis = extraction_method,
    manual_source_table_index = as.character(source_table_index),
    manual_source_row_label = source_row_label,
    manual_source_task = "extract_uhg_land_disclosures",
    manual_source_note = source_note,
    manual_cik10 = cik10,
    manual_sec_company_name = sec_company_name,
    manual_report_date = report_date,
    manual_filing_date = filing_date,
    manual_accession_number = source_accession_number,
    manual_primary_document = primary_document,
    manual_source_url = source_url,
    manual_source_local_path = source_local_path,
    manual_source_file_exists = TRUE
  )

tier1_early_manual <- read_csv("../input/tier1_early_2004_2005_land_panel.csv", show_col_types = FALSE, na = c("", "NA")) |>
  mutate(
    fiscal_year = as.integer(fiscal_year),
    panel_use_flag = panel_use_flag %in% c(TRUE, "TRUE", "true", "True", "1", 1),
    manual_review_flag = manual_review_flag %in% c(TRUE, "TRUE", "true", "True", "1", 1),
    component_identity_pass = component_identity_pass %in% c(TRUE, "TRUE", "true", "True", "1", 1),
    approximate_flag = approximate_flag %in% c(TRUE, "TRUE", "true", "True", "1", 1),
    uses_later_comparative_prior_year_row = uses_later_comparative_prior_year_row %in% c(TRUE, "TRUE", "true", "True", "1", 1)
  ) |>
  transmute(
    ticker, fiscal_year,
    firm_specific_land_source = "firm_specific_tier1_early_extractor",
    manual_unit_type = unit_type,
    manual_measure_definition = case_when(
      ticker == "BZH" ~ "Beazer optioned lots divided by total controlled lots from Land Bank table",
      ticker == "DHI" ~ "D.R. Horton lots controlled under lot option and similar contracts divided by total land/lots controlled",
      ticker == "HOV" ~ "Hovnanian optioned home sites divided by consolidated total home sites",
      ticker == "KBH" ~ "KB Home lots under option divided by total lots owned or under option",
      ticker == "LEN" ~ "Lennar optioned plus JV homesites divided by total owned, optioned, and JV homesites",
      ticker == "PHM" ~ "Pulte optioned lots divided by controlled lots",
      TRUE ~ "Tier-1 early land-control disclosure"
    ),
    manual_owned_physical_count = owned_lots,
    manual_nonowned_physical_count = nonowned_controlled_lots,
    manual_optioned_physical_count = optioned_lots,
    manual_jv_physical_count = jv_lots,
    manual_total_physical_count = total_lots,
    manual_nonowned_controlled_share = nonowned_controlled_share,
    manual_optioned_share = optioned_share,
    manual_owned_share = owned_share,
    manual_conservative_lpa_only_share = NA_real_,
    manual_exact_component_identity = component_identity_pass,
    manual_approximate_flag = approximate_flag,
    manual_review_flag,
    manual_review_reason,
    manual_hand_code_quality_tier = case_when(
      uses_later_comparative_prior_year_row ~ "comparative_prior_year_source",
      approximate_flag ~ "rounded_prose_component_identity",
      TRUE ~ "programmatic_firm_rule"
    ),
    manual_panel_use_flag = panel_use_flag,
    manual_panel_use_note = case_when(
      uses_later_comparative_prior_year_row ~ "Uses exact comparative prior-year row from the next 10-K because the original-year filing did not expose the same component split.",
      approximate_flag ~ "Uses approximate prose components that reconcile to the reported controlled-lot total.",
      TRUE ~ "Uses firm-era-specific table extraction after manual review."
    ),
    manual_disclosure_basis = extraction_method,
    manual_source_table_index = as.character(source_table_index),
    manual_source_row_label = source_row_label,
    manual_source_task = "extract_tier1_early_land_disclosures",
    manual_source_note = source_note,
    manual_cik10 = cik10,
    manual_sec_company_name = sec_company_name,
    manual_report_date = report_date,
    manual_filing_date = filing_date,
    manual_accession_number = source_accession_number,
    manual_primary_document = primary_document,
    manual_source_url = source_url,
    manual_source_local_path = source_local_path,
    manual_source_file_exists = TRUE
  )

ctx_manual <- read_csv("../input/ctx_2004_2009_land_panel.csv", show_col_types = FALSE, na = c("", "NA")) |>
  mutate(
    fiscal_year = as.integer(fiscal_year),
    panel_use_flag = panel_use_flag %in% c(TRUE, "TRUE", "true", "True", "1", 1),
    manual_review_flag = manual_review_flag %in% c(TRUE, "TRUE", "true", "True", "1", 1),
    component_identity_pass = component_identity_pass %in% c(TRUE, "TRUE", "true", "True", "1", 1)
  ) |>
  transmute(
    ticker, fiscal_year,
    firm_specific_land_source = "firm_specific_centex_extractor",
    manual_unit_type = unit_type,
    manual_measure_definition = "Centex lots controlled divided by total lots owned and controlled",
    manual_owned_physical_count = owned_lots,
    manual_nonowned_physical_count = nonowned_controlled_lots,
    manual_optioned_physical_count = optioned_lots,
    manual_jv_physical_count = NA_real_,
    manual_total_physical_count = total_lots,
    manual_nonowned_controlled_share = nonowned_controlled_share,
    manual_optioned_share = optioned_share,
    manual_owned_share = owned_share,
    manual_conservative_lpa_only_share = NA_real_,
    manual_exact_component_identity = component_identity_pass,
    manual_approximate_flag = FALSE,
    manual_review_flag,
    manual_review_reason,
    manual_hand_code_quality_tier = "programmatic_firm_rule",
    manual_panel_use_flag = panel_use_flag,
    manual_panel_use_note = if_else(
      fiscal_year == 2009L,
      "Centex fiscal year ends March 31; FY2009 is a standalone terminal Centex observation before the August 2009 Pulte acquisition.",
      "Centex fiscal year ends March 31; retain fiscal-year timing warning in event-window work."
    ),
    manual_disclosure_basis = extraction_method,
    manual_source_table_index = as.character(source_table_index),
    manual_source_row_label = source_row_label,
    manual_source_task = "extract_centex_land_disclosures",
    manual_source_note = source_note,
    manual_cik10 = cik10,
    manual_sec_company_name = sec_company_name,
    manual_report_date = report_date,
    manual_filing_date = filing_date,
    manual_accession_number = accession_number,
    manual_primary_document = primary_document,
    manual_source_url = source_url,
    manual_source_local_path = source_local_path,
    manual_source_file_exists = TRUE
  )

toa_manual <- read_csv("../input/toa_2004_2007_land_panel.csv", show_col_types = FALSE, na = c("", "NA")) |>
  mutate(
    fiscal_year = as.integer(fiscal_year),
    panel_use_flag = panel_use_flag %in% c(TRUE, "TRUE", "true", "True", "1", 1),
    manual_review_flag = manual_review_flag %in% c(TRUE, "TRUE", "true", "True", "1", 1),
    component_identity_pass = component_identity_pass %in% c(TRUE, "TRUE", "true", "True", "1", 1),
    approximate_flag = approximate_flag %in% c(TRUE, "TRUE", "true", "True", "1", 1),
    later_comparative_recast_available = later_comparative_recast_available %in% c(TRUE, "TRUE", "true", "True", "1", 1)
  ) |>
  transmute(
    ticker, fiscal_year,
    firm_specific_land_source = "firm_specific_tousa_extractor",
    manual_unit_type = unit_type,
    manual_measure_definition = "TOUSA combined optioned homesites divided by combined total homesites",
    manual_owned_physical_count = owned_homesites,
    manual_nonowned_physical_count = nonowned_controlled_homesites,
    manual_optioned_physical_count = optioned_homesites,
    manual_jv_physical_count = jv_homesites,
    manual_total_physical_count = total_homesites,
    manual_nonowned_controlled_share = nonowned_controlled_share,
    manual_optioned_share = optioned_share,
    manual_owned_share = owned_share,
    manual_conservative_lpa_only_share = NA_real_,
    manual_exact_component_identity = component_identity_pass,
    manual_approximate_flag = approximate_flag,
    manual_review_flag,
    manual_review_reason,
    manual_hand_code_quality_tier = if_else(approximate_flag, "rounded_combined_optioned_footnote", "programmatic_firm_rule"),
    manual_panel_use_flag = panel_use_flag,
    manual_panel_use_note = case_when(
      fiscal_year == 2006L & later_comparative_recast_available ~ "Main row uses contemporaneous 2006 10-K combined total excluding Transeastern after write-off; 2007 comparative recast including Transeastern is retained in the TOUSA task output.",
      approximate_flag ~ "Uses combined total and aggregate optioned-footnote values; owned homesites are residual owned at the combined portfolio level.",
      TRUE ~ "Uses TOUSA combined owned/optioned/controlled homesite table."
    ),
    manual_disclosure_basis = extraction_method,
    manual_source_table_index = as.character(source_table_index),
    manual_source_row_label = source_row_label,
    manual_source_task = "extract_tousa_land_disclosures",
    manual_source_note = source_note,
    manual_cik10 = cik10,
    manual_sec_company_name = sec_company_name,
    manual_report_date = report_date,
    manual_filing_date = filing_date,
    manual_accession_number = accession_number,
    manual_primary_document = primary_document,
    manual_source_url = source_url,
    manual_source_local_path = source_local_path,
    manual_source_file_exists = TRUE
  )

ohb_manual <- read_csv("../input/ohb_2004_2008_land_panel.csv", show_col_types = FALSE, na = c("", "NA")) |>
  mutate(
    fiscal_year = as.integer(fiscal_year),
    panel_use_flag = panel_use_flag %in% c(TRUE, "TRUE", "true", "True", "1", 1),
    manual_review_flag = manual_review_flag %in% c(TRUE, "TRUE", "true", "True", "1", 1),
    component_identity_pass = component_identity_pass %in% c(TRUE, "TRUE", "true", "True", "1", 1)
  ) |>
  transmute(
    ticker, fiscal_year,
    firm_specific_land_source = "firm_specific_orleans_extractor",
    manual_unit_type = unit_type,
    manual_measure_definition = "Orleans lots under option agreement, agreement of sale, or under contract divided by total lots owned and controlled",
    manual_owned_physical_count = owned_lots,
    manual_nonowned_physical_count = nonowned_controlled_lots,
    manual_optioned_physical_count = optioned_lots,
    manual_jv_physical_count = NA_real_,
    manual_total_physical_count = total_lots,
    manual_nonowned_controlled_share = nonowned_controlled_share,
    manual_optioned_share = optioned_share,
    manual_owned_share = owned_share,
    manual_conservative_lpa_only_share = NA_real_,
    manual_exact_component_identity = component_identity_pass,
    manual_approximate_flag = FALSE,
    manual_review_flag,
    manual_review_reason,
    manual_hand_code_quality_tier = "programmatic_firm_rule",
    manual_panel_use_flag = panel_use_flag,
    manual_panel_use_note = if_else(
      fiscal_year == 2004L,
      "Uses the June 30 fiscal-year table and excludes the post-year-end July 2004 Realen acquisition pro forma.",
      "Uses Orleans firm-level owned/option-controlled total row."
    ),
    manual_disclosure_basis = extraction_method,
    manual_source_table_index = as.character(source_table_index),
    manual_source_row_label = source_row_label,
    manual_source_task = "extract_orleans_land_disclosures",
    manual_source_note = source_note,
    manual_cik10 = cik10,
    manual_sec_company_name = sec_company_name,
    manual_report_date = report_date,
    manual_filing_date = filing_date,
    manual_accession_number = accession_number,
    manual_primary_document = primary_document,
    manual_source_url = source_url,
    manual_source_local_path = source_local_path,
    manual_source_file_exists = TRUE
  )

ucp_manual <- read_csv("../input/ucp_2013_2016_land_panel.csv", show_col_types = FALSE, na = c("", "NA")) |>
  mutate(
    fiscal_year = as.integer(fiscal_year),
    panel_use_flag = panel_use_flag %in% c(TRUE, "TRUE", "true", "True", "1", 1),
    manual_review_flag = manual_review_flag %in% c(TRUE, "TRUE", "true", "True", "1", 1),
    component_identity_pass = component_identity_pass %in% c(TRUE, "TRUE", "true", "True", "1", 1),
    owned_controlled_split_disclosed = owned_controlled_split_disclosed %in% c(TRUE, "TRUE", "true", "True", "1", 1),
    owned_controlled_split_reconstructed_from_explicit_changes = owned_controlled_split_reconstructed_from_explicit_changes %in% c(TRUE, "TRUE", "true", "True", "1", 1)
  ) |>
  transmute(
    ticker, fiscal_year,
    firm_specific_land_source = "firm_specific_ucp_extractor",
    manual_unit_type = unit_type,
    manual_measure_definition = if_else(
      owned_controlled_split_disclosed | owned_controlled_split_reconstructed_from_explicit_changes,
      "UCP controlled lots subject to purchase or option contract divided by total lots owned and controlled",
      "UCP denominator-only total owned or controlled lots; owned/controlled split not disclosed"
    ),
    manual_owned_physical_count = owned_lots,
    manual_nonowned_physical_count = nonowned_controlled_lots,
    manual_optioned_physical_count = optioned_lots,
    manual_jv_physical_count = NA_real_,
    manual_total_physical_count = total_lots,
    manual_nonowned_controlled_share = nonowned_controlled_share,
    manual_optioned_share = optioned_share,
    manual_owned_share = owned_share,
    manual_conservative_lpa_only_share = NA_real_,
    manual_exact_component_identity = if_else(owned_controlled_split_disclosed | owned_controlled_split_reconstructed_from_explicit_changes, component_identity_pass, NA),
    manual_approximate_flag = FALSE,
    manual_review_flag,
    manual_review_reason,
    manual_hand_code_quality_tier = if_else(owned_controlled_split_disclosed, "programmatic_firm_rule", "exact_explicit_prose_reconstruction"),
    manual_panel_use_flag = panel_use_flag,
    manual_panel_use_note = if_else(
      owned_controlled_split_disclosed,
      "Uses UCP recurring owned/controlled/total lot table.",
      "FY2016 is reconstructed exactly from the reported total, optioned-lot count, and component changes from FY2015."
    ),
    manual_disclosure_basis = extraction_method,
    manual_source_table_index = as.character(source_table_index),
    manual_source_row_label = source_row_label,
    manual_source_task = "extract_ucp_land_disclosures",
    manual_source_note = source_note,
    manual_cik10 = cik10,
    manual_sec_company_name = sec_company_name,
    manual_report_date = report_date,
    manual_filing_date = filing_date,
    manual_accession_number = accession_number,
    manual_primary_document = primary_document,
    manual_source_url = source_url,
    manual_source_local_path = source_local_path,
    manual_source_file_exists = TRUE
  )

dhom_manual <- read_csv("../input/dhom_2004_2007_land_panel.csv", show_col_types = FALSE, na = c("", "NA")) |>
  mutate(
    fiscal_year = as.integer(fiscal_year),
    panel_use_flag = panel_use_flag %in% c(TRUE, "TRUE", "true", "True", "1", 1),
    manual_review_flag = manual_review_flag %in% c(TRUE, "TRUE", "true", "True", "1", 1),
    component_identity_pass = component_identity_pass %in% c(TRUE, "TRUE", "true", "True", "1", 1),
    split_from_prose_following_table = split_from_prose_following_table %in% c(TRUE, "TRUE", "true", "True", "1", 1)
  ) |>
  transmute(
    ticker, fiscal_year,
    firm_specific_land_source = "firm_specific_dominion_extractor",
    manual_unit_type = unit_type,
    manual_measure_definition = "Dominion land controlled through option agreements or contingent contracts divided by owned plus controlled land inventory",
    manual_owned_physical_count = owned_lots,
    manual_nonowned_physical_count = nonowned_controlled_lots,
    manual_optioned_physical_count = optioned_lots,
    manual_jv_physical_count = NA_real_,
    manual_total_physical_count = total_lots,
    manual_nonowned_controlled_share = nonowned_controlled_share,
    manual_optioned_share = optioned_share,
    manual_owned_share = owned_share,
    manual_conservative_lpa_only_share = NA_real_,
    manual_exact_component_identity = component_identity_pass,
    manual_approximate_flag = FALSE,
    manual_review_flag,
    manual_review_reason,
    manual_hand_code_quality_tier = if_else(split_from_prose_following_table, "programmatic_firm_rule_prose_split", "programmatic_firm_rule"),
    manual_panel_use_flag = panel_use_flag,
    manual_panel_use_note = if_else(
      split_from_prose_following_table,
      "Owned/controlled split appears in prose following the land inventory table and reconciles exactly to total land inventory.",
      "Uses Dominion owned/control land inventory sentences."
    ),
    manual_disclosure_basis = extraction_method,
    manual_source_table_index = as.character(source_table_index),
    manual_source_row_label = source_row_label,
    manual_source_task = "extract_dominion_land_disclosures",
    manual_source_note = source_note,
    manual_cik10 = cik10,
    manual_sec_company_name = sec_company_name,
    manual_report_date = report_date,
    manual_filing_date = filing_date,
    manual_accession_number = accession_number,
    manual_primary_document = primary_document,
    manual_source_url = source_url,
    manual_source_local_path = source_local_path,
    manual_source_file_exists = TRUE
  )

bhs_manual <- read_csv("../input/bhs_2004_2010_land_panel.csv", show_col_types = FALSE, na = c("", "NA")) |>
  mutate(
    fiscal_year = as.integer(fiscal_year),
    panel_use_flag = panel_use_flag %in% c(TRUE, "TRUE", "true", "True", "1", 1),
    manual_review_flag = manual_review_flag %in% c(TRUE, "TRUE", "true", "True", "1", 1),
    component_identity_pass = component_identity_pass %in% c(TRUE, "TRUE", "true", "True", "1", 1),
    owned_includes_jv_unconsolidated_share = owned_includes_jv_unconsolidated_share %in% c(TRUE, "TRUE", "true", "True", "1", 1),
    optioned_may_include_jv_unconsolidated_share = optioned_may_include_jv_unconsolidated_share %in% c(TRUE, "TRUE", "true", "True", "1", 1)
  ) |>
  transmute(
    ticker = "BHS/BRP",
    fiscal_year,
    firm_specific_land_source = "firm_specific_brookfield_homes_extractor",
    manual_unit_type = unit_type,
    manual_measure_definition = "Brookfield Homes lots under option divided by total controlled lots",
    manual_owned_physical_count = owned_lots,
    manual_nonowned_physical_count = nonowned_controlled_lots,
    manual_optioned_physical_count = optioned_lots,
    manual_jv_physical_count = NA_real_,
    manual_total_physical_count = total_lots,
    manual_nonowned_controlled_share = nonowned_controlled_share,
    manual_optioned_share = optioned_share,
    manual_owned_share = owned_share,
    manual_conservative_lpa_only_share = NA_real_,
    manual_exact_component_identity = component_identity_pass,
    manual_approximate_flag = FALSE,
    manual_review_flag,
    manual_review_reason,
    manual_hand_code_quality_tier = "programmatic_firm_rule",
    manual_panel_use_flag = panel_use_flag,
    manual_panel_use_note = case_when(
      optioned_may_include_jv_unconsolidated_share ~ "Uses Brookfield controlled-lots table; owned and optioned rows may include proportionate JV or unconsolidated-entity share.",
      owned_includes_jv_unconsolidated_share ~ "Uses Brookfield controlled-lots table; owned row includes directly owned lots plus company share of JV-owned lots.",
      TRUE ~ "Uses Brookfield controlled-lots table."
    ),
    manual_disclosure_basis = extraction_method,
    manual_source_table_index = as.character(source_table_index),
    manual_source_row_label = source_row_label,
    manual_source_task = "extract_brookfield_homes_land_disclosures",
    manual_source_note = source_note,
    manual_cik10 = cik10,
    manual_sec_company_name = sec_company_name,
    manual_report_date = report_date,
    manual_filing_date = filing_date,
    manual_accession_number = accession_number,
    manual_primary_document = primary_document,
    manual_source_url = source_url,
    manual_source_local_path = source_local_path,
    manual_source_file_exists = TRUE
  )

wci_manual <- read_csv("../input/wci_2004_2015_land_panel.csv", show_col_types = FALSE, na = c("", "NA")) |>
  mutate(
    fiscal_year = as.integer(fiscal_year),
    main_panel_eligible = main_panel_eligible %in% c(TRUE, "TRUE", "true", "True", "1", 1),
    alternate_land_control_share_eligible = alternate_land_control_share_eligible %in% c(TRUE, "TRUE", "true", "True", "1", 1),
    manual_review_flag = manual_review_flag %in% c(TRUE, "TRUE", "true", "True", "1", 1),
    component_identity_pass = component_identity_pass %in% c(TRUE, "TRUE", "true", "True", "1", 1)
  ) |>
  transmute(
    ticker,
    fiscal_year,
    firm_specific_land_source = "firm_specific_wci_extractor",
    manual_unit_type = unit_type,
    manual_measure_definition = case_when(
      unit_type == "entitled_units" ~ "Old WCI nonowned controlled entitled units divided by total remaining entitled units",
      TRUE ~ "Post-reorganization WCIC controlled home sites divided by total owned and controlled home sites"
    ),
    manual_owned_physical_count = owned_lots,
    manual_nonowned_physical_count = nonowned_controlled_lots,
    manual_optioned_physical_count = optioned_lots,
    manual_jv_physical_count = NA_real_,
    manual_total_physical_count = total_lots,
    manual_nonowned_controlled_share = nonowned_controlled_share,
    manual_optioned_share = optioned_share,
    manual_owned_share = owned_share,
    manual_conservative_lpa_only_share = NA_real_,
    manual_exact_component_identity = component_identity_pass,
    manual_approximate_flag = unit_type == "entitled_units",
    manual_review_flag,
    manual_review_reason,
    manual_hand_code_quality_tier = if_else(main_panel_eligible, "programmatic_firm_rule", "alternate_entitled_unit_series"),
    manual_panel_use_flag = alternate_land_control_share_eligible,
    manual_main_plot_eligible = main_panel_eligible,
    manual_panel_use_note = case_when(
      unit_type == "entitled_units" ~ "Old WCI reports entitlement-capacity units rather than lots or home sites; selected for alternate review series but excluded from main comparable lot/home-site plot.",
      fiscal_year == 2015L ~ "Uses WCIC Development Status table; controlled total includes 191 sites grouped with active and other communities in the Our Communities table.",
      TRUE ~ "Uses WCIC Home Sites by Development Status table."
    ),
    manual_disclosure_basis = extraction_method,
    manual_source_table_index = as.character(source_table_index),
    manual_source_row_label = source_row_label,
    manual_source_task = "extract_wci_land_disclosures",
    manual_source_note = source_note,
    manual_cik10 = cik10,
    manual_sec_company_name = sec_company_name,
    manual_report_date = report_date,
    manual_filing_date = filing_date,
    manual_accession_number = accession_number,
    manual_primary_document = primary_document,
    manual_source_url = source_url,
    manual_source_local_path = source_local_path,
    manual_source_file_exists = TRUE
  )

nwhm_manual <- read_csv("../input/nwhm_2013_2020_land_panel.csv", show_col_types = FALSE, na = c("", "NA")) |>
  mutate(
    fiscal_year = as.integer(fiscal_year),
    panel_use_flag = panel_use_flag %in% c(TRUE, "TRUE", "true", "True", "1", 1),
    manual_review_flag = manual_review_flag %in% c(TRUE, "TRUE", "true", "True", "1", 1),
    component_identity_pass = component_identity_pass %in% c(TRUE, "TRUE", "true", "True", "1", 1),
    fee_building_excluded_from_main = fee_building_excluded_from_main %in% c(TRUE, "TRUE", "true", "True", "1", 1),
    unconsolidated_jv_excluded_from_main = unconsolidated_jv_excluded_from_main %in% c(TRUE, "TRUE", "true", "True", "1", 1)
  ) |>
  transmute(
    ticker,
    fiscal_year,
    firm_specific_land_source = "firm_specific_new_home_company_extractor",
    manual_unit_type = unit_type,
    manual_measure_definition = "New Home Company controlled lots divided by company/wholly-owned owned plus controlled lots",
    manual_owned_physical_count = owned_lots,
    manual_nonowned_physical_count = nonowned_controlled_lots,
    manual_optioned_physical_count = optioned_lots,
    manual_jv_physical_count = unconsolidated_jv_total_lots,
    manual_total_physical_count = total_lots,
    manual_nonowned_controlled_share = nonowned_controlled_share,
    manual_optioned_share = optioned_share,
    manual_owned_share = owned_share,
    manual_conservative_lpa_only_share = NA_real_,
    manual_exact_component_identity = component_identity_pass,
    manual_approximate_flag = FALSE,
    manual_review_flag,
    manual_review_reason,
    manual_hand_code_quality_tier = "programmatic_firm_rule",
    manual_panel_use_flag = panel_use_flag,
    manual_panel_use_note = "Uses NWHM company/wholly-owned land-position split. Fee-building lots and unconsolidated joint ventures are excluded from main omega and retained in the NWHM task output.",
    manual_disclosure_basis = extraction_method,
    manual_source_table_index = as.character(source_table_index),
    manual_source_row_label = source_row_label,
    manual_source_task = "extract_new_home_company_land_disclosures",
    manual_source_note = source_note,
    manual_cik10 = cik10,
    manual_sec_company_name = sec_company_name,
    manual_report_date = report_date,
    manual_filing_date = filing_date,
    manual_accession_number = accession_number,
    manual_primary_document = primary_document,
    manual_source_url = source_url,
    manual_source_local_path = source_local_path,
    manual_source_file_exists = TRUE
  )

ryl_manual <- read_csv("../input/ryl_2004_2014_land_panel.csv", show_col_types = FALSE, na = c("", "NA")) |>
  mutate(
    fiscal_year = as.integer(fiscal_year),
    panel_use_flag = panel_use_flag %in% c(TRUE, "TRUE", "true", "True", "1", 1),
    main_panel_eligible = main_panel_eligible %in% c(TRUE, "TRUE", "true", "True", "1", 1),
    manual_review_flag = manual_review_flag %in% c(TRUE, "TRUE", "true", "True", "1", 1),
    component_identity_pass = component_identity_pass %in% c(TRUE, "TRUE", "true", "True", "1", 1),
    uses_later_comparative_prior_year_row = uses_later_comparative_prior_year_row %in% c(TRUE, "TRUE", "true", "True", "1", 1),
    jv_lots_excluded_from_main = jv_lots_excluded_from_main %in% c(TRUE, "TRUE", "true", "True", "1", 1)
  ) |>
  transmute(
    ticker,
    fiscal_year,
    firm_specific_land_source = "firm_specific_ryland_extractor",
    manual_unit_type = unit_type,
    manual_measure_definition = "Ryland optioned lots divided by reporting-segment lots owned plus optioned",
    manual_owned_physical_count = owned_lots,
    manual_nonowned_physical_count = nonowned_controlled_lots,
    manual_optioned_physical_count = optioned_lots,
    manual_jv_physical_count = separately_disclosed_jv_lots,
    manual_total_physical_count = total_lots,
    manual_nonowned_controlled_share = nonowned_controlled_share,
    manual_optioned_share = optioned_share,
    manual_owned_share = owned_share,
    manual_conservative_lpa_only_share = NA_real_,
    manual_exact_component_identity = component_identity_pass,
    manual_approximate_flag = FALSE,
    manual_review_flag,
    manual_review_reason,
    manual_hand_code_quality_tier = case_when(
      !main_panel_eligible ~ "audited_missing_owned_optioned_split",
      uses_later_comparative_prior_year_row ~ "comparative_prior_year_source",
      TRUE ~ "programmatic_firm_rule"
    ),
    manual_panel_use_flag = panel_use_flag,
    manual_main_plot_eligible = main_panel_eligible,
    manual_panel_use_note = case_when(
      !main_panel_eligible ~ "Ryland 2004 filing discloses option and land-purchase dollar commitments but no physical owned/optioned lot-count table, so omega is missing.",
      uses_later_comparative_prior_year_row ~ "Uses exact 2005 comparative row from Ryland's 2006 10-K; 2005 filing lacks the owned/optioned lot-count table.",
      TRUE ~ "Uses Ryland recurring reporting-segment owned/optioned lot table; separately disclosed JV lots are excluded from main omega."
    ),
    manual_disclosure_basis = extraction_method,
    manual_source_table_index = as.character(source_table_index),
    manual_source_row_label = source_row_label,
    manual_source_task = "extract_ryland_land_disclosures",
    manual_source_note = source_note,
    manual_cik10 = cik10,
    manual_sec_company_name = sec_company_name,
    manual_report_date = report_date,
    manual_filing_date = filing_date,
    manual_accession_number = accession_number,
    manual_primary_document = primary_document,
    manual_source_url = source_url,
    manual_source_local_path = source_local_path,
    manual_source_file_exists = TRUE
  )

avhi_manual <- read_csv("../input/avhi_2004_2017_land_panel.csv", show_col_types = FALSE, na = c("", "NA")) |>
  mutate(
    fiscal_year = as.integer(fiscal_year),
    panel_use_flag = panel_use_flag %in% c(TRUE, "TRUE", "true", "True", "1", 1),
    main_panel_eligible = main_panel_eligible %in% c(TRUE, "TRUE", "true", "True", "1", 1),
    manual_review_flag = manual_review_flag %in% c(TRUE, "TRUE", "true", "True", "1", 1),
    land_position_total_only = land_position_total_only %in% c(TRUE, "TRUE", "true", "True", "1", 1),
    acres_only_no_lot_conversion = acres_only_no_lot_conversion %in% c(TRUE, "TRUE", "true", "True", "1", 1),
    omega_not_computable_no_owned_nonowned_split = omega_not_computable_no_owned_nonowned_split %in% c(TRUE, "TRUE", "true", "True", "1", 1)
  ) |>
  transmute(
    ticker,
    fiscal_year,
    firm_specific_land_source = "firm_specific_av_homes_extractor",
    manual_unit_type = unit_type,
    manual_measure_definition = case_when(
      acres_only_no_lot_conversion ~ "AV Homes / Avatar acres-only real-estate-assets disclosure; no lot conversion",
      TRUE ~ "AV Homes / Avatar disclosed land-position total without owned-vs-nonowned physical split"
    ),
    manual_owned_physical_count = as.numeric(owned_lots),
    manual_nonowned_physical_count = as.numeric(nonowned_controlled_lots),
    manual_optioned_physical_count = as.numeric(optioned_lots),
    manual_jv_physical_count = as.numeric(joint_venture_lots),
    manual_total_physical_count = as.numeric(total_lots),
    manual_nonowned_controlled_share = as.numeric(nonowned_controlled_share),
    manual_optioned_share = as.numeric(optioned_share),
    manual_owned_share = as.numeric(owned_share),
    manual_conservative_lpa_only_share = NA_real_,
    manual_exact_component_identity = NA,
    manual_approximate_flag = FALSE,
    manual_review_flag,
    manual_review_reason,
    manual_hand_code_quality_tier = "audited_land_position_no_owned_nonowned_split",
    manual_panel_use_flag = panel_use_flag,
    manual_main_plot_eligible = main_panel_eligible,
    manual_panel_use_note = "AV Homes / Avatar is audited as land-position-only: the filings do not disclose an owned-vs-nonowned physical split, so omega is missing and the row is excluded from main plots.",
    manual_disclosure_basis = extraction_method,
    manual_source_table_index = as.character(source_table_index),
    manual_source_row_label = source_row_label,
    manual_source_task = "extract_av_homes_land_disclosures",
    manual_source_note = source_note,
    manual_cik10 = cik10,
    manual_sec_company_name = sec_company_name,
    manual_report_date = report_date,
    manual_filing_date = filing_date,
    manual_accession_number = accession_number,
    manual_primary_document = primary_document,
    manual_source_url = source_url,
    manual_source_local_path = source_local_path,
    manual_source_file_exists = TRUE
  )

wlh_manual <- read_csv("../input/wlh_2004_2018_land_panel.csv", show_col_types = FALSE, na = c("", "NA")) |>
  mutate(
    fiscal_year = as.integer(fiscal_year),
    panel_use_flag = panel_use_flag %in% c(TRUE, "TRUE", "true", "True", "1", 1),
    main_panel_eligible = main_panel_eligible %in% c(TRUE, "TRUE", "true", "True", "1", 1),
    manual_review_flag = manual_review_flag %in% c(TRUE, "TRUE", "true", "True", "1", 1),
    component_identity_pass = component_identity_pass %in% c(TRUE, "TRUE", "true", "True", "1", 1),
    uses_later_comparative_prior_year_row = uses_later_comparative_prior_year_row %in% c(TRUE, "TRUE", "true", "True", "1", 1)
  ) |>
  transmute(
    ticker,
    fiscal_year,
    firm_specific_land_source = "firm_specific_william_lyon_extractor",
    manual_unit_type = unit_type,
    manual_measure_definition = "William Lyon Lots Controlled divided by Total Lots Owned and Controlled",
    manual_owned_physical_count = as.numeric(owned_lots),
    manual_nonowned_physical_count = as.numeric(nonowned_controlled_lots),
    manual_optioned_physical_count = as.numeric(optioned_lots),
    manual_jv_physical_count = NA_real_,
    manual_total_physical_count = as.numeric(total_lots),
    manual_nonowned_controlled_share = as.numeric(nonowned_controlled_share),
    manual_optioned_share = as.numeric(optioned_share),
    manual_owned_share = as.numeric(owned_share),
    manual_conservative_lpa_only_share = NA_real_,
    manual_exact_component_identity = component_identity_pass,
    manual_approximate_flag = FALSE,
    manual_review_flag,
    manual_review_reason,
    manual_hand_code_quality_tier = case_when(
      !main_panel_eligible ~ "audited_missing_owned_controlled_split",
      uses_later_comparative_prior_year_row ~ "comparative_prior_year_source",
      TRUE ~ "programmatic_firm_rule"
    ),
    manual_panel_use_flag = panel_use_flag,
    manual_main_plot_eligible = main_panel_eligible,
    manual_panel_use_note = case_when(
      !main_panel_eligible ~ "William Lyon filing lacks a comparable firmwide owned/nonowned controlled split.",
      uses_later_comparative_prior_year_row ~ "Uses exact comparative prior-year column from a later 10-K table.",
      TRUE ~ "Uses William Lyon recurring owned/controlled lot table."
    ),
    manual_disclosure_basis = extraction_method,
    manual_source_table_index = as.character(source_table_index),
    manual_source_row_label = source_row_label,
    manual_source_task = "extract_william_lyon_land_disclosures",
    manual_source_note = source_note,
    manual_cik10 = cik10,
    manual_sec_company_name = sec_company_name,
    manual_report_date = report_date,
    manual_filing_date = filing_date,
    manual_accession_number = accession_number,
    manual_primary_document = primary_document,
    manual_source_url = source_url,
    manual_source_local_path = source_local_path,
    manual_source_file_exists = TRUE
  )

spf_caa_manual <- read_csv("../input/spf_caa_2004_2016_land_panel.csv", show_col_types = FALSE, na = c("", "NA")) |>
  mutate(
    fiscal_year = as.integer(fiscal_year),
    panel_use_flag = panel_use_flag %in% c(TRUE, "TRUE", "true", "True", "1", 1),
    main_panel_eligible = main_panel_eligible %in% c(TRUE, "TRUE", "true", "True", "1", 1),
    manual_review_flag = manual_review_flag %in% c(TRUE, "TRUE", "true", "True", "1", 1),
    component_identity_pass = component_identity_pass %in% c(TRUE, "TRUE", "true", "True", "1", 1),
    merger_definition_break = merger_definition_break %in% c(TRUE, "TRUE", "true", "True", "1", 1),
    post_ryland_merger = post_ryland_merger %in% c(TRUE, "TRUE", "true", "True", "1", 1),
    calatlantic_transition = calatlantic_transition %in% c(TRUE, "TRUE", "true", "True", "1", 1),
    large_scope_change = large_scope_change %in% c(TRUE, "TRUE", "true", "True", "1", 1)
  ) |>
  transmute(
    ticker,
    fiscal_year,
    firm_specific_land_source = "firm_specific_standard_pacific_calatlantic_extractor",
    manual_unit_type = unit_type,
    manual_measure_definition = "Standard Pacific / CalAtlantic optioned-or-subject-to-contract sites divided by owned plus optioned/contract sites, excluding JV sites",
    manual_owned_physical_count = as.numeric(owned_lots),
    manual_nonowned_physical_count = as.numeric(nonowned_controlled_lots),
    manual_optioned_physical_count = as.numeric(optioned_lots),
    manual_jv_physical_count = as.numeric(jv_lots),
    manual_total_physical_count = as.numeric(total_lots),
    manual_nonowned_controlled_share = as.numeric(nonowned_controlled_share),
    manual_optioned_share = as.numeric(optioned_share),
    manual_owned_share = as.numeric(owned_share),
    manual_conservative_lpa_only_share = NA_real_,
    manual_exact_component_identity = component_identity_pass,
    manual_approximate_flag = FALSE,
    manual_review_flag,
    manual_review_reason,
    manual_hand_code_quality_tier = if_else(manual_review_flag, "programmatic_firm_rule_with_review_flag", "programmatic_firm_rule"),
    manual_panel_use_flag = panel_use_flag,
    manual_main_plot_eligible = main_panel_eligible,
    manual_panel_use_note = case_when(
      merger_definition_break ~ "Standard Pacific / Ryland merger and CalAtlantic transition; main-eligible but flagged for splice/event-window analyses.",
      TRUE ~ "Uses recurring owned plus optioned/subject-to-contract land table; JV lots are excluded from main omega and retained separately."
    ),
    manual_disclosure_basis = extraction_method,
    manual_source_table_index = as.character(source_table_index),
    manual_source_row_label = source_row_label,
    manual_source_task = "extract_standard_pacific_calatlantic_land_disclosures",
    manual_source_note = source_note,
    manual_cik10 = cik10,
    manual_sec_company_name = sec_company_name,
    manual_report_date = report_date,
    manual_filing_date = filing_date,
    manual_accession_number = accession_number,
    manual_primary_document = primary_document,
    manual_source_url = source_url,
    manual_source_local_path = source_local_path,
    manual_source_file_exists = TRUE
  )

chci_manual <- read_csv("../input/chci_2006_2016_land_panel.csv", show_col_types = FALSE, na = c("", "NA")) |>
  mutate(
    fiscal_year = as.integer(fiscal_year),
    panel_use_flag = panel_use_flag %in% c(TRUE, "TRUE", "true", "True", "1", 1),
    main_panel_eligible = main_panel_eligible %in% c(TRUE, "TRUE", "true", "True", "1", 1),
    manual_review_flag = manual_review_flag %in% c(TRUE, "TRUE", "true", "True", "1", 1),
    component_identity_pass = component_identity_pass %in% c(TRUE, "TRUE", "true", "True", "1", 1),
    foreclosed_lots_excluded_from_main = foreclosed_lots_excluded_from_main %in% c(TRUE, "TRUE", "true", "True", "1", 1)
  ) |>
  transmute(
    ticker, fiscal_year,
    firm_specific_land_source = "firm_specific_comstock_extractor",
    manual_unit_type = unit_type,
    manual_measure_definition = "Comstock nonowned option/control lots or units divided by owned unsold plus nonowned option/control lots or units, excluding backlog",
    manual_owned_physical_count = as.numeric(owned_lots),
    manual_nonowned_physical_count = as.numeric(nonowned_controlled_lots),
    manual_optioned_physical_count = as.numeric(optioned_lots),
    manual_jv_physical_count = NA_real_,
    manual_total_physical_count = as.numeric(total_lots),
    manual_nonowned_controlled_share = as.numeric(nonowned_controlled_share),
    manual_optioned_share = as.numeric(optioned_share),
    manual_owned_share = as.numeric(owned_share),
    manual_conservative_lpa_only_share = NA_real_,
    manual_exact_component_identity = component_identity_pass,
    manual_approximate_flag = FALSE,
    manual_review_flag,
    manual_review_reason,
    manual_hand_code_quality_tier = case_when(
      !main_panel_eligible ~ "audited_review_only_or_missing_nonowned_control",
      manual_review_flag ~ "programmatic_firm_rule_with_review_flag",
      TRUE ~ "programmatic_firm_rule"
    ),
    manual_panel_use_flag = panel_use_flag,
    manual_main_plot_eligible = main_panel_eligible,
    manual_panel_use_note = case_when(
      fiscal_year == 2009L ~ "Comstock 2009 uses the exact owned-unsold and optioned-unsold columns; separately reported foreclosed and bankruptcy-transfer lots are excluded from omega.",
      fiscal_year %in% c(2010L, 2011L, 2012L) ~ "Comstock discloses owned unsold lots but no nonowned option/control count; omega is intentionally missing.",
      TRUE ~ "Uses Comstock owned-unsold plus option/control pipeline table; backlog is excluded from main omega and retained separately."
    ),
    manual_disclosure_basis = extraction_method,
    manual_source_table_index = as.character(source_table_index),
    manual_source_row_label = source_row_label,
    manual_source_task = "extract_comstock_land_disclosures",
    manual_source_note = source_note,
    manual_cik10 = cik10,
    manual_sec_company_name = sec_company_name,
    manual_report_date = report_date,
    manual_filing_date = filing_date,
    manual_accession_number = accession_number,
    manual_primary_document = primary_document,
    manual_source_url = source_url,
    manual_source_local_path = source_local_path,
    manual_source_file_exists = TRUE
  )

lev_manual <- read_csv("../input/lev_2004_2007_land_panel.csv", show_col_types = FALSE, na = c("", "NA")) |>
  mutate(
    fiscal_year = as.integer(fiscal_year),
    panel_use_flag = panel_use_flag %in% c(TRUE, "TRUE", "true", "True", "1", 1),
    main_panel_eligible = main_panel_eligible %in% c(TRUE, "TRUE", "true", "True", "1", 1),
    manual_review_flag = manual_review_flag %in% c(TRUE, "TRUE", "true", "True", "1", 1)
  ) |>
  transmute(
    ticker, fiscal_year,
    firm_specific_land_source = "firm_specific_levitt_extractor",
    manual_unit_type = unit_type,
    manual_measure_definition = "Levitt current-development pipeline includes an unquantified optioned-lot subset",
    manual_owned_physical_count = as.numeric(owned_lots),
    manual_nonowned_physical_count = as.numeric(nonowned_controlled_lots),
    manual_optioned_physical_count = as.numeric(optioned_lots),
    manual_jv_physical_count = NA_real_,
    manual_total_physical_count = as.numeric(total_lots),
    manual_nonowned_controlled_share = as.numeric(nonowned_controlled_share),
    manual_optioned_share = NA_real_,
    manual_owned_share = NA_real_,
    manual_conservative_lpa_only_share = NA_real_,
    manual_exact_component_identity = FALSE,
    manual_approximate_flag = FALSE,
    manual_review_flag,
    manual_review_reason,
    manual_hand_code_quality_tier = "audited_pipeline_no_owned_optioned_split",
    manual_panel_use_flag = panel_use_flag,
    manual_main_plot_eligible = main_panel_eligible,
    manual_panel_use_note = manual_review_reason,
    manual_disclosure_basis = extraction_method,
    manual_source_table_index = NA_character_,
    manual_source_row_label = source_row_label,
    manual_source_task = "extract_levitt_land_disclosures",
    manual_source_note = source_note,
    manual_cik10 = cik10,
    manual_sec_company_name = sec_company_name,
    manual_report_date = report_date,
    manual_filing_date = filing_date,
    manual_accession_number = accession_number,
    manual_primary_document = primary_document,
    manual_source_url = source_url,
    manual_source_local_path = source_local_path,
    manual_source_file_exists = TRUE
  )

grbk_prebuilder_exclusions <- read_csv("../input/grbk_prebuilder_filing_exclusions.csv", show_col_types = FALSE, na = c("", "NA")) |>
  transmute(
    ticker,
    fiscal_year = as.integer(fiscal_year),
    pre_builder_predecessor_or_shell = TRUE,
    pre_builder_exclusion_reason = exclusion_reason
  )

lsea_prebuilder_exclusions <- read_csv("../input/lsea_2018_2019_prebuilder_filing_exclusions.csv", show_col_types = FALSE, na = c("", "NA")) |>
  transmute(
    ticker,
    fiscal_year = as.integer(fiscal_year),
    pre_builder_predecessor_or_shell = TRUE,
    pre_builder_exclusion_reason = exclusion_reason
  )

uhg_prebuilder_exclusions <- read_csv("../input/uhg_2020_2021_prebuilder_filing_exclusions.csv", show_col_types = FALSE, na = c("", "NA")) |>
  transmute(
    ticker,
    fiscal_year = as.integer(fiscal_year),
    pre_builder_predecessor_or_shell = TRUE,
    pre_builder_exclusion_reason = exclusion_reason
  )

prebuilder_exclusions <- bind_rows(grbk_prebuilder_exclusions, lsea_prebuilder_exclusions, uhg_prebuilder_exclusions)

if (prebuilder_exclusions |>
    count(ticker, fiscal_year) |>
    filter(n > 1) |>
    nrow() > 0) {
  stop("Pre-builder filing exclusions must be unique by ticker/fiscal_year.")
}

firm_specific_land <- bind_rows(six_firm_manual, toll_manual, mho_manual, mdc_manual, grbk_manual, mth_manual, tmhc_manual, tph_manual, nvr_early_manual, lsea_manual, dfh_manual, sdhc_manual, uhg_manual, tier1_early_manual, ctx_manual, toa_manual, ohb_manual, ucp_manual, dhom_manual, bhs_manual, wci_manual, nwhm_manual, ryl_manual, avhi_manual, wlh_manual, spf_caa_manual, chci_manual, lev_manual)

if (firm_specific_land |>
    count(manual_cik10, fiscal_year) |>
    filter(n > 1) |>
    nrow() > 0) {
  stop("Firm-specific land panel inputs must be unique by manual_cik10/fiscal_year.")
}

balanced_panel <- builder_universe |>
  crossing(fiscal_year = 2004:2025) |>
  left_join(
    generic_land,
    by = c("candidate_cik10" = "cik10", "fiscal_year"),
    relationship = "many-to-one"
  ) |>
  left_join(
    firm_specific_land |> select(-ticker),
    by = c("candidate_cik10" = "manual_cik10", "fiscal_year"),
    relationship = "many-to-one"
  ) |>
  left_join(
    prebuilder_exclusions,
    by = c("ticker", "fiscal_year"),
    relationship = "many-to-one"
  ) |>
  group_by(candidate_cik10) |>
  mutate(
    duplicate_cik_universe_rows = n_distinct(universe_episode_id) > 1L
  ) |>
  ungroup() |>
  mutate(
    in_universe_episode_window = (is.na(valid_from_year) | fiscal_year >= valid_from_year) &
      (is.na(valid_to_year) | fiscal_year <= valid_to_year)
  ) |>
  group_by(universe_episode_id) |>
  mutate(
    first_sec_fiscal_year = if (any(!is.na(accession_number) & in_universe_episode_window)) min(fiscal_year[!is.na(accession_number) & in_universe_episode_window]) else NA_integer_,
    last_sec_fiscal_year = if (any(!is.na(accession_number) & in_universe_episode_window)) max(fiscal_year[!is.na(accession_number) & in_universe_episode_window]) else NA_integer_
  ) |>
  ungroup() |>
  mutate(
    sec_filing_observed = !is.na(accession_number) & in_universe_episode_window,
    pre_sec_reporting_window = !is.na(first_sec_fiscal_year) & fiscal_year < first_sec_fiscal_year,
    post_sec_exit_window = !is.na(last_sec_fiscal_year) & fiscal_year > last_sec_fiscal_year,
    in_sec_reporting_window = !is.na(first_sec_fiscal_year) &
      fiscal_year >= first_sec_fiscal_year & fiscal_year <= last_sec_fiscal_year,
    missing_sec_filing_in_reporting_window = in_sec_reporting_window & !sec_filing_observed,
    pre_builder_predecessor_or_shell = coalesce(pre_builder_predecessor_or_shell, FALSE),
    pre_builder_exclusion_reason = coalesce(pre_builder_exclusion_reason, ""),
    manual_panel_use_flag = coalesce(manual_panel_use_flag, FALSE),
    manual_main_plot_eligible = coalesce(manual_main_plot_eligible, manual_panel_use_flag),
    manual_review_flag = coalesce(manual_review_flag, FALSE),
    selected_land_source = case_when(
      in_universe_episode_window & manual_panel_use_flag ~ firm_specific_land_source,
      in_universe_episode_window & generic_main_plot_eligible ~ "generic_parser_main",
      in_universe_episode_window & generic_analysis_ready_with_review ~ "generic_parser_with_review",
      TRUE ~ ""
    ),
    selected_owned_physical_count = case_when(
      selected_land_source == "hand_read_six_firm" | startsWith(selected_land_source, "firm_specific_") ~ manual_owned_physical_count,
      selected_land_source %in% c("generic_parser_main", "generic_parser_with_review") ~ generic_owned_physical_count,
      TRUE ~ NA_real_
    ),
    selected_nonowned_physical_count = case_when(
      selected_land_source == "hand_read_six_firm" | startsWith(selected_land_source, "firm_specific_") ~ manual_nonowned_physical_count,
      selected_land_source %in% c("generic_parser_main", "generic_parser_with_review") ~ generic_nonowned_physical_count,
      TRUE ~ NA_real_
    ),
    selected_total_physical_count = case_when(
      selected_land_source == "hand_read_six_firm" | startsWith(selected_land_source, "firm_specific_") ~ manual_total_physical_count,
      selected_land_source %in% c("generic_parser_main", "generic_parser_with_review") ~ generic_total_physical_count,
      TRUE ~ NA_real_
    ),
    selected_nonowned_controlled_share = case_when(
      selected_land_source == "hand_read_six_firm" | startsWith(selected_land_source, "firm_specific_") ~ manual_nonowned_controlled_share,
      selected_land_source %in% c("generic_parser_main", "generic_parser_with_review") ~ generic_nonowned_controlled_share,
      TRUE ~ NA_real_
    ),
    selected_unit_type = case_when(
      selected_land_source == "hand_read_six_firm" | startsWith(selected_land_source, "firm_specific_") ~ manual_unit_type,
      selected_land_source %in% c("generic_parser_main", "generic_parser_with_review") ~ generic_physical_unit_type,
      TRUE ~ ""
    ),
    selected_measure_definition = case_when(
      selected_land_source == "hand_read_six_firm" | startsWith(selected_land_source, "firm_specific_") ~ manual_measure_definition,
      selected_land_source %in% c("generic_parser_main", "generic_parser_with_review") ~ generic_harmonization_rule,
      TRUE ~ ""
    ),
    selected_source_note = case_when(
      selected_land_source == "hand_read_six_firm" | startsWith(selected_land_source, "firm_specific_") ~ manual_source_note,
      selected_land_source %in% c("generic_parser_main", "generic_parser_with_review") ~ generic_provenance_review_reason,
      TRUE ~ ""
    ),
    selected_accession_number = case_when(
      selected_land_source == "hand_read_six_firm" | startsWith(selected_land_source, "firm_specific_") ~ manual_accession_number,
      selected_land_source %in% c("generic_parser_main", "generic_parser_with_review") ~ accession_number,
      sec_filing_observed ~ accession_number,
      TRUE ~ NA_character_
    ),
    selected_source_url = case_when(
      selected_land_source == "hand_read_six_firm" | startsWith(selected_land_source, "firm_specific_") ~ manual_source_url,
      selected_land_source %in% c("generic_parser_main", "generic_parser_with_review") ~ filing_url,
      sec_filing_observed ~ filing_url,
      TRUE ~ NA_character_
    ),
    selected_source_local_path = case_when(
      selected_land_source == "hand_read_six_firm" | startsWith(selected_land_source, "firm_specific_") ~ manual_source_local_path,
      selected_land_source %in% c("generic_parser_main", "generic_parser_with_review") ~ primary_document_local_path,
      sec_filing_observed ~ primary_document_local_path,
      TRUE ~ NA_character_
    ),
    selected_main_plot_eligible = (((selected_land_source == "hand_read_six_firm" | startsWith(selected_land_source, "firm_specific_")) & manual_main_plot_eligible) |
      selected_land_source == "generic_parser_main") &
      !is.na(selected_nonowned_controlled_share),
    selected_review_plot_eligible = selected_land_source != "",
    selected_manual_review_flag = case_when(
      selected_land_source == "hand_read_six_firm" | startsWith(selected_land_source, "firm_specific_") ~ manual_review_flag,
      selected_land_source %in% c("generic_parser_main", "generic_parser_with_review") ~ generic_manual_review_flag,
      TRUE ~ FALSE
    ),
    needs_firm_era_review = sec_filing_observed & !selected_review_plot_eligible & !pre_builder_predecessor_or_shell,
    review_priority = case_when(
      needs_firm_era_review & tier == 1L ~ 1L,
      needs_firm_era_review & tier == 2L ~ 2L,
      TRUE ~ NA_integer_
    )
  ) |>
  select(
    universe_episode_id, universe_firm_id, company, ticker, tier, status,
    candidate_cik10, candidate_sec_company_name, fiscal_year,
    sec_filing_observed, first_sec_fiscal_year, last_sec_fiscal_year,
    pre_sec_reporting_window, in_sec_reporting_window, post_sec_exit_window,
    missing_sec_filing_in_reporting_window, duplicate_cik_universe_rows,
    valid_from_year, valid_to_year, in_universe_episode_window,
    pre_builder_predecessor_or_shell, pre_builder_exclusion_reason,
    selected_land_source, selected_main_plot_eligible, selected_review_plot_eligible,
    selected_manual_review_flag, needs_firm_era_review, review_priority,
    selected_owned_physical_count, selected_nonowned_physical_count,
    selected_total_physical_count, selected_nonowned_controlled_share,
    selected_unit_type, selected_measure_definition, selected_source_note,
    selected_accession_number, selected_source_url, selected_source_local_path,
    generic_nonowned_controlled_share, generic_harmonization_rule,
    generic_main_plot_eligible, generic_analysis_ready_with_review,
    generic_not_eligible_reason, generic_manual_review_reason,
    manual_nonowned_controlled_share, manual_measure_definition,
    manual_panel_use_flag, manual_review_reason,
    filing_window, fye_month, fye_month_number, fiscal_year_warning,
    merger_splice_flag, recent_ipo_flag, low_omega_anchor_flag,
    high_omega_prior_flag, fate_and_splicing_notes,
    omega_prior_and_relevance, universe_review_status
  ) |>
  arrange(tier, company, candidate_cik10, fiscal_year)

coverage_by_firm <- balanced_panel |>
  group_by(universe_episode_id, company, ticker, tier, candidate_cik10) |>
  summarise(
    first_sec_fiscal_year = first(first_sec_fiscal_year),
    last_sec_fiscal_year = first(last_sec_fiscal_year),
    sec_filing_years = sum(sec_filing_observed, na.rm = TRUE),
    selected_main_plot_years = sum(selected_main_plot_eligible, na.rm = TRUE),
    selected_review_plot_years = sum(selected_review_plot_eligible, na.rm = TRUE),
    firm_specific_years = sum(selected_land_source %in% c("hand_read_six_firm", "firm_specific_toll_extractor", "firm_specific_mho_extractor", "firm_specific_mdc_extractor", "firm_specific_grbk_extractor", "firm_specific_mth_extractor", "firm_specific_tmhc_extractor", "firm_specific_tph_extractor", "firm_specific_nvr_early_extractor", "firm_specific_lsea_extractor", "firm_specific_dfh_extractor", "firm_specific_sdhc_extractor", "firm_specific_uhg_extractor", "firm_specific_tier1_early_extractor", "firm_specific_centex_extractor", "firm_specific_tousa_extractor", "firm_specific_orleans_extractor", "firm_specific_ucp_extractor", "firm_specific_dominion_extractor", "firm_specific_brookfield_homes_extractor", "firm_specific_wci_extractor", "firm_specific_new_home_company_extractor", "firm_specific_ryland_extractor", "firm_specific_av_homes_extractor", "firm_specific_william_lyon_extractor", "firm_specific_standard_pacific_calatlantic_extractor", "firm_specific_comstock_extractor", "firm_specific_levitt_extractor"), na.rm = TRUE),
    generic_main_years = sum(selected_land_source == "generic_parser_main", na.rm = TRUE),
    generic_review_years = sum(selected_land_source == "generic_parser_with_review", na.rm = TRUE),
    review_needed_years = sum(needs_firm_era_review, na.rm = TRUE),
    duplicate_cik_universe_rows = first(duplicate_cik_universe_rows),
    fiscal_year_warning = first(fiscal_year_warning),
    universe_review_status = first(universe_review_status),
    .groups = "drop"
  ) |>
  arrange(tier, desc(review_needed_years), company, candidate_cik10)

coverage_by_year <- balanced_panel |>
  group_by(fiscal_year) |>
  summarise(
    universe_episodes = n_distinct(universe_episode_id),
    sec_filing_episodes = sum(sec_filing_observed, na.rm = TRUE),
    selected_main_plot_episodes = sum(selected_main_plot_eligible, na.rm = TRUE),
    selected_review_plot_episodes = sum(selected_review_plot_eligible, na.rm = TRUE),
    firm_specific_episodes = sum(selected_land_source %in% c("hand_read_six_firm", "firm_specific_toll_extractor", "firm_specific_mho_extractor", "firm_specific_mdc_extractor", "firm_specific_grbk_extractor", "firm_specific_mth_extractor", "firm_specific_tmhc_extractor", "firm_specific_tph_extractor", "firm_specific_nvr_early_extractor", "firm_specific_lsea_extractor", "firm_specific_dfh_extractor", "firm_specific_sdhc_extractor", "firm_specific_uhg_extractor", "firm_specific_tier1_early_extractor", "firm_specific_centex_extractor", "firm_specific_tousa_extractor", "firm_specific_orleans_extractor", "firm_specific_ucp_extractor", "firm_specific_dominion_extractor", "firm_specific_brookfield_homes_extractor", "firm_specific_wci_extractor", "firm_specific_new_home_company_extractor", "firm_specific_ryland_extractor", "firm_specific_av_homes_extractor", "firm_specific_william_lyon_extractor", "firm_specific_standard_pacific_calatlantic_extractor", "firm_specific_comstock_extractor", "firm_specific_levitt_extractor"), na.rm = TRUE),
    generic_main_episodes = sum(selected_land_source == "generic_parser_main", na.rm = TRUE),
    generic_review_episodes = sum(selected_land_source == "generic_parser_with_review", na.rm = TRUE),
    review_needed_episodes = sum(needs_firm_era_review, na.rm = TRUE),
    mean_nonowned_share_main = mean(selected_nonowned_controlled_share[selected_main_plot_eligible], na.rm = TRUE),
    mean_nonowned_share_review = mean(selected_nonowned_controlled_share[selected_review_plot_eligible], na.rm = TRUE),
    .groups = "drop"
  ) |>
  arrange(fiscal_year)

plot_data <- balanced_panel |>
  filter(selected_review_plot_eligible) |>
  transmute(
    fiscal_year, company, ticker, tier, candidate_cik10,
    selected_land_source, selected_main_plot_eligible,
    selected_review_plot_eligible, selected_unit_type,
    nonowned_controlled_share = selected_nonowned_controlled_share,
    nonowned_physical_count = selected_nonowned_physical_count,
    total_physical_count = selected_total_physical_count,
    source_url = selected_source_url
  ) |>
  arrange(fiscal_year, tier, ticker, company)

review_queue_rows <- balanced_panel |>
  filter(needs_firm_era_review)

if (nrow(review_queue_rows) == 0) {
  review_queue <- tibble(
    universe_episode_id = character(),
    company = character(),
    ticker = character(),
    tier = integer(),
    candidate_cik10 = character(),
    review_priority = integer(),
    first_review_year = integer(),
    last_review_year = integer(),
    review_needed_years = integer(),
    example_filing_url = character(),
    example_source_local_path = character(),
    generic_not_eligible_reasons = character(),
    generic_manual_review_reasons = character(),
    omega_prior_and_relevance = character(),
    fate_and_splicing_notes = character()
  )
} else {
  review_queue <- review_queue_rows |>
    group_by(universe_episode_id, company, ticker, tier, candidate_cik10) |>
    summarise(
      review_priority = first(review_priority),
      first_review_year = min(fiscal_year),
      last_review_year = max(fiscal_year),
      review_needed_years = n(),
      example_filing_url = first(selected_source_url[!is.na(selected_source_url) & selected_source_url != ""], default = NA_character_),
      example_source_local_path = first(selected_source_local_path[!is.na(selected_source_local_path) & selected_source_local_path != ""], default = NA_character_),
      generic_not_eligible_reasons = paste(sort(unique(generic_not_eligible_reason[!is.na(generic_not_eligible_reason) & generic_not_eligible_reason != ""])), collapse = "; "),
      generic_manual_review_reasons = paste(sort(unique(generic_manual_review_reason[!is.na(generic_manual_review_reason) & generic_manual_review_reason != ""])), collapse = "; "),
      omega_prior_and_relevance = first(omega_prior_and_relevance),
      fate_and_splicing_notes = first(fate_and_splicing_notes),
      .groups = "drop"
    ) |>
    arrange(review_priority, desc(review_needed_years), tier, company, candidate_cik10)
}

gap_audit <- balanced_panel |>
  filter(in_universe_episode_window, in_sec_reporting_window, sec_filing_observed, !selected_main_plot_eligible) |>
  transmute(
    company, ticker, tier, status, fiscal_year,
    candidate_cik10, selected_land_source,
    selected_review_plot_eligible, selected_manual_review_flag,
    selected_unit_type, selected_measure_definition,
    selected_owned_physical_count, selected_nonowned_physical_count,
    selected_total_physical_count, selected_nonowned_controlled_share,
    gap_reason = case_when(
      ticker == "AVHI" & fiscal_year <= 2008L ~ "missing_acres_only_no_lot_conversion",
      ticker == "AVHI" ~ "missing_land_position_total_only_no_owned_nonowned_split",
      ticker == "WCI/WCIC" & fiscal_year <= 2008L ~ "review_only_entitlement_capacity_not_physical_lots",
      ticker == "CHCI" & fiscal_year == 2009L ~ "review_only_distressed_denominator_conflict",
      ticker == "CHCI" & fiscal_year %in% c(2010L, 2011L, 2012L) ~ "missing_no_nonowned_count",
      ticker == "DFH" & fiscal_year >= 2024L ~ "pipeline_level_only_no_denominator",
      ticker == "RYL" & fiscal_year == 2004L ~ "missing_dollars_only_no_physical_lot_split",
      ticker == "LEV" & fiscal_year <= 2006L ~ "pipeline_combines_owned_and_unquantified_optioned_lots",
      ticker == "LEV" & fiscal_year == 2007L ~ "bankruptcy_exit_no_year_end_land_position",
      TRUE ~ coalesce(manual_review_reason, generic_manual_review_reason, generic_not_eligible_reason, "unclassified_gap")
    ),
    auxiliary_value_available = case_when(
      ticker == "AVHI" ~ "land-position total or acres/deposit evidence retained; no owned/non-owned split",
      ticker == "WCI/WCIC" & fiscal_year <= 2008L ~ "alternate non-owned entitlement-capacity share retained; not physical lots/homesites",
      ticker == "CHCI" & fiscal_year == 2009L ~ "distressed table values retained; foreclosure-adjusted denominator conflicts with table denominator",
      ticker == "CHCI" & fiscal_year %in% c(2010L, 2011L, 2012L) ~ "owned unsold lots retained; non-owned count absent",
      ticker == "DFH" & fiscal_year >= 2024L ~ "controlled-lot pipeline level retained; owned denominator absent",
      ticker == "RYL" & fiscal_year == 2004L ~ "option/deposit dollar exposure retained in extractor notes; physical counts absent",
      ticker == "LEV" & fiscal_year <= 2006L ~ "planned-unit pipeline retained; current developments include an unquantified optioned-lot subset",
      ticker == "LEV" & fiscal_year == 2007L ~ "bankruptcy and deconsolidation chronology retained",
      TRUE ~ "see selected and generic/manual review notes"
    ),
    recoverable_as_main_omega = FALSE,
    recommended_main_panel_treatment = "leave_omega_missing",
    recommended_auxiliary_treatment = case_when(
      ticker == "WCI/WCIC" & fiscal_year <= 2008L ~ "use_only_in_separately_labeled_entitlement_capacity_series",
      ticker == "DFH" & fiscal_year >= 2024L ~ "use_controlled_lot_level_only_not_share",
      ticker == "AVHI" ~ "use_land_position_scale_only_not_share",
      TRUE ~ "audit_only_not_main_share"
    ),
    manual_review_reason, generic_not_eligible_reason, generic_manual_review_reason,
    selected_source_note, selected_source_url, selected_source_local_path
  ) |>
  arrange(tier, company, fiscal_year)

write_csv_if_changed(balanced_panel, "../output/expanded_builder_2004_2025_land_panel.csv")
write_csv_if_changed(coverage_by_firm, "../output/expanded_builder_land_coverage_by_firm.csv")
write_csv_if_changed(coverage_by_year, "../output/expanded_builder_land_coverage_by_year.csv")
write_csv_if_changed(plot_data, "../output/expanded_builder_land_plot_data.csv")
write_csv_if_changed(review_queue, "../output/expanded_builder_land_review_queue.csv")
write_csv_if_changed(gap_audit, "../output/expanded_builder_land_gap_audit.csv")

cat("Wrote expanded builder land panel outputs to ../output\n")
