# setwd("/Users/jacobherbstman/Desktop/homebuilder_10ks/tasks/stage_builder_universe_roster/code")

suppressPackageStartupMessages({
  library(dplyr)
  library(jsonlite)
  library(readr)
  library(stringr)
  library(tibble)
  library(tidyr)
})

source("../../_lib/homebuilder_pipeline_utils.R")

roster_raw <- bind_rows(
  read_csv("../input/builder_universe_roster.csv", show_col_types = FALSE, na = c("", "NA")),
  read_csv("manual_builder_universe_additions.csv", show_col_types = FALSE, na = c("", "NA"))
) |>
  mutate(
    company = str_squish(as.character(company)),
    ticker = str_squish(as.character(ticker)),
    tier = suppressWarnings(as.integer(as.character(tier))),
    status = str_to_lower(str_squish(as.character(status))),
    filing_window = str_squish(as.character(filing_window)),
    fye_month = str_squish(as.character(fye_month)),
    fate_and_splicing_notes = str_squish(as.character(fate_and_splicing_notes)),
    omega_prior_and_relevance = str_squish(as.character(omega_prior_and_relevance)),
    universe_name_key = normalize_text_key(company),
    universe_firm_id = universe_name_key,
    tier_label = paste0("tier_", tier),
    analysis_role = if_else(tier == 3L, "adjacent_land_company", "builder"),
    builder_panel_eligible = tier %in% c(1L, 2L),
    adjacent_land_company = tier == 3L,
    current_or_historical_builder = tier %in% c(1L, 2L),
    fye_month_clean = str_to_lower(fye_month),
    fye_month_number = case_when(
      fye_month_clean %in% c("jan", "january") ~ 1L,
      fye_month_clean %in% c("feb", "february") ~ 2L,
      fye_month_clean %in% c("mar", "march") ~ 3L,
      fye_month_clean %in% c("apr", "april") ~ 4L,
      fye_month_clean %in% c("may") ~ 5L,
      fye_month_clean %in% c("jun", "june") ~ 6L,
      fye_month_clean %in% c("jul", "july") ~ 7L,
      fye_month_clean %in% c("aug", "august") ~ 8L,
      fye_month_clean %in% c("sep", "sept", "september") ~ 9L,
      fye_month_clean %in% c("oct", "october") ~ 10L,
      fye_month_clean %in% c("nov", "november") ~ 11L,
      fye_month_clean %in% c("dec", "december") ~ 12L,
      TRUE ~ NA_integer_
    ),
    fiscal_year_warning = case_when(
      fye_month_number == 12L ~ "",
      is.na(fye_month_number) ~ "fiscal_year_end_missing_or_unparsed",
      TRUE ~ "non_december_fiscal_year_end"
    ),
    merger_splice_flag = str_detect(str_to_lower(coalesce(fate_and_splicing_notes, "")), "acquired|merged|splic|private|bankrupt|chapter|de-spac|reverse merger|delisted"),
    recent_ipo_flag = str_detect(str_to_lower(coalesce(omega_prior_and_relevance, "")), "recent-ipo|ipo 2021|ipo 2024|de-spac 2023"),
    low_omega_anchor_flag = str_detect(str_to_lower(coalesce(omega_prior_and_relevance, "")), "low-omega anchor"),
    high_omega_prior_flag = str_detect(str_to_lower(coalesce(omega_prior_and_relevance, "")), "pure land-light|high|~95|~96|~100|omega ~1|asset-light"),
    ticker_list = str_replace_all(coalesce(ticker, ""), "\\s+", "")
  ) |>
  mutate(
    staged_row_id = row_number()
  ) |>
  select(
    staged_row_id, universe_firm_id, universe_name_key, company, ticker, ticker_list,
    tier, tier_label, status, analysis_role, builder_panel_eligible,
    adjacent_land_company, current_or_historical_builder, filing_window,
    fye_month, fye_month_number, fiscal_year_warning,
    merger_splice_flag, recent_ipo_flag, low_omega_anchor_flag, high_omega_prior_flag,
    fate_and_splicing_notes, omega_prior_and_relevance
  )

