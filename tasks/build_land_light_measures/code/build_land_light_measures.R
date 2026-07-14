# setwd("/Users/jacobherbstman/Desktop/homebuilder_10ks/tasks/build_land_light_measures/code")

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(stringr)
  library(tibble)
  library(tidyr)
})

source("../../_lib/homebuilder_pipeline_utils.R")

collapse_reasons <- function(...) {
  reason_matrix <- cbind(...)
  apply(reason_matrix, 1, function(x) {
    paste(unique(x[!is.na(x) & x != ""]), collapse = "; ")
  })
}

trim_separator <- function(x) {
  x <- str_replace_all(x, ";+", ";")
  x <- str_replace_all(x, "^;|;$", "")
  na_if(x, "")
}

identity_tolerance <- function(lhs, rhs) {
  pmax(5, 0.005 * pmax(abs(lhs), abs(rhs), na.rm = TRUE), na.rm = TRUE)
}

identity_pass <- function(lhs, rhs) {
  !is.na(lhs) & !is.na(rhs) & abs(lhs - rhs) <= identity_tolerance(lhs, rhs)
}

safe_weighted_mean <- function(x, w) {
  ok <- !is.na(x) & !is.na(w) & w > 0
  if (!any(ok)) {
    return(NA_real_)
  }
  stats::weighted.mean(x[ok], w[ok])
}

panel <- read_csv("../input/public_builder_10k_land_panel.csv", show_col_types = FALSE, na = c("", "NA")) |>
  mutate(
    cik10 = as.character(cik10),
    accession_number = as.character(accession_number),
    fiscal_year = suppressWarnings(as.integer(fiscal_year)),
    filing_date = suppressWarnings(as.Date(filing_date)),
    report_date = suppressWarnings(as.Date(report_date)),
    form = coalesce(form, ""),
    standalone_sec_panel_eligible = standalone_sec_panel_eligible %in% c(TRUE, "TRUE", "true", "True", "1", 1),
    extraction_manual_review_flag = extraction_manual_review_flag %in% c(TRUE, "TRUE", "true", "True", "1", 1)
  )

preferred_values <- read_csv("../input/tenk_land_preferred_values.csv", show_col_types = FALSE, na = c("", "NA")) |>
  mutate(
    cik10 = as.character(cik10),
    accession_number = as.character(accession_number),
    fiscal_year = suppressWarnings(as.integer(fiscal_year)),
    preferred_value = suppressWarnings(as.numeric(as.character(preferred_value))),
    confidence = coalesce(confidence, ""),
    extraction_method = coalesce(extraction_method, ""),
    source_scope = coalesce(source_scope, ""),
    metric_raw_name = coalesce(metric_raw_name, ""),
    source_section = coalesce(source_section, ""),
    source_row_label = coalesce(source_row_label, ""),
    source_column_label = coalesce(source_column_label, ""),
    context_snippet = coalesce(context_snippet, ""),
    table_row_or_table_text = coalesce(table_row_or_table_text, ""),
    source_excerpt = str_squish(str_sub(
      if_else(table_row_or_table_text != "", table_row_or_table_text, context_snippet),
      1, 900
    ))
  )

selection_audit <- read_csv("../input/tenk_land_value_selection_audit.csv", show_col_types = FALSE, na = c("", "NA")) |>
  mutate(
    cik10 = as.character(cik10),
    accession_number = as.character(accession_number),
    fiscal_year = suppressWarnings(as.integer(fiscal_year)),
    selected_as_preferred = selected_as_preferred %in% c(TRUE, "TRUE", "true", "True", "1", 1),
    conflicting_high_score_values = conflicting_high_score_values %in% c(TRUE, "TRUE", "true", "True", "1", 1)
  )

if (panel |>
    count(cik10, accession_number, fiscal_year) |>
    filter(n > 1) |>
    nrow() > 0) {
  stop("Input 10-K land panel is not unique by cik10/accession_number/fiscal_year.")
}

if (preferred_values |>
    count(cik10, accession_number, fiscal_year, variable_name) |>
    filter(n > 1) |>
    nrow() > 0) {
  stop("Preferred values are not unique by cik10/accession_number/fiscal_year/variable_name.")
}

land_light_metric_names <- c(
  "owned_lots", "optioned_lots", "controlled_lots", "total_lots",
  "owned_homesites", "controlled_homesites", "total_homesites",
  "lot_purchase_agreements", "closings", "lpa_cash_deposits",
  "remaining_purchase_price", "deposits_preacquisition_costs",
  "nonrefundable_deposits_preacquisition_costs", "refundable_deposits",
  "earnest_money_deposits", "option_deposits", "option_deposit_collateral_total",
  "land_not_owned_under_option_agreements", "land_purchase_contract_obligations",
  "letters_of_credit", "surety_bonds", "guarantees"
)

