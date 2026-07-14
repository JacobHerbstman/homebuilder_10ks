# setwd("/Users/jacobherbstman/Desktop/homebuilder_10ks/tasks/audit_expanded_builder_sample/code")

suppressPackageStartupMessages({
  library(arrow)
  library(dplyr)
  library(readr)
  library(tidyr)
})

source("../../_lib/homebuilder_pipeline_utils.R")

builder_panel <- read_parquet("../input/builder_panel.parquet")
harmonized <- read_csv("../input/builder_public_firm_harmonized.csv", show_col_types = FALSE, na = c("", "NA"))
universe <- read_csv("../input/builder_universe_sec_crosswalk.csv", show_col_types = FALSE, na = c("", "NA"))
expanded_land <- read_csv("../input/expanded_builder_2004_2025_land_panel.csv", show_col_types = FALSE, na = c("", "NA"))
gap_firm_years <- read_csv("../input/expanded_builder_land_gap_audit.csv", show_col_types = FALSE, na = c("", "NA"))
preferred_values <- read_csv("../input/tenk_land_preferred_values.csv", show_col_types = FALSE, na = c("", "NA"))
six_firm_operating <- read_csv("../input/six_firm_boom_bust_response_panel.csv", show_col_types = FALSE, na = c("", "NA"))
filing_index <- read_csv("../input/sec_10k_filing_index.csv", show_col_types = FALSE, na = c("", "NA"))
scope_decisions <- read_csv("manual_builder_scope_decisions.csv", show_col_types = FALSE, na = c("", "NA"))
land_gap_reviews <- read_csv("manual_land_gap_reviews.csv", show_col_types = FALSE, na = c("", "NA"))

if (nrow(harmonized) != n_distinct(harmonized$builder_name_key)) {
  stop("Harmonized Builder rows must be unique by builder_name_key.")
}
if (nrow(scope_decisions) != n_distinct(scope_decisions$builder_name_key)) {
  stop("Manual Builder scope decisions must be unique by builder_name_key.")
}
if (nrow(land_gap_reviews) != n_distinct(land_gap_reviews$review_case_id)) {
  stop("Manual land-gap reviews must be unique by review_case_id.")
}

current_public <- builder_panel |>
  filter(list_year == 2026L, builder_public_flag) |>
  select(
    builder_name_key,
    current_2026_rank = rank,
    current_2026_closings = total_closings,
    current_2026_revenue_millions = gross_revenue_homebuilding_millions
  )

if (nrow(current_public) != n_distinct(current_public$builder_name_key)) {
  stop("Current Builder-public rows must be unique by builder_name_key.")
}

universe_by_builder_name <- universe |>
  filter(builder_panel_eligible %in% TRUE) |>
  separate_rows(builder_name_keys, sep = " \\| ") |>
  filter(!is.na(builder_name_keys), builder_name_keys != "") |>
  group_by(builder_name_key = builder_name_keys) |>
  summarise(
    expanded_universe_companies = paste(sort(unique(company)), collapse = " | "),
    expanded_universe_tickers = paste(sort(unique(ticker)), collapse = " | "),
    expanded_universe_ciks = paste(sort(unique(candidate_cik10[selected_for_sec_download %in% TRUE])), collapse = " | "),
    selected_sec_episode = any(selected_for_sec_download %in% TRUE),
    expanded_universe_review_status = paste(sort(unique(universe_review_status)), collapse = " | "),
    .groups = "drop"
  )

if (nrow(universe_by_builder_name) != n_distinct(universe_by_builder_name$builder_name_key)) {
  stop("Expanded universe mapping must be unique by Builder name key after deterministic collapse.")
}

