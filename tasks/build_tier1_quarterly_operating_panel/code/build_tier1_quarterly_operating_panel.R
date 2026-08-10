# setwd("/Users/jacobherbstman/Desktop/homebuilder_10ks/tasks/build_tier1_quarterly_operating_panel/code")

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
})

source("../../_lib/homebuilder_pipeline_utils.R")

six_firm <- read_csv(
  "../input/six_firm_2018_2025_quarterly_operating_disclosures.csv",
  show_col_types = FALSE,
  na = c("", "NA"),
  col_types = cols(cik10 = col_character(), accession_number = col_character())
) |>
  mutate(
    report_date = as.Date(report_date),
    filing_date = as.Date(filing_date),
    average_community_count = NA_real_,
    average_selling_price_dollars = deliveries_value_thousands * 1000 / deliveries_units
  )

five_firm <- read_csv(
  "../input/five_firm_2018_2025_quarterly_operating_disclosures.csv",
  show_col_types = FALSE,
  na = c("", "NA"),
  col_types = cols(cik10 = col_character(), accession_number = col_character())
) |>
  mutate(
    report_date = as.Date(report_date),
    filing_date = as.Date(filing_date),
    deposit_writeoffs_thousands = NA_real_,
    deposit_writeoffs_ytd_thousands = NA_real_,
    deposit_writeoffs_extraction_method = NA_character_,
    deposit_writeoffs_context_snippet = NA_character_
  )

nine_firm <- read_csv(
  "../input/nine_firm_2018_2025_quarterly_operating_disclosures.csv",
  show_col_types = FALSE,
  na = c("", "NA"),
  col_types = cols(cik10 = col_character(), accession_number = col_character())
) |>
  mutate(
    report_date = as.Date(report_date),
    filing_date = as.Date(filing_date),
    deposit_writeoffs_thousands = NA_real_,
    deposit_writeoffs_ytd_thousands = NA_real_,
    deposit_writeoffs_extraction_method = NA_character_,
    deposit_writeoffs_context_snippet = NA_character_
  )

interim <- bind_rows(six_firm, five_firm, nine_firm) |>
  arrange(ticker, fiscal_year, fiscal_quarter) |>
  group_by(ticker, fiscal_year) |>
  mutate(
    orders_units = case_when(
      orders_period_basis == "fiscal_ytd" & fiscal_quarter == 1L ~ orders_units,
      orders_period_basis == "fiscal_ytd" & lag(fiscal_quarter) == fiscal_quarter - 1L ~ orders_units - lag(orders_units),
      orders_period_basis == "current_quarter" ~ orders_units,
      TRUE ~ NA_real_
    ),
    orders_value_thousands = case_when(
      orders_period_basis == "fiscal_ytd" & fiscal_quarter == 1L ~ orders_value_thousands,
      orders_period_basis == "fiscal_ytd" & lag(fiscal_quarter) == fiscal_quarter - 1L ~ orders_value_thousands - lag(orders_value_thousands),
      orders_period_basis == "current_quarter" ~ orders_value_thousands,
      TRUE ~ NA_real_
    ),
    deliveries_units = case_when(
      deliveries_period_basis == "fiscal_ytd" & fiscal_quarter == 1L ~ deliveries_units,
      deliveries_period_basis == "fiscal_ytd" & lag(fiscal_quarter) == fiscal_quarter - 1L ~ deliveries_units - lag(deliveries_units),
      deliveries_period_basis == "current_quarter" ~ deliveries_units,
      TRUE ~ NA_real_
    ),
    deliveries_value_thousands = case_when(
      deliveries_period_basis == "fiscal_ytd" & fiscal_quarter == 1L ~ deliveries_value_thousands,
      deliveries_period_basis == "fiscal_ytd" & lag(fiscal_quarter) == fiscal_quarter - 1L ~ deliveries_value_thousands - lag(deliveries_value_thousands),
      deliveries_period_basis == "current_quarter" ~ deliveries_value_thousands,
      TRUE ~ NA_real_
    ),
    quarterly_value_method = if_else(
      orders_period_basis == "fiscal_ytd" | deliveries_period_basis == "fiscal_ytd",
      "fiscal_ytd_less_prior_ytd",
      "reported_three_month"
    )
  ) |>
  ungroup()

