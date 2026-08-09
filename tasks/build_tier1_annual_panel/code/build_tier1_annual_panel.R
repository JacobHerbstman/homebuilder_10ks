# setwd("/Users/jacobherbstman/Desktop/homebuilder_10ks/tasks/build_tier1_annual_panel/code")

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
})

source("../../_lib/homebuilder_pipeline_utils.R")

land <- read_csv(
  "../input/expanded_builder_2004_2025_land_panel.csv",
  show_col_types = FALSE,
  na = c("", "NA"),
  col_types = cols(
    candidate_cik10 = col_character(),
    selected_accession_number = col_character()
  )
) |>
  filter(tier == 1, fiscal_year %in% 2018:2025) |>
  arrange(ticker, fiscal_year)

if (nrow(land) != 160 || n_distinct(land$ticker) != 20) {
  stop("Expected a balanced 20-firm by 8-year Tier-1 land skeleton.")
}

if (land |> count(ticker, fiscal_year) |> filter(n != 1) |> nrow() > 0) {
  stop("Tier-1 land inputs must be unique by ticker and fiscal year.")
}

operating <- read_csv(
  "../input/tier1_2018_2025_annual_operating_panel.csv",
  show_col_types = FALSE,
  na = c("", "NA"),
  col_types = cols(cik10 = col_character(), accession_number = col_character())
) |>
  select(-company, -cik10) |>
  rename(
    operating_accession_number = accession_number,
    operating_source_scope = source_scope,
    operating_extraction_method = extraction_method,
    operating_filing_url = filing_url,
    operating_source_local_path = source_local_path,
    operating_source_checksum_sha256 = source_checksum_sha256,
    operating_source_task = source_task
  ) |>
  arrange(ticker, fiscal_year)

if (nrow(operating) != 141 || n_distinct(operating$ticker) != 20) {
  stop("Expected 141 observed public firm-years in the Tier-1 operating input.")
}

if (operating |> count(ticker, fiscal_year) |> filter(n != 1) |> nrow() > 0) {
  stop("Tier-1 operating inputs must be unique by ticker and fiscal year.")
}

