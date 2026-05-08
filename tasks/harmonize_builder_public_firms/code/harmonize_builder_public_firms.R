# setwd("/Users/jacobherbstman/Desktop/homebuilder_10ks/tasks/harmonize_builder_public_firms/code")

suppressPackageStartupMessages({
  library(arrow)
  library(dplyr)
  library(readr)
  library(stringr)
  library(tibble)
})

source("../../_lib/homebuilder_pipeline_utils.R")

as_manual_bool <- function(x) {
  out <- str_to_lower(str_squish(as.character(x)))
  out %in% c("true", "t", "1", "yes")
}

first_or_blank <- function(x) {
  x <- x[!is.na(x) & x != ""]
  if (length(x) == 0) {
    return("")
  }
  x[[1]]
}

collapse_unique <- function(x) {
  x <- sort(unique(x[!is.na(x) & x != ""]))
  paste(x, collapse = " | ")
}

first_number_or_na <- function(x) {
  x <- x[!is.na(x)]
  if (length(x) == 0) {
    return(NA_real_)
  }
  x[[1]]
}

public_roster <- read_csv("../input/builder_public_firm_roster.csv", show_col_types = FALSE, na = c("", "NA")) |>
  mutate(builder_name_key = as.character(builder_name_key))

builder_panel <- read_parquet("../input/builder_panel.parquet") |>
  mutate(builder_name_key = as.character(builder_name_key))

sec_crosswalk <- read_csv("../input/builder_sec_crosswalk.csv", show_col_types = FALSE, na = c("", "NA")) |>
  mutate(
    builder_name_key = as.character(builder_name_key),
    cik = as.character(cik),
    cik10 = as.character(cik10)
  ) |>
  select(
    builder_name_key, ticker, cik, cik10, sec_company_name, match_method,
    sec_reporting_indicator, public_parent_no_comparable_us_10k,
    manual_review_indicator, valid_from_year, valid_to_year, notes
  ) |>
  rename(sec_crosswalk_notes = notes)

manual_harmonization <- read_csv("manual_builder_public_firm_harmonization.csv", show_col_types = FALSE, na = c("", "NA")) |>
  mutate(
    builder_name_key = as.character(builder_name_key),
    collapse_indicator = as_manual_bool(collapse_indicator),
    manual_review_indicator_harmonization = as_manual_bool(manual_review_indicator_harmonization)
  )

manual_pairs <- read_csv("manual_builder_public_firm_harmonization_pairs.csv", show_col_types = FALSE, na = c("", "NA")) |>
  mutate(
    builder_name_key_1 = as.character(builder_name_key_1),
    builder_name_key_2 = as.character(builder_name_key_2),
    collapse_allowed = as_manual_bool(collapse_allowed)
  )

manual_lifecycle <- read_csv("manual_builder_public_firm_lifecycle.csv", show_col_types = FALSE, na = c("", "NA")) |>
  mutate(
    builder_name_key = as.character(builder_name_key),
    event_year = as.integer(event_year),
    last_standalone_year = as.integer(last_standalone_year),
    lifecycle_manual_review_indicator = as_manual_bool(lifecycle_manual_review_indicator)
  )

if (nrow(manual_harmonization) != n_distinct(manual_harmonization$builder_name_key)) {
  stop("manual_builder_public_firm_harmonization.csv must be unique by builder_name_key.")
}

if (nrow(manual_lifecycle) != n_distinct(manual_lifecycle$builder_name_key)) {
  stop("manual_builder_public_firm_lifecycle.csv must be unique by builder_name_key.")
}

missing_harmonization_keys <- setdiff(manual_harmonization$builder_name_key, public_roster$builder_name_key)
if (length(missing_harmonization_keys) > 0) {
  stop(paste("Manual harmonization keys missing from Builder public roster:", paste(missing_harmonization_keys, collapse = ", ")))
}

missing_lifecycle_keys <- setdiff(manual_lifecycle$builder_name_key, public_roster$builder_name_key)
if (length(missing_lifecycle_keys) > 0) {
  stop(paste("Manual lifecycle keys missing from Builder public roster:", paste(missing_lifecycle_keys, collapse = ", ")))
}