metric_provenance <- preferred_values |>
  filter(variable_name %in% land_light_metric_names) |>
  transmute(
    builder_name_key, builder_name_clean, ticker, cik10, sec_company_name,
    accession_number, form, filing_date, report_date, fiscal_year,
    variable_name, preferred_value, unit, raw_value, metric_raw_name,
    source_scope, source_section, source_table_index, source_row_label,
    source_column_label, extraction_method, confidence, selection_score,
    source_excerpt, source_path, source_url
  ) |>
  arrange(ticker, fiscal_year, accession_number, variable_name)

selected_conflict_flags <- selection_audit |>
  filter(selected_as_preferred, variable_name %in% land_light_metric_names) |>
  group_by(cik10, accession_number, fiscal_year) |>
  summarise(
    land_light_conflicting_high_score_values = any(conflicting_high_score_values, na.rm = TRUE),
    land_light_selected_candidate_rows = n(),
    .groups = "drop"
  )

physical_conflict_flags <- selection_audit |>
  filter(
    selected_as_preferred,
    variable_name %in% c(
      "owned_lots", "optioned_lots", "controlled_lots", "total_lots",
      "owned_homesites", "controlled_homesites", "total_homesites",
      "lot_purchase_agreements"
    )
  ) |>
  group_by(cik10, accession_number, fiscal_year) |>
  summarise(
    physical_conflicting_high_score_values = any(conflicting_high_score_values, na.rm = TRUE),
    .groups = "drop"
  )

core_quality_flags <- metric_provenance |>
  filter(variable_name %in% c(
    "owned_lots", "optioned_lots", "controlled_lots", "total_lots",
    "owned_homesites", "controlled_homesites", "total_homesites",
    "lot_purchase_agreements"
  )) |>
  group_by(cik10, accession_number, fiscal_year) |>
  summarise(
    core_physical_low_confidence = any(confidence == "low", na.rm = TRUE),
    core_physical_snippet_selected = any(str_detect(extraction_method, "snippet"), na.rm = TRUE),
    .groups = "drop"
  )

definition_context <- metric_provenance |>
  filter(variable_name %in% c(
    "optioned_lots", "controlled_lots", "total_lots",
    "controlled_homesites", "total_homesites", "lot_purchase_agreements"
  )) |>
  mutate(
    definition_text = str_squish(str_to_lower(paste(
      metric_raw_name, source_section, source_row_label,
      source_column_label, source_excerpt
    )))
  ) |>
  select(cik10, accession_number, fiscal_year, variable_name, definition_text) |>
  pivot_wider(names_from = variable_name, values_from = definition_text, names_prefix = "definition_")

relevant_value_count <- panel |>
  select(any_of(land_light_metric_names)) |>
  mutate(row_id = row_number()) |>
  pivot_longer(cols = -row_id, values_to = "value") |>
  group_by(row_id) |>
  summarise(land_light_value_count = sum(!is.na(value)), .groups = "drop")

panel_for_selection <- panel |>
  mutate(row_id = row_number()) |>
  left_join(relevant_value_count, by = "row_id", relationship = "one-to-one") |>
  mutate(
    form_rank = case_when(
      form == "10-K" ~ 1L,
      form == "10-KT" ~ 2L,
      form == "10-K/A" ~ 3L,
      TRUE ~ 4L
    )
  ) |>
  arrange(cik10, fiscal_year, form_rank, desc(land_light_value_count), desc(filing_date), desc(accession_number)) |>
  group_by(cik10, fiscal_year) |>
  mutate(
    selected_filing_rank = row_number(),
    filings_available_same_fiscal_year = n(),
    selected_for_land_light_measures = selected_filing_rank == 1L
  ) |>
  ungroup()

duplicate_filing_audit <- panel_for_selection |>
  filter(filings_available_same_fiscal_year > 1) |>
  transmute(
    ticker, cik10, fiscal_year, accession_number, form, filing_date,
    report_date, land_light_value_count, selected_for_land_light_measures,
    filings_available_same_fiscal_year
  )