panel <- land |>
  transmute(
    universe_episode_id,
    universe_firm_id,
    ticker,
    company,
    cik10 = candidate_cik10,
    sec_company_name = candidate_sec_company_name,
    fiscal_year = as.integer(fiscal_year),
    panel_state = case_when(
      pre_sec_reporting_window ~ "pre_public",
      post_sec_exit_window ~ "post_exit",
      missing_sec_filing_in_reporting_window ~ "missing_sec_filing",
      sec_filing_observed ~ "public_filing_observed",
      TRUE ~ "outside_public_reporting_episode"
    ),
    public_reporting_episode_indicator = in_sec_reporting_window,
    public_filing_observed = sec_filing_observed,
    pre_public_indicator = pre_sec_reporting_window,
    death_indicator = post_sec_exit_window,
    valid_from_year,
    valid_to_year,
    filing_window,
    fiscal_year_warning,
    merger_splice_flag,
    recent_ipo_flag,
    fate_and_splicing_notes,
    owned_lots_or_homesites = selected_owned_physical_count,
    omega_numerator_lots_or_homesites = selected_nonowned_physical_count,
    total_lots_or_homesites = selected_total_physical_count,
    omega_nonowned_controlled_share = selected_nonowned_controlled_share,
    land_component_identity_gap = selected_owned_physical_count + selected_nonowned_physical_count - selected_total_physical_count,
    land_component_identity_status = case_when(
      is.na(selected_nonowned_controlled_share) ~ NA_character_,
      is.na(selected_owned_physical_count) | is.na(selected_nonowned_physical_count) | is.na(selected_total_physical_count) ~ "components_not_fully_disclosed",
      abs(selected_owned_physical_count + selected_nonowned_physical_count - selected_total_physical_count) <= 1 ~ "exact_within_one",
      selected_measure_definition == "optioned_home_sites / consolidated_total_home_sites" ~ "construction_to_permanent_category_excluded_from_omega_numerator",
      selected_land_source == "firm_specific_toll_extractor" & abs(selected_owned_physical_count + selected_nonowned_physical_count - selected_total_physical_count) <= 200 ~ "rounded_companywide_prose",
      TRUE ~ "unresolved"
    ),
    land_unit_type = selected_unit_type,
    land_measure_definition = selected_measure_definition,
    land_source = selected_land_source,
    land_source_note = selected_source_note,
    land_accession_number = selected_accession_number,
    land_source_url = selected_source_url,
    land_source_local_path = selected_source_local_path,
    land_main_plot_eligible = selected_main_plot_eligible,
    land_manual_review_flag = selected_manual_review_flag,
    land_share_missing_reason = case_when(
      !in_sec_reporting_window ~ panel_state,
      !is.na(selected_nonowned_controlled_share) ~ NA_character_,
      ticker == "DFH" & fiscal_year %in% 2024:2025 ~ "owned_lot_denominator_not_disclosed",
      !is.na(selected_land_source) ~ "incomplete_land_components",
      TRUE ~ "no_harmonized_land_disclosure"
    )
  ) |>
  left_join(operating, by = c("ticker", "fiscal_year"), relationship = "one-to-one") |>
  mutate(
    operating_data_observed = !is.na(orders_units) & !is.na(deliveries_units) & !is.na(backlog_units),
    land_share_observed = !is.na(omega_nonowned_controlled_share)
  ) |>
  select(
    universe_episode_id, universe_firm_id, ticker, company, cik10, sec_company_name,
    fiscal_year, panel_state, public_reporting_episode_indicator, public_filing_observed,
    pre_public_indicator, death_indicator, valid_from_year, valid_to_year, filing_window,
    fiscal_year_warning, merger_splice_flag, recent_ipo_flag, fate_and_splicing_notes,
    operating_data_observed, report_date, filing_date, operating_accession_number,
    orders_units, orders_value_thousands, orders_raw_label,
    deliveries_units, deliveries_value_thousands, deliveries_raw_label,
    backlog_units, backlog_value_thousands, cancellation_rate_pct,
    active_communities, average_community_count, average_selling_price_dollars,
    homebuilding_revenue_thousands, operating_source_scope, operating_extraction_method,
    operating_filing_url, operating_source_local_path, operating_source_checksum_sha256,
    operating_source_task, land_share_observed, owned_lots_or_homesites,
    omega_numerator_lots_or_homesites, total_lots_or_homesites,
    omega_nonowned_controlled_share, land_component_identity_gap,
    land_component_identity_status, land_unit_type, land_measure_definition,
    land_source, land_source_note, land_accession_number, land_source_url,
    land_source_local_path, land_main_plot_eligible, land_manual_review_flag,
    land_share_missing_reason
  ) |>
  arrange(ticker, fiscal_year)

if (panel |> filter(public_reporting_episode_indicator & !operating_data_observed) |> nrow() > 0) {
  stop("A Tier-1 public reporting firm-year is missing a core operating count.")
}

if (panel |> filter(!public_reporting_episode_indicator & operating_data_observed) |> nrow() > 0) {
  stop("Operating data were joined outside the defined public reporting episode.")
}

if (panel |> filter(land_share_observed, land_component_identity_status == "unresolved") |> nrow() > 0) {
  stop("A selected Tier-1 land row has an unresolved component identity.")
}

if (panel |> filter(land_share_observed, is.na(land_component_identity_status)) |> nrow() > 0) {
  stop("A selected Tier-1 land row is missing its component identity status.")
}

write_csv_if_changed(panel, "../output/tier1_2018_2025_annual_panel.csv")

cat("Wrote balanced Tier-1 annual panel to ../output\n")