if (nrow(roster_raw) != n_distinct(roster_raw$universe_firm_id)) {
  stop("builder_universe_roster.csv must be unique by normalized company name.")
}

roster_tickers <- roster_raw |>
  select(staged_row_id, universe_firm_id, company, ticker_list) |>
  separate_rows(ticker_list, sep = "/") |>
  mutate(ticker_token = str_to_upper(str_squish(ticker_list))) |>
  filter(ticker_token != "") |>
  select(staged_row_id, universe_firm_id, company, ticker_token)

if (nrow(roster_tickers) != n_distinct(roster_tickers$ticker_token)) {
  stop("Expanded roster ticker tokens must be unique before ticker candidate joins.")
}

crosswalk <- read_csv("../input/builder_sec_crosswalk.csv", show_col_types = FALSE, na = c("", "NA")) |>
  mutate(
    ticker = str_to_upper(as.character(ticker)),
    cik = as.character(cik),
    cik10 = as.character(cik10),
    builder_name_key = as.character(builder_name_key),
    builder_name_clean_key = normalize_text_key(builder_name_clean),
    sec_company_name_key = normalize_text_key(sec_company_name),
    sec_reporting_indicator = sec_reporting_indicator %in% c(TRUE, "TRUE", "true", "True", "1", 1),
    public_parent_no_comparable_us_10k = public_parent_no_comparable_us_10k %in% c(TRUE, "TRUE", "true", "True", "1", 1),
    manual_review_indicator = manual_review_indicator %in% c(TRUE, "TRUE", "true", "True", "1", 1),
    valid_from_year = suppressWarnings(as.integer(as.character(valid_from_year))),
    valid_to_year = suppressWarnings(as.integer(as.character(valid_to_year)))
  )

if ("crosswalk_episode_id" %in% names(crosswalk) &&
    nrow(crosswalk) != n_distinct(crosswalk$crosswalk_episode_id)) {
  stop("builder_sec_crosswalk.csv must be unique by crosswalk_episode_id.")
}

sec_file_inventory <- read_csv("../input/sec_company_tickers_files.csv", show_col_types = FALSE, na = c("", "NA")) |>
  filter(status %in% c("downloaded", "already_present"), file.exists(source_local_path)) |>
  arrange(desc(pull_date))

if (nrow(sec_file_inventory) == 0) {
  sec_tickers <- tibble(
    sec_ticker = character(),
    sec_cik = character(),
    sec_cik10 = character(),
    sec_title = character(),
    sec_title_key = character()
  )
} else {
  sec_ticker_json <- fromJSON(sec_file_inventory$source_local_path[[1]], simplifyVector = FALSE)
  sec_tickers <- bind_rows(lapply(sec_ticker_json, function(row) {
    raw_cik <- str_remove_all(as.character(if (is.null(row$cik_str)) NA_character_ else row$cik_str), "[^0-9]")
    raw_cik[raw_cik == ""] <- NA_character_
    tibble(
      sec_ticker = str_to_upper(as.character(if (is.null(row$ticker)) NA_character_ else row$ticker)),
      sec_cik = raw_cik,
      sec_cik10 = if_else(is.na(raw_cik), NA_character_, str_pad(raw_cik, 10, pad = "0")),
      sec_title = as.character(if (is.null(row$title)) NA_character_ else row$title),
      sec_title_key = normalize_text_key(if (is.null(row$title)) NA_character_ else row$title)
    )
  })) |>
    distinct(sec_ticker, .keep_all = TRUE)
}

sec_sic_1531 <- read_csv("../input/sec_sic_1531_companies.csv", show_col_types = FALSE, na = c("", "NA")) |>
  mutate(
    cik = as.character(cik),
    cik10 = as.character(cik10),
    sic_ticker_list = str_replace_all(coalesce(as.character(tickers), ""), "\\s+", ""),
    sic_company_name_key = normalize_text_key(sic_1531_company_name),
    sec_company_name_key = normalize_text_key(sec_company_name),
    annual_10k_filing_count = suppressWarnings(as.integer(as.character(annual_10k_filing_count))),
    first_annual_10k_report_date = as.character(first_annual_10k_report_date),
    last_annual_10k_report_date = as.character(last_annual_10k_report_date)
  )