disappearing_public_keys <- public_roster |>
  filter(
    last_list_year < max(last_list_year, na.rm = TRUE) |
      last_public_list_year < max(last_public_list_year, na.rm = TRUE)
  ) |>
  pull(builder_name_key)

missing_disappearing_lifecycle_keys <- setdiff(disappearing_public_keys, manual_lifecycle$builder_name_key)
if (length(missing_disappearing_lifecycle_keys) > 0) {
  stop(paste("Manual lifecycle decisions missing for disappearing Builder-public keys:", paste(missing_disappearing_lifecycle_keys, collapse = ", ")))
}

missing_pair_keys <- setdiff(unique(c(manual_pairs$builder_name_key_1, manual_pairs$builder_name_key_2)), public_roster$builder_name_key)
if (length(missing_pair_keys) > 0) {
  stop(paste("Manual pair keys missing from Builder public roster:", paste(missing_pair_keys, collapse = ", ")))
}

harmonized <- public_roster |>
  left_join(manual_harmonization, by = "builder_name_key", relationship = "one-to-one") |>
  left_join(manual_lifecycle, by = "builder_name_key", relationship = "one-to-one") |>
  left_join(sec_crosswalk, by = "builder_name_key", relationship = "one-to-one") |>
  mutate(
    harmonized_builder_id = coalesce(harmonized_builder_id, builder_name_key),
    harmonized_builder_name = coalesce(harmonized_builder_name, builder_name_clean),
    collapse_indicator = coalesce(collapse_indicator, FALSE),
    same_firm_confidence = coalesce(same_firm_confidence, "not_reviewed_singleton"),
    harmonization_action = coalesce(harmonization_action, "singleton_default_no_evidence_to_collapse"),
    source_url = coalesce(source_url, ""),
    source_note = coalesce(source_note, ""),
    manual_review_indicator_harmonization = coalesce(manual_review_indicator_harmonization, FALSE),
    notes = coalesce(notes, ""),
    lifecycle_status = coalesce(lifecycle_status, "continues_current_or_default"),
    successor_harmonized_builder_id = coalesce(successor_harmonized_builder_id, ""),
    successor_builder_name = coalesce(successor_builder_name, ""),
    successor_event_type = coalesce(successor_event_type, ""),
    firm_year_coding_decision = coalesce(firm_year_coding_decision, "Keep standalone harmonized firm ID in all observed Builder years."),
    lifecycle_source_url = coalesce(lifecycle_source_url, ""),
    lifecycle_source_note = coalesce(lifecycle_source_note, ""),
    lifecycle_manual_review_indicator = coalesce(lifecycle_manual_review_indicator, FALSE),
    lifecycle_notes = coalesce(lifecycle_notes, "")
  ) |>
  arrange(first_public_list_year, best_rank, builder_name_clean)

harmonization_groups <- harmonized |>
  group_by(harmonized_builder_id, harmonized_builder_name) |>
  summarise(
    input_builder_name_keys = n(),
    builder_name_keys = collapse_unique(builder_name_key),
    builder_names_observed = collapse_unique(builder_name_clean),
    first_list_year = min(first_list_year, na.rm = TRUE),
    last_list_year = max(last_list_year, na.rm = TRUE),
    first_public_list_year = min(first_public_list_year, na.rm = TRUE),
    last_public_list_year = max(last_public_list_year, na.rm = TRUE),
    public_years_total_before_dedup = sum(public_years, na.rm = TRUE),
    best_rank = min(best_rank, na.rm = TRUE),
    sec_cik10s = collapse_unique(cik10),
    tickers = collapse_unique(ticker),
    sec_company_names = collapse_unique(sec_company_name),
    any_sec_reporting = any(sec_reporting_indicator %in% TRUE, na.rm = TRUE),
    any_public_parent_no_comparable_us_10k = any(public_parent_no_comparable_us_10k %in% TRUE, na.rm = TRUE),
    any_sec_manual_review = any(manual_review_indicator %in% TRUE, na.rm = TRUE),
    any_harmonization_manual_review = any(manual_review_indicator_harmonization %in% TRUE, na.rm = TRUE),
    collapsed_from_multiple_builder_keys = n() > 1,
    harmonization_actions = collapse_unique(harmonization_action),
    same_firm_confidences = collapse_unique(same_firm_confidence),
    evidence_urls = collapse_unique(source_url),
    evidence_notes = collapse_unique(source_note),
    lifecycle_statuses = collapse_unique(lifecycle_status),
    successor_builder_names = collapse_unique(successor_builder_name),
    lifecycle_evidence_urls = collapse_unique(lifecycle_source_url),
    notes = collapse_unique(notes),
    .groups = "drop"
  ) |>
  arrange(first_public_list_year, best_rank, harmonized_builder_name)

