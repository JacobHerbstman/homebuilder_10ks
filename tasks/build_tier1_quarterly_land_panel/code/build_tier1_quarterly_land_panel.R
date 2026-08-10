# setwd("/Users/jacobherbstman/Desktop/homebuilder_10ks/tasks/build_tier1_quarterly_land_panel/code")

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

quarterly_disclosures <- read_csv(
  "../input/tier1_2018_2025_quarterly_land_disclosures.csv",
  show_col_types = FALSE,
  na = c("", "NA"),
  col_types = cols(cik10 = col_character(), accession_number = col_character())
) |>
  transmute(
    ticker,
    calendar_year,
    calendar_quarter,
    land_source_kind = "interim_10q",
    land_share_observed = !is.na(omega_nonowned_controlled_share),
    owned_lots_or_homesites,
    omega_numerator_lots_or_homesites = nonowned_controlled_lots_or_homesites,
    total_lots_or_homesites,
    omega_nonowned_controlled_share,
    reported_pipeline_lots_or_homesites,
    land_unit_type = unit_type,
    land_measure_definition = measure_definition,
    land_extraction_method = extraction_method,
    land_extraction_confidence = extraction_confidence,
    land_source_quality = source_quality,
    land_component_counts_available = omega_component_counts_available,
    land_component_identity_expected = component_identity_expected,
    land_manual_review_flag = manual_review_flag,
    land_share_missing_reason = manual_review_reason,
    land_context_snippet = context_snippet,
    land_accession_number = accession_number,
    land_source_url = source_url,
    land_source_local_path = source_local_path,
    land_source_checksum_sha256 = source_checksum_sha256
  )

if (quarterly_disclosures |> count(ticker, calendar_year, calendar_quarter) |> filter(n != 1) |> nrow() > 0) {
  stop("Quarterly land disclosures are not unique by firm and calendar quarter.")
}

annual_disclosures <- skeleton |>
  filter(source_kind == "annual_10k") |>
  select(
    ticker, calendar_year, calendar_quarter, fiscal_year,
    assigned_source_accession_number = source_accession_number,
    assigned_source_url = source_url,
    assigned_source_local_path = source_local_path,
    assigned_source_checksum_sha256 = source_checksum_sha256
  ) |>
  left_join(
    read_csv(
      "../input/tier1_2018_2025_annual_panel.csv",
      show_col_types = FALSE,
      na = c("", "NA"),
      col_types = cols(cik10 = col_character(), land_accession_number = col_character())
    ) |>
      select(
        ticker, fiscal_year, land_share_observed, owned_lots_or_homesites,
        omega_numerator_lots_or_homesites, total_lots_or_homesites,
        omega_nonowned_controlled_share, land_unit_type, land_measure_definition,
        land_source, land_source_note, land_component_identity_status,
        land_manual_review_flag, land_share_missing_reason, land_accession_number,
        land_source_url, land_source_local_path
      ),
    by = c("ticker", "fiscal_year"),
    relationship = "many-to-one"
  ) |>
  left_join(
    read_csv(
      "../input/sec_10k_download_inventory.csv",
      show_col_types = FALSE,
      na = c("", "NA"),
      col_types = cols(accession_number = col_character())
    ) |>
      transmute(
        land_accession_number = accession_number,
        selected_source_checksum_sha256 = primary_document_checksum_sha256
      ),
    by = "land_accession_number",
    relationship = "many-to-one"
  )

