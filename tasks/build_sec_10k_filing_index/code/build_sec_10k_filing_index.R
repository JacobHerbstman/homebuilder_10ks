# setwd("/Users/jacobherbstman/Desktop/homebuilder_10ks/tasks/build_sec_10k_filing_index/code")

suppressPackageStartupMessages({
  library(dplyr)
  library(jsonlite)
  library(purrr)
  library(readr)
  library(stringr)
  library(tibble)
})

source("../../_lib/homebuilder_pipeline_utils.R")

empty_index <- tibble(
  builder_name_key = character(),
  builder_name_clean = character(),
  ticker = character(),
  cik = character(),
  cik10 = character(),
  cik_no_leading_zeros = character(),
  sec_company_name = character(),
  accession_number = character(),
  accession_number_no_dashes = character(),
  form = character(),
  filing_date = as.Date(character()),
  report_date = as.Date(character()),
  fiscal_year = integer(),
  primary_document = character(),
  primary_doc_description = character(),
  filing_url = character(),
  main_builder_era_flag = logical(),
  source_submissions_path = character()
)

benchmark_accessions <- tibble(
  benchmark_name = c("d_r_horton_2024", "lennar_2024", "nvr_2024"),
  expected_ticker = c("DHI", "LEN", "NVR"),
  expected_report_date = as.Date(c("2024-09-30", "2024-11-30", "2024-12-31")),
  expected_accession_number = c("0000882184-24-000057", "0001628280-25-002404", "0000906163-25-000011")
)

parse_sec_date <- function(x) {
  out <- suppressWarnings(as.Date(as.character(x)))
  out
}

parallel_df <- function(x) {
  if (is.null(x) || length(x) == 0) {
    return(tibble())
  }

  max_len <- max(vapply(x, length, integer(1)))
  as_tibble(lapply(x, function(v) {
    v <- as.character(v)
    length(v) <- max_len
    v
  }))
}

parse_submissions_file <- function(row) {
  if (!file.exists(row$source_local_path)) {
    return(tibble())
  }

  submission_json <- tryCatch(fromJSON(row$source_local_path, simplifyVector = FALSE), error = function(e) NULL)
  if (is.null(submission_json)) {
    return(tibble())
  }

  filings <- if (!is.null(submission_json$filings$recent)) {
    parallel_df(submission_json$filings$recent)
  } else {
    parallel_df(submission_json)
  }

  if (nrow(filings) == 0 || !"accessionNumber" %in% names(filings)) {
    return(tibble())
  }

  filings |>
    transmute(
      cik10 = row$cik10,
      accession_number = as.character(accessionNumber),
      form = as.character(form),
      filing_date = parse_sec_date(filingDate),
      report_date = parse_sec_date(reportDate),
      primary_document = if ("primaryDocument" %in% names(filings)) as.character(primaryDocument) else NA_character_,
      primary_doc_description = if ("primaryDocDescription" %in% names(filings)) as.character(primaryDocDescription) else NA_character_,
      source_submissions_path = row$source_local_path
    )
}

crosswalk <- read_csv("../input/builder_sec_crosswalk.csv", show_col_types = FALSE, na = c("", "NA")) |>
  mutate(cik10 = as.character(cik10)) |>
  filter(sec_reporting_indicator %in% TRUE, !is.na(cik10), public_parent_no_comparable_us_10k %in% FALSE) |>
  distinct(cik10, .keep_all = TRUE) |>
  select(builder_name_key, builder_name_clean, ticker, cik, cik10, sec_company_name, first_public_list_year, last_public_list_year)

submission_files <- read_csv("../input/sec_submissions_files.csv", show_col_types = FALSE, na = c("", "NA")) |>
  filter(status %in% c("downloaded", "already_present"), file.exists(source_local_path)) |>
  mutate(cik10 = as.character(cik10), source_local_path = as.character(source_local_path))

if (nrow(submission_files) == 0) {
  write_csv_if_changed(empty_index, "../output/sec_10k_filing_index.csv")
  write_csv_if_changed(
    benchmark_accessions |>
      mutate(
        indexed_accession_number = NA_character_,
        indexed_report_date = as.Date(NA),
        indexed_filing_date = as.Date(NA),
        indexed_form = NA_character_,
        indexed_primary_document = NA_character_,
        indexed_flag = FALSE
      ),
    "../output/sec_10k_benchmark_filings.csv"
  )
  write_csv_if_changed(tibble(check = "indexed_10k_filings", status = "fail", value = 0, detail = "No SEC submissions files available."), "../output/sec_10k_filing_index_qc.csv")
  quit(save = "no")
}