land_light_firm_year_measures <- panel_for_selection |>
  filter(selected_for_land_light_measures) |>
  select(-row_id) |>
  left_join(definition_context, by = c("cik10", "accession_number", "fiscal_year"), relationship = "one-to-one") |>
  left_join(selected_conflict_flags, by = c("cik10", "accession_number", "fiscal_year"), relationship = "one-to-one") |>
  left_join(physical_conflict_flags, by = c("cik10", "accession_number", "fiscal_year"), relationship = "one-to-one") |>
  left_join(core_quality_flags, by = c("cik10", "accession_number", "fiscal_year"), relationship = "one-to-one") |>
  mutate(
    land_light_conflicting_high_score_values = coalesce(land_light_conflicting_high_score_values, FALSE),
    physical_conflicting_high_score_values = coalesce(physical_conflicting_high_score_values, FALSE),
    land_light_selected_candidate_rows = coalesce(land_light_selected_candidate_rows, 0L),
    core_physical_low_confidence = coalesce(core_physical_low_confidence, FALSE),
    core_physical_snippet_selected = coalesce(core_physical_snippet_selected, FALSE),
    lot_owned_optioned_total_complete = !is.na(owned_lots) & !is.na(optioned_lots) & !is.na(controlled_lots),
    lot_owned_optioned_total_diff = owned_lots + optioned_lots - controlled_lots,
    lot_owned_optioned_total_pass = identity_pass(owned_lots + optioned_lots, controlled_lots),
    lot_owned_controlled_total_complete = !is.na(owned_lots) & !is.na(controlled_lots) & !is.na(total_lots),
    lot_owned_controlled_total_diff = owned_lots + controlled_lots - total_lots,
    lot_owned_controlled_total_pass = identity_pass(owned_lots + controlled_lots, total_lots),
    homesite_owned_controlled_total_complete = !is.na(owned_homesites) & !is.na(controlled_homesites) & !is.na(total_homesites),
    homesite_owned_controlled_total_diff = owned_homesites + controlled_homesites - total_homesites,
    homesite_owned_controlled_total_pass = identity_pass(owned_homesites + controlled_homesites, total_homesites),
    controlled_lots_source_nonowned_hint = str_detect(
      coalesce(definition_controlled_lots, ""),
      "purchase contract|lot purchase agreement|\\blpa\\b|controlled through|option|not owned|under contract|land bank"
    ),
    total_lots_source_contract_position_hint = str_detect(
      coalesce(definition_total_lots, ""),
      "land position in lots|lots under contract|under contract|purchase contract|option contract|owned and controlled|owned or controlled"
    ),
    has_any_physical_count = if_any(
      any_of(c(
        "owned_lots", "optioned_lots", "controlled_lots", "total_lots",
        "owned_homesites", "controlled_homesites", "total_homesites",
        "lot_purchase_agreements"
      )),
      ~ !is.na(.x)
    ),
    harmonization_rule = case_when(
      homesite_owned_controlled_total_pass ~ "homesite_owned_plus_controlled_equals_total",
      lot_owned_controlled_total_pass ~ "lot_owned_plus_controlled_equals_total",
      lot_owned_optioned_total_pass ~ "lot_owned_plus_optioned_equals_controlled_total",
      !is.na(owned_lots) & !is.na(optioned_lots) &
        is.na(controlled_lots) & is.na(total_lots) ~ "lot_owned_plus_optioned_constructed_total",
      !is.na(owned_lots) & !is.na(controlled_lots) &
        is.na(total_lots) & controlled_lots_source_nonowned_hint ~ "lot_owned_plus_nonowned_constructed_total_from_source_label",
      !is.na(owned_lots) & !is.na(total_lots) &
        is.na(controlled_lots) & is.na(optioned_lots) &
        total_lots >= owned_lots & total_lots_source_contract_position_hint ~ "lot_owned_total_residual_under_contract",
      TRUE ~ "no_physical_share"
    ),
    source_metric_meaning = case_when(
      harmonization_rule == "homesite_owned_plus_controlled_equals_total" ~ "controlled_homesites is non-owned controlled homesites; total_homesites is the denominator",
      harmonization_rule == "lot_owned_plus_controlled_equals_total" ~ "controlled_lots is non-owned controlled lots; total_lots is the denominator",
      harmonization_rule == "lot_owned_plus_optioned_equals_controlled_total" ~ "optioned_lots is non-owned controlled lots; controlled_lots is the denominator",
      harmonization_rule == "lot_owned_plus_optioned_constructed_total" ~ "optioned_lots is treated as non-owned controlled lots; denominator is owned_lots + optioned_lots",
      harmonization_rule == "lot_owned_plus_nonowned_constructed_total_from_source_label" ~ "controlled_lots is treated as non-owned controlled lots from source wording; denominator is owned_lots + controlled_lots",
      harmonization_rule == "lot_owned_total_residual_under_contract" ~ "total_lots includes owned plus under-contract/controlled lots; non-owned count is constructed as total_lots - owned_lots",
      TRUE ~ ""
    ),
    share_comparability_tier = case_when(
      harmonization_rule %in% c(
        "homesite_owned_plus_controlled_equals_total",
        "lot_owned_plus_controlled_equals_total",
        "lot_owned_plus_optioned_equals_controlled_total"
      ) ~ "explicit_identity",
      harmonization_rule %in% c(
        "lot_owned_plus_optioned_constructed_total",
        "lot_owned_plus_nonowned_constructed_total_from_source_label"
      ) ~ "constructed_total",
      harmonization_rule == "lot_owned_total_residual_under_contract" ~ "residual_nonowned",
      TRUE ~ "not_eligible"
    ),
    physical_share_tier = case_when(
      share_comparability_tier == "explicit_identity" ~ 1L,
      harmonization_rule %in% c(
        "lot_owned_plus_optioned_constructed_total",
        "lot_owned_plus_nonowned_constructed_total_from_source_label"
      ) ~ 2L,
      harmonization_rule == "lot_owned_total_residual_under_contract" ~ 3L,
      TRUE ~ NA_integer_
    ),
    physical_unit_type = case_when(
      harmonization_rule == "homesite_owned_plus_controlled_equals_total" ~ "homesites",
      harmonization_rule != "no_physical_share" ~ "lots",
      TRUE ~ NA_character_
    ),
    owned_physical_count = case_when(
      physical_unit_type == "homesites" ~ owned_homesites,
      physical_unit_type == "lots" ~ owned_lots,
      TRUE ~ NA_real_
    ),
    nonowned_physical_count = case_when(
      harmonization_rule == "homesite_owned_plus_controlled_equals_total" ~ controlled_homesites,
      harmonization_rule == "lot_owned_plus_controlled_equals_total" ~ controlled_lots,
      harmonization_rule == "lot_owned_plus_optioned_equals_controlled_total" ~ optioned_lots,
      harmonization_rule == "lot_owned_plus_optioned_constructed_total" ~ optioned_lots,
      harmonization_rule == "lot_owned_plus_nonowned_constructed_total_from_source_label" ~ controlled_lots,
      harmonization_rule == "lot_owned_total_residual_under_contract" ~ total_lots - owned_lots,
      TRUE ~ NA_real_
    ),
    total_controlled_physical_count = case_when(
      harmonization_rule == "homesite_owned_plus_controlled_equals_total" ~ total_homesites,
      harmonization_rule == "lot_owned_plus_controlled_equals_total" ~ total_lots,
      harmonization_rule == "lot_owned_plus_optioned_equals_controlled_total" ~ controlled_lots,
      harmonization_rule == "lot_owned_plus_optioned_constructed_total" ~ owned_lots + optioned_lots,
      harmonization_rule == "lot_owned_plus_nonowned_constructed_total_from_source_label" ~ owned_lots + controlled_lots,
      harmonization_rule == "lot_owned_total_residual_under_contract" ~ total_lots,
      TRUE ~ NA_real_
    ),
    nonowned_value_source = case_when(
      harmonization_rule %in% c(
        "homesite_owned_plus_controlled_equals_total",
        "lot_owned_plus_controlled_equals_total",
        "lot_owned_plus_optioned_equals_controlled_total",
        "lot_owned_plus_optioned_constructed_total",
        "lot_owned_plus_nonowned_constructed_total_from_source_label"
      ) ~ "direct_reported",
      harmonization_rule == "lot_owned_total_residual_under_contract" ~ "residual_total_minus_owned",
      TRUE ~ "unavailable"
    ),
    total_value_source = case_when(
      harmonization_rule %in% c(
        "homesite_owned_plus_controlled_equals_total",
        "lot_owned_plus_controlled_equals_total",
        "lot_owned_plus_optioned_equals_controlled_total",
        "lot_owned_total_residual_under_contract"
      ) ~ "direct_reported",
      harmonization_rule %in% c(
        "lot_owned_plus_optioned_constructed_total",
        "lot_owned_plus_nonowned_constructed_total_from_source_label"
      ) ~ "owned_plus_nonowned",
      TRUE ~ "unavailable"
    ),
    denominator_basis = case_when(
      total_value_source == "direct_reported" ~ "reported_total",
      total_value_source == "owned_plus_nonowned" ~ "constructed_total",
      TRUE ~ "none"
    ),
    physical_share_constructed_denominator = denominator_basis == "constructed_total",
    physical_share_constructed_numerator_residual = nonowned_value_source == "residual_total_minus_owned",
    physical_share_identity_verified = share_comparability_tier == "explicit_identity",
    physical_share_identity_gap = case_when(
      harmonization_rule == "homesite_owned_plus_controlled_equals_total" ~ homesite_owned_controlled_total_diff,
      harmonization_rule == "lot_owned_plus_controlled_equals_total" ~ lot_owned_controlled_total_diff,
      harmonization_rule == "lot_owned_plus_optioned_equals_controlled_total" ~ lot_owned_optioned_total_diff,
      TRUE ~ NA_real_
    ),
    physical_share_identity_gap_pct = if_else(
      !is.na(physical_share_identity_gap) & !is.na(total_controlled_physical_count) &
        total_controlled_physical_count > 0,
      physical_share_identity_gap / total_controlled_physical_count,
      NA_real_
    ),
    nonowned_controlled_share = if_else(
      !is.na(nonowned_physical_count) & !is.na(total_controlled_physical_count) &
        total_controlled_physical_count > 0,
      nonowned_physical_count / total_controlled_physical_count,
      NA_real_
    ),
    eligible_nonowned_share = !is.na(nonowned_controlled_share) &
      nonowned_controlled_share >= 0 & nonowned_controlled_share <= 1 &
      !is.na(owned_physical_count),
    nonowned_pipeline_count = case_when(
      !is.na(lot_purchase_agreements) ~ lot_purchase_agreements,
      eligible_nonowned_share ~ nonowned_physical_count,
      !is.na(controlled_lots) & controlled_lots_source_nonowned_hint ~ controlled_lots,
      TRUE ~ NA_real_
    ),
    total_pipeline_count = case_when(
      eligible_nonowned_share ~ total_controlled_physical_count,
      !is.na(controlled_lots) ~ controlled_lots,
      !is.na(total_lots) ~ total_lots,
      !is.na(total_homesites) ~ total_homesites,
      TRUE ~ NA_real_
    ),
    nonowned_pipeline_per_closing = if_else(
      !is.na(nonowned_pipeline_count) & !is.na(closings) & closings > 0,
      nonowned_pipeline_count / closings,
      NA_real_
    ),
    total_pipeline_per_closing = if_else(
      !is.na(total_pipeline_count) & !is.na(closings) & closings > 0,
      total_pipeline_count / closings,
      NA_real_
    ),
    eligible_nonowned_pipeline = !is.na(nonowned_pipeline_per_closing),
    financial_deposit_balance = coalesce(
      deposits_preacquisition_costs, lpa_cash_deposits,
      option_deposit_collateral_total, option_deposits, earnest_money_deposits,
      nonrefundable_deposits_preacquisition_costs, refundable_deposits
    ),
    financial_deposit_metric = case_when(
      !is.na(deposits_preacquisition_costs) ~ "deposits_preacquisition_costs",
      !is.na(lpa_cash_deposits) ~ "lpa_cash_deposits",
      !is.na(option_deposit_collateral_total) ~ "option_deposit_collateral_total",
      !is.na(option_deposits) ~ "option_deposits",
      !is.na(earnest_money_deposits) ~ "earnest_money_deposits",
      !is.na(nonrefundable_deposits_preacquisition_costs) ~ "nonrefundable_deposits_preacquisition_costs",
      !is.na(refundable_deposits) ~ "refundable_deposits",
      TRUE ~ ""
    ),
    financial_purchase_obligation_balance = coalesce(
      remaining_purchase_price, land_purchase_contract_obligations,
      land_not_owned_under_option_agreements
    ),
    financial_purchase_obligation_metric = case_when(
      !is.na(remaining_purchase_price) ~ "remaining_purchase_price",
      !is.na(land_purchase_contract_obligations) ~ "land_purchase_contract_obligations",
      !is.na(land_not_owned_under_option_agreements) ~ "land_not_owned_under_option_agreements",
      TRUE ~ ""
    ),
    financial_deposit_rate = if_else(
      !is.na(financial_deposit_balance) & !is.na(financial_purchase_obligation_balance) &
        financial_purchase_obligation_balance > 0,
      financial_deposit_balance / financial_purchase_obligation_balance,
      NA_real_
    ),
    financial_deposit_to_inventory = if_else(
      !is.na(financial_deposit_balance) & !is.na(total_inventory) & total_inventory > 0,
      financial_deposit_balance / total_inventory,
      NA_real_
    ),
    financial_purchase_obligation_to_inventory = if_else(
      !is.na(financial_purchase_obligation_balance) & !is.na(total_inventory) & total_inventory > 0,
      financial_purchase_obligation_balance / total_inventory,
      NA_real_
    ),
    eligible_financial_exposure = !is.na(financial_deposit_balance) |
      !is.na(financial_purchase_obligation_balance),
    contract_type_observed = trim_separator(paste(
      if_else(!is.na(lot_purchase_agreements) | !is.na(lpa_cash_deposits), "lpa", ""),
      if_else(!is.na(optioned_lots) | !is.na(option_deposits) |
                !is.na(deposits_preacquisition_costs) |
                !is.na(nonrefundable_deposits_preacquisition_costs) |
                !is.na(refundable_deposits) |
                !is.na(option_deposit_collateral_total), "option", ""),
      if_else(!is.na(remaining_purchase_price) |
                !is.na(land_purchase_contract_obligations) |
                !is.na(land_not_owned_under_option_agreements), "purchase_obligation", ""),
      if_else(!is.na(letters_of_credit) | !is.na(surety_bonds) |
                !is.na(guarantees), "guarantee_or_collateral", ""),
      sep = ";"
    )),
    physical_identity_failure = (lot_owned_optioned_total_complete & !lot_owned_optioned_total_pass) |
      (lot_owned_controlled_total_complete & !lot_owned_controlled_total_pass) |
      (homesite_owned_controlled_total_complete & !homesite_owned_controlled_total_pass),
    not_eligible_reason = case_when(
      eligible_nonowned_share ~ "",
      !has_any_physical_count ~ "no_physical_land_count_selected",
      TRUE ~ "partial_or_ambiguous_physical_counts_without_harmonized_denominator"
    ),
    manual_review_reason = collapse_reasons(
      if_else(physical_identity_failure, "physical_identity_failure", ""),
      if_else(physical_share_constructed_numerator_residual, "residual_numerator_requires_source_table_verification", ""),
      if_else(core_physical_low_confidence, "low_confidence_selected_physical_metric", ""),
      if_else(!eligible_nonowned_share & has_any_physical_count,
              "partial_or_ambiguous_physical_counts_without_harmonized_denominator", "")
    ),
    manual_review_flag = manual_review_reason != "",
    provenance_review_reason = collapse_reasons(
      if_else(core_physical_snippet_selected, "snippet_selected_physical_metric", ""),
      if_else(physical_share_constructed_denominator, "constructed_denominator_from_direct_components", ""),
      if_else(physical_share_constructed_numerator_residual, "residual_nonowned_total_minus_owned", ""),
      if_else(physical_conflicting_high_score_values, "conflicting_high_score_physical_candidates", ""),
      if_else(land_light_conflicting_high_score_values, "conflicting_high_score_land_light_candidates", ""),
      if_else(filings_available_same_fiscal_year > 1, "multiple_filings_same_fiscal_year", "")
    ),
    provenance_review_flag = provenance_review_reason != "",
    analysis_ready_explicit_identity = eligible_nonowned_share &
      share_comparability_tier == "explicit_identity",
    main_plot_eligible = eligible_nonowned_share &
      physical_share_tier %in% c(1L, 2L) &
      !physical_identity_failure &
      !core_physical_low_confidence,
    robustness_plot_eligible = eligible_nonowned_share &
      physical_share_tier %in% c(1L, 2L, 3L) &
      !physical_identity_failure,
    analysis_ready_strict = eligible_nonowned_share &
      share_comparability_tier == "explicit_identity" &
      !manual_review_flag &
      !provenance_review_flag,
    analysis_ready_with_review = eligible_nonowned_share &
      share_comparability_tier %in% c("explicit_identity", "constructed_total"),
    public_builder_closings_weight = coalesce(closings, total_closings),
    public_builder_closings_weight_source = case_when(
      !is.na(closings) ~ "sec_10k_closings",
      !is.na(total_closings) ~ "builder_magazine_closings",
      TRUE ~ ""
    )
  ) |>
  select(
    builder_name_key, builder_name_clean, ticker, cik, cik10, sec_company_name,
    accession_number, accession_number_no_dashes, form, filing_date, report_date,
    fiscal_year, primary_document, filing_url, primary_document_local_path,
    harmonized_builder_id, harmonized_builder_name, best_builder_rank,
    total_closings, gross_revenue_homebuilding_millions,
    standalone_sec_panel_eligible, firm_year_manual_review_indicator,
    filings_available_same_fiscal_year, land_light_value_count,
    owned_lots, optioned_lots, controlled_lots, total_lots,
    owned_homesites, controlled_homesites, total_homesites,
    lot_purchase_agreements, closings,
    owned_physical_count, nonowned_physical_count, total_controlled_physical_count,
    physical_unit_type, nonowned_controlled_share, harmonization_rule,
    source_metric_meaning, share_comparability_tier, physical_share_tier,
    nonowned_value_source, total_value_source, denominator_basis,
    physical_share_constructed_denominator,
    physical_share_constructed_numerator_residual,
    physical_share_identity_verified, physical_share_identity_gap,
    physical_share_identity_gap_pct,
    eligible_nonowned_share,
    analysis_ready_strict, analysis_ready_with_review,
    analysis_ready_explicit_identity, main_plot_eligible,
    robustness_plot_eligible,
    nonowned_pipeline_count, total_pipeline_count,
    nonowned_pipeline_per_closing, total_pipeline_per_closing,
    eligible_nonowned_pipeline, financial_deposit_balance,
    financial_deposit_metric, financial_purchase_obligation_balance,
    financial_purchase_obligation_metric, financial_deposit_rate,
    financial_deposit_to_inventory, financial_purchase_obligation_to_inventory,
    eligible_financial_exposure, contract_type_observed,
    lot_owned_optioned_total_complete, lot_owned_optioned_total_diff,
    lot_owned_optioned_total_pass, lot_owned_controlled_total_complete,
    lot_owned_controlled_total_diff, lot_owned_controlled_total_pass,
    homesite_owned_controlled_total_complete,
    homesite_owned_controlled_total_diff,
    homesite_owned_controlled_total_pass,
    core_physical_low_confidence, core_physical_snippet_selected,
    physical_conflicting_high_score_values,
    land_light_conflicting_high_score_values,
    physical_identity_failure, not_eligible_reason,
    manual_review_flag, manual_review_reason,
    provenance_review_flag, provenance_review_reason,
    public_builder_closings_weight, public_builder_closings_weight_source
  ) |>
  arrange(ticker, fiscal_year)

