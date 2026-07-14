# setwd("/Users/jacobherbstman/Desktop/homebuilder_10ks/tasks/audit_sec_sic_1531_universe/code")

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(stringr)
  library(tibble)
})

source("../../_lib/homebuilder_pipeline_utils.R")

sec_sic_1531 <- read_csv("../input/sec_sic_1531_companies.csv", show_col_types = FALSE, na = c("", "NA")) |>
  mutate(
    cik10 = as.character(cik10),
    annual_10k_filing_count = suppressWarnings(as.integer(as.character(annual_10k_filing_count))),
    sic_1531_company_name_key = normalize_text_key(sic_1531_company_name),
    sec_company_name_key = normalize_text_key(sec_company_name)
  )

if (nrow(sec_sic_1531) != n_distinct(sec_sic_1531$cik10)) {
  stop("sec_sic_1531_companies.csv must be unique by cik10.")
}

crosswalk <- read_csv("../input/builder_sec_crosswalk.csv", show_col_types = FALSE, na = c("", "NA")) |>
  mutate(
    cik10 = as.character(cik10),
    sec_reporting_indicator = sec_reporting_indicator %in% c(TRUE, "TRUE", "true", "True", "1", 1),
    public_parent_no_comparable_us_10k = public_parent_no_comparable_us_10k %in% c(TRUE, "TRUE", "true", "True", "1", 1),
    manual_review_indicator = manual_review_indicator %in% c(TRUE, "TRUE", "true", "True", "1", 1),
    ever_marked_public = ever_marked_public %in% c(TRUE, "TRUE", "true", "True", "1", 1),
    valid_from_year = suppressWarnings(as.integer(as.character(valid_from_year))),
    valid_to_year = suppressWarnings(as.integer(as.character(valid_to_year))),
    builder_name_key = as.character(builder_name_key),
    builder_name_clean_key = normalize_text_key(builder_name_clean)
  )

if ("crosswalk_episode_id" %in% names(crosswalk) &&
    nrow(crosswalk) != n_distinct(crosswalk$crosswalk_episode_id)) {
  stop("builder_sec_crosswalk.csv must be unique by crosswalk_episode_id.")
}

builder_sec_episodes <- crosswalk |>
  filter(ever_marked_public, sec_reporting_indicator, !is.na(cik10)) |>
  select(
    crosswalk_episode_id, builder_name_key, builder_name_clean, builder_names_observed,
    ticker, cik, cik10, sec_company_name, sec_reporting_indicator,
    public_parent_no_comparable_us_10k, manual_review_indicator,
    valid_from_year, valid_to_year, notes
  )

sec_sic_1531_by_cik <- sec_sic_1531 |>
  select(
    cik10, sic_1531_company_name, sic_1531_state_country,
    sec_sic_company_name = sec_company_name, sec_sic, sec_sic_description,
    sec_sic_tickers = tickers, sec_sic_exchanges = exchanges,
    annual_10k_filing_count, annual_forms_observed,
    first_annual_10k_filing_date, last_annual_10k_filing_date,
    first_annual_10k_report_date, last_annual_10k_report_date,
    sec_company_url
  )

sec_sic_1531_builder_overlap <- builder_sec_episodes |>
  left_join(sec_sic_1531_by_cik, by = "cik10", relationship = "many-to-one") |>
  mutate(
    in_sec_sic_1531_universe = !is.na(sic_1531_company_name),
    sic_universe_audit_status = case_when(
      in_sec_sic_1531_universe ~ "builder_cik_in_sic_1531",
      public_parent_no_comparable_us_10k ~ "builder_cik_not_sic_1531_noncomparable_parent",
      manual_review_indicator ~ "builder_cik_not_sic_1531_manual_review",
      TRUE ~ "builder_cik_not_sic_1531"
    )
  ) |>
  arrange(desc(!in_sec_sic_1531_universe), builder_name_clean, cik10)

known_builder_ciks <- builder_sec_episodes |>
  distinct(cik10)