filings <- map_dfr(seq_len(nrow(submission_files)), function(i) parse_submissions_file(submission_files[i, ]))

tenk_index <- filings |>
  filter(form %in% c("10-K", "10-K/A", "10-KT")) |>
  left_join(crosswalk, by = "cik10", relationship = "many-to-one") |>
  mutate(
    accession_number_no_dashes = str_remove_all(accession_number, "-"),
    cik_no_leading_zeros = str_remove(cik10, "^0+"),
    fiscal_year = suppressWarnings(as.integer(format(coalesce(report_date, filing_date), "%Y"))),
    filing_url = paste0(
      "https://www.sec.gov/Archives/edgar/data/",
      cik_no_leading_zeros,
      "/",
      accession_number_no_dashes,
      "/",
      primary_document
    ),
    main_builder_era_flag = !is.na(fiscal_year) & fiscal_year >= 2004
  ) |>
  select(
    builder_name_key, builder_name_clean, ticker, cik, cik10, cik_no_leading_zeros,
    sec_company_name, accession_number, accession_number_no_dashes, form,
    filing_date, report_date, fiscal_year, primary_document, primary_doc_description,
    filing_url, main_builder_era_flag, source_submissions_path
  ) |>
  arrange(builder_name_clean, desc(report_date), desc(filing_date), accession_number)

benchmark_filings <- benchmark_accessions |>
  left_join(
    tenk_index |>
      transmute(
        expected_ticker = ticker,
        expected_accession_number = accession_number,
        indexed_accession_number = accession_number,
        indexed_report_date = report_date,
        indexed_filing_date = filing_date,
        indexed_form = form,
        indexed_primary_document = primary_document,
        indexed_flag = TRUE
      ),
    by = c("expected_ticker", "expected_accession_number"),
    relationship = "one-to-one"
  ) |>
  mutate(indexed_flag = coalesce(indexed_flag, FALSE))

qc_rows <- tibble(
  check = c(
    "submission_files_read",
    "indexed_10k_filings",
    "indexed_builder_era_10k_filings",
    "unique_sec_reporting_builders_with_10k",
    "benchmark_d_r_horton_2024_indexed",
    "benchmark_lennar_2024_indexed",
    "benchmark_nvr_2024_indexed"
  ),
  status = c(
    if_else(nrow(submission_files) > 0, "ok", "fail"),
    if_else(nrow(tenk_index) > 0, "ok", "fail"),
    if_else(sum(tenk_index$main_builder_era_flag, na.rm = TRUE) > 0, "ok", "warn"),
    if_else(n_distinct(tenk_index$cik10) > 0, "ok", "fail"),
    if_else(any(benchmark_filings$benchmark_name == "d_r_horton_2024" & benchmark_filings$indexed_flag), "ok", "warn"),
    if_else(any(benchmark_filings$benchmark_name == "lennar_2024" & benchmark_filings$indexed_flag), "ok", "warn"),
    if_else(any(benchmark_filings$benchmark_name == "nvr_2024" & benchmark_filings$indexed_flag), "ok", "warn")
  ),
  value = c(
    nrow(submission_files),
    nrow(tenk_index),
    sum(tenk_index$main_builder_era_flag, na.rm = TRUE),
    n_distinct(tenk_index$cik10),
    as.integer(any(benchmark_filings$benchmark_name == "d_r_horton_2024" & benchmark_filings$indexed_flag)),
    as.integer(any(benchmark_filings$benchmark_name == "lennar_2024" & benchmark_filings$indexed_flag)),
    as.integer(any(benchmark_filings$benchmark_name == "nvr_2024" & benchmark_filings$indexed_flag))
  ),
  detail = c(
    "",
    "",
    "Fiscal year inferred from report date, falling back to filing date.",
    "",
    rep("Benchmark accession availability check.", 3)
  )
)

write_csv_if_changed(tenk_index, "../output/sec_10k_filing_index.csv")
write_csv_if_changed(benchmark_filings, "../output/sec_10k_benchmark_filings.csv")
write_csv_if_changed(qc_rows, "../output/sec_10k_filing_index_qc.csv")

cat("Wrote SEC 10-K filing index outputs to ../output\n")
