# setwd("/Users/jacobherbstman/Desktop/homebuilder_10ks/tasks/audit_sec_coverage/code")

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(stringr)
  library(tibble)
})

source("../../_lib/homebuilder_pipeline_utils.R")

as_task_bool <- function(x) {
  x %in% c(TRUE, "TRUE", "true", "True", "1", 1)
}

as_task_int <- function(x) {
  suppressWarnings(as.integer(as.character(x)))
}

crosswalk <- read_csv("../input/builder_sec_crosswalk.csv", show_col_types = FALSE, na = c("", "NA")) |>
  mutate(
    sec_reporting_indicator = as_task_bool(sec_reporting_indicator),
    public_parent_no_comparable_us_10k = as_task_bool(public_parent_no_comparable_us_10k),
    manual_review_indicator = as_task_bool(manual_review_indicator),
    ever_marked_public = as_task_bool(ever_marked_public),
    first_public_list_year = as_task_int(first_public_list_year),
    last_public_list_year = as_task_int(last_public_list_year),
    cik10 = as.character(cik10)
  )

filing_index <- read_csv("../input/sec_10k_filing_index.csv", show_col_types = FALSE, na = c("", "NA")) |>
  mutate(
    fiscal_year = as_task_int(fiscal_year),
    filing_date = suppressWarnings(as.Date(filing_date)),
    report_date = suppressWarnings(as.Date(report_date)),
    cik10 = as.character(cik10),
    accession_number = as.character(accession_number),
    ticker = as.character(ticker)
  ) |>
  filter(!is.na(accession_number))

download_inventory <- read_csv("../input/sec_10k_download_inventory.csv", show_col_types = FALSE, na = c("", "NA")) |>
  mutate(
    fiscal_year = as_task_int(fiscal_year),
    cik10 = as.character(cik10),
    accession_number = as.character(accession_number),
    ticker = as.character(ticker)
  ) |>
  filter(!is.na(accession_number))

land_candidates <- read_csv("../input/tenk_land_candidates.csv", show_col_types = FALSE, na = c("", "NA")) |>
  mutate(
    cik10 = as.character(cik10),
    accession_number = as.character(accession_number),
    ticker = as.character(ticker)
  ) |>
  filter(!is.na(accession_number))

mention_flags <- read_csv("../input/tenk_land_mention_flags.csv", show_col_types = FALSE, na = c("", "NA")) |>
  mutate(
    cik10 = as.character(cik10),
    accession_number = as.character(accession_number),
    ticker = as.character(ticker),
    land_term_hit_count = as_task_int(land_term_hit_count)
  ) |>
  filter(!is.na(accession_number))

sec_public_builders_unmatched <- crosswalk |>
  filter(
    ever_marked_public,
    is.na(cik10) | !sec_reporting_indicator | public_parent_no_comparable_us_10k | manual_review_indicator
  ) |>
  mutate(
    review_reason = case_when(
      is.na(cik10) ~ "no_cik",
      !sec_reporting_indicator ~ "not_sec_reporting",
      public_parent_no_comparable_us_10k ~ "public_parent_no_comparable_us_10k",
      manual_review_indicator ~ "manual_review",
      TRUE ~ "review"
    )
  ) |>
  arrange(first_public_list_year, builder_name_clean)

matched_reporting <- crosswalk |>
  filter(sec_reporting_indicator, !is.na(cik10), !public_parent_no_comparable_us_10k) |>
  select(
    builder_name_key, builder_name_clean, first_public_list_year, last_public_list_year,
    ticker, cik, cik10, sec_company_name, match_method, manual_review_indicator, notes
  )

filing_counts <- filing_index |>
  distinct(cik10, accession_number) |>
  count(cik10, name = "indexed_10k_filings")

sec_matched_no_10k_filings <- matched_reporting |>
  left_join(filing_counts, by = "cik10", relationship = "many-to-one") |>
  mutate(indexed_10k_filings = coalesce(indexed_10k_filings, 0L)) |>
  filter(indexed_10k_filings == 0L) |>
  arrange(first_public_list_year, builder_name_clean)