land_light_identity_audit <- bind_rows(
  land_light_firm_year_measures |>
    transmute(
      ticker, cik10, accession_number, fiscal_year,
      identity_check = "owned_lots_plus_optioned_lots_equals_controlled_lots",
      lhs_value = owned_lots + optioned_lots,
      rhs_value = controlled_lots,
      discrepancy = lot_owned_optioned_total_diff,
      tolerance = identity_tolerance(owned_lots + optioned_lots, controlled_lots),
      identity_complete = lot_owned_optioned_total_complete,
      identity_pass = lot_owned_optioned_total_pass
    ),
  land_light_firm_year_measures |>
    transmute(
      ticker, cik10, accession_number, fiscal_year,
      identity_check = "owned_lots_plus_controlled_lots_equals_total_lots",
      lhs_value = owned_lots + controlled_lots,
      rhs_value = total_lots,
      discrepancy = lot_owned_controlled_total_diff,
      tolerance = identity_tolerance(owned_lots + controlled_lots, total_lots),
      identity_complete = lot_owned_controlled_total_complete,
      identity_pass = lot_owned_controlled_total_pass
    ),
  land_light_firm_year_measures |>
    transmute(
      ticker, cik10, accession_number, fiscal_year,
      identity_check = "owned_homesites_plus_controlled_homesites_equals_total_homesites",
      lhs_value = owned_homesites + controlled_homesites,
      rhs_value = total_homesites,
      discrepancy = homesite_owned_controlled_total_diff,
      tolerance = identity_tolerance(owned_homesites + controlled_homesites, total_homesites),
      identity_complete = homesite_owned_controlled_total_complete,
      identity_pass = homesite_owned_controlled_total_pass
    )
) |>
  filter(identity_complete) |>
  arrange(ticker, fiscal_year, identity_check)

