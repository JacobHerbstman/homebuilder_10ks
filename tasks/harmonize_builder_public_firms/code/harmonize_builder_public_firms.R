# setwd("/Users/jacobherbstman/Desktop/homebuilder_10ks/tasks/harmonize_builder_public_firms/code")

suppressPackageStartupMessages({
  library(arrow)
  library(dplyr)
  library(readr)
  library(stringr)
  library(tibble)
})

source("../../_lib/homebuilder_pipeline_utils.R")

public_roster <- read_csv("../input/builder_public_firm_roster.csv", show_col_types = FALSE, na = c("", "NA")) |>
  mutate(builder_name_key = as.character(builder_name_key))

builder_panel <- read_parquet("../input/builder_panel.parquet") |>
  mutate(builder_name_key = as.character(builder_name_key))

sec_crosswalk <- read_csv("../input/builder_sec_crosswalk.csv", show_col_types = FALSE, na = c("", "NA")) |>
  mutate(
    builder_name_key = as.character(builder_name_key),
    ticker = as.character(ticker),
    cik = as.character(cik),
    cik10 = as.character(cik10),
    sec_company_name = as.character(sec_company_name),
    match_method = as.character(match_method),
    sec_reporting_indicator = str_to_lower(str_squish(as.character(sec_reporting_indicator))) %in% c("true", "t", "1", "yes"),
    public_parent_no_comparable_us_10k = str_to_lower(str_squish(as.character(public_parent_no_comparable_us_10k))) %in% c("true", "t", "1", "yes"),
    manual_review_indicator = str_to_lower(str_squish(as.character(manual_review_indicator))) %in% c("true", "t", "1", "yes"),
    valid_from_year = as.integer(valid_from_year),
    valid_to_year = as.integer(valid_to_year),
    notes = as.character(notes)
  ) |>
  select(
    builder_name_key, ticker, cik, cik10, sec_company_name, match_method,
    sec_reporting_indicator, public_parent_no_comparable_us_10k,
    manual_review_indicator, valid_from_year, valid_to_year, notes
  ) |>
  rename(sec_crosswalk_notes = notes)

sec_crosswalk_firm_level <- sec_crosswalk |>
  group_by(builder_name_key) |>
  summarise(
    ticker = paste(sort(unique(ticker[!is.na(ticker) & ticker != ""])), collapse = " | "),
    cik = paste(sort(unique(cik[!is.na(cik) & cik != ""])), collapse = " | "),
    cik10 = paste(sort(unique(cik10[!is.na(cik10) & cik10 != ""])), collapse = " | "),
    sec_company_name = paste(sort(unique(sec_company_name[!is.na(sec_company_name) & sec_company_name != ""])), collapse = " | "),
    match_method = paste(sort(unique(match_method[!is.na(match_method) & match_method != ""])), collapse = " | "),
    sec_reporting_indicator = any(sec_reporting_indicator %in% TRUE, na.rm = TRUE),
    public_parent_no_comparable_us_10k = any(public_parent_no_comparable_us_10k %in% TRUE, na.rm = TRUE),
    manual_review_indicator = any(manual_review_indicator %in% TRUE, na.rm = TRUE),
    valid_from_year = if (all(is.na(valid_from_year))) NA_integer_ else min(valid_from_year, na.rm = TRUE),
    valid_to_year = if (all(is.na(valid_to_year))) NA_integer_ else max(valid_to_year, na.rm = TRUE),
    sec_crosswalk_notes = paste(sort(unique(sec_crosswalk_notes[!is.na(sec_crosswalk_notes) & sec_crosswalk_notes != ""])), collapse = " | "),
    .groups = "drop"
  )

manual_harmonization <- read_csv("manual_builder_public_firm_harmonization.csv", show_col_types = FALSE, na = c("", "NA")) |>
  mutate(
    builder_name_key = as.character(builder_name_key),
    collapse_indicator = str_to_lower(str_squish(as.character(collapse_indicator))) %in% c("true", "t", "1", "yes"),
    manual_review_indicator_harmonization = str_to_lower(str_squish(as.character(manual_review_indicator_harmonization))) %in% c("true", "t", "1", "yes")
  )

manual_pairs <- read_csv("manual_builder_public_firm_harmonization_pairs.csv", show_col_types = FALSE, na = c("", "NA")) |>
  mutate(
    builder_name_key_1 = as.character(builder_name_key_1),
    builder_name_key_2 = as.character(builder_name_key_2),
    collapse_allowed = str_to_lower(str_squish(as.character(collapse_allowed))) %in% c("true", "t", "1", "yes")
  )