first_filing_year <- filing_index |>
  filter(!is.na(fiscal_year)) |>
  group_by(cik10) |>
  summarise(
    first_sec_fiscal_year = if (all(is.na(fiscal_year))) NA_integer_ else min(fiscal_year, na.rm = TRUE),
    first_sec_report_date = if (all(is.na(report_date))) as.Date(NA) else min(report_date, na.rm = TRUE),
    .groups = "drop"
  )

sec_filings_start_after_builder_public_year <- matched_reporting |>
  left_join(first_filing_year, by = "cik10", relationship = "many-to-one") |>
  filter(
    !is.na(first_public_list_year),
    !is.na(first_sec_fiscal_year),
    first_sec_fiscal_year > first_public_list_year
  ) |>
  mutate(year_gap = first_sec_fiscal_year - first_public_list_year) |>
  arrange(desc(year_gap), first_public_list_year, builder_name_clean)

sec_download_status_audit <- download_inventory |>
  mutate(
    primary_document_download_ok = primary_document_status %in% c("downloaded", "already_present"),
    directory_index_download_ok = directory_index_status %in% c("downloaded", "already_present")
  ) |>
  select(
    builder_name_key, builder_name_clean, ticker, cik10, sec_company_name,
    accession_number, form, filing_date, report_date, fiscal_year, primary_document,
    directory_index_status, primary_document_status, directory_index_http_status,
    primary_document_http_status, primary_document_download_ok,
    directory_index_download_ok, primary_document_local_path, filing_url,
    primary_document_error, directory_index_error
  ) |>
  arrange(builder_name_clean, desc(fiscal_year), accession_number)

land_hit_counts <- mention_flags |>
  group_by(cik10, accession_number) |>
  summarise(
    land_term_hit_count = if (all(is.na(land_term_hit_count))) 0L else max(coalesce(land_term_hit_count, 0L), na.rm = TRUE),
    parser_row_present = TRUE,
    .groups = "drop"
  )

sec_filings_no_land_hits <- download_inventory |>
  filter(primary_document_status %in% c("downloaded", "already_present")) |>
  select(
    builder_name_key, builder_name_clean, ticker, cik10, sec_company_name,
    accession_number, form, filing_date, report_date, fiscal_year, primary_document,
    primary_document_local_path, filing_url
  ) |>
  left_join(land_hit_counts, by = c("cik10", "accession_number"), relationship = "one-to-one") |>
  mutate(
    parser_row_present = coalesce(parser_row_present, FALSE),
    land_term_hit_count = coalesce(land_term_hit_count, 0L)
  ) |>
  filter(land_term_hit_count == 0L) |>
  arrange(builder_name_clean, desc(fiscal_year), accession_number)

benchmark_expected <- tibble(
  benchmark_name = c("pulte_2011", "d_r_horton_2024", "lennar_2024", "nvr_2024"),
  expected_ticker = c("PHM", "DHI", "LEN", "NVR"),
  expected_report_date = as.Date(c("2011-12-31", "2024-09-30", "2024-11-30", "2024-12-31")),
  expected_accession_number = c("0000822416-12-000010", "0000882184-24-000057", "0001628280-25-002404", "0000906163-25-000011")
)

indexed_benchmarks <- filing_index |>
  transmute(
    expected_ticker = ticker,
    expected_accession_number = accession_number,
    indexed_flag = TRUE,
    indexed_form = form,
    indexed_filing_date = filing_date,
    indexed_report_date = report_date,
    indexed_primary_document = primary_document
  ) |>
  distinct(expected_ticker, expected_accession_number, .keep_all = TRUE)

downloaded_benchmarks <- download_inventory |>
  transmute(
    expected_ticker = ticker,
    expected_accession_number = accession_number,
    downloaded_or_present_flag = primary_document_status %in% c("downloaded", "already_present"),
    primary_document_status,
    primary_document_local_path
  ) |>
  distinct(expected_ticker, expected_accession_number, .keep_all = TRUE)