land_light_manual_review <- land_light_firm_year_measures |>
  filter(manual_review_flag | !eligible_nonowned_share | physical_identity_failure) |>
  transmute(
    ticker, cik10, sec_company_name, fiscal_year, accession_number, form,
    filing_date, harmonized_builder_name, eligible_nonowned_share,
    share_comparability_tier, harmonization_rule, physical_unit_type,
    owned_lots, optioned_lots, controlled_lots, total_lots,
    owned_homesites, controlled_homesites, total_homesites,
    lot_purchase_agreements, nonowned_controlled_share,
    nonowned_pipeline_per_closing, eligible_financial_exposure,
    manual_review_flag, manual_review_reason, not_eligible_reason,
    primary_document_local_path, filing_url
  ) |>
  arrange(ticker, fiscal_year)

land_light_measure_coverage_by_firm <- land_light_firm_year_measures |>
  group_by(ticker, cik10, sec_company_name) |>
  summarise(
    harmonized_builder_name = first(harmonized_builder_name[!is.na(harmonized_builder_name)], default = NA_character_),
    filing_years = n(),
    first_fiscal_year = min(fiscal_year, na.rm = TRUE),
    last_fiscal_year = max(fiscal_year, na.rm = TRUE),
    eligible_nonowned_share_years = sum(eligible_nonowned_share, na.rm = TRUE),
    analysis_ready_explicit_identity_years = sum(analysis_ready_explicit_identity, na.rm = TRUE),
    main_plot_eligible_years = sum(main_plot_eligible, na.rm = TRUE),
    robustness_plot_eligible_years = sum(robustness_plot_eligible, na.rm = TRUE),
    analysis_ready_strict_years = sum(analysis_ready_strict, na.rm = TRUE),
    analysis_ready_with_review_years = sum(analysis_ready_with_review, na.rm = TRUE),
    nonowned_pipeline_years = sum(eligible_nonowned_pipeline, na.rm = TRUE),
    financial_exposure_years = sum(eligible_financial_exposure, na.rm = TRUE),
    manual_review_years = sum(manual_review_flag, na.rm = TRUE),
    physical_unit_types = paste(sort(unique(physical_unit_type[!is.na(physical_unit_type)])), collapse = ";"),
    harmonization_rules = paste(sort(unique(harmonization_rule)), collapse = ";"),
    .groups = "drop"
  ) |>
  arrange(ticker)

