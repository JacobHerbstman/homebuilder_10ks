# setwd("/Users/jacobherbstman/Desktop/homebuilder_10ks/tasks/build_10k_land_panel/code")

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(stringr)
  library(tibble)
  library(tidyr)
})

source("../../_lib/homebuilder_pipeline_utils.R")

as_task_int <- function(x) {
  suppressWarnings(as.integer(as.character(x)))
}

as_task_num <- function(x) {
  suppressWarnings(as.numeric(as.character(x)))
}

as_task_bool <- function(x) {
  x %in% c(TRUE, "TRUE", "true", "True", "1", 1)
}

preferred_metric_names <- c(
  "owned_lots", "optioned_lots", "controlled_lots", "total_lots",
  "owned_homesites", "controlled_homesites", "total_homesites",
  "developed_share_owned", "developed_share_optioned", "developed_share_controlled",
  "lot_purchase_agreements", "optioned_lots_approved_for_purchase",
  "optioned_lots_pending_approval", "homes_in_inventory",
  "remaining_purchase_price", "deposits_preacquisition_costs",
  "deposits_and_preacquisition_costs", "refundable_deposits",
  "nonrefundable_deposits_preacquisition_costs",
  "earnest_money_deposits", "option_deposits", "land_not_owned_under_option_agreements",
  "land_purchase_contract_obligations", "lpa_cash_deposits",
  "closings", "closings_deliveries", "net_new_orders_units",
  "net_new_orders_dollars", "cancellation_rate", "active_communities",
  "backlog_units", "backlog_dollars", "average_selling_price",
  "home_sale_revenue", "land_sale_revenue", "land_sale_cost",
  "home_sale_gross_margin", "homes_under_construction_inventory",
  "land_under_development", "land_held_for_future_development",
  "land_held_for_sale", "land_held_for_sale_gross",
  "land_held_for_sale_nrv_reserve", "total_inventory", "total_assets",
  "land_related_charges_total", "land_community_valuation_adjustments",
  "nrv_adjustments_land_held_for_sale", "writeoff_deposits_preacquisition_costs",
  "deposit_write_offs", "jv_impairments", "letters_of_credit",
  "surety_bonds", "guarantees"
)

