# setwd("/Users/jacobherbstman/Desktop/homebuilder_10ks/tasks/build_tier1_quarterly_skeleton/code")
# start_year <- 2018L
# end_year <- 2025L

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(tidyr)
})

source("../../_lib/homebuilder_pipeline_utils.R")

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 2) {
  stop("Expected start_year and end_year.")
}

start_year <- as.integer(args[1])
end_year <- as.integer(args[2])

annual_panel <- read_csv(
  "../input/tier1_2018_2025_annual_panel.csv",
  show_col_types = FALSE,
  na = c("", "NA"),
  col_types = cols(cik10 = col_character(), operating_accession_number = col_character())
) |>
  mutate(
    report_date = as.Date(report_date),
    filing_date = as.Date(filing_date)
  )

firms <- annual_panel |>
  distinct(
    ticker, company, cik10, sec_company_name, valid_from_year, valid_to_year,
    recent_ipo_flag, merger_splice_flag, fiscal_year_warning,
    fate_and_splicing_notes
  ) |>
  arrange(ticker)

if (nrow(firms) != 20 || n_distinct(firms$ticker) != 20 || n_distinct(firms$cik10) != 20) {
  stop("Expected 20 unique Tier-1 firms in the annual panel.")
}

fiscal_calendar <- annual_panel |>
  filter(public_filing_observed, !is.na(report_date)) |>
  arrange(ticker, fiscal_year) |>
  group_by(ticker) |>
  slice_tail(n = 1) |>
  transmute(
    ticker,
    fiscal_end_month = as.integer(format(report_date, "%m")),
    fiscal_end_day = as.integer(format(report_date, "%d"))
  ) |>
  ungroup()

if (nrow(fiscal_calendar) != 20) {
  stop("Could not infer one fiscal year-end for every Tier-1 firm.")
}

tenq_filings <- read_csv(
  "../input/tier1_2018_2025_sec_10q_download_inventory.csv",
  show_col_types = FALSE,
  na = c("", "NA"),
  col_types = cols(cik10 = col_character(), accession_number = col_character())
) |>
  filter(
    selected_for_panel,
    calendar_panel_window_flag,
    primary_document_status %in% c("downloaded", "already_present")
  ) |>
  mutate(
    report_date = as.Date(report_date),
    filing_date = as.Date(filing_date),
    report_month = as.integer(format(report_date, "%m"))
  ) |>
  left_join(fiscal_calendar, by = "ticker", relationship = "many-to-one") |>
  mutate(
    fiscal_quarter = case_when(
      report_month == ((fiscal_end_month + 3L - 1L) %% 12L) + 1L ~ 1L,
      report_month == ((fiscal_end_month + 6L - 1L) %% 12L) + 1L ~ 2L,
      report_month == ((fiscal_end_month + 9L - 1L) %% 12L) + 1L ~ 3L,
      TRUE ~ NA_integer_
    ),
    fiscal_year = if_else(report_month > fiscal_end_month, calendar_year + 1L, calendar_year),
    source_form = form,
    source_kind = "interim_10q",
    source_accession_number = accession_number,
    source_filing_date = filing_date,
    source_report_date = report_date,
    source_url = filing_url
  ) |>
  select(
    ticker, calendar_year, calendar_quarter, fiscal_year, fiscal_quarter,
    source_form, source_kind, source_accession_number, source_filing_date,
    source_report_date, source_url, source_local_path, source_checksum_sha256
  )

if (any(is.na(tenq_filings$fiscal_quarter))) {
  stop("At least one selected 10-Q does not match the inferred fiscal calendar.")
}

tenk_filings <- annual_panel |>
  filter(
    public_filing_observed,
    !is.na(report_date),
    as.integer(format(report_date, "%Y")) %in% start_year:end_year
  ) |>
  transmute(
    ticker,
    calendar_year = as.integer(format(report_date, "%Y")),
    calendar_quarter = ((as.integer(format(report_date, "%m")) - 1L) %/% 3L) + 1L,
    fiscal_year = as.integer(fiscal_year),
    fiscal_quarter = 4L,
    source_form = "10-K",
    source_kind = "annual_10k",
    source_accession_number = operating_accession_number,
    source_filing_date = filing_date,
    source_report_date = report_date,
    source_url = operating_filing_url,
    source_local_path = operating_source_local_path,
    source_checksum_sha256 = operating_source_checksum_sha256
  )

