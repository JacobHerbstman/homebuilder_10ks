# setwd("/Users/jacobherbstman/Desktop/homebuilder_10ks/tasks/stage_builder_panel/code")

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(stringr)
  library(tibble)
})

source("../../_lib/homebuilder_pipeline_utils.R")

clean_builder_name <- function(x, list_year = NULL) {
  out <- as.character(x)
  out <- str_replace_all(out, "\u00a0", " ")
  out <- str_remove_all(out, "\\s*\\(p\\)\\s*")
  out <- str_remove_all(out, "[*†‡]+")
  if (!is.null(list_year)) {
    out <- str_remove(out, paste0("^", list_year, "\\s+"))
  }
  str_squish(out)
}

empty_panel <- tibble(
  list_year = integer(),
  underlying_closings_year = integer(),
  underlying_revenue_year = integer(),
  prior_rank_year = integer(),
  list_type = character(),
  rank = integer(),
  builder_name_raw = character(),
  builder_name_clean = character(),
  builder_name_key = character(),
  builder_public_flag = logical(),
  total_closings = numeric(),
  gross_revenue_homebuilding_millions = numeric(),
  gross_revenue_units = character(),
  prior_year_rank = numeric(),
  revenue_declined_flag = logical(),
  revenue_estimated_flag = logical(),
  revenue_homebuilding_only_flag = logical(),
  company_detail_url = character(),
  source_url = character(),
  source_path = character(),
  parse_timestamp_utc = character()
)

empty_roster <- tibble(
  builder_name_key = character(),
  builder_name_clean = character(),
  builder_names_observed = character(),
  first_list_year = integer(),
  last_list_year = integer(),
  years_observed = integer(),
  builder_year_rows = integer(),
  top_100_years = integer(),
  next_100_years = integer(),
  ever_marked_public = logical(),
  public_years = integer(),
  first_public_list_year = integer(),
  last_public_list_year = integer(),
  best_rank = integer(),
  latest_list_year = integer(),
  latest_rank = integer(),
  latest_total_closings = numeric(),
  latest_gross_revenue_homebuilding_millions = numeric(),
  latest_company_detail_url = character()
)

raw_rows <- read_csv("../input/builder_magazine_raw_rows.csv", show_col_types = FALSE, na = c("", "NA"))

if (nrow(raw_rows) == 0) {
  write_parquet_if_changed(empty_panel, "../output/builder_panel.parquet")
  write_csv_if_changed(empty_roster, "../output/builder_firm_roster.csv")
  write_csv_if_changed(empty_roster, "../output/builder_public_firm_roster.csv")
  write_csv_if_changed(tibble(), "../output/builder_year_coverage.csv")
  write_csv_if_changed(tibble(check = "staged_rows", status = "fail", value = 0, detail = "No Builder rows parsed from raw HTML."), "../output/builder_panel_qc.csv")
  quit(save = "no")
}

builder_panel <- raw_rows |>
  transmute(
    list_year = suppressWarnings(as.integer(list_year)),
    underlying_closings_year = suppressWarnings(as.integer(underlying_closings_year)),
    underlying_revenue_year = suppressWarnings(as.integer(underlying_revenue_year)),
    prior_rank_year = suppressWarnings(as.integer(prior_rank_year)),
    list_type = as.character(list_type),
    rank = suppressWarnings(as.integer(rank)),
    builder_name_raw = as.character(raw_company_name),
    builder_name_clean = clean_builder_name(raw_company_name, list_year),
    builder_name_key = normalize_text_key(clean_builder_name(raw_company_name, list_year)),
    builder_public_flag = public_marker_flag %in% TRUE,
    total_closings = suppressWarnings(parse_number(as.character(raw_total_closings), na = c("", "NA", "N/A", "*"))),
    gross_revenue_homebuilding_millions = suppressWarnings(parse_number(as.character(raw_gross_revenue), na = c("", "NA", "N/A", "*"))),
    gross_revenue_units = as.character(gross_revenue_units),
    prior_year_rank = suppressWarnings(parse_number(as.character(raw_prior_year_rank), na = c("", "NA", "N/A", "*"))),
    revenue_declined_flag = str_detect(coalesce(as.character(raw_gross_revenue), ""), "\\*"),
    revenue_estimated_flag = str_detect(coalesce(as.character(raw_gross_revenue), ""), "‡"),
    revenue_homebuilding_only_flag = str_detect(coalesce(as.character(raw_gross_revenue), ""), "†"),
    company_detail_url = as.character(company_detail_url),
    source_url = as.character(source_url),
    source_path = as.character(source_path),
    parse_timestamp_utc = as.character(parse_timestamp_utc)
  ) |>
  arrange(list_year, list_type, rank, builder_name_key)

latest_rows <- builder_panel |>
  arrange(builder_name_key, desc(list_year), rank) |>
  group_by(builder_name_key) |>
  slice_head(n = 1) |>
  ungroup() |>
  transmute(
    builder_name_key,
    latest_list_year = list_year,
    latest_rank = rank,
    latest_total_closings = total_closings,
    latest_gross_revenue_homebuilding_millions = gross_revenue_homebuilding_millions,
    latest_company_detail_url = company_detail_url
  )