sec_sic_1531_not_in_builder_crosswalk <- sec_sic_1531 |>
  anti_join(known_builder_ciks, by = "cik10") |>
  mutate(
    review_priority = case_when(
      str_detect(str_to_lower(coalesce(sic_1531_company_name, "")), "home|homes|builder|communities|residential") ~ "name_suggests_homebuilder",
      annual_10k_filing_count >= 10 ~ "many_annual_10k_filings",
      TRUE ~ "lower_priority"
    )
  ) |>
  select(
    cik, cik10, sic_1531_company_name, sic_1531_state_country,
    sec_company_name, sec_sic, sec_sic_description, tickers, exchanges,
    annual_10k_filing_count, annual_forms_observed,
    first_annual_10k_filing_date, last_annual_10k_filing_date,
    first_annual_10k_report_date, last_annual_10k_report_date,
    review_priority, sec_company_url
  ) |>
  arrange(desc(review_priority == "name_suggests_homebuilder"), desc(annual_10k_filing_count), sic_1531_company_name)

builder_public_not_in_sec_sic_1531 <- sec_sic_1531_builder_overlap |>
  filter(!in_sec_sic_1531_universe) |>
  select(
    crosswalk_episode_id, builder_name_key, builder_name_clean, ticker, cik, cik10,
    sec_company_name, public_parent_no_comparable_us_10k, manual_review_indicator,
    valid_from_year, valid_to_year, sic_universe_audit_status, notes
  ) |>
  arrange(public_parent_no_comparable_us_10k, manual_review_indicator, builder_name_clean)

qc_rows <- tibble(
  check = c(
    "sec_sic_1531_companies",
    "sec_sic_1531_companies_with_annual_10k",
    "builder_public_sec_reporting_episodes",
    "builder_public_sec_reporting_ciks",
    "builder_public_sec_reporting_episodes_in_sic_1531",
    "builder_public_sec_reporting_episodes_not_in_sic_1531",
    "sec_sic_1531_companies_not_in_builder_crosswalk",
    "sec_sic_1531_homebuilder_name_priority_not_in_builder_crosswalk"
  ),
  status = c(
    if_else(nrow(sec_sic_1531) > 0, "ok", "fail"),
    if_else(sum(sec_sic_1531$annual_10k_filing_count > 0, na.rm = TRUE) > 0, "ok", "warn"),
    if_else(nrow(builder_sec_episodes) > 0, "ok", "fail"),
    if_else(n_distinct(builder_sec_episodes$cik10) > 0, "ok", "fail"),
    if_else(sum(sec_sic_1531_builder_overlap$in_sec_sic_1531_universe, na.rm = TRUE) > 0, "ok", "warn"),
    "ok",
    "ok",
    "ok"
  ),
  value = c(
    nrow(sec_sic_1531),
    sum(sec_sic_1531$annual_10k_filing_count > 0, na.rm = TRUE),
    nrow(builder_sec_episodes),
    n_distinct(builder_sec_episodes$cik10),
    sum(sec_sic_1531_builder_overlap$in_sec_sic_1531_universe, na.rm = TRUE),
    sum(!sec_sic_1531_builder_overlap$in_sec_sic_1531_universe, na.rm = TRUE),
    nrow(sec_sic_1531_not_in_builder_crosswalk),
    sum(sec_sic_1531_not_in_builder_crosswalk$review_priority == "name_suggests_homebuilder", na.rm = TRUE)
  ),
  detail = c(
    "SEC browse-edgar SIC 1531 company list.",
    "SIC 1531 companies with annual 10-K-family filings in submissions JSON.",
    "Builder-public crosswalk rows with a known SEC CIK.",
    "Distinct CIKs among Builder-public SEC rows.",
    "Builder SEC rows whose CIK appears in the SIC 1531 universe.",
    "Builder SEC rows outside SIC 1531; often SIC 1520 or non-comparable public parents.",
    "SIC 1531 CIKs not currently linked to a Builder-public row.",
    "Name-based review priority only; not an automatic match."
  )
)

write_csv_if_changed(sec_sic_1531_builder_overlap, "../output/sec_sic_1531_builder_overlap.csv")
write_csv_if_changed(sec_sic_1531_not_in_builder_crosswalk, "../output/sec_sic_1531_not_in_builder_crosswalk.csv")
write_csv_if_changed(builder_public_not_in_sec_sic_1531, "../output/builder_public_not_in_sec_sic_1531.csv")
write_csv_if_changed(qc_rows, "../output/sec_sic_1531_universe_qc.csv")

cat("Wrote SEC SIC-1531 universe audit outputs to ../output\n")