candidates <- read_csv("../input/tenk_land_candidates.csv", show_col_types = FALSE, na = c("", "NA")) |>
  mutate(
    cik10 = as.character(cik10),
    accession_number = as.character(accession_number),
    fiscal_year = as_task_int(fiscal_year),
    numeric_value = as_task_num(numeric_value),
    candidate_score = as_task_num(candidate_score),
    statement_scale_factor = as_task_num(statement_scale_factor),
    period_year = as_task_int(str_extract(as.character(period_label), "(19|20)\\d{2}")),
    candidate_score = coalesce(candidate_score, 0),
    source_scope = coalesce(source_scope, ""),
    table_scale_label = coalesce(table_scale_label, ""),
    extraction_method = coalesce(extraction_method, ""),
    confidence = coalesce(confidence, ""),
    variable_name = if_else(variable_name == "deposits_and_preacquisition_costs", "deposits_preacquisition_costs", variable_name),
    variable_name = if_else(variable_name == "closings_deliveries", "closings", variable_name),
    physical_unit_type = case_when(
      str_detect(variable_name, "homesite") ~ "homesite",
      str_detect(variable_name, "lot|lpa") ~ "lot",
      variable_name %in% c("closings", "net_new_orders_units", "backlog_units") ~ "home",
      variable_name == "active_communities" ~ "community",
      unit == "dollars" ~ "dollar",
      unit == "percent" ~ "percent",
      TRUE ~ "unknown"
    ),
    contract_type = case_when(
      variable_name %in% c("owned_lots", "owned_homesites") ~ "owned",
      variable_name %in% c("optioned_lots", "optioned_lots_approved_for_purchase",
                           "optioned_lots_pending_approval", "remaining_purchase_price",
                           "deposits_preacquisition_costs", "refundable_deposits",
                           "nonrefundable_deposits_preacquisition_costs",
                           "land_not_owned_under_option_agreements") ~ "option",
      variable_name %in% c("lot_purchase_agreements", "lpa_cash_deposits") ~ "lpa",
      variable_name == "land_purchase_contract_obligations" ~ "land_bank_or_purchase_contract",
      variable_name %in% c("controlled_lots", "controlled_homesites", "total_lots", "total_homesites") ~ "mixed_controlled",
      TRUE ~ ""
    ),
    metric_is_exact_table_value = extraction_method == "table_cell_structured",
    metric_is_rounded_prose = source_scope == "filing_snippet" & str_detect(str_to_lower(coalesce(context_snippet, "")), "approximately|approx\\.|about"),
    metric_is_approximate = metric_is_rounded_prose | str_detect(str_to_lower(coalesce(raw_value, "")), "approximately|approx\\.|about"),
    metric_uses_statement_scale = !is.na(statement_scale_factor) & statement_scale_factor != 1,
    metric_uses_table_scale = table_scale_label != "",
    metric_uses_metric_specific_scale = variable_name %in% c("average_selling_price", "lpa_cash_deposits"),
    metric_is_reported_total = source_scope == "firm_year" |
      str_to_lower(coalesce(source_row_label, "")) %in% c("total", "total lots", "total homesites", "total owned and optioned lots"),
    metric_is_sum_of_segments = FALSE,
    included_in_reported_total_controlled = variable_name %in% c(
      "owned_lots", "optioned_lots", "controlled_lots", "total_lots",
      "owned_homesites", "controlled_homesites", "total_homesites",
      "lot_purchase_agreements"
    ),
    manual_review_reason = case_when(
      variable_name %in% c("controlled_lots", "controlled_homesites", "total_lots", "total_homesites") & contract_type == "mixed_controlled" ~ "reported_controlled_definition_varies_by_firm",
      metric_is_rounded_prose ~ "rounded_prose_candidate",
      TRUE ~ ""
    )
  ) |>
  filter(!is.na(accession_number), !is.na(numeric_value), variable_name %in% preferred_metric_names)

download_inventory <- read_csv("../input/sec_10k_download_inventory.csv", show_col_types = FALSE, na = c("", "NA")) |>
  mutate(
    cik10 = as.character(cik10),
    accession_number = as.character(accession_number),
    fiscal_year = as_task_int(fiscal_year),
    report_date = suppressWarnings(as.Date(report_date)),
    filing_date = suppressWarnings(as.Date(filing_date))
  ) |>
  filter(primary_document_status %in% c("downloaded", "already_present"))

if (download_inventory |>
    count(cik10, accession_number) |>
    filter(n > 1) |>
    nrow() > 0) {
  stop("SEC download inventory is not unique by cik10/accession_number.")
}

builder_firm_years <- read_csv("../input/builder_public_firm_year_identifiers.csv", show_col_types = FALSE, na = c("", "NA")) |>
  mutate(
    cik10 = as.character(cik10),
    builder_activity_year = as_task_int(builder_activity_year),
    standalone_sec_panel_eligible = as_task_bool(standalone_sec_panel_eligible),
    firm_year_manual_review_indicator = as_task_bool(firm_year_manual_review_indicator)
  ) |>
  select(
    builder_name_key, cik10, builder_activity_year, harmonized_builder_id,
    harmonized_builder_name, best_builder_rank, total_closings,
    gross_revenue_homebuilding_millions, standalone_sec_panel_eligible,
    firm_year_manual_review_indicator
  ) |>
  distinct(builder_name_key, cik10, builder_activity_year, .keep_all = TRUE)

