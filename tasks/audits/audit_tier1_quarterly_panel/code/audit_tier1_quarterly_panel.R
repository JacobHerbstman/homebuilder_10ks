# setwd("/Users/jacobherbstman/Desktop/homebuilder_10ks/tasks/audits/audit_tier1_quarterly_panel/code")

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(tidyr)
})

source("../../../_lib/homebuilder_pipeline_utils.R")

panel <- read_csv(
  "../input/tier1_2018_2025_quarterly_panel.csv",
  show_col_types = FALSE,
  na = c("", "NA"),
  col_types = cols(cik10 = col_character(), operating_accession_number = col_character())
) |>
  mutate(source_report_date = as.Date(source_report_date))

annual <- read_csv(
  "../input/tier1_2018_2025_annual_operating_panel.csv",
  show_col_types = FALSE,
  na = c("", "NA"),
  col_types = cols(cik10 = col_character(), accession_number = col_character())
) |>
  filter(ticker != "MDC" | fiscal_year != 2024L)

coverage <- panel |>
  filter(public_equity_episode_indicator) |>
  group_by(ticker) |>
  summarise(
    expected_quarters = n(),
    source_filings = sum(!is.na(operating_accession_number)),
    orders_units = sum(!is.na(orders_units)),
    deliveries_units = sum(!is.na(deliveries_units)),
    backlog_units = sum(!is.na(backlog_units)),
    cancellation_rate_pct = sum(!is.na(cancellation_rate_pct)),
    active_communities = sum(!is.na(active_communities)),
    quarterly_omega = sum(quarterly_omega_observed),
    lagged_quarterly_omega = sum(lagged_quarterly_omega_observed),
    joint_lagged_quarterly_omega_and_operating = sum(lagged_quarterly_omega_observed & operating_data_observed),
    lagged_annual_omega = sum(!is.na(lagged_annual_omega_nonowned_controlled_share)),
    .groups = "drop"
  ) |>
  pivot_longer(
    cols = -c(ticker, expected_quarters),
    names_to = "metric",
    values_to = "actual_value"
  ) |>
  transmute(
    audit_type = "firm_coverage",
    ticker,
    fiscal_year = NA_integer_,
    metric,
    expected_value = if_else(
      metric %in% c("source_filings", "orders_units", "deliveries_units", "backlog_units"),
      as.numeric(expected_quarters),
      NA_real_
    ),
    actual_value = as.numeric(actual_value),
    difference = actual_value - expected_value,
    pass = is.na(expected_value) | actual_value == expected_value,
    detail = "Core operating fields must cover every reviewed public-equity quarter. Other fields report disclosure coverage without imposing a target."
  )

expected_quarters <- tribble(
  ~ticker, ~report_date, ~orders_units, ~deliveries_units, ~backlog_units,
  "BZH", as.Date("2024-03-31"), 1299, 1044, 2046,
  "MHO", as.Date("2024-03-31"), 2547, 2158, 3391,
  "MTH", as.Date("2024-03-31"), 3991, 3507, 3033,
  "TOL", as.Date("2024-01-31"), 2042, 1927, 6693,
  "MDC", as.Date("2024-03-31"), 2470, 2395, 1965,
  "HOV", as.Date("2018-01-31"), 1027, 1025, 2004,
  "HOV", as.Date("2025-01-31"), 1205, 1254, 1598,
  "LEN", as.Date("2024-02-29"), 18176, 16798, 16270,
  "DFH", as.Date("2021-03-31"), 2010, 1002, 3612,
  "SDHC", as.Date("2024-03-31"), 765, 566, 1110,
  "TPH", as.Date("2020-06-30"), 1332, 1229, 2558,
  "UHG", as.Date("2023-06-30"), 341, 385, 293,
  "LSEA", as.Date("2021-03-31"), 426, 301, 875
) |>
  pivot_longer(
    cols = c(orders_units, deliveries_units, backlog_units),
    names_to = "metric",
    values_to = "expected_value"
  )

benchmarks <- panel |>
  select(ticker, fiscal_year, report_date = source_report_date, operating_accession_number, orders_units, deliveries_units, backlog_units) |>
  pivot_longer(
    cols = c(orders_units, deliveries_units, backlog_units),
    names_to = "metric",
    values_to = "actual_value"
  ) |>
  inner_join(expected_quarters, by = c("ticker", "report_date", "metric"), relationship = "one-to-one") |>
  transmute(
    audit_type = "hand_read_quarter",
    ticker,
    fiscal_year,
    metric,
    expected_value,
    actual_value,
    difference = actual_value - expected_value,
    pass = !is.na(actual_value) & difference == 0,
    detail = paste("Value checked against SEC accession", operating_accession_number)
  )