annual_disclosures <- annual_disclosures |>
  transmute(
    ticker,
    calendar_year,
    calendar_quarter,
    land_source_kind = case_when(
      !is.na(land_accession_number) & land_accession_number != assigned_source_accession_number ~
        "later_10k_comparative",
      TRUE ~ "annual_10k"
    ),
    land_share_observed,
    owned_lots_or_homesites,
    omega_numerator_lots_or_homesites,
    total_lots_or_homesites,
    omega_nonowned_controlled_share,
    reported_pipeline_lots_or_homesites = NA_real_,
    land_unit_type,
    land_measure_definition,
    land_extraction_method = land_source,
    land_extraction_confidence = if_else(land_share_observed, "high", NA_character_),
    land_source_quality = land_component_identity_status,
    land_component_counts_available = !is.na(omega_numerator_lots_or_homesites) & !is.na(total_lots_or_homesites),
    land_component_identity_expected = land_component_identity_status == "exact_within_one",
    land_manual_review_flag,
    land_share_missing_reason,
    land_context_snippet = land_source_note,
    land_accession_number = coalesce(land_accession_number, assigned_source_accession_number),
    land_source_url = coalesce(land_source_url, assigned_source_url),
    land_source_local_path = coalesce(land_source_local_path, assigned_source_local_path),
    land_source_checksum_sha256 = coalesce(selected_source_checksum_sha256, assigned_source_checksum_sha256)
  )

land_disclosures <- bind_rows(quarterly_disclosures, annual_disclosures)

if (land_disclosures |> count(ticker, calendar_year, calendar_quarter) |> filter(n != 1) |> nrow() > 0) {
  stop("Combined quarterly and annual land disclosures are not unique by firm and calendar quarter.")
}

panel <- skeleton |>
  left_join(
    land_disclosures,
    by = c("ticker", "calendar_year", "calendar_quarter"),
    relationship = "one-to-one"
  ) |>
  mutate(
    land_share_observed = coalesce(land_share_observed, FALSE),
    land_manual_review_flag = coalesce(land_manual_review_flag, FALSE),
    land_share_missing_reason = case_when(
      land_share_observed ~ NA_character_,
      !is.na(land_share_missing_reason) ~ land_share_missing_reason,
      pre_public_indicator ~ "Firm had not yet entered its public-reporting episode.",
      death_indicator ~ "Firm had exited public reporting.",
      !filing_observed ~ "No SEC filing was assigned to this calendar quarter.",
      TRUE ~ "No harmonized land-control share was recovered from the assigned filing."
    ),
    quarter_index = calendar_year * 4L + calendar_quarter
  ) |>
  arrange(ticker, quarter_index) |>
  group_by(ticker) |>
  mutate(
    lagged_quarterly_omega_source_calendar_quarter_label = if_else(
      public_reporting_episode_indicator & quarter_index - lag(quarter_index) == 1L & lag(land_share_observed),
      lag(calendar_quarter_label),
      NA_character_
    ),
    lagged_quarterly_omega_nonowned_controlled_share = if_else(
      public_reporting_episode_indicator & quarter_index - lag(quarter_index) == 1L & lag(land_share_observed),
      lag(omega_nonowned_controlled_share),
      NA_real_
    ),
    lagged_quarterly_omega_source_accession_number = if_else(
      public_reporting_episode_indicator & quarter_index - lag(quarter_index) == 1L & lag(land_share_observed),
      lag(land_accession_number),
      NA_character_
    ),
    lagged_quarterly_omega_observed = !is.na(lagged_quarterly_omega_nonowned_controlled_share)
  ) |>
  ungroup() |>
  select(-quarter_index) |>
  arrange(ticker, calendar_year, calendar_quarter)

if (nrow(panel) != 640 || n_distinct(panel$ticker) != 20) {
  stop("Expected a balanced 20-firm by 32-quarter Tier-1 land panel.")
}

if (panel |> count(ticker, calendar_year, calendar_quarter) |> filter(n != 1) |> nrow() > 0) {
  stop("Tier-1 quarterly land panel is not unique by firm and calendar quarter.")
}

if (panel |> filter(!is.na(omega_nonowned_controlled_share), !between(omega_nonowned_controlled_share, 0, 1)) |> nrow() > 0) {
  stop("Quarterly land-control shares must lie between zero and one.")
}

write_csv_if_changed(panel, "../output/tier1_2018_2025_quarterly_land_panel.csv")

cat("Wrote balanced Tier-1 quarterly land panel to ../output\n")
