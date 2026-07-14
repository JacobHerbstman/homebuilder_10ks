# setwd("/Users/jacobherbstman/Desktop/homebuilder_10ks/tasks/build_tier1_land_adjustment_panel/code")

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(tidyr)
})

source("../../_lib/homebuilder_pipeline_utils.R")

land <- read_csv("../input/expanded_builder_2004_2025_land_panel.csv", show_col_types = FALSE) |>
  filter(
    ticker %in% c(
      "DHI", "LEN", "PHM", "NVR", "KBH", "HOV",
      "BZH", "MHO", "MTH", "TOL", "MDC",
      "TMHC", "TPH", "CCS", "LGIH", "GRBK", "DFH", "LSEA"
    ),
    fiscal_year %in% c(2021, 2023),
    in_universe_episode_window %in% TRUE,
    selected_main_plot_eligible %in% TRUE
  ) |>
  transmute(
    ticker, company, fiscal_year,
    unit_type = selected_unit_type,
    owned_count = selected_owned_physical_count,
    nonowned_controlled_count = selected_nonowned_physical_count,
    total_controlled_count = selected_total_physical_count,
    nonowned_controlled_share = selected_nonowned_controlled_share,
    measure_definition = selected_measure_definition,
    land_source = selected_land_source,
    source_note = selected_source_note,
    accession_number = selected_accession_number,
    source_url = selected_source_url,
    recent_ipo_flag
  )

if (nrow(land) != 36 || land |> count(ticker, fiscal_year) |> filter(n != 1) |> nrow() > 0) {
  stop("Expected 36 unique land observations for 18 firms in 2021 and 2023.")
}

operating <- read_csv("../input/tier1_2018_2025_annual_operating_panel.csv", show_col_types = FALSE) |>
  filter(fiscal_year %in% c(2021, 2023)) |>
  select(ticker, fiscal_year, deliveries_units)

six_firm_options <- read_csv("../input/six_firm_2006_2025_manual_land_panel.csv", show_col_types = FALSE) |>
  filter(
    ticker %in% c("LEN", "PHM", "KBH", "HOV"),
    fiscal_year %in% c(2021, 2023)
  ) |>
  select(ticker, fiscal_year, optioned_physical_count)

land <- land |>
  left_join(operating, by = c("ticker", "fiscal_year"), relationship = "one-to-one") |>
  left_join(six_firm_options, by = c("ticker", "fiscal_year"), relationship = "one-to-one") |>
  mutate(
    option_labeled_count = case_when(
      ticker %in% c("BZH", "MDC", "TOL") ~ nonowned_controlled_count,
      ticker %in% c("LEN", "PHM", "KBH", "HOV") ~ optioned_physical_count,
      TRUE ~ NA_real_
    ),
    option_labeled_definition = case_when(
      ticker == "BZH" ~ "Optioned lots",
      ticker == "LEN" & !is.na(optioned_physical_count) ~ "Optioned homesites excluding separately reported JV homesites",
      ticker == "PHM" ~ "Optioned lots",
      ticker == "KBH" ~ "Land under option",
      ticker == "HOV" ~ "Optioned home sites",
      ticker == "MDC" ~ "Optioned lots",
      ticker == "TOL" ~ "Home sites controlled through options",
      TRUE ~ NA_character_
    ),
    component_residual_count = total_controlled_count - owned_count - nonowned_controlled_count,
    total_controlled_per_delivery = total_controlled_count / deliveries_units,
    owned_per_delivery = owned_count / deliveries_units,
    nonowned_controlled_per_delivery = nonowned_controlled_count / deliveries_units,
    option_labeled_per_delivery = option_labeled_count / deliveries_units
  )

panel <- land |>
  select(
    ticker, company, fiscal_year, recent_ipo_flag, unit_type,
    owned_count, nonowned_controlled_count, option_labeled_count,
    total_controlled_count, component_residual_count, nonowned_controlled_share,
    deliveries_units, total_controlled_per_delivery, owned_per_delivery,
    nonowned_controlled_per_delivery, option_labeled_per_delivery,
    option_labeled_definition, measure_definition, land_source,
    accession_number, source_url, source_note
  ) |>
  pivot_wider(
    names_from = fiscal_year,
    values_from = -c(ticker, company),
    names_glue = "{.value}_{fiscal_year}"
  ) |>
  mutate(
    owned_count_change = owned_count_2023 - owned_count_2021,
    owned_count_growth = owned_count_2023 / owned_count_2021 - 1,
    nonowned_controlled_count_change = nonowned_controlled_count_2023 - nonowned_controlled_count_2021,
    nonowned_controlled_count_growth = nonowned_controlled_count_2023 / nonowned_controlled_count_2021 - 1,
    option_labeled_count_change = option_labeled_count_2023 - option_labeled_count_2021,
    option_labeled_count_growth = option_labeled_count_2023 / option_labeled_count_2021 - 1,
    total_controlled_count_change = total_controlled_count_2023 - total_controlled_count_2021,
    total_controlled_count_growth = total_controlled_count_2023 / total_controlled_count_2021 - 1,
    nonowned_controlled_share_change = nonowned_controlled_share_2023 - nonowned_controlled_share_2021,
    total_controlled_per_delivery_change = total_controlled_per_delivery_2023 - total_controlled_per_delivery_2021,
    owned_per_delivery_change = owned_per_delivery_2023 - owned_per_delivery_2021,
    nonowned_controlled_per_delivery_change = nonowned_controlled_per_delivery_2023 - nonowned_controlled_per_delivery_2021,
    option_labeled_per_delivery_change = option_labeled_per_delivery_2023 - option_labeled_per_delivery_2021,
    unit_definition_continuous = unit_type_2021 == unit_type_2023,
    land_measure_definition_continuous = measure_definition_2021 == measure_definition_2023,
    option_measure_continuous = !is.na(option_labeled_count_2021) & !is.na(option_labeled_count_2023) &
      option_labeled_definition_2021 == option_labeled_definition_2023,
    land_adjustment_analysis_ready = unit_definition_continuous & land_measure_definition_continuous &
      !is.na(total_controlled_count_2021) & !is.na(total_controlled_count_2023) &
      !is.na(nonowned_controlled_count_2021) & !is.na(nonowned_controlled_count_2023)
  ) |>
  arrange(ticker)

if (nrow(panel) != 18 || n_distinct(panel$ticker) != 18 || !all(panel$land_adjustment_analysis_ready)) {
  stop("The land-adjustment panel is not complete for all 18 continuously observed firms.")
}

write_csv_if_changed(panel, "../output/tier1_2021_2023_land_adjustment_panel.csv")

cat("Wrote Tier-1 land-adjustment panel to ../output\n")