scored_candidates <- candidates |>
  mutate(
    period_rank = case_when(
      !is.na(period_year) & !is.na(fiscal_year) & period_year == fiscal_year ~ 60,
      is.na(period_year) ~ 20,
      TRUE ~ -80
    ),
    scope_rank = case_when(
      source_scope == "firm_year" ~ 90,
      source_scope == "filing_snippet" ~ 45,
      source_scope == "contract_structure" ~ 35,
      source_scope == "segment_year" ~ 20,
      TRUE ~ 25
    ),
    method_rank = case_when(
      extraction_method == "table_cell_structured" ~ 45,
      str_detect(extraction_method, "snippet") ~ 15,
      TRUE ~ 0
    ),
    confidence_rank = case_when(
      confidence == "high" ~ 20,
      confidence == "medium" ~ 10,
      TRUE ~ 0
    ),
    total_rank = if_else(str_to_lower(coalesce(source_row_label, "")) == "total", 20, 0),
    selection_score = candidate_score + period_rank + scope_rank + method_rank + confidence_rank + total_rank
  ) |>
  group_by(cik10, accession_number, fiscal_year, variable_name) |>
  mutate(
    selection_score = selection_score + if_else(
      variable_name == "remaining_purchase_price" &
        numeric_value == max(numeric_value, na.rm = TRUE),
      25,
      0
    )
  ) |>
  ungroup()

firm_year_candidates <- scored_candidates |>
  filter(source_scope %in% c("firm_year", "filing_snippet", "contract_structure", "")) |>
  arrange(
    cik10, accession_number, variable_name, desc(selection_score),
    desc(extraction_method == "table_cell_structured"),
    desc(confidence == "high")
  ) |>
  group_by(cik10, accession_number, fiscal_year, variable_name) |>
  mutate(selection_rank = row_number()) |>
  ungroup()

preferred_values <- firm_year_candidates |>
  filter(selection_rank == 1) |>
  transmute(
    builder_name_key, builder_name_clean, ticker, cik, cik10, sec_company_name,
    accession_number, accession_number_no_dashes, form, filing_date, report_date,
    fiscal_year, primary_document, filing_url, variable_name, preferred_value = numeric_value,
    unit, raw_value, metric_raw_name, metric_family, source_scope, period_label,
    segment_label, source_section, source_table_index, source_row_label,
    source_column_label, table_scale_label, statement_scale_factor,
    scale_factor_applied, candidate_score, context_snippet,
    table_row_or_table_text, extraction_method, confidence, selection_score,
    physical_unit_type, contract_type, metric_is_reported_total,
    metric_is_sum_of_segments, metric_is_rounded_prose, metric_is_exact_table_value,
    metric_is_approximate, metric_uses_statement_scale, metric_uses_table_scale,
    metric_uses_metric_specific_scale, included_in_reported_total_controlled,
    manual_review_reason,
    source_path, source_url, notes
  )

conflict_flags <- firm_year_candidates |>
  filter(selection_score >= 75) |>
  group_by(cik10, accession_number, fiscal_year, variable_name) |>
  summarise(
    high_score_candidate_values = n_distinct(round(numeric_value, 6), na.rm = TRUE),
    conflicting_high_score_values = high_score_candidate_values > 1,
    .groups = "drop"
  )

selected_keys <- preferred_values |>
  transmute(cik10, accession_number, fiscal_year, variable_name, selected_value = preferred_value)

value_selection_audit <- firm_year_candidates |>
  left_join(selected_keys, by = c("cik10", "accession_number", "fiscal_year", "variable_name"), relationship = "many-to-one") |>
  left_join(conflict_flags, by = c("cik10", "accession_number", "fiscal_year", "variable_name"), relationship = "many-to-one") |>
  mutate(
    selected_as_preferred = selection_rank == 1,
    selected_value = coalesce(selected_value, NA_real_),
    conflicting_high_score_values = coalesce(conflicting_high_score_values, FALSE)
  ) |>
  select(
    builder_name_key, ticker, cik10, accession_number, fiscal_year, variable_name,
    raw_value, numeric_value, selected_value, unit, selected_as_preferred,
    selection_score, confidence, extraction_method, source_scope, segment_label,
    period_label, source_table_index, source_row_label, source_column_label,
    physical_unit_type, contract_type, metric_is_reported_total,
    metric_is_sum_of_segments, metric_is_rounded_prose, metric_is_exact_table_value,
    metric_is_approximate, metric_uses_statement_scale, metric_uses_table_scale,
    metric_uses_metric_specific_scale, included_in_reported_total_controlled,
    manual_review_reason, conflicting_high_score_values, context_snippet,
    table_row_or_table_text, source_path
  ) |>
  arrange(ticker, fiscal_year, variable_name, desc(selected_as_preferred), desc(selection_score))

