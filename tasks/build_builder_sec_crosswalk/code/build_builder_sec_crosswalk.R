# setwd("/Users/jacobherbstman/Desktop/homebuilder_10ks/tasks/build_builder_sec_crosswalk/code")

suppressPackageStartupMessages({
  library(dplyr)
  library(jsonlite)
  library(readr)
  library(stringr)
  library(tibble)
})

source("../../_lib/homebuilder_pipeline_utils.R")

format_cik10 <- function(x) {
  raw_value <- str_remove_all(as.character(x), "[^0-9]")
  raw_value[raw_value == ""] <- NA_character_
  if_else(is.na(raw_value), NA_character_, str_pad(raw_value, 10, pad = "0"))
}

parse_sec_ticker_map <- function() {
  file_inventory <- read_csv("../input/sec_company_tickers_files.csv", show_col_types = FALSE, na = c("", "NA")) |>
    filter(status %in% c("downloaded", "already_present"), file.exists(source_local_path)) |>
    arrange(desc(pull_date))

  if (nrow(file_inventory) == 0) {
    return(tibble(
      sec_ticker = character(),
      sec_cik = character(),
      sec_cik10 = character(),
      sec_title = character(),
      sec_title_key = character()
    ))
  }

  raw_json <- fromJSON(file_inventory$source_local_path[[1]], simplifyVector = FALSE)
  bind_rows(lapply(raw_json, function(row) {
    tibble(
      sec_ticker = str_to_upper(as.character(if (is.null(row$ticker)) NA_character_ else row$ticker)),
      sec_cik = as.character(if (is.null(row$cik_str)) NA_character_ else row$cik_str),
      sec_cik10 = format_cik10(if (is.null(row$cik_str)) NA_character_ else row$cik_str),
      sec_title = as.character(if (is.null(row$title)) NA_character_ else row$title),
      sec_title_key = normalize_text_key(if (is.null(row$title)) NA_character_ else row$title)
    )
  })) |>
    distinct(sec_ticker, .keep_all = TRUE)
}

builder_public <- read_csv("../input/builder_public_firm_roster.csv", show_col_types = FALSE, na = c("", "NA")) |>
  mutate(builder_name_key = as.character(builder_name_key))

manual_crosswalk <- read_csv("manual_builder_sec_crosswalk.csv", show_col_types = FALSE, na = c("", "NA")) |>
  mutate(
    builder_name_key = as.character(builder_name_key),
    manual_ticker = str_to_upper(as.character(ticker)),
    manual_cik = as.character(cik),
    manual_cik10 = format_cik10(cik),
    manual_sec_company_name = as.character(sec_company_name),
    manual_sec_reporting_indicator = sec_reporting_indicator %in% TRUE,
    manual_public_parent_no_comparable_us_10k = public_parent_no_comparable_us_10k %in% TRUE,
    manual_review_indicator_seed = manual_review_indicator %in% TRUE,
    manual_valid_from_year = suppressWarnings(as.integer(valid_from_year)),
    manual_valid_to_year = suppressWarnings(as.integer(valid_to_year)),
    manual_notes = as.character(notes)
  ) |>
  select(
    builder_name_key, manual_ticker, manual_cik, manual_cik10, manual_sec_company_name,
    manual_sec_reporting_indicator, manual_public_parent_no_comparable_us_10k,
    manual_review_indicator_seed, manual_valid_from_year, manual_valid_to_year, manual_notes
  )

if (nrow(manual_crosswalk) != n_distinct(manual_crosswalk$builder_name_key)) {
  stop("manual_builder_sec_crosswalk.csv must be unique by builder_name_key.")
}

sec_tickers <- parse_sec_ticker_map()

crosswalk <- builder_public |>
  left_join(manual_crosswalk, by = "builder_name_key", relationship = "one-to-one") |>
  left_join(sec_tickers, by = c("manual_ticker" = "sec_ticker"), relationship = "many-to-one") |>
  mutate(
    ticker = manual_ticker,
    cik = coalesce(manual_cik, sec_cik),
    cik10 = coalesce(manual_cik10, sec_cik10),
    sec_company_name = coalesce(manual_sec_company_name, sec_title),
    match_method = case_when(
      !is.na(manual_cik10) ~ "manual_seed_cik",
      is.na(manual_cik10) & !is.na(manual_ticker) & !is.na(sec_cik10) ~ "manual_seed_ticker_to_sec_ticker_map",
      !is.na(manual_ticker) ~ "manual_seed_ticker_no_cik",
      TRUE ~ "unmatched"
    ),
    sec_reporting_indicator = case_when(
      !is.na(cik10) ~ TRUE,
      !is.na(manual_sec_reporting_indicator) ~ manual_sec_reporting_indicator,
      TRUE ~ FALSE
    ),
    public_parent_no_comparable_us_10k = coalesce(manual_public_parent_no_comparable_us_10k, FALSE),
    manual_review_indicator = coalesce(manual_review_indicator_seed, FALSE) | is.na(cik10) | public_parent_no_comparable_us_10k,
    valid_from_year = manual_valid_from_year,
    valid_to_year = manual_valid_to_year,
    notes = manual_notes
  ) |>
  transmute(
    builder_name_key,
    builder_name_clean,
    builder_names_observed,
    first_list_year,
    last_list_year,
    years_observed,
    ever_marked_public,
    first_public_list_year,
    last_public_list_year,
    ticker,
    cik,
    cik10,
    sec_company_name,
    match_method,
    match_score = NA_real_,
    sec_reporting_indicator,
    public_parent_no_comparable_us_10k,
    manual_review_indicator,
    valid_from_year,
    valid_to_year,
    notes
  ) |>
  arrange(desc(sec_reporting_indicator), desc(!manual_review_indicator), first_public_list_year, builder_name_clean)

