# setwd("/Users/jacobherbstman/Desktop/homebuilder_10ks/tasks/audit_six_firm_annual_land_values/code")

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(tidyr)
})

source("../../_lib/homebuilder_pipeline_utils.R")

machine <- read_csv("../input/six_firm_2006_2025_annual_land_machine_values.csv", show_col_types = FALSE, na = c("", "NA")) |>
  mutate(
    fiscal_year = as.integer(fiscal_year),
    across(
      c(
        owned_physical_count,
        nonowned_controlled_physical_count,
        optioned_physical_count,
        jv_physical_count,
        construction_to_perm_physical_count,
        total_physical_count,
        nonowned_controlled_share
      ),
      \(x) suppressWarnings(as.numeric(as.character(x)))
    ),
    machine_manual_review_flag = if_else(is.na(manual_review_flag), NA, as.character(manual_review_flag) %in% c("TRUE", "true", "True", "1"))
  ) |>
  select(
    ticker,
    fiscal_year,
    machine_unit_type = unit_type,
    machine_measure_definition = measure_definition,
    machine_owned_physical_count = owned_physical_count,
    machine_nonowned_controlled_physical_count = nonowned_controlled_physical_count,
    machine_optioned_physical_count = optioned_physical_count,
    machine_jv_physical_count = jv_physical_count,
    machine_construction_to_perm_physical_count = construction_to_perm_physical_count,
    machine_total_physical_count = total_physical_count,
    machine_nonowned_controlled_share = nonowned_controlled_share,
    extraction_template_id,
    extraction_method,
    extraction_status,
    extraction_confidence,
    machine_manual_review_flag,
    machine_manual_review_reason = manual_review_reason,
    context_snippet
  )

gold <- read_csv("../input/six_firm_2006_2025_manual_land_panel.csv", show_col_types = FALSE, na = c("", "NA")) |>
  mutate(
    fiscal_year = as.integer(fiscal_year),
    across(
      c(
        owned_physical_count,
        nonowned_controlled_physical_count,
        optioned_physical_count,
        jv_physical_count,
        construction_to_perm_physical_count,
        total_physical_count,
        nonowned_controlled_share
      ),
      \(x) suppressWarnings(as.numeric(as.character(x)))
    ),
    gold_manual_review_flag = if_else(is.na(manual_review_flag), NA, as.character(manual_review_flag) %in% c("TRUE", "true", "True", "1")),
    panel_use_flag = if_else(is.na(panel_use_flag), NA, as.character(panel_use_flag) %in% c("TRUE", "true", "True", "1"))
  ) |>
  select(
    ticker,
    pilot_builder_name,
    fiscal_year,
    gold_unit_type = unit_type,
    gold_measure_definition = measure_definition,
    gold_owned_physical_count = owned_physical_count,
    gold_nonowned_controlled_physical_count = nonowned_controlled_physical_count,
    gold_optioned_physical_count = optioned_physical_count,
    gold_jv_physical_count = jv_physical_count,
    gold_construction_to_perm_physical_count = construction_to_perm_physical_count,
    gold_total_physical_count = total_physical_count,
    gold_nonowned_controlled_share = nonowned_controlled_share,
    gold_manual_review_flag,
    gold_manual_review_reason = manual_review_reason,
    hand_code_quality_tier,
    panel_use_flag,
    source_task,
    source_note,
    accession_number,
    source_url,
    source_local_path
  )

joined <- gold |>
  left_join(machine, by = c("ticker", "fiscal_year"), relationship = "one-to-one")

