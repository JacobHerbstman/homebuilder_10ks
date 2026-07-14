# setwd("/Users/jacobherbstman/Desktop/homebuilder_10ks/tasks/build_sec_10k_filing_index/code")

suppressPackageStartupMessages({
  library(dplyr)
  library(jsonlite)
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
  benchmark_name = c("pulte_2011", "d_r_horton_2024", "lennar_2024", "nvr_2024"),
  expected_ticker = c("PHM", "DHI", "LEN", "NVR"),
  expected_report_date = as.Date(c("2011-12-31", "2024-09-30", "2024-11-30", "2024-12-31")),
  expected_accession_number = c("0000822416-12-000010", "0000882184-24-000057", "0001628280-25-002404", "0000906163-25-000011")
)

crosswalk <- read_csv("../input/builder_sec_crosswalk.csv", show_col_types = FALSE, na = c("", "NA")) |>
  mutate(cik10 = as.character(cik10)) |>
  filter(sec_reporting_indicator %in% TRUE, !is.na(cik10), public_parent_no_comparable_us_10k %in% FALSE) |>
  distinct(cik10, .keep_all = TRUE) |>
  select(builder_name_key, builder_name_clean, ticker, cik, cik10, sec_company_name, first_public_list_year, last_public_list_year)

submission_files <- read_csv("../input/sec_submissions_files.csv", show_col_types = FALSE, na = c("", "NA")) |>
  filter(status %in% c("downloaded", "already_present"), file.exists(source_local_path)) |>
  mutate(cik10 = as.character(cik10), source_local_path = as.character(source_local_path))

manual_filing_seeds <- read_csv("manual_sec_10k_filing_seeds.csv", show_col_types = FALSE, na = c("", "NA")) |>
  mutate(
    cik10 = as.character(cik10),
    filing_date = suppressWarnings(as.Date(as.character(filing_date))),
    report_date = suppressWarnings(as.Date(as.character(report_date))),
    source_submissions_path = "manual_sec_10k_filing_seeds.csv"
  ) |>
  select(
    cik10, accession_number, form, filing_date, report_date,
    primary_document, primary_doc_description, source_submissions_path
  )

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

filings_from_submissions <- tibble()

for (i in seq_len(nrow(submission_files))) {
  submission_json <- tryCatch(
    fromJSON(submission_files$source_local_path[i], simplifyVector = FALSE),
    error = function(e) NULL
  )
  if (is.null(submission_json)) {
    next
  }

  submission_lists <- if (!is.null(submission_json$filings$recent)) {
    submission_json$filings$recent
  } else {
    submission_json
  }
  if (is.null(submission_lists) || length(submission_lists) == 0) {
    next
  }

  max_len <- max(vapply(submission_lists, length, integer(1)))
  filings_i <- as_tibble(lapply(submission_lists, function(v) {
    v <- as.character(v)
    length(v) <- max_len
    v
  }))
  if (nrow(filings_i) == 0 || !"accessionNumber" %in% names(filings_i)) {
    next
  }

  filings_from_submissions <- bind_rows(
    filings_from_submissions,
    filings_i |>
      transmute(
        cik10 = submission_files$cik10[i],
        accession_number = as.character(accessionNumber),
        form = as.character(form),
        filing_date = suppressWarnings(as.Date(as.character(filingDate))),
        report_date = suppressWarnings(as.Date(as.character(reportDate))),
        primary_document = if ("primaryDocument" %in% names(filings_i)) as.character(primaryDocument) else NA_character_,
        primary_doc_description = if ("primaryDocDescription" %in% names(filings_i)) as.character(primaryDocDescription) else NA_character_,
        source_submissions_path = submission_files$source_local_path[i]
      )
  )
}

filings_raw <- bind_rows(
  filings_from_submissions,
  manual_filing_seeds
)

duplicate_submission_groups <- filings_raw |>
  filter(form %in% c("10-K", "10-K/A", "10-KT")) |>
  count(cik10, accession_number) |>
  filter(n > 1)

filings <- filings_raw |>
  filter(form %in% c("10-K", "10-K/A", "10-KT")) |>
  arrange(cik10, accession_number, desc(form == "10-K"), desc(filing_date), desc(report_date), primary_document, source_submissions_path) |>
  group_by(cik10, accession_number) |>
  summarise(
    form = first(form),
    filing_date = first(filing_date),
    report_date = first(report_date),
    primary_document = first(primary_document),
    primary_doc_description = first(primary_doc_description),
    source_submissions_path = paste(
      sort(unique(source_submissions_path[!is.na(source_submissions_path) & source_submissions_path != ""])),
      collapse = " | "
    ),
    .groups = "drop"
  )

tenk_index <- filings |>
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
    "duplicate_submission_filing_rows_collapsed",
    "manual_10k_filing_seeds",
    "benchmark_pulte_2011_indexed",
    "benchmark_d_r_horton_2024_indexed",
    "benchmark_lennar_2024_indexed",
    "benchmark_nvr_2024_indexed"
  ),
  status = c(
    if_else(nrow(submission_files) > 0, "ok", "fail"),
    if_else(nrow(tenk_index) > 0, "ok", "fail"),
    if_else(sum(tenk_index$main_builder_era_flag, na.rm = TRUE) > 0, "ok", "warn"),
    if_else(n_distinct(tenk_index$cik10) > 0, "ok", "fail"),
    if_else(nrow(duplicate_submission_groups) == 0, "ok", "warn"),
    if_else(nrow(manual_filing_seeds) > 0, "ok", "ok"),
    if_else(any(benchmark_filings$benchmark_name == "pulte_2011" & benchmark_filings$indexed_flag), "ok", "warn"),
    if_else(any(benchmark_filings$benchmark_name == "d_r_horton_2024" & benchmark_filings$indexed_flag), "ok", "warn"),
    if_else(any(benchmark_filings$benchmark_name == "lennar_2024" & benchmark_filings$indexed_flag), "ok", "warn"),
    if_else(any(benchmark_filings$benchmark_name == "nvr_2024" & benchmark_filings$indexed_flag), "ok", "warn")
  ),
  value = c(
    nrow(submission_files),
    nrow(tenk_index),
    sum(tenk_index$main_builder_era_flag, na.rm = TRUE),
    n_distinct(tenk_index$cik10),
    nrow(duplicate_submission_groups),
    nrow(manual_filing_seeds),
    as.integer(any(benchmark_filings$benchmark_name == "pulte_2011" & benchmark_filings$indexed_flag)),
    as.integer(any(benchmark_filings$benchmark_name == "d_r_horton_2024" & benchmark_filings$indexed_flag)),
    as.integer(any(benchmark_filings$benchmark_name == "lennar_2024" & benchmark_filings$indexed_flag)),
    as.integer(any(benchmark_filings$benchmark_name == "nvr_2024" & benchmark_filings$indexed_flag))
  ),
  detail = c(
    "",
    "",
    "Fiscal year inferred from report date, falling back to filing date.",
    "",
    "Same accession can appear in SEC recent submissions and older submission shards; accession rows are collapsed before downstream joins.",
    "Tracked task-local manual accessions added when SEC submissions JSON omits a public 10-K known from EDGAR.",
    rep("Benchmark accession availability check.", 4)
  )
)

write_csv_if_changed(tenk_index, "../output/sec_10k_filing_index.csv")
write_csv_if_changed(benchmark_filings, "../output/sec_10k_benchmark_filings.csv")
write_csv_if_changed(qc_rows, "../output/sec_10k_filing_index_qc.csv")

cat("Wrote SEC 10-K filing index outputs to ../output\n")