segment_year_panel <- scored_candidates |>
  filter(source_scope == "segment_year", metric_family %in% c("land_control", "risk_accounting", "inventory_accounting")) |>
  arrange(
    cik10, accession_number, fiscal_year, segment_label, variable_name,
    desc(selection_score), desc(confidence == "high")
  ) |>
  group_by(cik10, accession_number, fiscal_year, segment_label, variable_name) |>
  slice(1) |>
  ungroup() |>
  transmute(
    builder_name_key, builder_name_clean, ticker, cik10, sec_company_name,
    accession_number, form, filing_date, report_date, fiscal_year,
    segment_label, variable_name, value = numeric_value, unit,
    raw_value, source_table_index, source_row_label, source_column_label,
    extraction_method, confidence, selection_score, source_path
  ) |>
  arrange(ticker, fiscal_year, segment_label, variable_name)

preferred_wide <- preferred_values |>
  select(cik10, accession_number, fiscal_year, variable_name, preferred_value) |>
  distinct(cik10, accession_number, fiscal_year, variable_name, .keep_all = TRUE) |>
  pivot_wider(names_from = variable_name, values_from = preferred_value)

for (metric_name in setdiff(preferred_metric_names, names(preferred_wide))) {
  preferred_wide[[metric_name]] <- NA_real_
}

panel_base <- download_inventory |>
  select(
    builder_name_key, builder_name_clean, ticker, cik, cik10, sec_company_name,
    accession_number, accession_number_no_dashes, form, filing_date, report_date,
    fiscal_year, primary_document, filing_url, primary_document_local_path
  ) |>
  left_join(
    builder_firm_years,
    by = c("builder_name_key", "cik10", "fiscal_year" = "builder_activity_year"),
    relationship = "many-to-one"
  )

public_builder_10k_land_panel <- panel_base |>
  left_join(preferred_wide, by = c("cik10", "accession_number", "fiscal_year"), relationship = "one-to-one") |>
  mutate(
    optioned_share = if_else(!is.na(optioned_lots) & !is.na(controlled_lots) & controlled_lots != 0, optioned_lots / controlled_lots, NA_real_),
    controlled_share = case_when(
      !is.na(controlled_lots) & !is.na(total_lots) & total_lots != 0 ~ controlled_lots / total_lots,
      !is.na(controlled_homesites) & !is.na(total_homesites) & total_homesites != 0 ~ controlled_homesites / total_homesites,
      TRUE ~ NA_real_
    ),
    controlled_lots_per_closing = if_else(!is.na(controlled_lots) & !is.na(closings) & closings != 0, controlled_lots / closings, NA_real_),
    owned_lots_per_closing = if_else(!is.na(owned_lots) & !is.na(closings) & closings != 0, owned_lots / closings, NA_real_),
    optioned_lots_per_closing = if_else(!is.na(optioned_lots) & !is.na(closings) & closings != 0, optioned_lots / closings, NA_real_),
    deposit_rate = if_else(!is.na(deposits_preacquisition_costs) & !is.na(remaining_purchase_price) & remaining_purchase_price != 0, deposits_preacquisition_costs / remaining_purchase_price, NA_real_),
    remaining_purchase_price_per_optioned_lot = if_else(!is.na(remaining_purchase_price) & !is.na(optioned_lots) & optioned_lots != 0, remaining_purchase_price / optioned_lots, NA_real_),
    land_sale_margin = if_else(!is.na(land_sale_revenue) & !is.na(land_sale_cost), land_sale_revenue - land_sale_cost, NA_real_),
    controlled_share_physical_unit_type = case_when(
      !is.na(controlled_lots) & !is.na(total_lots) ~ "lots",
      !is.na(controlled_homesites) & !is.na(total_homesites) ~ "homesites",
      TRUE ~ NA_character_
    ),
    controlled_share_definition = case_when(
      controlled_share_physical_unit_type == "lots" ~ "controlled_lots / total_lots",
      controlled_share_physical_unit_type == "homesites" ~ "controlled_homesites / total_homesites",
      TRUE ~ NA_character_
    ),
    extraction_conflicting_values = accession_number %in% conflict_flags$accession_number[conflict_flags$conflicting_high_score_values],
    extraction_manual_review_flag = coalesce(extraction_conflicting_values, FALSE) | coalesce(firm_year_manual_review_indicator, FALSE)
  ) |>
  arrange(builder_name_clean, desc(fiscal_year), accession_number)

