# setwd("/Users/jacobherbstman/Desktop/homebuilder_10ks/tasks/audits/audit_tier1_quarterly_land_panel/code")

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(tidyr)
})

source("../../../_lib/homebuilder_pipeline_utils.R")

panel <- read_csv(
  "../input/tier1_2018_2025_quarterly_land_panel.csv",
  show_col_types = FALSE,
  na = c("", "NA"),
  col_types = cols(
    cik10 = col_character(),
    source_accession_number = col_character(),
    land_accession_number = col_character(),
    lagged_quarterly_omega_source_accession_number = col_character()
  )
)

annual <- read_csv(
  "../input/tier1_2018_2025_annual_panel.csv",
  show_col_types = FALSE,
  na = c("", "NA"),
  col_types = cols(cik10 = col_character(), land_accession_number = col_character())
)

lag_checks <- panel |>
  arrange(ticker, calendar_year, calendar_quarter) |>
  group_by(ticker) |>
  mutate(
    expected_lag = lag(omega_nonowned_controlled_share),
    expected_lag_observed = public_reporting_episode_indicator & lag(land_share_observed, default = FALSE)
  ) |>
  ungroup() |>
  filter(
    lagged_quarterly_omega_observed != expected_lag_observed |
      lagged_quarterly_omega_observed & abs(lagged_quarterly_omega_nonowned_controlled_share - expected_lag) > 1e-12
  )

structural <- tibble(
  audit_type = "structural",
  ticker = NA_character_,
  calendar_year = NA_integer_,
  calendar_quarter = NA_integer_,
  metric = c(
    "balanced_rows",
    "unique_firm_calendar_quarter",
    "tier1_firms",
    "assigned_land_source_rows",
    "interim_10q_land_rows",
    "annual_10k_land_rows",
    "omega_outside_unit_interval",
    "observed_omega_outside_public_episode",
    "assigned_land_source_without_accession",
    "assigned_land_source_without_checksum",
    "interim_source_accession_mismatches",
    "component_identity_failures",
    "unflagged_missing_omega_in_assigned_filing",
    "one_quarter_lag_failures"
  ),
  expected_value = c(640, 640, 20, 565, 424, 141, rep(0, 8)),
  actual_value = c(
    nrow(panel),
    n_distinct(paste(panel$ticker, panel$calendar_year, panel$calendar_quarter)),
    n_distinct(panel$ticker),
    sum(!is.na(panel$land_source_kind)),
    sum(panel$land_source_kind == "interim_10q", na.rm = TRUE),
    sum(panel$land_source_kind %in% c("annual_10k", "later_10k_comparative"), na.rm = TRUE),
    sum(!is.na(panel$omega_nonowned_controlled_share) &
          !between(panel$omega_nonowned_controlled_share, 0, 1)),
    sum(!panel$public_reporting_episode_indicator & panel$land_share_observed),
    sum(!is.na(panel$land_source_kind) & is.na(panel$land_accession_number)),
    sum(!is.na(panel$land_source_kind) & is.na(panel$land_source_checksum_sha256)),
    sum(
      panel$land_source_kind == "interim_10q" &
        panel$land_accession_number != panel$source_accession_number,
      na.rm = TRUE
    ),
    panel |>
      filter(
        land_component_identity_expected,
        !is.na(owned_lots_or_homesites),
        !is.na(omega_numerator_lots_or_homesites),
        !is.na(total_lots_or_homesites)
      ) |>
      summarise(n = sum(abs(owned_lots_or_homesites + omega_numerator_lots_or_homesites - total_lots_or_homesites) > 1)) |>
      pull(n),
    sum(!is.na(panel$land_source_kind) & !panel$land_share_observed & !panel$land_manual_review_flag),
    nrow(lag_checks)
  ),
  detail = c(
    "Twenty firms by 32 calendar quarters.",
    "One row per firm and calendar quarter.",
    "Reviewed Tier-1 universe.",
    "Every assigned SEC filing has one corresponding land-disclosure row.",
    "Every interim 10-Q in the quarterly skeleton was processed.",
    "Fiscal year-end land observations supplied by the audited annual panel.",
    "All observed quarterly land-control shares lie between zero and one.",
    "No land-control share is retained outside the reviewed public-reporting episode.",
    "Every assigned land source retains its SEC accession, including partial disclosures.",
    "Every assigned land source retains its SEC filing checksum, including partial disclosures.",
    "Every interim land row points to the same SEC accession assigned by the quarterly skeleton.",
    "Owned and nonowned components add to the disclosed total where the filing definition requires it.",
    "Assigned filings without a harmonized omega are explicitly flagged for review.",
    "Quarterly omega lags use the immediately preceding calendar quarter only."
  )
) |>
  mutate(
    difference = actual_value - expected_value,
    pass = actual_value == expected_value
  ) |>
  select(
    audit_type, ticker, calendar_year, calendar_quarter, metric,
    expected_value, actual_value, difference, pass, detail
  )

coverage <- panel |>
  filter(public_reporting_episode_indicator) |>
  group_by(ticker) |>
  summarise(
    public_reporting_quarters = n(),
    assigned_filing_quarters = sum(filing_observed),
    land_share_quarters = sum(land_share_observed),
    lagged_land_share_quarters = sum(lagged_quarterly_omega_observed),
    partial_or_missing_filing_quarters = sum(!is.na(land_source_kind) & !land_share_observed),
    .groups = "drop"
  ) |>
  pivot_longer(
    cols = -ticker,
    names_to = "metric",
    values_to = "actual_value"
  ) |>
  transmute(
    audit_type = "firm_coverage",
    ticker,
    calendar_year = NA_integer_,
    calendar_quarter = NA_integer_,
    metric,
    expected_value = NA_real_,
    actual_value = as.numeric(actual_value),
    difference = NA_real_,
    pass = TRUE,
    detail = "Coverage is reported without treating genuine disclosure omissions or pre-IPO quarters as parser failures."
  )