universe_reconciliation <- harmonized |>
  filter(ever_marked_public %in% TRUE) |>
  select(
    builder_name_key, builder_name_clean, harmonized_builder_id,
    harmonized_builder_name, first_public_list_year, last_public_list_year,
    best_rank, lifecycle_status, ticker, cik10, sec_reporting_indicator,
    public_parent_no_comparable_us_10k
  ) |>
  left_join(current_public, by = "builder_name_key", relationship = "one-to-one") |>
  left_join(universe_by_builder_name, by = "builder_name_key", relationship = "one-to-one") |>
  left_join(scope_decisions, by = "builder_name_key", relationship = "one-to-one") |>
  mutate(
    current_2026_public = !is.na(current_2026_rank),
    current_2026_top_50 = current_2026_public & current_2026_rank <= 50L,
    sample_disposition = case_when(
      !is.na(sample_disposition) ~ sample_disposition,
      selected_sec_episode %in% TRUE ~ "included_sec_builder_universe",
      TRUE ~ "unresolved_builder_public_name"
    ),
    scope_reason = case_when(
      !is.na(scope_reason) ~ scope_reason,
      selected_sec_episode %in% TRUE ~ "Builder-public firm resolves to an included SEC builder episode.",
      TRUE ~ "No included SEC episode or documented scope disposition."
    ),
    universe_audit_pass = sample_disposition != "unresolved_builder_public_name"
  ) |>
  arrange(desc(current_2026_public), current_2026_rank, best_rank, builder_name_clean)

gap_case_years <- land_gap_reviews |>
  rowwise() |>
  mutate(fiscal_year = list(seq.int(start_year, end_year))) |>
  ungroup() |>
  unnest(fiscal_year) |>
  select(ticker, fiscal_year, review_case_id)

uncovered_existing_gaps <- gap_firm_years |>
  select(ticker, fiscal_year) |>
  anti_join(gap_case_years, by = c("ticker", "fiscal_year"))

operating_counts <- preferred_values |>
  filter(variable_name %in% c("closings", "net_new_orders_units", "backlog_units", "active_communities", "average_selling_price")) |>
  group_by(variable_name) |>
  summarise(
    firm_years = n_distinct(cik10, fiscal_year),
    firms = n_distinct(cik10),
    .groups = "drop"
  )

operating_readiness <- bind_rows(
  tibble(
    outcome_source = "expanded_firm_specific_sec_land_panel",
    measure = "nonowned_controlled_share",
    firm_years_available = sum(expanded_land$selected_main_plot_eligible %in% TRUE, na.rm = TRUE),
    firms_available = n_distinct(expanded_land$candidate_cik10[expanded_land$selected_main_plot_eligible %in% TRUE]),
    readiness = "ready_for_land_share_descriptives",
    limitation = "Use the main-eligible flag and preserve firm disclosure definitions; do not fill audited missing eras."
  ),
  tibble(
    outcome_source = "builder_magazine",
    measure = "annual_closings",
    firm_years_available = sum(builder_panel$builder_public_flag & !is.na(builder_panel$total_closings)),
    firms_available = n_distinct(builder_panel$builder_name_key[builder_panel$builder_public_flag & !is.na(builder_panel$total_closings)]),
    readiness = "ready_for_builder_roster_and_market_share_descriptives",
    limitation = "Survey-based Builder closings are not interchangeable with SEC fiscal-year deliveries."
  ),
  operating_counts |>
    transmute(
      outcome_source = "generic_sec_preferred_values",
      measure = variable_name,
      firm_years_available = firm_years,
      firms_available = firms,
      readiness = "not_ready_for_expanded_cross_firm_descriptives",
      limitation = "Generic selections are sparse and have not received firm-era operating-table audits."
    ),
  tibble(
    outcome_source = "audited_six_firm_annual_panel",
    measure = c("deliveries_units", "orders_units", "backlog_units", "active_communities"),
    firm_years_available = c(
      sum(!is.na(six_firm_operating$deliveries_units)),
      sum(!is.na(six_firm_operating$orders_units)),
      sum(!is.na(six_firm_operating$backlog_units)),
      sum(!is.na(six_firm_operating$active_communities))
    ),
    firms_available = c(
      n_distinct(six_firm_operating$ticker[!is.na(six_firm_operating$deliveries_units)]),
      n_distinct(six_firm_operating$ticker[!is.na(six_firm_operating$orders_units)]),
      n_distinct(six_firm_operating$ticker[!is.na(six_firm_operating$backlog_units)]),
      n_distinct(six_firm_operating$ticker[!is.na(six_firm_operating$active_communities)])
    ),
    readiness = "ready_for_six_firm_pilot_only",
    limitation = "The audited pilot covers six firms and mainly fiscal 2012-2023; it is not the expanded-universe operating panel."
  ),
  tibble(
    outcome_source = "new_public_parent_sec_filing_index",
    measure = c("wreco_10k_filings_2004_2013", "jim_walter_10k_filings_2004_2008"),
    firm_years_available = c(
      n_distinct(filing_index$fiscal_year[filing_index$cik10 == "0000106535" & filing_index$fiscal_year >= 2004L & filing_index$fiscal_year <= 2013L]),
      n_distinct(filing_index$fiscal_year[filing_index$cik10 == "0000837173" & filing_index$fiscal_year >= 2004L & filing_index$fiscal_year <= 2008L])
    ),
    firms_available = 1L,
    readiness = "documents_available_for_firm_specific_operating_extraction",
    limitation = c(
      "WRECO operating tables are recoverable but annual omega is not consistently identified.",
      "Jim Walter operating outcomes are recoverable but omega is structurally nonapplicable for an on-your-lot builder."
    )
  )
)