if (nrow(sec_sic_1531) != n_distinct(sec_sic_1531$cik10)) {
  stop("sec_sic_1531_companies.csv must be unique by cik10.")
}

sic_tickers <- sec_sic_1531 |>
  select(
    cik, cik10, sic_1531_company_name, sec_company_name, tickers, sic_ticker_list,
    annual_10k_filing_count, first_annual_10k_report_date, last_annual_10k_report_date,
    sec_company_url
  ) |>
  separate_rows(sic_ticker_list, sep = "\\|") |>
  mutate(sic_ticker = str_to_upper(str_squish(sic_ticker_list))) |>
  filter(sic_ticker != "")

candidate_rows <- bind_rows(
  roster_tickers |>
    inner_join(
      crosswalk |>
        filter(!is.na(ticker), ticker != "") |>
        select(
          ticker, crosswalk_episode_id, builder_name_key, builder_name_clean,
          cik, cik10, sec_company_name, sec_reporting_indicator,
          public_parent_no_comparable_us_10k, manual_review_indicator,
          valid_from_year, valid_to_year, notes
      ),
      by = c("ticker_token" = "ticker"),
      relationship = "one-to-many"
    ) |>
    transmute(
      staged_row_id, universe_firm_id, company, ticker_token,
      candidate_cik = cik, candidate_cik10 = cik10, candidate_sec_company_name = sec_company_name,
      match_source = "builder_sec_crosswalk_ticker",
      match_strength = "high",
      crosswalk_episode_id, builder_name_key, builder_name_clean,
      sec_reporting_indicator, public_parent_no_comparable_us_10k, manual_review_indicator,
      valid_from_year, valid_to_year,
      annual_10k_filing_count = NA_integer_,
      first_annual_10k_report_date = NA_character_,
      last_annual_10k_report_date = NA_character_,
      sec_company_url = NA_character_,
      match_notes = notes
    ),
  roster_raw |>
    inner_join(
      crosswalk |>
        select(
          crosswalk_episode_id, builder_name_key, builder_name_clean,
          cik, cik10, sec_company_name, sec_reporting_indicator,
          public_parent_no_comparable_us_10k, manual_review_indicator,
          valid_from_year, valid_to_year, notes
        ),
      by = c("universe_name_key" = "builder_name_key"),
      relationship = "one-to-many"
    ) |>
    transmute(
      staged_row_id, universe_firm_id, company, ticker_token = NA_character_,
      candidate_cik = cik, candidate_cik10 = cik10, candidate_sec_company_name = sec_company_name,
      match_source = "builder_sec_crosswalk_name",
      match_strength = "high",
      crosswalk_episode_id, builder_name_key = universe_name_key, builder_name_clean,
      sec_reporting_indicator, public_parent_no_comparable_us_10k, manual_review_indicator,
      valid_from_year, valid_to_year,
      annual_10k_filing_count = NA_integer_,
      first_annual_10k_report_date = NA_character_,
      last_annual_10k_report_date = NA_character_,
      sec_company_url = NA_character_,
      match_notes = notes
    ),
  roster_tickers |>
    inner_join(sec_tickers, by = c("ticker_token" = "sec_ticker"), relationship = "many-to-one") |>
    transmute(
      staged_row_id, universe_firm_id, company, ticker_token,
      candidate_cik = sec_cik, candidate_cik10 = sec_cik10, candidate_sec_company_name = sec_title,
      match_source = "sec_company_tickers_ticker",
      match_strength = "high",
      crosswalk_episode_id = NA_character_, builder_name_key = NA_character_, builder_name_clean = NA_character_,
      sec_reporting_indicator = TRUE, public_parent_no_comparable_us_10k = FALSE, manual_review_indicator = FALSE,
      valid_from_year = NA_integer_, valid_to_year = NA_integer_,
      annual_10k_filing_count = NA_integer_,
      first_annual_10k_report_date = NA_character_,
      last_annual_10k_report_date = NA_character_,
      sec_company_url = NA_character_,
      match_notes = "Matched by ticker in current SEC company_tickers.json."
    ),
  roster_tickers |>
    inner_join(sic_tickers, by = c("ticker_token" = "sic_ticker"), relationship = "one-to-many") |>
    transmute(
      staged_row_id, universe_firm_id, company, ticker_token,
      candidate_cik = cik, candidate_cik10 = cik10, candidate_sec_company_name = coalesce(sec_company_name, sic_1531_company_name),
      match_source = "sec_sic_1531_ticker",
      match_strength = "high",
      crosswalk_episode_id = NA_character_, builder_name_key = NA_character_, builder_name_clean = NA_character_,
      sec_reporting_indicator = TRUE, public_parent_no_comparable_us_10k = FALSE, manual_review_indicator = FALSE,
      valid_from_year = NA_integer_, valid_to_year = NA_integer_,
      annual_10k_filing_count,
      first_annual_10k_report_date,
      last_annual_10k_report_date,
      sec_company_url,
      match_notes = "Matched by ticker in SEC SIC 1531 browse universe."
    ),
  roster_raw |>
    inner_join(
      sec_sic_1531 |>
        select(
          cik, cik10, sic_1531_company_name, sec_company_name,
          sic_company_name_key, sec_company_name_key,
          annual_10k_filing_count, first_annual_10k_report_date,
          last_annual_10k_report_date, sec_company_url
        ),
      by = c("universe_name_key" = "sic_company_name_key"),
      relationship = "one-to-many"
    ) |>
    transmute(
      staged_row_id, universe_firm_id, company, ticker_token = NA_character_,
      candidate_cik = cik, candidate_cik10 = cik10, candidate_sec_company_name = coalesce(sec_company_name, sic_1531_company_name),
      match_source = "sec_sic_1531_exact_company_name",
      match_strength = "medium",
      crosswalk_episode_id = NA_character_, builder_name_key = NA_character_, builder_name_clean = NA_character_,
      sec_reporting_indicator = TRUE, public_parent_no_comparable_us_10k = FALSE, manual_review_indicator = FALSE,
      valid_from_year = NA_integer_, valid_to_year = NA_integer_,
      annual_10k_filing_count,
      first_annual_10k_report_date,
      last_annual_10k_report_date,
      sec_company_url,
      match_notes = "Matched by exact normalized company name in SEC SIC 1531 browse universe."
    )
) |>
  filter(!is.na(candidate_cik10), candidate_cik10 != "") |>
  distinct() |>
  arrange(staged_row_id, desc(match_strength == "high"), candidate_cik10, match_source)