manual_lifecycle <- read_csv("manual_builder_public_firm_lifecycle.csv", show_col_types = FALSE, na = c("", "NA")) |>
  mutate(
    builder_name_key = as.character(builder_name_key),
    event_year = as.integer(event_year),
    last_standalone_year = as.integer(last_standalone_year),
    lifecycle_manual_review_indicator = str_to_lower(str_squish(as.character(lifecycle_manual_review_indicator))) %in% c("true", "t", "1", "yes")
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
  left_join(sec_crosswalk_firm_level, by = "builder_name_key", relationship = "one-to-one") |>
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
    builder_name_keys = paste(sort(unique(builder_name_key[!is.na(builder_name_key) & builder_name_key != ""])), collapse = " | "),
    builder_names_observed = paste(sort(unique(builder_name_clean[!is.na(builder_name_clean) & builder_name_clean != ""])), collapse = " | "),
    first_list_year = min(first_list_year, na.rm = TRUE),
    last_list_year = max(last_list_year, na.rm = TRUE),
    first_public_list_year = min(first_public_list_year, na.rm = TRUE),
    last_public_list_year = max(last_public_list_year, na.rm = TRUE),
    public_years_total_before_dedup = sum(public_years, na.rm = TRUE),
    best_rank = min(best_rank, na.rm = TRUE),
    sec_cik10s = paste(sort(unique(cik10[!is.na(cik10) & cik10 != ""])), collapse = " | "),
    tickers = paste(sort(unique(ticker[!is.na(ticker) & ticker != ""])), collapse = " | "),
    sec_company_names = paste(sort(unique(sec_company_name[!is.na(sec_company_name) & sec_company_name != ""])), collapse = " | "),
    any_sec_reporting = any(sec_reporting_indicator %in% TRUE, na.rm = TRUE),
    any_public_parent_no_comparable_us_10k = any(public_parent_no_comparable_us_10k %in% TRUE, na.rm = TRUE),
    any_sec_manual_review = any(manual_review_indicator %in% TRUE, na.rm = TRUE),
    any_harmonization_manual_review = any(manual_review_indicator_harmonization %in% TRUE, na.rm = TRUE),
    collapsed_from_multiple_builder_keys = n() > 1,
    harmonization_actions = paste(sort(unique(harmonization_action[!is.na(harmonization_action) & harmonization_action != ""])), collapse = " | "),
    same_firm_confidences = paste(sort(unique(same_firm_confidence[!is.na(same_firm_confidence) & same_firm_confidence != ""])), collapse = " | "),
    evidence_urls = paste(sort(unique(source_url[!is.na(source_url) & source_url != ""])), collapse = " | "),
    evidence_notes = paste(sort(unique(source_note[!is.na(source_note) & source_note != ""])), collapse = " | "),
    lifecycle_statuses = paste(sort(unique(lifecycle_status[!is.na(lifecycle_status) & lifecycle_status != ""])), collapse = " | "),
    successor_builder_names = paste(sort(unique(successor_builder_name[!is.na(successor_builder_name) & successor_builder_name != ""])), collapse = " | "),
    lifecycle_evidence_urls = paste(sort(unique(lifecycle_source_url[!is.na(lifecycle_source_url) & lifecycle_source_url != ""])), collapse = " | "),
    notes = paste(sort(unique(notes[!is.na(notes) & notes != ""])), collapse = " | "),
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
    ticker_1 = first(ticker[!is.na(ticker) & ticker != ""], default = ""),
    ticker_2 = paste(sort(unique(ticker[-1][!is.na(ticker[-1]) & ticker[-1] != ""])), collapse = " | "),
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
    builder_activity_year = as.integer(first(underlying_closings_year[!is.na(underlying_closings_year)], default = NA_real_)),
    list_types = paste(sort(unique(list_type[!is.na(list_type) & list_type != ""])), collapse = " | "),
    best_builder_rank = first(rank[!is.na(rank)], default = NA_real_),
    builder_public_flag = any(builder_public_flag %in% TRUE, na.rm = TRUE),
    builder_name_clean = first(builder_name_clean[!is.na(builder_name_clean) & builder_name_clean != ""], default = ""),
    builder_name_raw = first(builder_name_raw[!is.na(builder_name_raw) & builder_name_raw != ""], default = ""),
    total_closings = first(total_closings[!is.na(total_closings)], default = NA_real_),
    gross_revenue_homebuilding_millions = first(gross_revenue_homebuilding_millions[!is.na(gross_revenue_homebuilding_millions)], default = NA_real_),
    source_urls = paste(sort(unique(source_url[!is.na(source_url) & source_url != ""])), collapse = " | "),
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