builder_firm_roster <- builder_panel |>
  filter(!is.na(builder_name_key)) |>
  group_by(builder_name_key) |>
  summarise(
    builder_name_clean = first(builder_name_clean[!is.na(builder_name_clean) & builder_name_clean != ""], default = NA_character_),
    builder_names_observed = paste(sort(unique(builder_name_clean[!is.na(builder_name_clean) & builder_name_clean != ""])), collapse = " | "),
    first_list_year = if (all(is.na(list_year))) NA_integer_ else as.integer(min(list_year, na.rm = TRUE)),
    last_list_year = if (all(is.na(list_year))) NA_integer_ else as.integer(max(list_year, na.rm = TRUE)),
    years_observed = n_distinct(list_year),
    builder_year_rows = n(),
    top_100_years = n_distinct(list_year[list_type == "top_100"]),
    next_100_years = n_distinct(list_year[list_type == "next_100"]),
    ever_marked_public = any(builder_public_flag, na.rm = TRUE),
    public_years = n_distinct(list_year[builder_public_flag %in% TRUE]),
    first_public_list_year = if (all(is.na(list_year[builder_public_flag %in% TRUE]))) NA_integer_ else as.integer(min(list_year[builder_public_flag %in% TRUE], na.rm = TRUE)),
    last_public_list_year = if (all(is.na(list_year[builder_public_flag %in% TRUE]))) NA_integer_ else as.integer(max(list_year[builder_public_flag %in% TRUE], na.rm = TRUE)),
    best_rank = if (all(is.na(rank))) NA_integer_ else as.integer(min(rank, na.rm = TRUE)),
    .groups = "drop"
  ) |>
  left_join(latest_rows, by = "builder_name_key", relationship = "one-to-one") |>
  arrange(desc(ever_marked_public), first_list_year, best_rank, builder_name_clean)

builder_public_firm_roster <- builder_firm_roster |>
  filter(ever_marked_public) |>
  arrange(first_public_list_year, best_rank, builder_name_clean)

builder_year_coverage <- builder_panel |>
  group_by(list_year, list_type) |>
  summarise(
    row_count = n(),
    unique_builder_count = n_distinct(builder_name_key),
    public_row_count = sum(builder_public_flag, na.rm = TRUE),
    total_closings = sum(total_closings, na.rm = TRUE),
    gross_revenue_nonmissing_count = sum(!is.na(gross_revenue_homebuilding_millions)),
    min_rank = min(rank, na.rm = TRUE),
    max_rank = max(rank, na.rm = TRUE),
    .groups = "drop"
  ) |>
  arrange(list_year, list_type)

latest_year <- max(builder_panel$list_year, na.rm = TRUE)
latest_public_keys <- builder_panel |>
  filter(list_year == latest_year, builder_public_flag) |>
  pull(builder_name_key) |>
  unique()

expected_latest_public <- tibble(
  check = paste0("latest_public_seed_", c("d_r_horton", "lennar", "pultegroup", "nvr", "meritage")),
  expected_key = normalize_text_key(c("D.R. Horton", "Lennar Corp.", "PulteGroup", "NVR", "Meritage Homes"))
) |>
  mutate(
    status = if_else(expected_key %in% latest_public_keys, "ok", "fail"),
    value = as.integer(expected_key %in% latest_public_keys),
    detail = paste0("Latest parsed list year: ", latest_year)
  ) |>
  select(check, status, value, detail)

duplicate_firm_list_rows <- builder_panel |>
  count(list_year, list_type, builder_name_key) |>
  filter(n > 1, !is.na(builder_name_key))

qc_rows <- bind_rows(
  tibble(
    check = c(
      "staged_rows",
      "unique_builder_firms",
      "unique_public_builder_firms",
      "first_list_year",
      "last_list_year",
      "rows_missing_builder_key",
      "duplicate_firm_list_rows"
    ),
    status = c(
      if_else(nrow(builder_panel) > 0, "ok", "fail"),
      if_else(n_distinct(builder_panel$builder_name_key, na.rm = TRUE) > 0, "ok", "fail"),
      if_else(nrow(builder_public_firm_roster) > 0, "ok", "fail"),
      "ok",
      "ok",
      if_else(sum(is.na(builder_panel$builder_name_key)) == 0, "ok", "warn"),
      if_else(nrow(duplicate_firm_list_rows) == 0, "ok", "warn")
    ),
    value = c(
      nrow(builder_panel),
      n_distinct(builder_panel$builder_name_key, na.rm = TRUE),
      nrow(builder_public_firm_roster),
      min(builder_panel$list_year, na.rm = TRUE),
      max(builder_panel$list_year, na.rm = TRUE),
      sum(is.na(builder_panel$builder_name_key)),
      nrow(duplicate_firm_list_rows)
    ),
    detail = c(
      "",
      "",
      "",
      "",
      "",
      "Builder rows with no normalized firm key.",
      "Firm appears more than once within the same list year and list type."
    )
  ),
  expected_latest_public
)

write_parquet_if_changed(builder_panel, "../output/builder_panel.parquet")
write_csv_if_changed(builder_firm_roster, "../output/builder_firm_roster.csv")
write_csv_if_changed(builder_public_firm_roster, "../output/builder_public_firm_roster.csv")
write_csv_if_changed(builder_year_coverage, "../output/builder_year_coverage.csv")
write_csv_if_changed(qc_rows, "../output/builder_panel_qc.csv")

cat("Wrote staged Builder panel outputs to ../output\n")