candidate_summary <- candidate_rows |>
  group_by(staged_row_id, candidate_cik10) |>
  summarise(
    universe_firm_id = first(universe_firm_id),
    company = first(company),
    candidate_cik = first(candidate_cik[!is.na(candidate_cik) & candidate_cik != ""], default = NA_character_),
    candidate_sec_company_name = first(candidate_sec_company_name[!is.na(candidate_sec_company_name) & candidate_sec_company_name != ""], default = NA_character_),
    tickers_matched = paste(sort(unique(ticker_token[!is.na(ticker_token) & ticker_token != ""])), collapse = " | "),
    match_sources = paste(sort(unique(match_source)), collapse = " | "),
    high_strength_sources = sum(match_strength == "high", na.rm = TRUE),
    has_high_strength_match = any(match_strength == "high", na.rm = TRUE),
    crosswalk_episode_ids = paste(sort(unique(crosswalk_episode_id[!is.na(crosswalk_episode_id) & crosswalk_episode_id != ""])), collapse = " | "),
    builder_name_keys = paste(sort(unique(builder_name_key[!is.na(builder_name_key) & builder_name_key != ""])), collapse = " | "),
    sec_reporting_indicator = any(sec_reporting_indicator, na.rm = TRUE),
    public_parent_no_comparable_us_10k = any(public_parent_no_comparable_us_10k, na.rm = TRUE),
    manual_review_indicator = any(manual_review_indicator, na.rm = TRUE),
    valid_from_year = if (all(is.na(valid_from_year))) NA_integer_ else min(valid_from_year, na.rm = TRUE),
    open_ended_valid_to_match = any(is.na(valid_to_year)),
    valid_to_year = if (all(is.na(valid_to_year))) NA_integer_ else max(valid_to_year, na.rm = TRUE),
    annual_10k_filing_count = if (all(is.na(annual_10k_filing_count))) NA_integer_ else max(annual_10k_filing_count, na.rm = TRUE),
    first_annual_10k_report_date = first(sort(unique(first_annual_10k_report_date[!is.na(first_annual_10k_report_date) & first_annual_10k_report_date != ""])), default = NA_character_),
    last_annual_10k_report_date = last(sort(unique(last_annual_10k_report_date[!is.na(last_annual_10k_report_date) & last_annual_10k_report_date != ""])), default = NA_character_),
    sec_company_url = first(sec_company_url[!is.na(sec_company_url) & sec_company_url != ""], default = NA_character_),
    match_notes = paste(sort(unique(match_notes[!is.na(match_notes) & match_notes != ""])), collapse = " | "),
    .groups = "drop"
  )

