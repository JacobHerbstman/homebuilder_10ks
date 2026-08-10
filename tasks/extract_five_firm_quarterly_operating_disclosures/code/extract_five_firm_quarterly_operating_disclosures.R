# setwd("/Users/jacobherbstman/Desktop/homebuilder_10ks/tasks/extract_five_firm_quarterly_operating_disclosures/code")

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(rvest)
  library(stringr)
  library(tibble)
})

source("../../_lib/homebuilder_pipeline_utils.R")

inventory <- read_csv("../input/tier1_2018_2025_sec_10q_download_inventory.csv", show_col_types = FALSE) |>
  filter(
    ticker %in% c("BZH", "MHO", "MTH", "TOL", "MDC"),
    form == "10-Q",
    primary_document_status %in% c("downloaded", "already_present"),
    selected_for_panel | fiscal_q4_derivation_lookback_flag,
    ticker != "MDC" | report_date <= as.Date("2024-03-31")
  ) |>
  mutate(
    filing_date = as.Date(filing_date),
    report_date = as.Date(report_date),
    fiscal_year = case_when(
      ticker == "BZH" & as.integer(format(report_date, "%m")) == 12L ~ as.integer(format(report_date, "%Y")) + 1L,
      TRUE ~ as.integer(format(report_date, "%Y"))
    ),
    fiscal_quarter = case_when(
      ticker == "BZH" & as.integer(format(report_date, "%m")) == 12L ~ 1L,
      ticker == "BZH" & as.integer(format(report_date, "%m")) == 3L ~ 2L,
      ticker == "BZH" & as.integer(format(report_date, "%m")) == 6L ~ 3L,
      ticker == "TOL" & as.integer(format(report_date, "%m")) == 1L ~ 1L,
      ticker == "TOL" & as.integer(format(report_date, "%m")) == 4L ~ 2L,
      ticker == "TOL" & as.integer(format(report_date, "%m")) == 7L ~ 3L,
      as.integer(format(report_date, "%m")) == 3L ~ 1L,
      as.integer(format(report_date, "%m")) == 6L ~ 2L,
      as.integer(format(report_date, "%m")) == 9L ~ 3L
    ),
    primary_document_local_path = source_local_path,
    primary_document_checksum_sha256 = source_checksum_sha256
  ) |>
  arrange(ticker, fiscal_year, fiscal_quarter, filing_date)

if (inventory |> count(ticker, fiscal_year, fiscal_quarter) |> filter(n != 1) |> nrow() > 0) {
  stop("Original 10-Q rows are not unique by firm and fiscal quarter.")
}

rows <- vector("list", nrow(inventory))

