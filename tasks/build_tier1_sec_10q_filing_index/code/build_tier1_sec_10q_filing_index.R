# setwd("/Users/jacobherbstman/Desktop/homebuilder_10ks/tasks/build_tier1_sec_10q_filing_index/code")
# index_start_date <- "20171001"
# index_end_date <- "20251231"

suppressPackageStartupMessages({
  library(dplyr)
  library(jsonlite)
  library(readr)
  library(stringr)
  library(tibble)
})

source("../../_lib/homebuilder_pipeline_utils.R")

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 2) {
  stop("Expected index_start_date and index_end_date.")
}

index_start_date <- as.Date(args[1], format = "%Y%m%d")
index_end_date <- as.Date(args[2], format = "%Y%m%d")

firms <- read_csv(
  "../input/tier1_2018_2025_annual_panel.csv",
  show_col_types = FALSE,
  na = c("", "NA"),
  col_types = cols(cik10 = col_character())
) |>
  distinct(ticker, company, cik10, sec_company_name, valid_from_year, valid_to_year) |>
  arrange(ticker)

if (nrow(firms) != 20 || n_distinct(firms$ticker) != 20 || n_distinct(firms$cik10) != 20 || any(is.na(firms$cik10))) {
  stop("Expected 20 Tier-1 firms with unique SEC CIKs.")
}

submission_files <- read_csv(
  "../input/sec_submissions_files.csv",
  show_col_types = FALSE,
  na = c("", "NA"),
  col_types = cols(cik10 = col_character())
) |>
  filter(cik10 %in% firms$cik10) |>
  arrange(cik10, source_local_path)

if (n_distinct(submission_files$cik10) != 20) {
  stop("SEC submissions files are missing for at least one Tier-1 firm.")
}

if (any(!submission_files$status %in% c("downloaded", "already_present")) ||
    any(!file.exists(submission_files$source_local_path))) {
  stop("At least one required SEC submissions file was not downloaded or is missing locally.")
}

filing_rows <- vector("list", nrow(submission_files))

for (i in seq_len(nrow(submission_files))) {
  submission_json <- fromJSON(submission_files$source_local_path[i], simplifyVector = FALSE)
  submission_lists <- if (!is.null(submission_json$filings$recent)) submission_json$filings$recent else submission_json
  row_count <- max(vapply(submission_lists, length, integer(1)))

  filing_rows[[i]] <- as_tibble(lapply(submission_lists, function(x) {
    x <- as.character(x)
    length(x) <- row_count
    x
  })) |>
    transmute(
      cik10 = submission_files$cik10[i],
      accession_number = accessionNumber,
      form,
      filing_date = as.Date(filingDate),
      report_date = as.Date(reportDate),
      primary_document = primaryDocument,
      primary_document_description = primaryDocDescription,
      source_submissions_path = submission_files$source_local_path[i]
    )
}

filing_index <- bind_rows(filing_rows) |>
  filter(
    form %in% c("10-Q", "10-Q/A", "10-QT"),
    !is.na(report_date),
    report_date >= index_start_date,
    report_date <= index_end_date
  ) |>
  arrange(cik10, accession_number, desc(form == "10-Q"), desc(filing_date), source_submissions_path) |>
  distinct(cik10, accession_number, .keep_all = TRUE) |>
  left_join(firms, by = "cik10", relationship = "many-to-one") |>
  mutate(
    accession_number_no_dashes = str_remove_all(accession_number, "-"),
    cik_no_leading_zeros = str_remove(cik10, "^0+"),
    calendar_year = as.integer(format(report_date, "%Y")),
    calendar_quarter = ((as.integer(format(report_date, "%m")) - 1L) %/% 3L) + 1L,
    calendar_quarter_label = paste0(calendar_year, "Q", calendar_quarter),
    amendment_indicator = form == "10-Q/A",
    calendar_panel_window_flag = report_date >= as.Date("2018-01-01"),
    fiscal_q4_derivation_lookback_flag = report_date < as.Date("2018-01-01"),
    filing_url = paste0(
      "https://www.sec.gov/Archives/edgar/data/", cik_no_leading_zeros, "/",
      accession_number_no_dashes, "/", primary_document
    )
  ) |>
  filter(
    calendar_year >= valid_from_year,
    is.na(valid_to_year) | calendar_year <= valid_to_year
  ) |>
  arrange(ticker, report_date, desc(form == "10-Q"), desc(form == "10-QT"), desc(filing_date), accession_number) |>
  group_by(ticker, report_date) |>
  mutate(selected_for_panel = row_number() == 1L) |>
  ungroup() |>
  select(
    ticker, company, cik10, cik_no_leading_zeros, sec_company_name,
    valid_from_year, valid_to_year,
    accession_number, accession_number_no_dashes, form, amendment_indicator,
    filing_date, report_date, calendar_year, calendar_quarter,
    calendar_quarter_label, selected_for_panel, calendar_panel_window_flag,
    fiscal_q4_derivation_lookback_flag, primary_document,
    primary_document_description, filing_url, source_submissions_path
  ) |>
  arrange(ticker, report_date, desc(selected_for_panel), filing_date, accession_number)

if (
  n_distinct(filing_index$ticker) != 20 ||
  any(is.na(filing_index$primary_document)) ||
  filing_index |> count(cik10, accession_number) |> filter(n != 1) |> nrow() > 0 ||
  filing_index |> filter(selected_for_panel) |> count(ticker, report_date) |> filter(n != 1) |> nrow() > 0
) {
  stop("Tier-1 SEC 10-Q filing-index validation failed.")
}

write_csv_if_changed(filing_index, "../output/tier1_2018_2025_sec_10q_filing_index.csv")

cat("Wrote Tier-1 SEC 10-Q filing index to ../output\n")