mention_benchmarks <- mention_flags |>
  transmute(
    expected_ticker = ticker,
    expected_accession_number = accession_number,
    land_term_hit_count = coalesce(land_term_hit_count, 0L)
  ) |>
  group_by(expected_ticker, expected_accession_number) |>
  summarise(land_term_hit_count = max(land_term_hit_count, na.rm = TRUE), .groups = "drop")

candidate_benchmarks <- land_candidates |>
  count(ticker, accession_number, name = "candidate_rows") |>
  transmute(
    expected_ticker = ticker,
    expected_accession_number = accession_number,
    candidate_rows
  )

sec_benchmark_availability <- benchmark_expected |>
  left_join(indexed_benchmarks, by = c("expected_ticker", "expected_accession_number"), relationship = "one-to-one") |>
  left_join(downloaded_benchmarks, by = c("expected_ticker", "expected_accession_number"), relationship = "one-to-one") |>
  left_join(mention_benchmarks, by = c("expected_ticker", "expected_accession_number"), relationship = "one-to-one") |>
  left_join(candidate_benchmarks, by = c("expected_ticker", "expected_accession_number"), relationship = "one-to-one") |>
  mutate(
    indexed_flag = coalesce(indexed_flag, FALSE),
    downloaded_or_present_flag = coalesce(downloaded_or_present_flag, FALSE),
    land_term_hit_count = coalesce(land_term_hit_count, 0L),
    candidate_rows = coalesce(candidate_rows, 0L),
    availability_status = case_when(
      indexed_flag & downloaded_or_present_flag & candidate_rows > 0 ~ "parsed_with_candidates",
      indexed_flag & downloaded_or_present_flag & land_term_hit_count > 0 ~ "downloaded_with_hits",
      indexed_flag & downloaded_or_present_flag ~ "downloaded_no_candidates",
      indexed_flag ~ "indexed_not_downloaded",
      TRUE ~ "not_indexed"
    )
  )