for (i in seq_len(nrow(inventory))) {
  filing <- inventory[i, ]
  filing_html <- read_html(filing$primary_document_local_path)
  table_text <- html_elements(filing_html, "table") |>
    lapply(html_text2) |>
    unlist() |>
    str_squish()

  orders_units <- NA_real_
  orders_value_thousands <- NA_real_
  deliveries_units <- NA_real_
  deliveries_value_thousands <- NA_real_
  backlog_units <- NA_real_
  backlog_value_thousands <- NA_real_
  cancellation_rate_pct <- NA_real_
  active_communities <- NA_real_
  average_community_count <- NA_real_
  average_selling_price_dollars <- NA_real_
  source_table_text <- NA_character_
  extraction_method <- NA_character_

  if (filing$ticker == "BZH") {
    orders_index <- which(str_detect(table_text, regex("Three Months Ended.*New Orders,? net", ignore_case = TRUE)))
    closings_index <- which(str_detect(table_text, regex("Three Months Ended.*Homebuilding Revenue.*Closings", ignore_case = TRUE)))
    backlog_index <- which(str_detect(table_text, regex("Backlog Units|Units in Backlog", ignore_case = TRUE)))

    orders_text <- table_text[orders_index[1]]
    closings_text <- table_text[closings_index[1]]
    backlog_text <- table_text[backlog_index[1]]
    orders_units <- parse_number(str_match(orders_text, regex("Total\\s+([0-9,]+)", ignore_case = TRUE))[, 2])
    cancellation_rate_pct <- parse_number(str_match(orders_text, regex("Total\\s+[0-9,]+.*?([0-9.]+)\\s*%", ignore_case = TRUE))[, 2])
    closings_section <- str_extract(closings_text, regex("Closings.*", ignore_case = TRUE))
    deliveries_units <- parse_number(
      str_match(closings_section, regex("Total.*?%.*?%\\s+([0-9,]+)\\s+[0-9,]+", ignore_case = TRUE))[, 2]
    )
    backlog_units <- parse_number(str_match(backlog_text, regex("Total\\s+([0-9,]+)", ignore_case = TRUE))[, 2])
    backlog_value_thousands <- 1000 * parse_number(str_match(backlog_text, regex("Aggregate dollar value.*?\\$\\s*([0-9,.]+)", ignore_case = TRUE))[, 2])
    if (is.na(backlog_units)) {
      filing_text <- str_squish(html_text2(filing_html))
      backlog_units <- parse_number(str_match(filing_text, regex("Backlog Units:.*?Total\\s*([0-9,]+)", ignore_case = TRUE))[, 2])
      backlog_value_thousands <- 1000 * parse_number(str_match(filing_text, regex("Backlog Units:.*?Aggregate dollar value.*?\\$\\s*([0-9,.]+)", ignore_case = TRUE))[, 2])
    }
    source_table_text <- paste(orders_text, closings_text, backlog_text, sep = " || ")
    extraction_method <- "bzh_three_month_total_tables"
  }

  if (filing$ticker == "MHO") {
    operating_index <- which(
      str_detect(table_text, regex("Three Months Ended", ignore_case = TRUE)) &
        str_detect(table_text, fixed("Total Homebuilding Regions", ignore_case = TRUE)) &
        str_detect(table_text, fixed("New contracts, net", ignore_case = TRUE))
    )
    operating_text <- table_text[operating_index[1]]
    total_text <- str_extract(operating_text, regex("Total Homebuilding Regions.*", ignore_case = TRUE))
    deliveries_units <- parse_number(str_match(total_text, regex("Homes delivered\\s+([0-9,]+)", ignore_case = TRUE))[, 2])
    orders_units <- parse_number(str_match(total_text, regex("New contracts, net\\s+([0-9,]+)", ignore_case = TRUE))[, 2])
    backlog_units <- parse_number(str_match(total_text, regex("Backlog at end of period\\s+([0-9,]+)", ignore_case = TRUE))[, 2])
    average_selling_price_dollars <- 1000 * parse_number(str_match(total_text, regex("Average sales price of homes delivered\\s+\\$\\s*([0-9,.]+)", ignore_case = TRUE))[, 2])
    backlog_value_thousands <- parse_number(str_match(total_text, regex("Aggregate sales value of homes in backlog\\s+\\$\\s*([0-9,]+)", ignore_case = TRUE))[, 2])
    deliveries_value_thousands <- parse_number(str_match(total_text, regex("Housing revenue\\s+\\$\\s*([0-9,]+)", ignore_case = TRUE))[, 2])
    average_community_count <- parse_number(str_match(total_text, regex("Number of average active communities\\s+([0-9,]+)", ignore_case = TRUE))[, 2])
    active_communities <- parse_number(str_match(total_text, regex("Number of active communities, end of period\\s+([0-9,]+)", ignore_case = TRUE))[, 2])
    source_table_text <- operating_text
    extraction_method <- "mho_three_month_total_homebuilding_regions"
  }

  if (filing$ticker == "MTH") {
    closing_index <- which(
      str_detect(table_text, regex("Home Closing Revenue", ignore_case = TRUE)) &
        str_detect(table_text, regex("Three Months Ended", ignore_case = TRUE)) &
        str_detect(table_text, regex("Homes closed", ignore_case = TRUE))
    )
    orders_index <- which(
      str_detect(table_text, regex("Home Orders", ignore_case = TRUE)) &
        str_detect(table_text, regex("Three Months Ended", ignore_case = TRUE))
    )
    backlog_index <- which(str_detect(table_text, regex("Order Backlog.*Homes in backlog", ignore_case = TRUE)))
    closing_text <- table_text[closing_index[1]]
    orders_text <- table_text[orders_index[1]]
    backlog_text <- table_text[backlog_index[1]]
    deliveries_value_thousands <- parse_number(str_match(closing_text, regex("Total Dollars\\s+\\$\\s*([0-9,]+)", ignore_case = TRUE))[, 2])
    deliveries_units <- parse_number(str_match(closing_text, regex("Homes closed\\s+([0-9,]+)", ignore_case = TRUE))[, 2])
    average_selling_price_dollars <- 1000 * parse_number(str_match(closing_text, regex("Average sales price\\s+\\$\\s*([0-9,.]+)", ignore_case = TRUE))[, 2])
    orders_value_thousands <- parse_number(str_match(orders_text, regex("Total Dollars\\s+\\$\\s*([0-9,]+)", ignore_case = TRUE))[, 2])
    orders_units <- parse_number(str_match(orders_text, regex("Homes ordered\\s+([0-9,]+)", ignore_case = TRUE))[, 2])
    backlog_value_thousands <- parse_number(str_match(backlog_text, regex("Total Dollars\\s+\\$\\s*([0-9,]+)", ignore_case = TRUE))[, 2])
    backlog_units <- parse_number(str_match(backlog_text, regex("Homes in backlog\\s+([0-9,]+)", ignore_case = TRUE))[, 2])
    source_table_text <- paste(closing_text, orders_text, backlog_text, sep = " || ")
    extraction_method <- "mth_three_month_total_tables"
  }

  if (filing$ticker == "TOL") {
    operating_index <- which(
      str_detect(table_text, regex("Three months ended", ignore_case = TRUE)) &
        str_detect(table_text, regex("Deliveries.*units", ignore_case = TRUE)) &
        str_detect(table_text, regex("Net contracts signed.*units", ignore_case = TRUE)) &
        str_detect(table_text, regex("Backlog.*units", ignore_case = TRUE))
    )
    operating_text <- table_text[operating_index[1]]
    deliveries_units <- parse_number(str_match(operating_text, regex("Deliveries[^0-9]*units\\s+([0-9,]+)", ignore_case = TRUE))[, 2])
    average_selling_price_dollars <- 1000 * parse_number(str_match(operating_text, regex("Deliveries.*?average.*?\\$\\s*([0-9,.]+)", ignore_case = TRUE))[, 2])
    orders_units <- parse_number(str_match(operating_text, regex("Net contracts signed[^0-9]*units\\s+([0-9,]+)", ignore_case = TRUE))[, 2])
    orders_value_thousands <- 1000 * parse_number(str_match(operating_text, regex("Net contracts signed[^0-9]*value\\s+\\$\\s*([0-9,.]+)", ignore_case = TRUE))[, 2])
    backlog_units <- parse_number(str_match(operating_text, regex("Backlog[^0-9]*units\\s+([0-9,]+)", ignore_case = TRUE))[, 2])
    backlog_value_thousands <- 1000 * parse_number(str_match(operating_text, regex("Backlog[^0-9]*value\\s+\\$\\s*([0-9,.]+)", ignore_case = TRUE))[, 2])
    source_table_text <- operating_text
    extraction_method <- if_else(
      str_detect(operating_text, regex("^Three months ended", ignore_case = TRUE)),
      "tol_three_month_supplemental_table",
      "tol_year_to_date_supplemental_table"
    )
  }

  if (filing$ticker == "MDC") {
    filing_text <- str_squish(html_text2(filing_html))
    orders_sections <- str_extract_all(filing_text, regex("Net New Orders and Active Subdivisions:.*?For the three months", ignore_case = TRUE))[[1]]
    deliveries_sections <- str_extract_all(filing_text, regex("New Home Deliveries & Home Sale Revenues:.*?For the three months", ignore_case = TRUE))[[1]]
    backlog_sections <- str_extract_all(filing_text, regex("Backlog:.*?At .*?we had", ignore_case = TRUE))[[1]]
    orders_text <- orders_sections[length(orders_sections)]
    deliveries_text <- deliveries_sections[length(deliveries_sections)]
    backlog_text <- backlog_sections[length(backlog_sections)]
    orders_match <- str_match(orders_text, regex("Total\\s+([0-9,]+)\\s+\\$\\s*([0-9,]+)\\s+\\$\\s*([0-9,.]+)", ignore_case = TRUE))
    deliveries_match <- str_match(deliveries_text, regex("Total\\s+([0-9,]+)\\s+\\$\\s*([0-9,]+)\\s+\\$\\s*([0-9,.]+)", ignore_case = TRUE))
    backlog_match <- str_match(backlog_text, regex("Total\\s+([0-9,]+)\\s+\\$\\s*([0-9,]+)\\s+\\$\\s*([0-9,.]+)", ignore_case = TRUE))
    orders_units <- parse_number(orders_match[, 2])
    orders_value_thousands <- parse_number(orders_match[, 3])
    deliveries_units <- parse_number(deliveries_match[, 2])
    deliveries_value_thousands <- parse_number(deliveries_match[, 3])
    average_selling_price_dollars <- 1000 * parse_number(deliveries_match[, 4])
    backlog_units <- parse_number(backlog_match[, 2])
    backlog_value_thousands <- parse_number(backlog_match[, 3])
    source_table_text <- paste(orders_text, deliveries_text, backlog_text, sep = " || ")
    extraction_method <- "mdc_three_month_mda_total_sections"
  }

  rows[[i]] <- tibble(
    ticker = filing$ticker,
    company = filing$company,
    cik10 = filing$cik10,
    fiscal_year = filing$fiscal_year,
    fiscal_quarter = filing$fiscal_quarter,
    report_date = filing$report_date,
    calendar_year = as.integer(format(filing$report_date, "%Y")),
    calendar_quarter = ((as.integer(format(filing$report_date, "%m")) - 1L) %/% 3L) + 1L,
    calendar_quarter_label = paste0(calendar_year, "Q", calendar_quarter),
    filing_date = filing$filing_date,
    accession_number = filing$accession_number,
    form = filing$form,
    orders_units,
    orders_value_thousands,
    orders_period_basis = if_else(extraction_method == "tol_year_to_date_supplemental_table", "fiscal_ytd", "current_quarter"),
    deliveries_units,
    deliveries_value_thousands,
    deliveries_period_basis = if_else(extraction_method == "tol_year_to_date_supplemental_table", "fiscal_ytd", "current_quarter"),
    backlog_units,
    backlog_value_thousands,
    cancellation_rate_pct,
    active_communities,
    average_community_count,
    average_selling_price_dollars,
    operating_extraction_method = extraction_method,
    filing_url = filing$filing_url,
    source_local_path = filing$primary_document_local_path,
    source_checksum_sha256 = filing$primary_document_checksum_sha256,
    operating_context_snippet = source_table_text
  )
}

disclosures <- bind_rows(rows) |>
  arrange(ticker, report_date, fiscal_quarter)

if (
  nrow(disclosures) != 116 ||
  disclosures |> count(ticker, fiscal_year, fiscal_quarter) |> filter(n != 1) |> nrow() > 0 ||
  disclosures |> filter(is.na(orders_units) | is.na(deliveries_units) | is.na(backlog_units)) |> nrow() > 0
) {
  stop("Expected 116 unique five-firm 10-Q disclosure rows, including the BZH fiscal-2018 lookback quarter.")
}

write_csv_if_changed(disclosures, "../output/five_firm_2018_2025_quarterly_operating_disclosures.csv")

cat("Wrote five-firm quarterly operating disclosures to ../output\n")