benchmark_expected <- tribble(
  ~benchmark_name, ~ticker, ~accession_number, ~fiscal_year, ~variable_name, ~expected_value, ~tolerance,
  "pulte_2011", "PHM", "0000822416-12-000010", 2011L, "owned_lots", 116933, 1,
  "pulte_2011", "PHM", "0000822416-12-000010", 2011L, "optioned_lots", 14077, 1,
  "pulte_2011", "PHM", "0000822416-12-000010", 2011L, "controlled_lots", 131010, 1,
  "pulte_2011", "PHM", "0000822416-12-000010", 2011L, "developed_share_owned", 28, 0.1,
  "pulte_2011", "PHM", "0000822416-12-000010", 2011L, "developed_share_optioned", 38, 0.1,
  "pulte_2011", "PHM", "0000822416-12-000010", 2011L, "developed_share_controlled", 29, 0.1,
  "pulte_2011", "PHM", "0000822416-12-000010", 2011L, "optioned_share", 14077 / 131010, 0.002,
  "pulte_2011", "PHM", "0000822416-12-000010", 2011L, "optioned_lots_approved_for_purchase", 10060, 1,
  "pulte_2011", "PHM", "0000822416-12-000010", 2011L, "optioned_lots_pending_approval", 4017, 1,
  "pulte_2011", "PHM", "0000822416-12-000010", 2011L, "remaining_purchase_price", 697994000, 1000,
  "pulte_2011", "PHM", "0000822416-12-000010", 2011L, "deposits_preacquisition_costs", 57047000, 1000,
  "pulte_2011", "PHM", "0000822416-12-000010", 2011L, "land_not_owned_under_option_agreements", 24905000, 1000,
  "pulte_2011", "PHM", "0000822416-12-000010", 2011L, "closings", 15275, 1,
  "pulte_2011", "PHM", "0000822416-12-000010", 2011L, "net_new_orders_units", 15215, 1,
  "pulte_2011", "PHM", "0000822416-12-000010", 2011L, "cancellation_rate", 19, 0.1,
  "pulte_2011", "PHM", "0000822416-12-000010", 2011L, "active_communities", 700, 1,
  "pulte_2011", "PHM", "0000822416-12-000010", 2011L, "backlog_units", 3924, 1,
  "pulte_2011", "PHM", "0000822416-12-000010", 2011L, "backlog_dollars", 1059649000, 1000,
  "pulte_2011", "PHM", "0000822416-12-000010", 2011L, "average_selling_price", 259000, 1000,
  "pulte_2011", "PHM", "0000822416-12-000010", 2011L, "homes_under_construction_inventory", 1210717000, 1000,
  "pulte_2011", "PHM", "0000822416-12-000010", 2011L, "land_under_development", 2610501000, 1000,
  "pulte_2011", "PHM", "0000822416-12-000010", 2011L, "land_held_for_future_development", 815250000, 1000,
  "pulte_2011", "PHM", "0000822416-12-000010", 2011L, "total_inventory", 4636468000, 1000,
  "pulte_2011", "PHM", "0000822416-12-000010", 2011L, "total_assets", 6885620000, 1000,
  "pulte_2011", "PHM", "0000822416-12-000010", 2011L, "land_held_for_sale", 135307000, 1000,
  "pulte_2011", "PHM", "0000822416-12-000010", 2011L, "land_sale_revenue", 82853000, 1000,
  "pulte_2011", "PHM", "0000822416-12-000010", 2011L, "land_sale_cost", 59279000, 1000,
  "pulte_2011", "PHM", "0000822416-12-000010", 2011L, "land_sale_margin", 23574000, 1000,
  "pulte_2011", "PHM", "0000822416-12-000010", 2011L, "land_related_charges_total", 35786000, 1000,
  "pulte_2011", "PHM", "0000822416-12-000010", 2011L, "land_community_valuation_adjustments", 15940000, 1000,
  "pulte_2011", "PHM", "0000822416-12-000010", 2011L, "nrv_adjustments_land_held_for_sale", 9844000, 1000,
  "pulte_2011", "PHM", "0000822416-12-000010", 2011L, "writeoff_deposits_preacquisition_costs", 10002000, 1000,
  "d_r_horton_2024", "DHI", "0000882184-24-000057", 2024L, "owned_lots", 152500, 1,
  "d_r_horton_2024", "DHI", "0000882184-24-000057", 2024L, "controlled_lots", 480400, 1,
  "d_r_horton_2024", "DHI", "0000882184-24-000057", 2024L, "total_lots", 632900, 1,
  "d_r_horton_2024", "DHI", "0000882184-24-000057", 2024L, "controlled_share", 480400 / 632900, 0.002,
  "d_r_horton_2024", "DHI", "0000882184-24-000057", 2024L, "remaining_purchase_price", 25200000000, 100000000,
  "d_r_horton_2024", "DHI", "0000882184-24-000057", 2024L, "earnest_money_deposits", 2200000000, 100000000,
  "lennar_2024", "LEN", "0001628280-25-002404", 2024L, "controlled_homesites", 393649, 1,
  "lennar_2024", "LEN", "0001628280-25-002404", 2024L, "owned_homesites", 85428, 1,
  "lennar_2024", "LEN", "0001628280-25-002404", 2024L, "total_homesites", 479077, 1,
  "lennar_2024", "LEN", "0001628280-25-002404", 2024L, "controlled_share", 393649 / 479077, 0.002,
  "lennar_2024", "LEN", "0001628280-25-002404", 2024L, "land_purchase_contract_obligations", 1507964000, 1000,
  "nvr_2024", "NVR", "0000906163-25-000011", 2024L, "controlled_lots", 162400, 1,
  "nvr_2024", "NVR", "0000906163-25-000011", 2024L, "lot_purchase_agreements", 155000, 1,
  "nvr_2024", "NVR", "0000906163-25-000011", 2024L, "lpa_cash_deposits", 764900000, 1000
)