same_cik_not_collapsed <- harmonized |>
  filter(!is.na(cik10), cik10 != "") |>
  group_by(cik10) |>
  filter(n_distinct(harmonized_builder_id) > 1) |>
  ungroup() |>
  select(cik10, builder_name_key, builder_name_clean, harmonized_builder_id, harmonized_builder_name, ticker, sec_company_name) |>
  group_by(cik10) |>
  summarise(
    review_type = "same_sec_cik_not_collapsed",
    builder_name_key_1 = first(builder_name_key),
    builder_name_clean_1 = first(builder_name_clean),
    builder_name_key_2 = paste(builder_name_key[-1], collapse = " | "),
    builder_name_clean_2 = paste(builder_name_clean[-1], collapse = " | "),
    harmonized_builder_id_1 = first(harmonized_builder_id),
    harmonized_builder_id_2 = paste(harmonized_builder_id[-1], collapse = " | "),
    cik10_1 = first(cik10),
    cik10_2 = first(cik10),
    ticker_1 = first_or_blank(ticker),
    ticker_2 = collapse_unique(ticker[-1]),
    source_url = "",
    source_note = "",
    notes = "Same SEC CIK appears under multiple uncollapsed Builder labels. Review before collapsing because same public parent can mask divisions, brands, or non-comparable entities.",
    .groups = "drop"
  ) |>
  select(-cik10)

manual_pair_review <- manual_pairs |>
  left_join(
    harmonized |>
      select(builder_name_key, builder_name_clean, harmonized_builder_id, cik10, ticker),
    by = c("builder_name_key_1" = "builder_name_key"),
    relationship = "many-to-one"
  ) |>
  rename(
    builder_name_clean_1 = builder_name_clean,
    harmonized_builder_id_1 = harmonized_builder_id,
    cik10_1 = cik10,
    ticker_1 = ticker
  ) |>
  left_join(
    harmonized |>
      select(builder_name_key, builder_name_clean, harmonized_builder_id, cik10, ticker),
    by = c("builder_name_key_2" = "builder_name_key"),
    relationship = "many-to-one"
  ) |>
  rename(
    builder_name_clean_2 = builder_name_clean,
    harmonized_builder_id_2 = harmonized_builder_id,
    cik10_2 = cik10,
    ticker_2 = ticker
  ) |>
  transmute(
    review_type,
    builder_name_key_1,
    builder_name_clean_1,
    builder_name_key_2,
    builder_name_clean_2,
    harmonized_builder_id_1,
    harmonized_builder_id_2,
    cik10_1,
    cik10_2,
    ticker_1,
    ticker_2,
    source_url = coalesce(source_url, ""),
    source_note = coalesce(source_note, ""),
    notes = coalesce(notes, "")
  )

manual_group_review <- harmonized |>
  filter(manual_review_indicator_harmonization %in% TRUE) |>
  transmute(
    review_type = "collapsed_group_retained_for_manual_review",
    builder_name_key_1 = builder_name_key,
    builder_name_clean_1 = builder_name_clean,
    builder_name_key_2 = "",
    builder_name_clean_2 = "",
    harmonized_builder_id_1 = harmonized_builder_id,
    harmonized_builder_id_2 = "",
    cik10_1 = cik10,
    cik10_2 = "",
    ticker_1 = ticker,
    ticker_2 = "",
    source_url,
    source_note,
    notes
  )