crosswalk_out <- roster_raw |>
  left_join(candidate_summary, by = c("staged_row_id", "universe_firm_id", "company"), relationship = "one-to-many") |>
  group_by(staged_row_id) |>
  mutate(
    distinct_cik_count = n_distinct(candidate_cik10[!is.na(candidate_cik10) & candidate_cik10 != ""]),
    multi_cik_expected = str_detect(coalesce(ticker, ""), "/") |
      str_detect(str_to_lower(coalesce(fate_and_splicing_notes, "")), "two public windows|bhs|brp|wci|wcic"),
    resolved_to_sec_cik = !is.na(candidate_cik10) & candidate_cik10 != "",
    selected_for_sec_download = resolved_to_sec_cik & sec_reporting_indicator &
      !public_parent_no_comparable_us_10k & tier %in% c(1L, 2L) &
      (distinct_cik_count == 1L | multi_cik_expected | has_high_strength_match),
    nonbuilder_land_company_download_target = resolved_to_sec_cik & sec_reporting_indicator &
      !public_parent_no_comparable_us_10k & tier == 3L,
    universe_review_status = case_when(
      !resolved_to_sec_cik ~ "needs_cik_resolution",
      tier == 3L ~ "adjacent_land_company_keep_separate",
      public_parent_no_comparable_us_10k ~ "noncomparable_public_parent_review",
      manual_review_indicator ~ "manual_review_from_builder_crosswalk",
      distinct_cik_count > 1L & !multi_cik_expected ~ "multiple_cik_candidates_review",
      merger_splice_flag ~ "resolved_splice_or_lifecycle_case",
      TRUE ~ "resolved"
    ),
    manual_review_needed = universe_review_status != "resolved" &
      universe_review_status != "resolved_splice_or_lifecycle_case" &
      universe_review_status != "adjacent_land_company_keep_separate"
  ) |>
  ungroup() |>
  mutate(
    valid_to_year = if_else(status == "active" & open_ended_valid_to_match, NA_integer_, valid_to_year),
    universe_episode_id = if_else(
      resolved_to_sec_cik,
      paste(universe_firm_id, candidate_cik10, sep = "__"),
      paste0(universe_firm_id, "__unresolved")
    )
  ) |>
  select(
    universe_episode_id, staged_row_id, universe_firm_id, universe_name_key,
    company, ticker, tickers_matched, tier, tier_label, status, analysis_role,
    builder_panel_eligible, adjacent_land_company, current_or_historical_builder,
    resolved_to_sec_cik, selected_for_sec_download, nonbuilder_land_company_download_target,
    candidate_cik, candidate_cik10, candidate_sec_company_name,
    sec_reporting_indicator, public_parent_no_comparable_us_10k,
    manual_review_indicator, manual_review_needed, universe_review_status,
    distinct_cik_count, multi_cik_expected, match_sources, high_strength_sources,
    has_high_strength_match, crosswalk_episode_ids, builder_name_keys,
    valid_from_year, valid_to_year, annual_10k_filing_count,
    first_annual_10k_report_date, last_annual_10k_report_date,
    filing_window, fye_month, fye_month_number, fiscal_year_warning,
    merger_splice_flag, recent_ipo_flag, low_omega_anchor_flag, high_omega_prior_flag,
    fate_and_splicing_notes, omega_prior_and_relevance, sec_company_url, match_notes
  ) |>
  arrange(tier, staged_row_id, candidate_cik10)