sec_builder_coverage_audit <- tibble(
  audit_area = c(
    "builder_roster",
    "builder_roster",
    "builder_sec_crosswalk",
    "builder_sec_crosswalk",
    "builder_sec_crosswalk",
    "sec_index",
    "sec_index",
    "sec_index",
    "sec_downloads",
    "sec_downloads",
    "sec_downloads",
    "tenk_parser",
    "tenk_parser",
    "tenk_parser",
    "benchmarks",
    "benchmarks",
    "benchmarks",
    "benchmarks"
  ),
  check = c(
    "builder_public_firms",
    "builder_public_firms_manual_review_or_unmatched",
    "public_firms_with_known_sec_reporting_cik",
    "public_parent_or_noncomparable_rows",
    "matched_sec_reporting_rows_with_no_10k_filings",
    "indexed_10k_filings",
    "unique_sec_reporting_builders_with_indexed_10ks",
    "filings_start_after_first_builder_public_year",
    "filings_requested_for_download",
    "primary_documents_downloaded_or_present",
    "primary_document_download_failures",
    "filings_with_parser_rows",
    "filings_with_land_term_hits",
    "candidate_rows",
    "benchmark_pulte_2011_available",
    "benchmark_d_r_horton_2024_available",
    "benchmark_lennar_2024_available",
    "benchmark_nvr_2024_available"
  ),
  status = c(
    if_else(nrow(crosswalk) > 0, "ok", "fail"),
    if_else(nrow(sec_public_builders_unmatched) == 0, "ok", "warn"),
    if_else(nrow(matched_reporting) > 0, "ok", "fail"),
    "ok",
    if_else(nrow(sec_matched_no_10k_filings) == 0, "ok", "warn"),
    if_else(nrow(filing_index) > 0, "ok", "fail"),
    if_else(n_distinct(filing_index$cik10) > 0, "ok", "fail"),
    if_else(nrow(sec_filings_start_after_builder_public_year) == 0, "ok", "warn"),
    if_else(nrow(download_inventory) > 0, "ok", "fail"),
    if_else(sum(sec_download_status_audit$primary_document_download_ok, na.rm = TRUE) > 0, "ok", "fail"),
    if_else(sum(!sec_download_status_audit$primary_document_download_ok, na.rm = TRUE) == 0, "ok", "warn"),
    if_else(nrow(mention_flags) > 0, "ok", "warn"),
    if_else(sum(mention_flags$land_term_hit_count > 0, na.rm = TRUE) > 0, "ok", "warn"),
    if_else(nrow(land_candidates) > 0, "ok", "warn"),
    if_else(any(sec_benchmark_availability$benchmark_name == "pulte_2011" & sec_benchmark_availability$indexed_flag), "ok", "warn"),
    if_else(any(sec_benchmark_availability$benchmark_name == "d_r_horton_2024" & sec_benchmark_availability$indexed_flag), "ok", "warn"),
    if_else(any(sec_benchmark_availability$benchmark_name == "lennar_2024" & sec_benchmark_availability$indexed_flag), "ok", "warn"),
    if_else(any(sec_benchmark_availability$benchmark_name == "nvr_2024" & sec_benchmark_availability$indexed_flag), "ok", "warn")
  ),
  value = c(
    nrow(crosswalk),
    nrow(sec_public_builders_unmatched),
    nrow(matched_reporting),
    sum(crosswalk$public_parent_no_comparable_us_10k, na.rm = TRUE),
    nrow(sec_matched_no_10k_filings),
    nrow(filing_index),
    n_distinct(filing_index$cik10),
    nrow(sec_filings_start_after_builder_public_year),
    nrow(download_inventory),
    sum(sec_download_status_audit$primary_document_download_ok, na.rm = TRUE),
    sum(!sec_download_status_audit$primary_document_download_ok, na.rm = TRUE),
    nrow(mention_flags),
    sum(mention_flags$land_term_hit_count > 0, na.rm = TRUE),
    nrow(land_candidates),
    as.integer(any(sec_benchmark_availability$benchmark_name == "pulte_2011" & sec_benchmark_availability$indexed_flag)),
    as.integer(any(sec_benchmark_availability$benchmark_name == "d_r_horton_2024" & sec_benchmark_availability$indexed_flag)),
    as.integer(any(sec_benchmark_availability$benchmark_name == "lennar_2024" & sec_benchmark_availability$indexed_flag)),
    as.integer(any(sec_benchmark_availability$benchmark_name == "nvr_2024" & sec_benchmark_availability$indexed_flag))
  ),
  detail = c(
    "Rows inherited from builder_public_firm_roster.",
    "Includes no-CIK, manual-review, non-SEC-reporting, and non-comparable public-parent rows.",
    "Rows eligible for SEC submissions downloads.",
    "Rows retained but excluded from comparable U.S. 10-K downloads.",
    "Matched rows with no indexed 10-K/10-KA/10-KT filings.",
    "All available SEC years, with Builder-era flag upstream.",
    "Distinct CIKs with indexed 10-K filings.",
    "SEC filing coverage begins after first Builder-public year.",
    "Rows in SEC download inventory.",
    "Primary documents with downloaded or already_present status.",
    "Primary documents not downloaded or not present.",
    "Downloaded filings with parser mention rows.",
    "Parser rows with at least one tracked land term mention.",
    "Deterministic snippet-level candidate values.",
    "Expected accession 0000822416-12-000010.",
    "Expected accession 0000882184-24-000057.",
    "Expected accession 0001628280-25-002404.",
    "Expected accession 0000906163-25-000011."
  )
)

write_csv_if_changed(sec_builder_coverage_audit, "../output/sec_builder_coverage_audit.csv")
write_csv_if_changed(sec_public_builders_unmatched, "../output/sec_public_builders_unmatched.csv")
write_csv_if_changed(sec_matched_no_10k_filings, "../output/sec_matched_no_10k_filings.csv")
write_csv_if_changed(sec_filings_start_after_builder_public_year, "../output/sec_filings_start_after_builder_public_year.csv")
write_csv_if_changed(sec_download_status_audit, "../output/sec_download_status_audit.csv")
write_csv_if_changed(sec_filings_no_land_hits, "../output/sec_filings_no_land_hits.csv")
write_csv_if_changed(sec_benchmark_availability, "../output/sec_benchmark_availability.csv")

cat("Wrote SEC coverage audit outputs to ../output\n")
