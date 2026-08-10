# setwd("/Users/jacobherbstman/Desktop/homebuilder_10ks/tasks/build_tier1_quarterly_panel/code")

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
})

source("../../_lib/homebuilder_pipeline_utils.R")

skeleton <- read_csv(
  "../input/tier1_2018_2025_quarterly_skeleton.csv",
  show_col_types = FALSE,
  na = c("", "NA"),
  col_types = cols(cik10 = col_character(), source_accession_number = col_character())
) |>
  mutate(calendar_quarter_end = as.Date(calendar_quarter_end))

operating <- read_csv(
  "../input/tier1_2018_2025_quarterly_operating_panel.csv",
  show_col_types = FALSE,
  na = c("", "NA"),
  col_types = cols(cik10 = col_character(), accession_number = col_character())
) |>
  select(
    -company, -cik10, -fiscal_year, -fiscal_quarter, -form,
    -filing_date, -report_date
  ) |>
  rename(
    operating_accession_number = accession_number,
    operating_source_url = filing_url,
    operating_source_local_path = source_local_path,
    operating_source_checksum_sha256 = source_checksum_sha256
  )

if (operating |> count(ticker, calendar_year, calendar_quarter) |> filter(n != 1) |> nrow() > 0) {
  stop("Quarterly operating inputs are not unique by firm and calendar quarter.")
}

land <- read_csv(
  "../input/tier1_2018_2025_quarterly_land_panel.csv",
  show_col_types = FALSE,
  na = c("", "NA"),
  col_types = cols(
    cik10 = col_character(),
    source_accession_number = col_character(),
    land_accession_number = col_character(),
    lagged_quarterly_omega_source_accession_number = col_character()
  )
) |>
  select(
    ticker, calendar_year, calendar_quarter,
    land_source_kind, land_share_observed,
    owned_lots_or_homesites, omega_numerator_lots_or_homesites,
    total_lots_or_homesites, omega_nonowned_controlled_share,
    reported_pipeline_lots_or_homesites, land_unit_type,
    land_measure_definition, land_extraction_method,
    land_extraction_confidence, land_source_quality,
    land_component_counts_available, land_component_identity_expected,
    land_manual_review_flag, land_share_missing_reason,
    land_accession_number, land_source_url, land_source_local_path,
    land_source_checksum_sha256,
    lagged_quarterly_omega_source_calendar_quarter_label,
    lagged_quarterly_omega_nonowned_controlled_share,
    lagged_quarterly_omega_source_accession_number,
    lagged_quarterly_omega_observed
  )

if (land |> count(ticker, calendar_year, calendar_quarter) |> filter(n != 1) |> nrow() > 0) {
  stop("Quarterly land inputs are not unique by firm and calendar quarter.")
}

exits <- read_csv("../input/builder_public_lifecycle_events.csv", show_col_types = FALSE) |>
  filter(builder_name_clean %in% c("M.D.C. Holdings", "Landsea Homes")) |>
  transmute(company = builder_name_clean, public_equity_exit_date = as.Date(event_date))

if (nrow(exits) != 2 || any(is.na(exits$public_equity_exit_date))) {
  stop("Expected reviewed acquisition dates for M.D.C. Holdings and Landsea Homes.")
}

annual_omega <- read_csv(
  "../input/tier1_2018_2025_annual_panel.csv",
  show_col_types = FALSE,
  na = c("", "NA"),
  col_types = cols(cik10 = col_character())
) |>
  transmute(
    ticker,
    omega_source_fiscal_year = fiscal_year,
    lagged_annual_owned_lots_or_homesites = owned_lots_or_homesites,
    lagged_annual_nonowned_lots_or_homesites = omega_numerator_lots_or_homesites,
    lagged_annual_total_lots_or_homesites = total_lots_or_homesites,
    lagged_annual_omega_nonowned_controlled_share = omega_nonowned_controlled_share,
    lagged_annual_land_unit_type = land_unit_type,
    lagged_annual_land_measure_definition = land_measure_definition,
    lagged_annual_land_source = land_source,
    lagged_annual_land_accession_number = land_accession_number
  )