quarterly_years <- panel |>
  filter(public_equity_episode_indicator, !is.na(fiscal_year)) |>
  group_by(ticker, fiscal_year) |>
  summarise(
    quarter_rows = n(),
    order_quarters = sum(!is.na(orders_units)),
    delivery_quarters = sum(!is.na(deliveries_units)),
    quarterly_orders = if_else(order_quarters == 4L, sum(orders_units), NA_real_),
    quarterly_deliveries = if_else(delivery_quarters == 4L, sum(deliveries_units), NA_real_),
    fourth_quarter_backlog = backlog_units[fiscal_quarter == 4L][1],
    .groups = "drop"
  )

reconciliation <- annual |>
  filter(!(ticker %in% c("DHI", "BZH") & fiscal_year == 2018L)) |>
  select(ticker, fiscal_year, orders_units, deliveries_units, backlog_units) |>
  left_join(quarterly_years, by = c("ticker", "fiscal_year"), relationship = "one-to-one") |>
  pivot_longer(
    cols = c(orders_units, deliveries_units, backlog_units, quarterly_orders, quarterly_deliveries, fourth_quarter_backlog),
    names_to = "field",
    values_to = "value"
  ) |>
  mutate(
    metric = case_when(
      field %in% c("orders_units", "quarterly_orders") ~ "annual_orders_equal_quarter_sum",
      field %in% c("deliveries_units", "quarterly_deliveries") ~ "annual_deliveries_equal_quarter_sum",
      TRUE ~ "annual_backlog_equal_fiscal_q4_stock"
    ),
    value_type = case_when(
      field %in% c("orders_units", "deliveries_units", "backlog_units") ~ "expected",
      TRUE ~ "actual"
    )
  ) |>
  select(ticker, fiscal_year, metric, value_type, value) |>
  pivot_wider(names_from = value_type, values_from = value) |>
  transmute(
    audit_type = "annual_quarter_reconciliation",
    ticker,
    fiscal_year,
    metric,
    expected_value = expected,
    actual_value = actual,
    difference = actual - expected,
    pass = !is.na(actual) & abs(difference) <= 1,
    detail = "Quarterly flows sum to the audited fiscal-year 10-K total; fiscal-Q4 backlog equals the year-end stock."
  )

structural <- tibble(
  audit_type = "structural",
  ticker = NA_character_,
  fiscal_year = NA_integer_,
  metric = c(
    "balanced_rows",
    "unique_firm_calendar_quarter",
    "tier1_firms",
    "public_equity_quarters",
    "operating_rows_outside_public_equity_episode",
    "land_rows_outside_public_equity_episode",
    "missing_core_operating_cells",
    "negative_order_or_delivery_flows",
    "derived_fiscal_q4_rows"
  ),
  expected_value = c(640, 640, 20, 562, 0, 0, 0, 0, 140),
  actual_value = c(
    nrow(panel),
    n_distinct(paste(panel$ticker, panel$calendar_year, panel$calendar_quarter)),
    n_distinct(panel$ticker),
    sum(panel$public_equity_episode_indicator),
    sum(!panel$public_equity_episode_indicator & !is.na(panel$operating_accession_number)),
    sum(!panel$public_equity_episode_indicator & panel$quarterly_omega_observed),
    panel |>
      filter(public_equity_episode_indicator) |>
      summarise(n = sum(is.na(orders_units)) + sum(is.na(deliveries_units)) + sum(is.na(backlog_units))) |>
      pull(n),
    panel |>
      filter(public_equity_episode_indicator) |>
      summarise(n = sum(orders_units < 0, na.rm = TRUE) + sum(deliveries_units < 0, na.rm = TRUE)) |>
      pull(n),
    sum(panel$quarterly_value_method == "fiscal_year_total_less_first_three_quarters", na.rm = TRUE)
  ),
  detail = c(
    "Twenty firms by 32 calendar quarters.",
    "One row per firm and calendar quarter.",
    "Reviewed Tier-1 universe.",
    "Quarterly public-equity episodes after exact MDC and Landsea acquisition dates.",
    "No extracted operating row survives after a reviewed exit.",
    "No extracted land-control share survives after a reviewed exit.",
    "Orders, deliveries, and backlog are present in every reviewed public-equity quarter.",
    "Quarter-flow derivations cannot produce negative unit counts.",
    "Fiscal Q4 flows are derived once from annual totals and the first three fiscal quarters."
  )
) |>
  mutate(
    difference = actual_value - expected_value,
    pass = actual_value == expected_value
  ) |>
  select(audit_type, ticker, fiscal_year, metric, expected_value, actual_value, difference, pass, detail)

audit <- bind_rows(structural, coverage, benchmarks, reconciliation) |>
  arrange(audit_type, ticker, fiscal_year, metric)

if (any(!audit$pass)) {
  stop("At least one Tier-1 quarterly panel audit failed.")
}

write_csv_if_changed(audit, "../output/tier1_quarterly_panel_audit.csv")

cat("Wrote Tier-1 quarterly panel audit to ../output\n")