comparison <- bind_rows(
  joined |>
    transmute(
      ticker, pilot_builder_name, fiscal_year,
      metric = "owned_physical_count",
      gold_value = gold_owned_physical_count,
      machine_value = machine_owned_physical_count
    ),
  joined |>
    transmute(
      ticker, pilot_builder_name, fiscal_year,
      metric = "nonowned_controlled_physical_count",
      gold_value = gold_nonowned_controlled_physical_count,
      machine_value = machine_nonowned_controlled_physical_count
    ),
  joined |>
    transmute(
      ticker, pilot_builder_name, fiscal_year,
      metric = "optioned_physical_count",
      gold_value = gold_optioned_physical_count,
      machine_value = machine_optioned_physical_count
    ),
  joined |>
    transmute(
      ticker, pilot_builder_name, fiscal_year,
      metric = "jv_physical_count",
      gold_value = gold_jv_physical_count,
      machine_value = machine_jv_physical_count
    ),
  joined |>
    transmute(
      ticker, pilot_builder_name, fiscal_year,
      metric = "construction_to_perm_physical_count",
      gold_value = gold_construction_to_perm_physical_count,
      machine_value = machine_construction_to_perm_physical_count
    ),
  joined |>
    transmute(
      ticker, pilot_builder_name, fiscal_year,
      metric = "total_physical_count",
      gold_value = gold_total_physical_count,
      machine_value = machine_total_physical_count
    ),
  joined |>
    transmute(
      ticker, pilot_builder_name, fiscal_year,
      metric = "nonowned_controlled_share",
      gold_value = gold_nonowned_controlled_share,
      machine_value = machine_nonowned_controlled_share
    )
) |>
  left_join(
    joined |>
      select(
        ticker, fiscal_year, accession_number, source_url, source_local_path,
        gold_unit_type, machine_unit_type, gold_measure_definition, machine_measure_definition,
        extraction_template_id, extraction_method, extraction_status, extraction_confidence,
        machine_manual_review_flag, machine_manual_review_reason,
        gold_manual_review_flag, gold_manual_review_reason, hand_code_quality_tier,
        panel_use_flag, source_task, source_note, context_snippet
      ),
    by = c("ticker", "fiscal_year"),
    relationship = "many-to-one"
  ) |>
  mutate(
    tolerance = if_else(metric == "nonowned_controlled_share", 1e-8, 1),
    both_missing = is.na(gold_value) & is.na(machine_value),
    exact_match = !both_missing & !is.na(gold_value) & !is.na(machine_value) &
      abs(gold_value - machine_value) <= tolerance,
    comparison_status = case_when(
      both_missing ~ "both_missing",
      exact_match ~ "match",
      is.na(machine_value) & !is.na(gold_value) ~ "machine_missing",
      !is.na(machine_value) & is.na(gold_value) ~ "machine_extra",
      TRUE ~ "mismatch"
    ),
    absolute_difference = machine_value - gold_value,
    unit_match = coalesce(gold_unit_type == machine_unit_type, FALSE),
    definition_match = coalesce(gold_measure_definition == machine_measure_definition, FALSE),
    needs_review = comparison_status %in% c("machine_missing", "machine_extra", "mismatch") |
      extraction_status != "value_extracted" |
      coalesce(machine_manual_review_flag, TRUE) |
      !unit_match
  ) |>
  arrange(ticker, fiscal_year, metric)

review_queue <- comparison |>
  filter(needs_review) |>
  select(
    ticker, pilot_builder_name, fiscal_year, metric, comparison_status,
    gold_value, machine_value, absolute_difference, extraction_status,
    extraction_template_id, extraction_method, extraction_confidence,
    machine_manual_review_reason, gold_manual_review_reason,
    accession_number, source_url, source_local_path, context_snippet
  ) |>
  arrange(ticker, fiscal_year, metric)

summary <- comparison |>
  group_by(ticker, pilot_builder_name, metric) |>
  summarise(
    rows = n(),
    matches = sum(comparison_status == "match", na.rm = TRUE),
    both_missing = sum(comparison_status == "both_missing", na.rm = TRUE),
    machine_missing = sum(comparison_status == "machine_missing", na.rm = TRUE),
    machine_extra = sum(comparison_status == "machine_extra", na.rm = TRUE),
    mismatches = sum(comparison_status == "mismatch", na.rm = TRUE),
    review_rows = sum(needs_review, na.rm = TRUE),
    .groups = "drop"
  ) |>
  arrange(ticker, metric)

if (joined |> count(ticker, fiscal_year) |> filter(n > 1) |> nrow() > 0) {
  stop("Duplicate joined firm-years in six-firm annual land value audit.")
}

write_csv_if_changed(comparison, "../output/six_firm_2006_2025_annual_land_gold_comparison.csv")
write_csv_if_changed(review_queue, "../output/six_firm_2006_2025_annual_land_review_queue.csv")
write_csv_if_changed(summary, "../output/six_firm_2006_2025_annual_land_gold_summary.csv")