annual_reconciliation <- panel |>
  filter(land_source_kind %in% c("annual_10k", "later_10k_comparative")) |>
  select(
    ticker, calendar_year, calendar_quarter, fiscal_year,
    actual_owned = owned_lots_or_homesites,
    actual_nonowned = omega_numerator_lots_or_homesites,
    actual_total = total_lots_or_homesites,
    actual_omega = omega_nonowned_controlled_share
  ) |>
  left_join(
    annual |>
      transmute(
        ticker, fiscal_year,
        expected_owned = owned_lots_or_homesites,
        expected_nonowned = omega_numerator_lots_or_homesites,
        expected_total = total_lots_or_homesites,
        expected_omega = omega_nonowned_controlled_share
      ),
    by = c("ticker", "fiscal_year"),
    relationship = "many-to-one"
  ) |>
  pivot_longer(
    cols = matches("^(actual|expected)_"),
    names_to = c("value_type", "metric"),
    names_pattern = "(actual|expected)_(.*)",
    values_to = "value"
  ) |>
  pivot_wider(names_from = value_type, values_from = value) |>
  transmute(
    audit_type = "annual_10k_reconciliation",
    ticker,
    calendar_year,
    calendar_quarter,
    metric,
    expected_value = expected,
    actual_value = actual,
    difference = actual - expected,
    pass = if_else(is.na(expected), is.na(actual), !is.na(actual) & abs(difference) <= 1e-12),
    detail = "Fiscal year-end quarterly observations must reproduce the audited annual panel exactly."
  )

expected_values <- tribble(
  ~ticker, ~calendar_year, ~calendar_quarter, ~metric, ~expected_value,
  "CCS", 2018L, 1L, "owned_lots_or_homesites", 15901,
  "CCS", 2018L, 1L, "omega_numerator_lots_or_homesites", 14432,
  "CCS", 2018L, 1L, "total_lots_or_homesites", 30333,
  "CCS", 2022L, 3L, "owned_lots_or_homesites", 34477,
  "CCS", 2022L, 3L, "omega_numerator_lots_or_homesites", 28301,
  "CCS", 2022L, 3L, "total_lots_or_homesites", 62778,
  "LGIH", 2022L, 3L, "owned_lots_or_homesites", 60627,
  "LGIH", 2022L, 3L, "omega_numerator_lots_or_homesites", 15826,
  "LGIH", 2022L, 3L, "total_lots_or_homesites", 76453,
  "MTH", 2022L, 2L, "omega_numerator_lots_or_homesites", 24322,
  "SDHC", 2024L, 2L, "owned_lots_or_homesites", 1675,
  "SDHC", 2024L, 2L, "omega_numerator_lots_or_homesites", 14167,
  "SDHC", 2024L, 2L, "total_lots_or_homesites", 15842,
  "TMHC", 2021L, 1L, "omega_nonowned_controlled_share", 0.32,
  "TMHC", 2021L, 1L, "total_lots_or_homesites", 73000,
  "TMHC", 2022L, 1L, "owned_lots_or_homesites", 47169,
  "TMHC", 2022L, 1L, "omega_numerator_lots_or_homesites", 29714,
  "TMHC", 2022L, 1L, "total_lots_or_homesites", 76883,
  "TMHC", 2024L, 1L, "owned_lots_or_homesites", 35206,
  "TMHC", 2024L, 1L, "omega_numerator_lots_or_homesites", 38976,
  "TMHC", 2024L, 1L, "total_lots_or_homesites", 74182,
  "UHG", 2023L, 1L, "reported_pipeline_lots_or_homesites", 6249,
  "UHG", 2023L, 3L, "reported_pipeline_lots_or_homesites", 8635
)

benchmarks <- panel |>
  select(
    ticker, calendar_year, calendar_quarter, land_accession_number,
    owned_lots_or_homesites, omega_numerator_lots_or_homesites,
    total_lots_or_homesites, omega_nonowned_controlled_share,
    reported_pipeline_lots_or_homesites
  ) |>
  pivot_longer(
    cols = c(
      owned_lots_or_homesites, omega_numerator_lots_or_homesites,
      total_lots_or_homesites, omega_nonowned_controlled_share,
      reported_pipeline_lots_or_homesites
    ),
    names_to = "metric",
    values_to = "actual_value"
  ) |>
  inner_join(
    expected_values,
    by = c("ticker", "calendar_year", "calendar_quarter", "metric"),
    relationship = "one-to-one"
  ) |>
  transmute(
    audit_type = "hand_read_filing_benchmark",
    ticker,
    calendar_year,
    calendar_quarter,
    metric,
    expected_value,
    actual_value,
    difference = actual_value - expected_value,
    pass = !is.na(actual_value) & abs(difference) <= 1e-12,
    detail = paste("Value checked against SEC accession", land_accession_number)
  )

audit <- bind_rows(structural, coverage, annual_reconciliation, benchmarks) |>
  arrange(audit_type, ticker, calendar_year, calendar_quarter, metric)

if (any(!audit$pass)) {
  stop("At least one Tier-1 quarterly land-panel audit failed.")
}

write_csv_if_changed(audit, "../output/tier1_quarterly_land_panel_audit.csv")

cat("Wrote Tier-1 quarterly land-panel audit to ../output\n")