panel_long <- public_builder_10k_land_panel |>
  select(ticker, accession_number, fiscal_year, any_of(unique(benchmark_expected$variable_name))) |>
  pivot_longer(
    cols = -c(ticker, accession_number, fiscal_year),
    names_to = "variable_name",
    values_to = "extracted_value",
    values_drop_na = FALSE
  )

benchmark_sources <- preferred_values |>
  select(
    ticker, accession_number, fiscal_year, variable_name,
    raw_value, context_snippet, table_row_or_table_text, extraction_method,
    confidence, source_path, source_table_index, source_row_label, source_column_label
  ) |>
  distinct(ticker, accession_number, fiscal_year, variable_name, .keep_all = TRUE)

tenk_land_benchmark_audit <- benchmark_expected |>
  left_join(panel_long, by = c("ticker", "accession_number", "fiscal_year", "variable_name"), relationship = "one-to-one") |>
  left_join(benchmark_sources, by = c("ticker", "accession_number", "fiscal_year", "variable_name"), relationship = "many-to-one") |>
  mutate(
    abs_error = abs(extracted_value - expected_value),
    benchmark_pass = !is.na(extracted_value) & abs_error <= tolerance,
    selected_as_preferred = !is.na(extracted_value),
    audit_status = case_when(
      benchmark_pass ~ "pass",
      is.na(extracted_value) ~ "missing",
      TRUE ~ "fail"
    )
  ) |>
  arrange(benchmark_name, variable_name)

