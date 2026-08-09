# setwd("/Users/jacobherbstman/Desktop/homebuilder_10ks/tasks/audits/audit_expanded_builder_land_panel/code")

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(tibble)
})

source("../../../_lib/homebuilder_pipeline_utils.R")

panel <- read_csv(
  "../input/expanded_builder_2004_2025_land_panel.csv",
  show_col_types = FALSE,
  na = c("", "NA"),
  col_types = cols(candidate_cik10 = col_character())
)

firm_specific_sources <- c(
  "hand_read_six_firm",
  "firm_specific_toll_extractor",
  "firm_specific_mho_extractor",
  "firm_specific_mdc_extractor",
  "firm_specific_grbk_extractor",
  "firm_specific_mth_extractor",
  "firm_specific_tmhc_extractor",
  "firm_specific_tph_extractor",
  "firm_specific_nvr_early_extractor",
  "firm_specific_lsea_extractor",
  "firm_specific_dfh_extractor",
  "firm_specific_sdhc_extractor",
  "firm_specific_uhg_extractor",
  "firm_specific_tier1_early_extractor",
  "firm_specific_centex_extractor",
  "firm_specific_tousa_extractor",
  "firm_specific_orleans_extractor",
  "firm_specific_ucp_extractor",
  "firm_specific_dominion_extractor",
  "firm_specific_brookfield_homes_extractor",
  "firm_specific_wci_extractor",
  "firm_specific_new_home_company_extractor",
  "firm_specific_ryland_extractor",
  "firm_specific_av_homes_extractor",
  "firm_specific_william_lyon_extractor",
  "firm_specific_standard_pacific_calatlantic_extractor",
  "firm_specific_comstock_extractor",
  "firm_specific_levitt_extractor"
)

coverage_by_firm <- panel |>
  group_by(universe_episode_id, company, ticker, tier, candidate_cik10) |>
  summarise(
    first_sec_fiscal_year = first(first_sec_fiscal_year),
    last_sec_fiscal_year = first(last_sec_fiscal_year),
    sec_filing_years = sum(sec_filing_observed, na.rm = TRUE),
    selected_main_plot_years = sum(selected_main_plot_eligible, na.rm = TRUE),
    selected_review_plot_years = sum(selected_review_plot_eligible, na.rm = TRUE),
    firm_specific_years = sum(selected_land_source %in% firm_specific_sources, na.rm = TRUE),
    generic_main_years = sum(selected_land_source == "generic_parser_main", na.rm = TRUE),
    generic_review_years = sum(selected_land_source == "generic_parser_with_review", na.rm = TRUE),
    review_needed_years = sum(needs_firm_era_review, na.rm = TRUE),
    duplicate_cik_universe_rows = first(duplicate_cik_universe_rows),
    fiscal_year_warning = first(fiscal_year_warning),
    universe_review_status = first(universe_review_status),
    .groups = "drop"
  ) |>
  arrange(tier, desc(review_needed_years), company, candidate_cik10)

coverage_by_year <- panel |>
  group_by(fiscal_year) |>
  summarise(
    universe_episodes = n_distinct(universe_episode_id),
    sec_filing_episodes = sum(sec_filing_observed, na.rm = TRUE),
    selected_main_plot_episodes = sum(selected_main_plot_eligible, na.rm = TRUE),
    selected_review_plot_episodes = sum(selected_review_plot_eligible, na.rm = TRUE),
    firm_specific_episodes = sum(selected_land_source %in% firm_specific_sources, na.rm = TRUE),
    generic_main_episodes = sum(selected_land_source == "generic_parser_main", na.rm = TRUE),
    generic_review_episodes = sum(selected_land_source == "generic_parser_with_review", na.rm = TRUE),
    review_needed_episodes = sum(needs_firm_era_review, na.rm = TRUE),
    mean_nonowned_share_main = mean(selected_nonowned_controlled_share[selected_main_plot_eligible], na.rm = TRUE),
    mean_nonowned_share_review = mean(selected_nonowned_controlled_share[selected_review_plot_eligible], na.rm = TRUE),
    .groups = "drop"
  ) |>
  arrange(fiscal_year)

review_queue_rows <- panel |>
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

gap_audit <- panel |>
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

write_csv_if_changed(coverage_by_firm, "../output/expanded_builder_land_coverage_by_firm.csv")
write_csv_if_changed(coverage_by_year, "../output/expanded_builder_land_coverage_by_year.csv")
write_csv_if_changed(review_queue, "../output/expanded_builder_land_review_queue.csv")
write_csv_if_changed(gap_audit, "../output/expanded_builder_land_gap_audit.csv")

cat("Wrote expanded builder land audits to ../output\n")