land_light_measure_coverage_by_year <- land_light_firm_year_measures |>
  group_by(fiscal_year) |>
  summarise(
    sec_filing_firms = n_distinct(cik10),
    eligible_nonowned_share_firms = sum(eligible_nonowned_share, na.rm = TRUE),
    analysis_ready_explicit_identity_firms = sum(analysis_ready_explicit_identity, na.rm = TRUE),
    main_plot_eligible_firms = sum(main_plot_eligible, na.rm = TRUE),
    robustness_plot_eligible_firms = sum(robustness_plot_eligible, na.rm = TRUE),
    analysis_ready_strict_firms = sum(analysis_ready_strict, na.rm = TRUE),
    analysis_ready_with_review_firms = sum(analysis_ready_with_review, na.rm = TRUE),
    nonowned_pipeline_firms = sum(eligible_nonowned_pipeline, na.rm = TRUE),
    financial_exposure_firms = sum(eligible_financial_exposure, na.rm = TRUE),
    manual_review_firms = sum(manual_review_flag, na.rm = TRUE),
    strict_share_closings_weight = sum(public_builder_closings_weight[analysis_ready_strict], na.rm = TRUE),
    all_available_closings_weight = sum(public_builder_closings_weight, na.rm = TRUE),
    strict_share_closings_coverage = if_else(
      all_available_closings_weight > 0,
      strict_share_closings_weight / all_available_closings_weight,
      NA_real_
    ),
    .groups = "drop"
  ) |>
  arrange(fiscal_year)