panel <- skeleton |>
  left_join(exits, by = "company", relationship = "many-to-one") |>
  mutate(
    post_public_equity_exit = !is.na(public_equity_exit_date) & calendar_quarter_end >= public_equity_exit_date,
    panel_state = case_when(
      post_public_equity_exit ~ "post_exit",
      TRUE ~ panel_state
    ),
    public_equity_episode_indicator = !pre_public_indicator & !post_public_equity_exit,
    death_indicator = post_public_equity_exit,
    lagged_omega_source_fiscal_year = fiscal_year - 1L
  ) |>
  left_join(
    operating,
    by = c("ticker", "calendar_year", "calendar_quarter", "calendar_quarter_label"),
    relationship = "one-to-one"
  ) |>
  left_join(
    land,
    by = c("ticker", "calendar_year", "calendar_quarter"),
    relationship = "one-to-one"
  ) |>
  left_join(
    annual_omega,
    by = c("ticker", "lagged_omega_source_fiscal_year" = "omega_source_fiscal_year"),
    relationship = "many-to-one"
  ) |>
  mutate(
    across(
      c(
        owned_lots_or_homesites,
        omega_numerator_lots_or_homesites,
        total_lots_or_homesites,
        omega_nonowned_controlled_share,
        reported_pipeline_lots_or_homesites,
        lagged_quarterly_omega_nonowned_controlled_share
      ),
      ~ if_else(public_equity_episode_indicator, .x, NA)
    ),
    lagged_quarterly_omega_source_calendar_quarter_label = if_else(
      public_equity_episode_indicator,
      lagged_quarterly_omega_source_calendar_quarter_label,
      NA_character_
    ),
    lagged_quarterly_omega_source_accession_number = if_else(
      public_equity_episode_indicator,
      lagged_quarterly_omega_source_accession_number,
      NA_character_
    ),
    land_share_observed = public_equity_episode_indicator & coalesce(land_share_observed, FALSE),
    land_manual_review_flag = public_equity_episode_indicator & coalesce(land_manual_review_flag, FALSE),
    lagged_quarterly_omega_observed = public_equity_episode_indicator &
      coalesce(lagged_quarterly_omega_observed, FALSE),
    operating_data_observed = !is.na(orders_units) & !is.na(deliveries_units) & !is.na(backlog_units),
    quarterly_omega_observed = !is.na(omega_nonowned_controlled_share),
    lagged_annual_omega_observed = !is.na(lagged_annual_omega_nonowned_controlled_share),
    across(
      starts_with("lagged_annual_"),
      ~ if_else(public_equity_episode_indicator, .x, NA)
    )
  ) |>
  arrange(ticker, calendar_year, calendar_quarter)

if (nrow(panel) != 640 || n_distinct(panel$ticker) != 20) {
  stop("Expected a balanced 20-firm by 32-quarter Tier-1 panel.")
}

if (panel |> count(ticker, calendar_year, calendar_quarter) |> filter(n != 1) |> nrow() > 0) {
  stop("Tier-1 quarterly panel is not unique by firm and calendar quarter.")
}

if (panel |> filter(!public_equity_episode_indicator, !is.na(operating_accession_number)) |> nrow() > 0) {
  stop("Quarterly operating data were joined outside a reviewed public-equity episode.")
}

if (panel |> filter(!public_equity_episode_indicator, quarterly_omega_observed) |> nrow() > 0) {
  stop("Quarterly land data were joined outside a reviewed public-equity episode.")
}

write_csv_if_changed(panel, "../output/tier1_2018_2025_quarterly_panel.csv")

cat("Wrote balanced Tier-1 quarterly panel to ../output\n")
