# setwd("/Users/jacobherbstman/Desktop/homebuilder_10ks/tasks/audit_builder_operating_coverage/code")

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(tidyr)
})

source("../../_lib/homebuilder_pipeline_utils.R")

land_sample <- read_csv(
  "../input/expanded_builder_land_plot_data.csv",
  show_col_types = FALSE,
  na = c("", "NA")
) |>
  mutate(
    fiscal_year = as.integer(fiscal_year),
    selected_main_plot_eligible = selected_main_plot_eligible %in% c(TRUE, "TRUE", "true", "True", "1", 1)
  ) |>
  filter(selected_main_plot_eligible, !is.na(nonowned_controlled_share), fiscal_year %in% 2006:2025) |>
  distinct(ticker, company, fiscal_year)

if (land_sample |> count(ticker, fiscal_year) |> filter(n != 1) |> nrow() > 0) {
  stop("Expanded land sample is not unique by ticker and fiscal year.")
}

core_firms <- land_sample |>
  group_by(ticker, company) |>
  summarise(
    land_years_available = n(),
    first_land_year = min(fiscal_year),
    last_land_year = max(fiscal_year),
    .groups = "drop"
  ) |>
  mutate(core_land_sample = TRUE)

if (nrow(core_firms) != 33 || n_distinct(core_firms$ticker) != 33) {
  stop("Expected 33 distinct firms in the current 2006-2025 land-share sample.")
}

six_firm_operating <- read_csv(
  "../input/six_firm_2006_2025_operating_panel.csv",
  show_col_types = FALSE,
  na = c("", "NA")
) |>
  transmute(
    ticker,
    company,
    fiscal_year = as.integer(fiscal_year),
    orders_units = as.numeric(orders_units),
    deliveries_units = as.numeric(deliveries_units),
    backlog_units = as.numeric(backlog_units),
    cancellation_rate_pct = as.numeric(cancellation_rate_pct),
    active_communities = as.numeric(active_communities),
    average_selling_price_dollars = as.numeric(average_selling_price_dollars),
    homebuilding_revenue_thousands = as.numeric(homebuilding_revenue_thousands),
    extraction_status = "programmatic_firm_era_audited"
  )

wreco_operating <- read_csv(
  "../input/wreco_2004_2013_operating_panel.csv",
  show_col_types = FALSE,
  na = c("", "NA")
) |>
  transmute(
    ticker,
    company,
    fiscal_year = as.integer(fiscal_year),
    orders_units = as.numeric(orders_units),
    deliveries_units = as.numeric(deliveries_units),
    backlog_units = as.numeric(backlog_units),
    cancellation_rate_pct = as.numeric(cancellation_rate_pct),
    active_communities = as.numeric(active_communities),
    average_selling_price_dollars = as.numeric(average_selling_price_dollars),
    homebuilding_revenue_thousands = as.numeric(homebuilding_revenue_thousands),
    extraction_status = "programmatic_firm_era_audited"
  )

operating_rows <- bind_rows(six_firm_operating, wreco_operating)

if (operating_rows |> count(ticker, fiscal_year) |> filter(n != 1) |> nrow() > 0) {
  stop("Operating coverage inputs are not unique by ticker and fiscal year.")
}

metric_coverage <- operating_rows |>
  pivot_longer(
    cols = c(
      orders_units,
      deliveries_units,
      backlog_units,
      cancellation_rate_pct,
      active_communities,
      average_selling_price_dollars,
      homebuilding_revenue_thousands
    ),
    names_to = "metric_name",
    values_to = "numeric_value"
  ) |>
  group_by(ticker, company, extraction_status, metric_name) |>
  summarise(
    firm_years_available = sum(!is.na(numeric_value)),
    first_available_year = if (any(!is.na(numeric_value))) min(fiscal_year[!is.na(numeric_value)]) else NA_integer_,
    last_available_year = if (any(!is.na(numeric_value))) max(fiscal_year[!is.na(numeric_value)]) else NA_integer_,
    .groups = "drop"
  ) |>
  arrange(ticker, metric_name)

firm_coverage <- operating_rows |>
  group_by(ticker, company, extraction_status) |>
  summarise(
    operating_rows_available = n(),
    first_operating_year = min(fiscal_year),
    last_operating_year = max(fiscal_year),
    orders_years_available = sum(!is.na(orders_units)),
    deliveries_years_available = sum(!is.na(deliveries_units)),
    backlog_years_available = sum(!is.na(backlog_units)),
    cancellation_rate_years_available = sum(!is.na(cancellation_rate_pct)),
    active_community_years_available = sum(!is.na(active_communities)),
    average_selling_price_years_available = sum(!is.na(average_selling_price_dollars)),
    homebuilding_revenue_years_available = sum(!is.na(homebuilding_revenue_thousands)),
    .groups = "drop"
  )