benchmark_identity_audit <- public_builder_10k_land_panel |>
  filter(
    accession_number %in% c("0000882184-24-000057", "0001628280-25-002404", "0000822416-12-000010")
  ) |>
  transmute(
    ticker, accession_number, fiscal_year,
    d_r_horton_2024 = if_else(
      accession_number == "0000882184-24-000057",
      owned_lots + controlled_lots - total_lots,
      NA_real_
    ),
    lennar_2024 = if_else(
      accession_number == "0001628280-25-002404",
      owned_homesites + controlled_homesites - total_homesites,
      NA_real_
    ),
    pulte_2011_lot_total = if_else(
      accession_number == "0000822416-12-000010",
      owned_lots + optioned_lots - controlled_lots,
      NA_real_
    ),
    pulte_2011_option_components = if_else(
      accession_number == "0000822416-12-000010",
      optioned_lots_approved_for_purchase + optioned_lots_pending_approval - optioned_lots,
      NA_real_
    )
  ) |>
  pivot_longer(
    cols = c(d_r_horton_2024, lennar_2024, pulte_2011_lot_total, pulte_2011_option_components),
    names_to = "identity_check",
    values_to = "extracted_value",
    values_drop_na = TRUE
  ) |>
  mutate(
    benchmark_name = case_when(
      identity_check == "d_r_horton_2024" ~ "d_r_horton_2024",
      identity_check == "lennar_2024" ~ "lennar_2024",
      TRUE ~ "pulte_2011"
    ),
    variable_name = paste0("identity_", identity_check),
    expected_value = 0,
    tolerance = 1,
    raw_value = NA_character_,
    context_snippet = NA_character_,
    table_row_or_table_text = NA_character_,
    extraction_method = "derived_identity_audit",
    confidence = "high",
    source_path = NA_character_,
    source_table_index = NA_real_,
    source_row_label = NA_character_,
    source_column_label = NA_character_,
    abs_error = abs(extracted_value - expected_value),
    benchmark_pass = !is.na(extracted_value) & abs_error <= tolerance,
    selected_as_preferred = TRUE,
    audit_status = if_else(benchmark_pass, "pass", "fail")
  ) |>
  select(
    benchmark_name, ticker, accession_number, fiscal_year, variable_name,
    expected_value, tolerance, extracted_value, raw_value, context_snippet,
    table_row_or_table_text, extraction_method, confidence, source_path,
    source_table_index, source_row_label, source_column_label, abs_error,
    benchmark_pass, selected_as_preferred, audit_status
  )

tenk_land_benchmark_audit <- bind_rows(tenk_land_benchmark_audit, benchmark_identity_audit) |>
  arrange(benchmark_name, variable_name)

write_csv_if_changed(public_builder_10k_land_panel, "../output/public_builder_10k_land_panel.csv")
write_csv_if_changed(preferred_values, "../output/tenk_land_preferred_values.csv")
write_csv_if_changed(segment_year_panel, "../output/tenk_land_segment_year_panel.csv")
write_csv_if_changed(value_selection_audit, "../output/tenk_land_value_selection_audit.csv")
write_csv_if_changed(tenk_land_benchmark_audit, "../output/tenk_land_benchmark_audit.csv")

cat("Wrote first-pass public-builder 10-K land panel outputs to ../output\n")