harmonization_review <- bind_rows(manual_pair_review, same_cik_not_collapsed, manual_group_review) |>
  distinct() |>
  arrange(review_type, builder_name_clean_1, builder_name_clean_2)

lifecycle_events <- harmonized |>
  select(
    builder_name_key, builder_name_clean, harmonized_builder_id, harmonized_builder_name,
    first_list_year, last_list_year, first_public_list_year, last_public_list_year, best_rank,
    lifecycle_status, event_date, event_year, last_standalone_year,
    successor_harmonized_builder_id, successor_builder_name, successor_event_type,
    firm_year_coding_decision, lifecycle_source_url, lifecycle_source_note,
    lifecycle_manual_review_indicator, lifecycle_notes
  ) |>
  filter(builder_name_key %in% manual_lifecycle$builder_name_key) |>
  arrange(first_public_list_year, best_rank, builder_name_clean)

builder_public_firm_year_identifiers <- builder_panel |>
  filter(builder_name_key %in% public_roster$builder_name_key) |>
  arrange(builder_name_key, list_year, rank) |>
  group_by(builder_name_key, list_year) |>
  summarise(
    builder_activity_year = as.integer(first_number_or_na(underlying_closings_year)),
    list_types = collapse_unique(list_type),
    best_builder_rank = first_number_or_na(rank),
    builder_public_flag = any(builder_public_flag %in% TRUE, na.rm = TRUE),
    builder_name_clean = first_or_blank(builder_name_clean),
    builder_name_raw = first_or_blank(builder_name_raw),
    total_closings = first_number_or_na(total_closings),
    gross_revenue_homebuilding_millions = first_number_or_na(gross_revenue_homebuilding_millions),
    source_urls = collapse_unique(source_url),
    .groups = "drop"
  ) |>
  mutate(builder_activity_year = coalesce(builder_activity_year, as.integer(list_year))) |>
  left_join(
    harmonized |>
      select(
        builder_name_key, harmonized_builder_id, harmonized_builder_name,
        first_public_list_year, last_public_list_year, ticker, cik10,
        sec_company_name, sec_reporting_indicator, public_parent_no_comparable_us_10k,
        lifecycle_status, event_date, event_year, last_standalone_year,
        successor_harmonized_builder_id, successor_builder_name, successor_event_type,
        firm_year_coding_decision, lifecycle_manual_review_indicator, lifecycle_notes
      ),
    by = "builder_name_key",
    relationship = "many-to-one"
  ) |>
  mutate(
    post_lifecycle_event_activity = !is.na(event_year) & builder_activity_year > event_year,
    event_year_activity = !is.na(event_year) & builder_activity_year == event_year,
    after_last_standalone_activity = !is.na(last_standalone_year) & builder_activity_year > last_standalone_year,
    standalone_sec_panel_eligible = sec_reporting_indicator %in% TRUE &
      !(public_parent_no_comparable_us_10k %in% TRUE) &
      !after_last_standalone_activity,
    successor_tracking_indicator = successor_harmonized_builder_id != "",
    firm_year_manual_review_indicator = lifecycle_manual_review_indicator %in% TRUE |
      lifecycle_status %in% c(
        "manual_review_unresolved",
        "public_marker_inconsistent_with_sec_reporting",
        "same_parent_or_brand_noncomparable_review"
      )
  ) |>
  arrange(builder_activity_year, best_builder_rank, builder_name_clean)