coverage <- bind_rows(
  core_firms,
  tibble(
    ticker = "WY",
    company = "Weyerhaeuser Real Estate Co.",
    land_years_available = 0L,
    first_land_year = NA_integer_,
    last_land_year = NA_integer_,
    core_land_sample = FALSE
  )
) |>
  left_join(firm_coverage, by = c("ticker", "company"), relationship = "one-to-one") |>
  mutate(
    extraction_status = coalesce(extraction_status, "not_started_firm_era_extraction"),
    operating_rows_available = coalesce(operating_rows_available, 0L),
    across(
      ends_with("_years_available"),
      ~ coalesce(as.integer(.x), 0L)
    ),
    mechanism_sample_role = case_when(
      core_land_sample ~ "core_land_share_mechanism_sample",
      ticker == "WY" ~ "supplemental_bust_operating_series_without_comparable_omega"
    ),
    programmatic_operating_extraction_complete = extraction_status == "programmatic_firm_era_audited",
    needs_programmatic_firm_era_extraction = core_land_sample & !programmatic_operating_extraction_complete,
    queue_group = case_when(
      ticker %in% c("DHI", "LEN", "PHM", "KBH", "HOV", "NVR") ~ 1L,
      ticker %in% c("BZH", "MHO", "MTH", "TOL", "MDC") ~ 2L,
      land_years_available >= 10 ~ 3L,
      TRUE ~ 4L
    ),
    queue_reason = case_when(
      ticker %in% c("DHI", "LEN", "PHM", "KBH", "HOV", "NVR") ~ "Programmatic 2006-2025 operating extraction complete and checked against the reviewed pilot values.",
      ticker %in% c("BZH", "MHO", "MTH", "TOL", "MDC") ~ "Long operating history and strong land-share coverage; highest-value expansion after the benchmark firms.",
      land_years_available >= 10 ~ "At least ten usable land-share years; extract operating tables by disclosure era.",
      core_land_sample ~ "Short public or pre-merger history; extract the full SEC-reporting window without splicing successors.",
      TRUE ~ "Programmatic operating extraction complete; omega remains unavailable because WRECO does not report a comparable owned-versus-optioned denominator."
    )
  ) |>
  arrange(desc(core_land_sample), queue_group, desc(land_years_available), ticker)

extraction_queue <- coverage |>
  filter(needs_programmatic_firm_era_extraction) |>
  mutate(queue_order = row_number()) |>
  select(
    queue_order,
    queue_group,
    ticker,
    company,
    land_years_available,
    first_land_year,
    last_land_year,
    extraction_status,
    operating_rows_available,
    queue_reason
  )

coverage_qc <- bind_rows(
  tibble(
    check = "core_land_sample_firms",
    status = if_else(sum(coverage$core_land_sample) == 33, "ok", "fail"),
    value = as.character(sum(coverage$core_land_sample)),
    detail = "Distinct firms with at least one main-eligible land-share observation during 2006-2025."
  ),
  tibble(
    check = "programmatic_firm_era_operating_extractions",
    status = if_else(sum(coverage$programmatic_operating_extraction_complete) == 7, "ok", "fail"),
    value = as.character(sum(coverage$programmatic_operating_extraction_complete)),
    detail = "The six pilot firms and supplemental WRECO series now have filing-driven firm-era operating extractors."
  ),
  tibble(
    check = "manual_pilot_firms_awaiting_programmatic_conversion",
    status = if_else(sum(coverage$extraction_status == "reviewed_manual_pilot_not_yet_programmatic") == 0, "ok", "fail"),
    value = as.character(sum(coverage$extraction_status == "reviewed_manual_pilot_not_yet_programmatic")),
    detail = "No pilot firm remains dependent on the manually assembled panel as its production source."
  ),
  tibble(
    check = "core_firms_awaiting_programmatic_extraction",
    status = if_else(sum(coverage$needs_programmatic_firm_era_extraction) == 27, "ok", "fail"),
    value = as.character(sum(coverage$needs_programmatic_firm_era_extraction)),
    detail = "Twenty-seven core land-share firms remain after completing the original six programmatic extractors."
  )
)

if (any(coverage_qc$status != "ok")) {
  stop("Builder operating coverage QC failed.")
}

write_csv_if_changed(coverage, "../output/builder_operating_extraction_coverage.csv")
write_csv_if_changed(metric_coverage, "../output/builder_operating_metric_coverage.csv")
write_csv_if_changed(extraction_queue, "../output/builder_operating_extraction_queue.csv")
write_csv_if_changed(coverage_qc, "../output/builder_operating_coverage_qc.csv")

cat("Wrote builder operating coverage audit outputs to ../output\n")
