# setwd("/Users/jacobherbstman/Desktop/homebuilder_10ks/tasks/audit_10k_land_values/code")

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(stringr)
  library(tibble)
  library(tidyr)
})

source("../../_lib/homebuilder_pipeline_utils.R")

as_task_bool <- function(x) {
  x %in% c(TRUE, "TRUE", "true", "True", "1", 1)
}

as_task_num <- function(x) {
  suppressWarnings(as.numeric(as.character(x)))
}

quantile_or_na <- function(x, p) {
  x <- x[!is.na(x)]
  if (length(x) == 0) {
    return(NA_real_)
  }
  as.numeric(stats::quantile(x, p, names = FALSE, type = 7))
}

flag_rows <- function(df, flag_type, flag_reason) {
  df |>
    mutate(
      flag_type = flag_type,
      flag_reason = flag_reason,
      source_excerpt = str_squish(str_sub(
        if_else(coalesce(table_row_or_table_text, "") != "",
                coalesce(table_row_or_table_text, ""),
                coalesce(context_snippet, "")),
        1, 900
      ))
    ) |>
    select(
      flag_type, flag_reason, builder_name_key, ticker, cik10, accession_number,
      fiscal_year, variable_name, preferred_value, unit, raw_value, confidence,
      extraction_method, source_scope, period_label, selection_score,
      source_table_index, source_row_label, source_column_label, source_path,
      source_excerpt
    )
}

panel_flag_rows <- function(df, flag_type, flag_reason) {
  df |>
    mutate(
      flag_type = flag_type,
      flag_reason = flag_reason
    ) |>
    select(
      flag_type, flag_reason, builder_name_key, builder_name_clean, ticker, cik10,
      accession_number, fiscal_year, check_value, owned_lots, optioned_lots,
      controlled_lots, total_lots, owned_homesites, controlled_homesites,
      total_homesites, closings, active_communities, controlled_share,
      optioned_share, deposit_rate, remaining_purchase_price_per_optioned_lot,
      primary_document_local_path, filing_url
    )
}

preferred_values <- read_csv("../input/tenk_land_preferred_values.csv", show_col_types = FALSE, na = c("", "NA")) |>
  mutate(
    cik10 = as.character(cik10),
    accession_number = as.character(accession_number),
    fiscal_year = suppressWarnings(as.integer(fiscal_year)),
    preferred_value = as_task_num(preferred_value),
    period_label = suppressWarnings(as.integer(period_label)),
    selection_score = as_task_num(selection_score),
    confidence = coalesce(confidence, ""),
    extraction_method = coalesce(extraction_method, ""),
    source_scope = coalesce(source_scope, ""),
    unit = coalesce(unit, ""),
    raw_value = coalesce(raw_value, ""),
    context_snippet = coalesce(context_snippet, ""),
    table_row_or_table_text = coalesce(table_row_or_table_text, ""),
    manual_review_reason = coalesce(manual_review_reason, "")
  )

selection_audit <- read_csv(
  "../input/tenk_land_value_selection_audit.csv",
  show_col_types = FALSE,
  na = c("", "NA"),
  col_types = cols(segment_label = col_character())
) |>
  mutate(
    cik10 = as.character(cik10),
    accession_number = as.character(accession_number),
    fiscal_year = suppressWarnings(as.integer(fiscal_year)),
    variable_name = as.character(variable_name),
    selected_as_preferred = as_task_bool(selected_as_preferred),
    conflicting_high_score_values = as_task_bool(conflicting_high_score_values),
    numeric_value = as_task_num(numeric_value)
  )

panel <- read_csv("../input/public_builder_10k_land_panel.csv", show_col_types = FALSE, na = c("", "NA")) |>
  mutate(
    cik10 = as.character(cik10),
    accession_number = as.character(accession_number),
    fiscal_year = suppressWarnings(as.integer(fiscal_year))
  )

benchmark_audit <- read_csv("../input/tenk_land_benchmark_audit.csv", show_col_types = FALSE, na = c("", "NA")) |>
  mutate(benchmark_pass = as_task_bool(benchmark_pass))