manual_review <- crosswalk_out |>
  filter(manual_review_needed | !resolved_to_sec_cik | public_parent_no_comparable_us_10k | distinct_cik_count > 1L | fiscal_year_warning != "") |>
  arrange(tier, staged_row_id, universe_review_status, candidate_cik10)

qc_rows <- tibble(
  check = c(
    "raw_roster_rows",
    "tier_1_firms",
    "tier_2_firms",
    "tier_3_firms",
    "builder_panel_eligible_firms",
    "resolved_builder_download_episodes",
    "adjacent_land_company_download_episodes",
    "unresolved_roster_firms",
    "manual_review_rows",
    "non_december_fye_rows",
    "recent_ipo_rows",
    "low_omega_anchor_rows"
  ),
  status = c(
    if_else(nrow(roster_raw) == 40L, "ok", "warn"),
    if_else(sum(roster_raw$tier == 1L, na.rm = TRUE) == 20L, "ok", "warn"),
    if_else(sum(roster_raw$tier == 2L, na.rm = TRUE) == 18L, "ok", "warn"),
    if_else(sum(roster_raw$tier == 3L, na.rm = TRUE) == 2L, "ok", "warn"),
    if_else(sum(roster_raw$builder_panel_eligible, na.rm = TRUE) == 38L, "ok", "warn"),
    if_else(sum(crosswalk_out$selected_for_sec_download, na.rm = TRUE) > 0, "ok", "fail"),
    if_else(sum(crosswalk_out$nonbuilder_land_company_download_target, na.rm = TRUE) > 0, "ok", "warn"),
    if_else(sum(!crosswalk_out$resolved_to_sec_cik, na.rm = TRUE) == 0, "ok", "warn"),
    "ok",
    "ok",
    "ok",
    "ok"
  ),
  value = c(
    nrow(roster_raw),
    sum(roster_raw$tier == 1L, na.rm = TRUE),
    sum(roster_raw$tier == 2L, na.rm = TRUE),
    sum(roster_raw$tier == 3L, na.rm = TRUE),
    sum(roster_raw$builder_panel_eligible, na.rm = TRUE),
    sum(crosswalk_out$selected_for_sec_download, na.rm = TRUE),
    sum(crosswalk_out$nonbuilder_land_company_download_target, na.rm = TRUE),
    sum(!crosswalk_out$resolved_to_sec_cik, na.rm = TRUE),
    nrow(manual_review),
    sum(roster_raw$fiscal_year_warning != "", na.rm = TRUE),
    sum(roster_raw$recent_ipo_flag, na.rm = TRUE),
    sum(roster_raw$low_omega_anchor_flag, na.rm = TRUE)
  ),
  detail = c(
    "Manual Fable/Claude expansion roster rows, excluding header.",
    "Tier-1 public production-builder targets.",
    "Tier-2 historical/dead/acquired builder targets, including manually added Builder-public omissions.",
    "Tier-3 adjacent public land companies, kept out of the builder panel.",
    "Tier 1 and Tier 2 builder firms.",
    "Builder CIK episodes eligible for SEC filing expansion.",
    "Forestar/Millrose-type land-company CIK episodes kept separate.",
    "Roster firms with no candidate CIK from Builder crosswalk, SEC ticker map, or SIC 1531.",
    "Rows needing some form of manual/comparability/fiscal-year review.",
    "Rows with non-December or unparsed fiscal year end.",
    "Rows flagged as recent IPO/de-SPAC cohort.",
    "Rows flagged as low-omega anchors."
  )
)

write_csv_if_changed(roster_raw, "../output/builder_universe_roster_staged.csv")
write_csv_if_changed(candidate_rows, "../output/builder_universe_match_candidates.csv")
write_csv_if_changed(crosswalk_out, "../output/builder_universe_sec_crosswalk.csv")
write_csv_if_changed(manual_review, "../output/builder_universe_manual_review.csv")
write_csv_if_changed(qc_rows, "../output/builder_universe_qc.csv")

cat("Wrote staged builder universe roster outputs to ../output\n")