qc <- tibble(
  check = c(
    "builder_public_name_rows",
    "current_2026_public_rows",
    "current_2026_top_50_unresolved_rows",
    "all_builder_public_unresolved_rows",
    "existing_land_gap_firm_years",
    "existing_land_gaps_without_manual_case",
    "expanded_builder_universe_selected_sec_episodes",
    "wreco_builder_era_10k_years",
    "jim_walter_builder_era_10k_years"
  ),
  status = c(
    if_else(nrow(universe_reconciliation) == 53L, "ok", "warn"),
    if_else(sum(universe_reconciliation$current_2026_public) == 20L, "ok", "warn"),
    if_else(sum(universe_reconciliation$current_2026_top_50 & !universe_reconciliation$universe_audit_pass) == 0L, "ok", "fail"),
    if_else(sum(!universe_reconciliation$universe_audit_pass) == 0L, "ok", "fail"),
    "ok",
    if_else(nrow(uncovered_existing_gaps) == 0L, "ok", "fail"),
    if_else(sum(universe$selected_for_sec_download %in% TRUE) == 39L, "ok", "warn"),
    if_else(n_distinct(filing_index$fiscal_year[filing_index$cik10 == "0000106535" & filing_index$fiscal_year >= 2004L & filing_index$fiscal_year <= 2013L]) == 10L, "ok", "fail"),
    if_else(n_distinct(filing_index$fiscal_year[filing_index$cik10 == "0000837173" & filing_index$fiscal_year >= 2004L & filing_index$fiscal_year <= 2008L]) == 5L, "ok", "fail")
  ),
  value = c(
    nrow(universe_reconciliation),
    sum(universe_reconciliation$current_2026_public),
    sum(universe_reconciliation$current_2026_top_50 & !universe_reconciliation$universe_audit_pass),
    sum(!universe_reconciliation$universe_audit_pass),
    nrow(gap_firm_years),
    nrow(uncovered_existing_gaps),
    sum(universe$selected_for_sec_download %in% TRUE),
    n_distinct(filing_index$fiscal_year[filing_index$cik10 == "0000106535" & filing_index$fiscal_year >= 2004L & filing_index$fiscal_year <= 2013L]),
    n_distinct(filing_index$fiscal_year[filing_index$cik10 == "0000837173" & filing_index$fiscal_year >= 2004L & filing_index$fiscal_year <= 2008L])
  ),
  detail = c(
    "All raw Builder name rows ever marked public.",
    "Official 2026 Builder list rows marked public.",
    "Current Top 50 public names lacking either an SEC-universe episode or an explicit scope decision.",
    "Historical Builder-public names lacking either an SEC-universe episode or an explicit scope decision.",
    "SEC filing-years already audited as lacking a main-comparable omega.",
    "Existing gap rows not covered by an era-level manual retrieval conclusion.",
    "Selected Tier 1 and Tier 2 SEC episodes; WCI contributes two public-company episodes.",
    "Distinct Weyerhaeuser parent fiscal years overlapping the WRECO Builder era.",
    "Distinct Walter Industries parent fiscal years overlapping the Jim Walter Builder era."
  )
)

write_csv_if_changed(universe_reconciliation, "../output/builder_public_universe_reconciliation.csv")
write_csv_if_changed(land_gap_reviews, "../output/land_gap_retrieval_audit.csv")
write_csv_if_changed(operating_readiness, "../output/operating_measure_readiness.csv")
write_csv_if_changed(qc, "../output/expanded_builder_sample_audit_qc.csv")

cat("Wrote expanded Builder sample audit outputs to ../output\n")