selected_conflicts <- selection_audit |>
  filter(selected_as_preferred) |>
  group_by(cik10, accession_number, fiscal_year, variable_name) |>
  summarise(
    conflicting_high_score_values = any(conflicting_high_score_values, na.rm = TRUE),
    candidate_values_reviewed = n(),
    alternative_candidate_values = n_distinct(round(numeric_value, 6), na.rm = TRUE),
    .groups = "drop"
  )

preferred_values <- preferred_values |>
  left_join(
    selected_conflicts,
    by = c("cik10", "accession_number", "fiscal_year", "variable_name"),
    relationship = "one-to-one"
  ) |>
  mutate(
    conflicting_high_score_values = coalesce(conflicting_high_score_values, FALSE),
    candidate_values_reviewed = coalesce(candidate_values_reviewed, 1L),
    alternative_candidate_values = coalesce(alternative_candidate_values, 1L)
  )

lot_metric_names <- c(
  "owned_lots", "optioned_lots", "controlled_lots", "total_lots",
  "lot_purchase_agreements", "optioned_lots_approved_for_purchase",
  "optioned_lots_pending_approval"
)

homesite_metric_names <- c("owned_homesites", "controlled_homesites", "total_homesites")

home_metric_names <- c("closings", "net_new_orders_units", "backlog_units", "homes_in_inventory")

community_metric_names <- c("active_communities")

percent_metric_names <- c(
  "cancellation_rate", "home_sale_gross_margin", "developed_share_owned",
  "developed_share_optioned", "developed_share_controlled"
)

expected_units <- tibble(variable_name = sort(unique(preferred_values$variable_name))) |>
  mutate(
    expected_unit = case_when(
      variable_name %in% lot_metric_names ~ "lots",
      variable_name %in% homesite_metric_names ~ "homesites",
      variable_name %in% home_metric_names ~ "homes",
      variable_name %in% community_metric_names ~ "communities",
      variable_name %in% percent_metric_names ~ "percent",
      TRUE ~ "dollars"
    ),
    integer_metric = expected_unit %in% c("lots", "homesites", "homes"),
    nonnegative_metric = variable_name != "home_sale_gross_margin"
  )

preferred_values <- preferred_values |>
  left_join(expected_units, by = "variable_name", relationship = "many-to-one") |>
  mutate(
    expected_unit = coalesce(expected_unit, "unknown"),
    unit_mismatch = unit != expected_unit,
    noninteger_physical_value = integer_metric & !is.na(preferred_value) &
      abs(preferred_value - round(preferred_value)) > 1e-6,
    small_positive_dollar_value = expected_unit == "dollars" &
      !is.na(preferred_value) & preferred_value > 0 & preferred_value <= 31,
    tiny_positive_dollar_value = expected_unit == "dollars" &
      !is.na(preferred_value) & preferred_value > 31 & preferred_value < 1000,
    negative_nonnegative_value = nonnegative_metric & !is.na(preferred_value) & preferred_value < 0,
    period_mismatch = !is.na(period_label) & !is.na(fiscal_year) & period_label != fiscal_year,
    percent_out_of_range = expected_unit == "percent" & !is.na(preferred_value) &
      if_else(variable_name == "home_sale_gross_margin",
              preferred_value < -100 | preferred_value > 100,
              preferred_value < 0 | preferred_value > 100),
    physical_count_too_large = expected_unit %in% c("lots", "homesites", "homes") &
      !is.na(preferred_value) & preferred_value > 2000000,
    community_count_too_large = expected_unit == "communities" &
      !is.na(preferred_value) & preferred_value > 10000,
    asp_out_of_range = variable_name == "average_selling_price" &
      !is.na(preferred_value) & (preferred_value < 50000 | preferred_value > 2000000),
    dollar_value_too_large = expected_unit == "dollars" &
      !is.na(preferred_value) & preferred_value > 150000000000,
    missing_source_provenance = context_snippet == "" & table_row_or_table_text == "",
    low_confidence_selected = confidence == "low",
    snippet_selected = str_detect(extraction_method, "snippet")
  )

