# setwd("/Users/jacobherbstman/Desktop/homebuilder_10ks/tasks/audits/audit_tier1_sec_10q_filings/code")

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(tibble)
})

source("../../../_lib/homebuilder_pipeline_utils.R")

filing_index <- read_csv(
  "../input/tier1_2018_2025_sec_10q_filing_index.csv",
  show_col_types = FALSE,
  na = c("", "NA"),
  col_types = cols(cik10 = col_character(), accession_number = col_character())
)

download_inventory <- read_csv(
  "../input/tier1_2018_2025_sec_10q_download_inventory.csv",
  show_col_types = FALSE,
  na = c("", "NA"),
  col_types = cols(cik10 = col_character(), accession_number = col_character())
)

if (filing_index |> count(cik10, accession_number) |> filter(n != 1) |> nrow() > 0) {
  stop("Tier-1 SEC 10-Q filing index has duplicate accession keys.")
}

if (download_inventory |> count(cik10, accession_number) |> filter(n != 1) |> nrow() > 0) {
  stop("Tier-1 SEC 10-Q download inventory has duplicate accession keys.")
}

joined <- filing_index |>
  select(cik10, accession_number, index_ticker = ticker, index_report_date = report_date) |>
  left_join(
    download_inventory |>
      select(cik10, accession_number, inventory_ticker = ticker, inventory_report_date = report_date),
    by = c("cik10", "accession_number"),
    relationship = "one-to-one"
  )

source_files <- file.path("..", download_inventory$source_local_path)
directory_index_files <- file.path("..", download_inventory$directory_index_local_path)

source_hashes <- vapply(
  source_files,
  digest::digest,
  character(1),
  algo = "sha256",
  file = TRUE,
  serialize = FALSE
)

coverage <- filing_index |>
  filter(selected_for_panel) |>
  group_by(ticker, company, cik10) |>
  summarise(
    selected_10q_filings = n(),
    calendar_panel_filings = sum(calendar_panel_window_flag),
    fiscal_q4_lookback_filings = sum(fiscal_q4_derivation_lookback_flag),
    first_report_date = min(as.Date(report_date)),
    last_report_date = max(as.Date(report_date)),
    first_calendar_year = min(calendar_year),
    last_calendar_year = max(calendar_year),
    downloaded_filings = sum(
      download_inventory$primary_document_status[
        match(accession_number, download_inventory$accession_number)
      ] %in% c("downloaded", "already_present")
    ),
    .groups = "drop"
  ) |>
  arrange(ticker)

audit <- tribble(
  ~check, ~expected, ~observed, ~pass, ~detail,
  "tier1_firms", "20", as.character(n_distinct(filing_index$ticker)), n_distinct(filing_index$ticker) == 20, "Every Tier-1 firm appears in the 10-Q index.",
  "unique_filing_accessions", as.character(nrow(filing_index)), as.character(n_distinct(paste(filing_index$cik10, filing_index$accession_number))), nrow(filing_index) == n_distinct(paste(filing_index$cik10, filing_index$accession_number)), "CIK-accession keys are unique.",
  "selected_report_dates", as.character(filing_index |> distinct(ticker, report_date) |> nrow()), as.character(sum(filing_index$selected_for_panel)), filing_index |> filter(selected_for_panel) |> count(ticker, report_date) |> filter(n != 1) |> nrow() == 0, "Exactly one filing is selected for each firm report date.",
  "selected_calendar_quarters", "at most one", as.character(filing_index |> filter(selected_for_panel, calendar_panel_window_flag) |> count(ticker, calendar_year, calendar_quarter) |> summarise(maximum = max(n)) |> pull(maximum)), filing_index |> filter(selected_for_panel, calendar_panel_window_flag) |> count(ticker, calendar_year, calendar_quarter) |> filter(n > 1) |> nrow() == 0, "No firm has two selected 10-Qs mapped to the same calendar quarter.",
  "inventory_rows", as.character(nrow(filing_index)), as.character(nrow(download_inventory)), nrow(download_inventory) == nrow(filing_index), "Every indexed filing has one inventory row.",
  "inventory_metadata", as.character(nrow(filing_index)), as.character(sum(!is.na(joined$inventory_ticker) & joined$index_ticker == joined$inventory_ticker & as.Date(joined$index_report_date) == as.Date(joined$inventory_report_date))), all(!is.na(joined$inventory_ticker) & joined$index_ticker == joined$inventory_ticker & as.Date(joined$index_report_date) == as.Date(joined$inventory_report_date)), "Index and inventory ticker/report-date metadata agree.",
  "download_status", as.character(nrow(download_inventory)), as.character(sum(download_inventory$primary_document_status %in% c("downloaded", "already_present"))), all(download_inventory$primary_document_status %in% c("downloaded", "already_present")), "Every primary filing document downloaded successfully.",
  "source_files", as.character(nrow(download_inventory)), as.character(sum(file.exists(source_files))), all(file.exists(source_files)), "Every recorded primary filing path exists.",
  "directory_index_files", as.character(nrow(download_inventory)), as.character(sum(file.exists(directory_index_files))), all(file.exists(directory_index_files)), "Every recorded SEC directory index exists.",
  "source_checksums", as.character(nrow(download_inventory)), as.character(sum(source_hashes == download_inventory$source_checksum_sha256)), all(source_hashes == download_inventory$source_checksum_sha256), "Every primary filing matches its recorded SHA-256 checksum."
)

if (any(!audit$pass)) {
  print(audit |> filter(!pass))
  stop("Tier-1 SEC 10-Q audit failed.")
}

write_csv_if_changed(audit, "../output/tier1_2018_2025_sec_10q_audit.csv")
write_csv_if_changed(coverage, "../output/tier1_2018_2025_sec_10q_coverage.csv")

cat("Wrote Tier-1 SEC 10-Q audits to ../output\n")