qc_rows <- tibble(
  check = c(
    "input_builder_public_name_keys",
    "output_builder_public_name_keys",
    "unique_harmonized_public_builders",
    "collapsed_builder_name_keys",
    "collapsed_harmonized_groups",
    "high_confidence_collapsed_groups",
    "rows_retained_for_harmonization_manual_review",
    "disappearing_public_keys_with_lifecycle_decisions",
    "lifecycle_manual_review_rows",
    "builder_public_firm_year_identifier_rows",
    "standalone_sec_panel_eligible_firm_years",
    "same_cik_not_collapsed_groups",
    "manual_pair_review_rows",
    "manual_harmonization_keys_missing_from_roster",
    "manual_lifecycle_keys_missing_from_roster"
  ),
  status = c(
    if_else(nrow(public_roster) == 53, "ok", "warn"),
    if_else(nrow(harmonized) == nrow(public_roster), "ok", "fail"),
    "ok",
    "ok",
    "ok",
    "ok",
    if_else(sum(harmonized$manual_review_indicator_harmonization, na.rm = TRUE) == 0, "ok", "warn"),
    if_else(length(missing_disappearing_lifecycle_keys) == 0, "ok", "fail"),
    if_else(sum(manual_lifecycle$lifecycle_manual_review_indicator, na.rm = TRUE) == 0, "ok", "warn"),
    "ok",
    "ok",
    if_else(nrow(same_cik_not_collapsed) == 0, "ok", "warn"),
    "ok",
    if_else(length(missing_harmonization_keys) == 0, "ok", "fail"),
    if_else(length(missing_lifecycle_keys) == 0, "ok", "fail")
  ),
  value = c(
    nrow(public_roster),
    nrow(harmonized),
    n_distinct(harmonized$harmonized_builder_id),
    sum(harmonized$collapse_indicator, na.rm = TRUE),
    sum(harmonization_groups$collapsed_from_multiple_builder_keys, na.rm = TRUE),
    sum(harmonization_groups$collapsed_from_multiple_builder_keys & str_detect(harmonization_groups$same_firm_confidences, "high"), na.rm = TRUE),
    sum(harmonized$manual_review_indicator_harmonization, na.rm = TRUE),
    nrow(manual_lifecycle),
    sum(manual_lifecycle$lifecycle_manual_review_indicator, na.rm = TRUE),
    nrow(builder_public_firm_year_identifiers),
    sum(builder_public_firm_year_identifiers$standalone_sec_panel_eligible, na.rm = TRUE),
    nrow(same_cik_not_collapsed),
    nrow(manual_pairs),
    length(missing_harmonization_keys),
    length(missing_lifecycle_keys)
  ),
  detail = c(
    "Expected 53 from stage_builder_panel/output/builder_public_firm_roster.csv.",
    "Harmonization should preserve one row per input Builder-public name key.",
    "Conservative count after only source-verified name collapses.",
    "Input Builder name keys assigned to a non-default harmonized ID.",
    "Harmonized IDs containing more than one Builder input name key.",
    "Collapsed groups with high-confidence evidence.",
    "Rows collapsed or flagged while still needing manual comparability review.",
    "Disappearing or no-longer-public Builder keys must have explicit lifecycle decisions.",
    "Lifecycle decisions retained for manual review or weak source evidence.",
    "Builder firm-year rows for every Builder-public name key ever observed in the Builder panel.",
    "Firm-years not after the target's standalone SEC-reporting window and not flagged as non-comparable public parent.",
    "Groups sharing an SEC CIK but intentionally not collapsed by the current evidence file.",
    "Tracked candidate pairs that should not be collapsed without more evidence.",
    "Manual harmonization decisions must reference current Builder public roster keys.",
    "Manual lifecycle decisions must reference current Builder public roster keys."
  )
)

write_csv_if_changed(harmonized, "../output/builder_public_firm_harmonized.csv")
write_csv_if_changed(harmonization_groups, "../output/builder_public_harmonization_groups.csv")
write_csv_if_changed(harmonization_review, "../output/builder_public_harmonization_review.csv")
write_csv_if_changed(lifecycle_events, "../output/builder_public_lifecycle_events.csv")
write_csv_if_changed(builder_public_firm_year_identifiers, "../output/builder_public_firm_year_identifiers.csv")
write_csv_if_changed(qc_rows, "../output/builder_public_harmonization_qc.csv")

cat("Wrote Builder public-firm harmonization outputs to ../output\n")