tenk_land_sanity_flags <- bind_rows(
  preferred_values |> filter(unit_mismatch) |>
    flag_rows("unit_mismatch", "Observed unit does not match the metric dictionary."),
  preferred_values |> filter(noninteger_physical_value) |>
    flag_rows("noninteger_physical_value", "Lots, homesites, and homes should be integer counts."),
  preferred_values |> filter(small_positive_dollar_value) |>
    flag_rows("small_positive_dollar_value", "Positive dollar value is at or below 31; this often indicates a stray footnote/date/table index."),
  preferred_values |> filter(tiny_positive_dollar_value) |>
    flag_rows("tiny_positive_dollar_value", "Positive dollar value is below 1,000; inspect scale and context."),
  preferred_values |> filter(negative_nonnegative_value) |>
    flag_rows("negative_nonnegative_value", "Metric is expected to be a nonnegative magnitude."),
  preferred_values |> filter(period_mismatch) |>
    flag_rows("period_mismatch", "Source period label differs from fiscal year."),
  preferred_values |> filter(percent_out_of_range) |>
    flag_rows("percent_out_of_range", "Percent metric is outside [0, 100]."),
  preferred_values |> filter(physical_count_too_large) |>
    flag_rows("physical_count_too_large", "Physical count exceeds 2,000,000."),
  preferred_values |> filter(community_count_too_large) |>
    flag_rows("community_count_too_large", "Active community count exceeds 10,000."),
  preferred_values |> filter(asp_out_of_range) |>
    flag_rows("average_selling_price_out_of_range", "Average selling price is outside $50k-$2m."),
  preferred_values |> filter(dollar_value_too_large) |>
    flag_rows("dollar_value_too_large", "Dollar value exceeds $150b."),
  preferred_values |> filter(missing_source_provenance) |>
    flag_rows("missing_source_provenance", "Selected value has no snippet or table provenance text."),
  preferred_values |> filter(conflicting_high_score_values) |>
    flag_rows("conflicting_high_score_values", "Multiple high-scoring candidate values exist for this firm filing metric."),
  preferred_values |> filter(low_confidence_selected) |>
    flag_rows("low_confidence_selected", "Preferred value was selected from a low-confidence candidate."),
  preferred_values |> filter(snippet_selected & variable_name %in% c(
    "owned_lots", "controlled_lots", "total_lots", "owned_homesites",
    "controlled_homesites", "total_homesites", "remaining_purchase_price",
    "deposits_preacquisition_costs", "home_sale_revenue", "land_sale_revenue",
    "total_inventory", "total_assets"
  )) |>
    flag_rows("snippet_selected_core_metric", "Core metric selected from nearby snippet rather than structured table.")
) |>
  arrange(ticker, fiscal_year, variable_name, flag_type)

flag_counts <- tenk_land_sanity_flags |>
  count(variable_name, name = "sanity_flag_rows")

tenk_land_sanity_summary <- preferred_values |>
  group_by(variable_name, expected_unit) |>
  summarise(
    observed_units = paste(sort(unique(unit)), collapse = ";"),
    preferred_rows = n(),
    firms = n_distinct(cik10),
    filings = n_distinct(accession_number),
    first_fiscal_year = min(fiscal_year, na.rm = TRUE),
    last_fiscal_year = max(fiscal_year, na.rm = TRUE),
    table_rows = sum(extraction_method == "table_cell_structured", na.rm = TRUE),
    snippet_rows = sum(str_detect(extraction_method, "snippet"), na.rm = TRUE),
    high_confidence_rows = sum(confidence == "high", na.rm = TRUE),
    medium_confidence_rows = sum(confidence == "medium", na.rm = TRUE),
    low_confidence_rows = sum(confidence == "low", na.rm = TRUE),
    conflicting_high_score_rows = sum(conflicting_high_score_values, na.rm = TRUE),
    unit_mismatch_rows = sum(unit_mismatch, na.rm = TRUE),
    noninteger_physical_rows = sum(noninteger_physical_value, na.rm = TRUE),
    small_positive_dollar_rows = sum(small_positive_dollar_value, na.rm = TRUE),
    tiny_positive_dollar_rows = sum(tiny_positive_dollar_value, na.rm = TRUE),
    negative_rows = sum(negative_nonnegative_value, na.rm = TRUE),
    period_mismatch_rows = sum(period_mismatch, na.rm = TRUE),
    min_value = min(preferred_value, na.rm = TRUE),
    p01_value = quantile_or_na(preferred_value, 0.01),
    p05_value = quantile_or_na(preferred_value, 0.05),
    p25_value = quantile_or_na(preferred_value, 0.25),
    p50_value = quantile_or_na(preferred_value, 0.50),
    p75_value = quantile_or_na(preferred_value, 0.75),
    p95_value = quantile_or_na(preferred_value, 0.95),
    p99_value = quantile_or_na(preferred_value, 0.99),
    max_value = max(preferred_value, na.rm = TRUE),
    .groups = "drop"
  ) |>
  left_join(flag_counts, by = "variable_name", relationship = "one-to-one") |>
  mutate(sanity_flag_rows = coalesce(sanity_flag_rows, 0L)) |>
  arrange(desc(sanity_flag_rows), variable_name)