filings <- bind_rows(tenq_filings, tenk_filings) |>
  arrange(ticker, calendar_year, calendar_quarter)

if (filings |> count(ticker, calendar_year, calendar_quarter) |> filter(n != 1) |> nrow() > 0) {
  stop("Multiple SEC source filings map to the same Tier-1 calendar quarter.")
}

observed_bounds <- filings |>
  mutate(quarter_index = calendar_year * 4L + calendar_quarter) |>
  group_by(ticker) |>
  summarise(
    first_observed_quarter_index = min(quarter_index),
    last_observed_quarter_index = max(quarter_index),
    .groups = "drop"
  )

quarterly_skeleton <- crossing(
  ticker = firms$ticker,
  calendar_year = start_year:end_year,
  calendar_quarter = 1:4
) |>
  left_join(firms, by = "ticker", relationship = "many-to-one") |>
  left_join(fiscal_calendar, by = "ticker", relationship = "many-to-one") |>
  left_join(
    filings,
    by = c("ticker", "calendar_year", "calendar_quarter"),
    relationship = "one-to-one"
  ) |>
  left_join(observed_bounds, by = "ticker", relationship = "many-to-one") |>
  mutate(
    calendar_quarter_label = paste0(calendar_year, "Q", calendar_quarter),
    calendar_quarter_end = as.Date(case_when(
      calendar_quarter == 1L ~ paste0(calendar_year, "-03-31"),
      calendar_quarter == 2L ~ paste0(calendar_year, "-06-30"),
      calendar_quarter == 3L ~ paste0(calendar_year, "-09-30"),
      calendar_quarter == 4L ~ paste0(calendar_year, "-12-31")
    )),
    quarter_index = calendar_year * 4L + calendar_quarter,
    filing_observed = !is.na(source_accession_number),
    panel_state = case_when(
      filing_observed ~ "public_filing_observed",
      quarter_index < first_observed_quarter_index ~ "pre_public",
      !is.na(valid_to_year) & quarter_index > last_observed_quarter_index ~ "post_exit",
      TRUE ~ "public_filing_missing"
    ),
    public_reporting_episode_indicator = panel_state %in% c("public_filing_observed", "public_filing_missing"),
    pre_public_indicator = panel_state == "pre_public",
    death_indicator = panel_state == "post_exit"
  ) |>
  select(
    ticker, company, cik10, sec_company_name,
    calendar_year, calendar_quarter, calendar_quarter_label,
    calendar_quarter_end, panel_state, public_reporting_episode_indicator,
    filing_observed, pre_public_indicator, death_indicator,
    fiscal_year, fiscal_quarter, fiscal_end_month, fiscal_end_day,
    valid_from_year, valid_to_year, recent_ipo_flag, merger_splice_flag,
    fiscal_year_warning, fate_and_splicing_notes,
    source_form, source_kind, source_accession_number, source_report_date,
    source_filing_date, source_url, source_local_path, source_checksum_sha256
  ) |>
  arrange(ticker, calendar_year, calendar_quarter)

if (
  nrow(quarterly_skeleton) != 20 * (end_year - start_year + 1L) * 4L ||
  quarterly_skeleton |> count(ticker, calendar_year, calendar_quarter) |> filter(n != 1) |> nrow() > 0 ||
  any(quarterly_skeleton$panel_state == "public_filing_missing")
) {
  stop("Tier-1 quarterly skeleton validation failed.")
}

write_csv_if_changed(quarterly_skeleton, "../output/tier1_2018_2025_quarterly_skeleton.csv")

cat("Wrote Tier-1 quarterly skeleton to ../output\n")