token_candidates <- builder_public |>
  filter(!builder_name_key %in% crosswalk$builder_name_key[!is.na(crosswalk$cik10)]) |>
  mutate(builder_token = str_extract(builder_name_key, "^[a-z0-9]+")) |>
  inner_join(
    sec_tickers |>
      mutate(sec_token = str_extract(sec_title_key, "^[a-z0-9]+")) |>
      filter(!is.na(sec_token)),
    by = c("builder_token" = "sec_token"),
    relationship = "many-to-many"
  ) |>
  transmute(
    builder_name_key,
    builder_name_clean,
    candidate_ticker = sec_ticker,
    candidate_cik = sec_cik,
    candidate_cik10 = sec_cik10,
    candidate_sec_company_name = sec_title,
    candidate_method = "shared_first_token",
    candidate_notes = "Candidate only; do not use without manual review."
  ) |>
  distinct() |>
  arrange(builder_name_clean, candidate_ticker)

unmatched <- crosswalk |>
  filter(is.na(cik10) | manual_review_indicator) |>
  arrange(first_public_list_year, builder_name_clean)

qc_rows <- tibble(
  check = c(
    "builder_public_firms",
    "sec_reporting_cik_known",
    "manual_review_rows",
    "unmatched_no_cik",
    "current_seed_dhi",
    "current_seed_len",
    "current_seed_phm",
    "current_seed_nvr",
    "current_seed_mth",
    "current_seed_kbh",
    "current_seed_tol",
    "current_seed_mho",
    "current_seed_bzh"
  ),
  status = c(
    if_else(nrow(crosswalk) == 53, "ok", "warn"),
    if_else(sum(!is.na(crosswalk$cik10) & crosswalk$sec_reporting_indicator) > 0, "ok", "fail"),
    "ok",
    if_else(sum(is.na(crosswalk$cik10)) == 0, "ok", "warn"),
    if_else(any(crosswalk$ticker == "DHI" & crosswalk$cik10 == "0000882184"), "ok", "fail"),
    if_else(any(crosswalk$ticker == "LEN" & crosswalk$cik10 == "0000920760"), "ok", "fail"),
    if_else(any(crosswalk$ticker == "PHM" & crosswalk$cik10 == "0000822416"), "ok", "fail"),
    if_else(any(crosswalk$ticker == "NVR" & crosswalk$cik10 == "0000906163"), "ok", "fail"),
    if_else(any(crosswalk$ticker == "MTH" & crosswalk$cik10 == "0000833079"), "ok", "fail"),
    if_else(any(crosswalk$ticker == "KBH" & crosswalk$cik10 == "0000795266"), "ok", "fail"),
    if_else(any(crosswalk$ticker == "TOL" & crosswalk$cik10 == "0000794170"), "ok", "fail"),
    if_else(any(crosswalk$ticker == "MHO" & crosswalk$cik10 == "0000799292"), "ok", "fail"),
    if_else(any(crosswalk$ticker == "BZH" & crosswalk$cik10 == "0000915840"), "ok", "fail")
  ),
  value = c(
    nrow(crosswalk),
    sum(!is.na(crosswalk$cik10) & crosswalk$sec_reporting_indicator),
    sum(crosswalk$manual_review_indicator, na.rm = TRUE),
    sum(is.na(crosswalk$cik10)),
    rep(NA_real_, 9)
  ),
  detail = c(
    "Expected 53 from the current Builder public roster.",
    "Rows with known CIK and SEC-reporting indicator.",
    "Rows retained for manual review or comparability review.",
    "Rows with no CIK after manual seeds and ticker map.",
    rep("Seed ticker/CIK sanity check.", 9)
  )
)

write_csv_if_changed(crosswalk, "../output/builder_sec_crosswalk.csv")
write_csv_if_changed(token_candidates, "../output/builder_sec_match_candidates.csv")
write_csv_if_changed(unmatched, "../output/builder_sec_unmatched_public_firms.csv")
write_csv_if_changed(qc_rows, "../output/builder_sec_crosswalk_qc.csv")

cat("Wrote Builder-SEC crosswalk outputs to ../output\n")