set.seed(20260509)

random_sample <- preferred_values |>
  group_by(variable_name) |>
  mutate(random_order = runif(n())) |>
  arrange(random_order, .by_group = TRUE) |>
  slice_head(n = 20) |>
  ungroup() |>
  mutate(sample_reason = "deterministic_random_by_variable")

low_sample <- preferred_values |>
  filter(!is.na(preferred_value)) |>
  group_by(variable_name) |>
  slice_min(preferred_value, n = 3, with_ties = FALSE) |>
  ungroup() |>
  mutate(sample_reason = "lowest_values_by_variable")

high_sample <- preferred_values |>
  filter(!is.na(preferred_value)) |>
  group_by(variable_name) |>
  slice_max(preferred_value, n = 3, with_ties = FALSE) |>
  ungroup() |>
  mutate(sample_reason = "highest_values_by_variable")

flag_sample_reasons <- tenk_land_sanity_flags |>
  group_by(cik10, accession_number, fiscal_year, variable_name) |>
  summarise(sample_reason = paste(sort(unique(paste0("flag:", flag_type))), collapse = ";"), .groups = "drop")

flag_sample <- preferred_values |>
  inner_join(
    flag_sample_reasons,
    by = c("cik10", "accession_number", "fiscal_year", "variable_name"),
    relationship = "many-to-one"
  )

tenk_land_sanity_sample <- bind_rows(random_sample, low_sample, high_sample, flag_sample) |>
  group_by(cik10, accession_number, fiscal_year, variable_name, raw_value, preferred_value) |>
  summarise(
    sample_reason = paste(sort(unique(sample_reason)), collapse = ";"),
    builder_name_key = first(builder_name_key),
    builder_name_clean = first(builder_name_clean),
    ticker = first(ticker),
    sec_company_name = first(sec_company_name),
    expected_unit = first(expected_unit),
    unit = first(unit),
    confidence = first(confidence),
    extraction_method = first(extraction_method),
    source_scope = first(source_scope),
    period_label = first(period_label),
    source_table_index = first(source_table_index),
    source_row_label = first(source_row_label),
    source_column_label = first(source_column_label),
    selection_score = first(selection_score),
    source_path = first(source_path),
    source_excerpt = str_squish(str_sub(first(coalesce(table_row_or_table_text, context_snippet, "")), 1, 1200)),
    .groups = "drop"
  ) |>
  arrange(variable_name, ticker, fiscal_year, sample_reason)