first_three_quarters <- interim |>
  filter(fiscal_quarter %in% 1:3) |>
  group_by(ticker, fiscal_year) |>
  summarise(
    interim_quarters = n(),
    complete_order_quarters = sum(!is.na(orders_units)),
    complete_order_value_quarters = sum(!is.na(orders_value_thousands)),
    complete_delivery_quarters = sum(!is.na(deliveries_units)),
    complete_delivery_value_quarters = sum(!is.na(deliveries_value_thousands)),
    first_three_quarter_orders = if_else(complete_order_quarters == 3L, sum(orders_units), NA_real_),
    first_three_quarter_order_value = if_else(complete_order_value_quarters == 3L, sum(orders_value_thousands), NA_real_),
    first_three_quarter_deliveries = if_else(complete_delivery_quarters == 3L, sum(deliveries_units), NA_real_),
    first_three_quarter_delivery_value = if_else(complete_delivery_value_quarters == 3L, sum(deliveries_value_thousands), NA_real_),
    quarterly_component_accessions = paste(accession_number[order(fiscal_quarter)], collapse = " | "),
    .groups = "drop"
  )

annual <- read_csv(
  "../input/tier1_2018_2025_annual_operating_panel.csv",
  show_col_types = FALSE,
  na = c("", "NA"),
  col_types = cols(cik10 = col_character(), accession_number = col_character())
) |>
  filter(
    ticker != "MDC" | fiscal_year <= 2023L,
    ticker != "LSEA" | fiscal_year <= 2024L
  ) |>
  mutate(
    report_date = as.Date(report_date),
    filing_date = as.Date(filing_date)
  )

fourth_quarters <- annual |>
  left_join(first_three_quarters, by = c("ticker", "fiscal_year"), relationship = "one-to-one") |>
  transmute(
    ticker, company, cik10,
    calendar_year = as.integer(format(report_date, "%Y")),
    calendar_quarter = ((as.integer(format(report_date, "%m")) - 1L) %/% 3L) + 1L,
    calendar_quarter_label = paste0(calendar_year, "Q", calendar_quarter),
    fiscal_year, fiscal_quarter = 4L, form = "10-K", filing_date, report_date,
    accession_number,
    orders_units = if_else(interim_quarters == 3L, orders_units - first_three_quarter_orders, NA_real_),
    orders_value_thousands = if_else(interim_quarters == 3L, orders_value_thousands - first_three_quarter_order_value, NA_real_),
    orders_period_basis = "derived_current_quarter",
    deliveries_units = if_else(interim_quarters == 3L, deliveries_units - first_three_quarter_deliveries, NA_real_),
    deliveries_value_thousands = if_else(interim_quarters == 3L, deliveries_value_thousands - first_three_quarter_delivery_value, NA_real_),
    deliveries_period_basis = "derived_current_quarter",
    backlog_units, backlog_value_thousands, cancellation_rate_pct = NA_real_,
    active_communities, average_community_count,
    average_selling_price_dollars = deliveries_value_thousands * 1000 / deliveries_units,
    deposit_writeoffs_thousands = NA_real_,
    deposit_writeoffs_ytd_thousands = NA_real_,
    deposit_writeoffs_extraction_method = NA_character_,
    deposit_writeoffs_context_snippet = NA_character_,
    operating_extraction_method = "fiscal_year_total_less_first_three_quarters",
    operating_context_snippet = NA_character_,
    quarterly_value_method = "fiscal_year_total_less_first_three_quarters",
    quarterly_component_accessions = paste(accession_number, quarterly_component_accessions, sep = " | "),
    filing_url, source_local_path, source_checksum_sha256
  )

interim <- interim |>
  filter(report_date >= as.Date("2018-01-01")) |>
  mutate(quarterly_component_accessions = accession_number) |>
  select(names(fourth_quarters))

panel <- bind_rows(interim, fourth_quarters) |>
  arrange(ticker, calendar_year, calendar_quarter)

if (nrow(panel) != 562 || n_distinct(panel$ticker) != 20) {
  stop("Expected 562 quarterly operating rows in the reviewed Tier-1 public-equity episodes.")
}

if (panel |> count(ticker, calendar_year, calendar_quarter) |> filter(n != 1) |> nrow() > 0) {
  stop("Tier-1 quarterly operating panel is not unique by firm and calendar quarter.")
}

if (
  panel |> filter(is.na(orders_units) | is.na(deliveries_units) | is.na(backlog_units)) |> nrow() > 0 ||
  panel |> filter(orders_units < 0 | deliveries_units < 0) |> nrow() > 0
) {
  stop("Tier-1 quarterly operating panel contains missing core values or negative flows.")
}

write_csv_if_changed(panel, "../output/tier1_2018_2025_quarterly_operating_panel.csv")

cat("Wrote Tier-1 quarterly operating panel to ../output\n")