land_light_plot_summary <- bind_rows(
  land_light_firm_year_measures |>
    filter(analysis_ready_explicit_identity) |>
    mutate(sample_definition = "explicit_identity_all_provenance_flags_retained"),
  land_light_firm_year_measures |>
    filter(main_plot_eligible) |>
    mutate(sample_definition = "main_plot_tier_1_or_2"),
  land_light_firm_year_measures |>
    filter(robustness_plot_eligible) |>
    mutate(sample_definition = "robustness_plot_tier_1_to_3"),
  land_light_firm_year_measures |>
    filter(analysis_ready_strict) |>
    mutate(sample_definition = "strict_explicit_identity_no_blocking_or_provenance_flags"),
  land_light_firm_year_measures |>
    filter(analysis_ready_with_review) |>
    mutate(sample_definition = "eligible_including_constructed_or_review")
) |>
  group_by(fiscal_year, sample_definition) |>
  summarise(
    firms = n(),
    median_nonowned_share = median(nonowned_controlled_share, na.rm = TRUE),
    p25_nonowned_share = quantile(nonowned_controlled_share, 0.25, na.rm = TRUE, names = FALSE),
    p75_nonowned_share = quantile(nonowned_controlled_share, 0.75, na.rm = TRUE, names = FALSE),
    mean_nonowned_share = mean(nonowned_controlled_share, na.rm = TRUE),
    closings_weighted_nonowned_share = safe_weighted_mean(
      nonowned_controlled_share, public_builder_closings_weight
    ),
    closings_weight_sum = sum(public_builder_closings_weight, na.rm = TRUE),
    .groups = "drop"
  ) |>
  arrange(fiscal_year, sample_definition)

write_csv_if_changed(land_light_firm_year_measures, "../output/land_light_firm_year_measures.csv")
write_csv_if_changed(land_light_measure_coverage_by_year, "../output/land_light_measure_coverage_by_year.csv")
write_csv_if_changed(land_light_measure_coverage_by_firm, "../output/land_light_measure_coverage_by_firm.csv")
write_csv_if_changed(land_light_identity_audit, "../output/land_light_identity_audit.csv")
write_csv_if_changed(metric_provenance, "../output/land_light_metric_provenance.csv")
write_csv_if_changed(land_light_manual_review, "../output/land_light_manual_review.csv")
write_csv_if_changed(land_light_plot_summary, "../output/land_light_plot_summary.csv")

cat("Wrote harmonized land-light measure outputs to ../output\n")