tenk_land_panel_sanity_flags <- bind_rows(
  panel |> filter(!is.na(controlled_share) & (controlled_share < 0 | controlled_share > 1.02)) |>
    mutate(check_value = controlled_share) |>
    panel_flag_rows("controlled_share_out_of_range", "Controlled share should be in [0, 1] allowing tiny rounding slack."),
  panel |> filter(!is.na(optioned_share) & (optioned_share < 0 | optioned_share > 1.02)) |>
    mutate(check_value = optioned_share) |>
    panel_flag_rows("optioned_share_out_of_range", "Optioned share should be in [0, 1] allowing tiny rounding slack."),
  panel |> filter(!is.na(deposit_rate) & (deposit_rate < 0 | deposit_rate > 0.75)) |>
    mutate(check_value = deposit_rate) |>
    panel_flag_rows("deposit_rate_out_of_range", "Deposit rate is outside [0, .75]."),
  panel |> filter(!is.na(total_lots) & !is.na(owned_lots) & total_lots + 1 < owned_lots) |>
    mutate(check_value = total_lots - owned_lots) |>
    panel_flag_rows("total_lots_less_than_owned_lots", "Total lots is below owned lots."),
  panel |> filter(!is.na(total_lots) & !is.na(controlled_lots) & total_lots + 1 < controlled_lots) |>
    mutate(check_value = total_lots - controlled_lots) |>
    panel_flag_rows("total_lots_less_than_controlled_lots", "Total lots is below controlled lots."),
  panel |> filter(!is.na(total_homesites) & !is.na(owned_homesites) & !is.na(controlled_homesites) &
                    abs(total_homesites - owned_homesites - controlled_homesites) > 1) |>
    mutate(check_value = total_homesites - owned_homesites - controlled_homesites) |>
    panel_flag_rows("homesite_total_identity_failure", "Total homesites differs from owned plus controlled homesites."),
  panel |> filter(!is.na(controlled_lots_per_closing) & controlled_lots_per_closing > 100) |>
    mutate(check_value = controlled_lots_per_closing) |>
    panel_flag_rows("controlled_lots_per_closing_extreme", "Controlled lots per closing exceeds 100."),
  panel |> filter(!is.na(owned_lots_per_closing) & owned_lots_per_closing > 100) |>
    mutate(check_value = owned_lots_per_closing) |>
    panel_flag_rows("owned_lots_per_closing_extreme", "Owned lots per closing exceeds 100."),
  panel |> filter(!is.na(remaining_purchase_price_per_optioned_lot) &
                    (remaining_purchase_price_per_optioned_lot < 1000 | remaining_purchase_price_per_optioned_lot > 500000)) |>
    mutate(check_value = remaining_purchase_price_per_optioned_lot) |>
    panel_flag_rows("remaining_purchase_price_per_optioned_lot_out_of_range", "Remaining purchase price per optioned lot is outside $1k-$500k.")
) |>
  arrange(ticker, fiscal_year, flag_type)

tenk_land_panel_column_coverage <- bind_rows(lapply(names(panel), function(column_name) {
  x <- panel[[column_name]]
  nonmissing <- if (is.character(x)) {
    sum(!is.na(x) & x != "")
  } else {
    sum(!is.na(x))
  }
  numeric_x <- if (is.numeric(x)) x else suppressWarnings(as.numeric(as.character(x)))
  numeric_x <- numeric_x[!is.na(numeric_x)]
  tibble(
    column_name = column_name,
    column_type = paste(class(x), collapse = ";"),
    rows = nrow(panel),
    nonmissing_rows = nonmissing,
    nonmissing_share = nonmissing / nrow(panel),
    unique_nonmissing_values = n_distinct(x[!is.na(x)]),
    numeric_min = if (length(numeric_x) == 0) NA_real_ else min(numeric_x),
    numeric_p50 = if (length(numeric_x) == 0) NA_real_ else quantile_or_na(numeric_x, 0.50),
    numeric_max = if (length(numeric_x) == 0) NA_real_ else max(numeric_x)
  )
})) |>
  arrange(desc(nonmissing_rows), column_name)

tenk_land_benchmark_status <- benchmark_audit |>
  group_by(benchmark_name) |>
  summarise(
    benchmark_rows = n(),
    passed_rows = sum(benchmark_pass, na.rm = TRUE),
    failed_or_missing_rows = sum(!benchmark_pass, na.rm = TRUE),
    benchmark_status = if_else(failed_or_missing_rows == 0, "pass", "review"),
    .groups = "drop"
  ) |>
  arrange(benchmark_name)

write_csv_if_changed(tenk_land_sanity_summary, "../output/tenk_land_sanity_summary.csv")
write_csv_if_changed(tenk_land_sanity_flags, "../output/tenk_land_sanity_flags.csv")
write_csv_if_changed(tenk_land_sanity_sample, "../output/tenk_land_sanity_sample.csv")
write_csv_if_changed(tenk_land_panel_sanity_flags, "../output/tenk_land_panel_sanity_flags.csv")
write_csv_if_changed(tenk_land_panel_column_coverage, "../output/tenk_land_panel_column_coverage.csv")
write_csv_if_changed(tenk_land_benchmark_status, "../output/tenk_land_benchmark_status.csv")

cat("Wrote 10-K land value sanity audit outputs to ../output\n")
