# setwd("/Users/jacobherbstman/Desktop/homebuilder_10ks/tasks/build_tier1_annual_operating_panel/code")

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
})

source("../../_lib/homebuilder_pipeline_utils.R")

six_firm <- read_csv(
  "../input/six_firm_2006_2025_operating_panel.csv",
  show_col_types = FALSE,
  col_types = cols(cik10 = col_character(), accession_number = col_character())
) |>
  filter(fiscal_year %in% 2018:2025) |>
  transmute(
    ticker, company, cik10, fiscal_year, report_date, filing_date, accession_number,
    orders_units, orders_value_thousands, orders_raw_label,
    deliveries_units, deliveries_value_thousands, deliveries_raw_label,
    backlog_units, backlog_value_thousands, cancellation_rate_pct,
    active_communities, average_community_count, average_selling_price_dollars,
    homebuilding_revenue_thousands, source_scope, extraction_method,
    filing_url, source_local_path, source_checksum_sha256,
    source_task = "extract_six_firm_annual_operating_disclosures"
  )

five_firm <- read_csv(
  "../input/five_firm_2006_2025_annual_operating_panel.csv",
  show_col_types = FALSE,
  col_types = cols(cik10 = col_character(), accession_number = col_character())
) |>
  filter(fiscal_year %in% 2018:2025) |>
  transmute(
    ticker, company, cik10, fiscal_year, report_date, filing_date, accession_number,
    orders_units, orders_value_thousands, orders_raw_label,
    deliveries_units, deliveries_value_thousands, deliveries_raw_label,
    backlog_units, backlog_value_thousands, cancellation_rate_pct,
    active_communities, average_community_count, average_selling_price_dollars,
    homebuilding_revenue_thousands, source_scope, extraction_method,
    filing_url, source_local_path, source_checksum_sha256,
    source_task = "extract_five_firm_annual_operating_disclosures"
  )

nine_firm <- read_csv(
  "../input/nine_firm_2018_2025_annual_operating_panel.csv",
  show_col_types = FALSE,
  col_types = cols(cik10 = col_character(), accession_number = col_character())
) |>
  transmute(
    ticker, company, cik10, fiscal_year, report_date, filing_date, accession_number,
    orders_units, orders_value_thousands,
    orders_raw_label = "Net new orders or firm-equivalent net contracts",
    deliveries_units, deliveries_value_thousands,
    deliveries_raw_label = "Home closings or homes delivered",
    backlog_units, backlog_value_thousands, cancellation_rate_pct,
    active_communities, average_community_count, average_selling_price_dollars,
    homebuilding_revenue_thousands = deliveries_value_thousands,
    source_scope = "Consolidated homebuilding",
    extraction_method, filing_url, source_local_path, source_checksum_sha256,
    source_task = "extract_nine_firm_annual_operating_disclosures"
  )

panel <- bind_rows(six_firm, five_firm, nine_firm) |>
  mutate(
    fiscal_year = as.integer(fiscal_year),
    report_date = as.Date(report_date),
    filing_date = as.Date(filing_date)
  ) |>
  arrange(ticker, fiscal_year)

if (nrow(panel) != 141 || n_distinct(panel$ticker) != 20) {
  stop("Expected 141 public firm-years for the 20 Tier-1 builders in 2018-2025.")
}

if (panel |> count(ticker, fiscal_year) |> filter(n != 1) |> nrow() > 0) {
  stop("Tier-1 annual operating panel must be unique by ticker and fiscal year.")
}

if (panel |> filter(is.na(orders_units) | is.na(deliveries_units) | is.na(backlog_units)) |> nrow() > 0) {
  stop("Tier-1 annual operating panel has a missing core operating count.")
}

write_csv_if_changed(panel, "../output/tier1_2018_2025_annual_operating_panel.csv")

cat("Wrote Tier-1 annual operating panel to ../output\n")
