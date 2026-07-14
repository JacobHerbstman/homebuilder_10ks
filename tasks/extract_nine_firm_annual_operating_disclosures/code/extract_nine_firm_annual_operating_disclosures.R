# setwd("/Users/jacobherbstman/Desktop/homebuilder_10ks/tasks/extract_nine_firm_annual_operating_disclosures/code")

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(rvest)
  library(stringr)
  library(tibble)
})

source("../../_lib/homebuilder_pipeline_utils.R")

inventory <- read_csv("../input/sec_10k_download_inventory.csv", show_col_types = FALSE) |>
  filter(
    ticker %in% c("TMHC", "TPH", "CCS", "LGIH", "GRBK", "DFH", "SDHC", "UHG", "LSEA"),
    form == "10-K",
    fiscal_year %in% 2018:2025,
    ticker != "DFH" | fiscal_year >= 2021,
    ticker != "SDHC" | fiscal_year >= 2024,
    ticker != "UHG" | fiscal_year >= 2023,
    ticker != "LSEA" | fiscal_year >= 2021 & fiscal_year <= 2024
  ) |>
  mutate(report_date = as.Date(report_date), filing_date = as.Date(filing_date)) |>
  arrange(ticker, fiscal_year)

if (nrow(inventory) != 54 || inventory |> count(ticker, fiscal_year) |> filter(n != 1) |> nrow() > 0) {
  stop("Expected 54 unique annual filings in the nine public-firm episodes.")
}

rows <- vector("list", nrow(inventory))

for (i in seq_len(nrow(inventory))) {
  filing <- inventory[i, ]
  filing_html <- read_html(filing$primary_document_local_path)
  filing_text <- str_squish(html_text2(filing_html))
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

  if (filing$ticker == "TMHC") {
    orders_index <- which(str_detect(table_text, regex("Net Sales Orders.*Sales Value.*Average Selling Price", ignore_case = TRUE)))
    deliveries_index <- which(
      str_detect(table_text, regex("Homes Closed", ignore_case = TRUE)) &
        str_detect(table_text, regex("Home Closings Revenue", ignore_case = TRUE))
    )
    backlog_index <- which(str_detect(table_text, regex("Sold Homes in Backlog.*Sales Value", ignore_case = TRUE)))
    orders_text <- table_text[orders_index[1]]
    deliveries_text <- table_text[deliveries_index[1]]
    backlog_text <- table_text[backlog_index[1]]
    orders_match <- str_match_all(orders_text, regex("Total\\s+([0-9,]+).*?\\$\\s*([0-9,]+)", ignore_case = TRUE))[[1]]
    deliveries_match <- str_match_all(deliveries_text, regex("Total\\s+([0-9,]+).*?\\$\\s*([0-9,]+)", ignore_case = TRUE))[[1]]
    backlog_match <- str_match_all(backlog_text, regex("Total\\s+([0-9,]+).*?\\$\\s*([0-9,]+)", ignore_case = TRUE))[[1]]
    orders_units <- parse_number(orders_match[nrow(orders_match), 2])
    orders_value_thousands <- parse_number(orders_match[nrow(orders_match), 3])
    deliveries_units <- parse_number(deliveries_match[nrow(deliveries_match), 2])
    deliveries_value_thousands <- parse_number(deliveries_match[nrow(deliveries_match), 3])
    backlog_units <- parse_number(backlog_match[nrow(backlog_match), 2])
    backlog_value_thousands <- parse_number(backlog_match[nrow(backlog_match), 3])
    if (is.na(orders_units)) {
      operating_index <- which(
        str_detect(table_text, regex("Operating Data", ignore_case = TRUE)) &
          str_detect(table_text, regex("Net sales orders \\(units\\)", ignore_case = TRUE))
      )
      if (length(operating_index) >= 1) {
        operating_text <- table_text[operating_index[1]]
        orders_units <- parse_number(str_match(operating_text, regex("Net sales orders \\(units\\)\\s+([0-9,]+)", ignore_case = TRUE))[, 2])
        source_table_text <- paste(c(source_table_text, operating_text), collapse = " || ")
      }
    }
    source_table_text <- paste(c(orders_text, deliveries_text, backlog_text), collapse = " || ")
    if (source_table_text == "") source_table_text <- NA_character_
    extraction_method <- "tmhc_annual_total_rows"
  }

  if (filing$ticker == "TPH") {
    orders_index <- which(str_detect(table_text, regex("New Home Orders.*Average Selling Communities", ignore_case = TRUE)))
    deliveries_index <- which(
      str_detect(table_text, regex("New ?Homes ?Delivered", ignore_case = TRUE)) &
        str_detect(table_text, regex("Home ?Sales ?Revenue", ignore_case = TRUE)) &
        str_detect(table_text, regex("Total", ignore_case = TRUE))
    )
    backlog_index <- which(
      str_detect(table_text, regex("Backlog.*Units", ignore_case = TRUE)) &
        str_detect(table_text, regex("Backlog.*Dollar.*Value", ignore_case = TRUE))
    )
    orders_text <- if (length(orders_index) >= 1) table_text[orders_index[1]] else NA_character_
    deliveries_text <- if (length(deliveries_index) >= 1) table_text[deliveries_index[1]] else NA_character_
    backlog_text <- if (length(backlog_index) >= 1) table_text[backlog_index[1]] else NA_character_
    orders_match <- str_match_all(orders_text, regex("Total\\s+([0-9,]+)", ignore_case = TRUE))[[1]]
    deliveries_match <- str_match_all(deliveries_text, regex("Total\\s+([0-9,]+).*?\\$\\s*([0-9,]+)", ignore_case = TRUE))[[1]]
    backlog_match <- str_match_all(backlog_text, regex("Total\\s+([0-9,]+)\\s+\\$\\s*([0-9,]+)", ignore_case = TRUE))[[1]]
    if (nrow(orders_match) > 0) orders_units <- parse_number(orders_match[nrow(orders_match), 2])
    if (is.na(orders_units)) {
      orders_units <- parse_number(str_match(filing_text, regex("Net new home orders for the year ended.*?(?:increased|decreased).*?to\\s+([0-9,]+)", ignore_case = TRUE))[, 2])
    }
    if (nrow(deliveries_match) > 0) {
      deliveries_units <- parse_number(deliveries_match[nrow(deliveries_match), 2])
      deliveries_value_thousands <- parse_number(deliveries_match[nrow(deliveries_match), 3])
    }
    if (nrow(backlog_match) > 0) {
      backlog_units <- parse_number(backlog_match[nrow(backlog_match), 2])
      backlog_value_thousands <- parse_number(backlog_match[nrow(backlog_match), 3])
    }
    source_table_text <- paste(c(orders_text, deliveries_text, backlog_text), collapse = " || ")
    if (source_table_text == "") source_table_text <- NA_character_
    extraction_method <- "tph_annual_total_rows"
  }

  if (filing$ticker == "CCS") {
    summary_index <- which(
      str_detect(table_text, regex("Other Operating Information", ignore_case = TRUE)) &
      str_detect(table_text, regex("Number of (?:new )?homes delivered", ignore_case = TRUE))
    )
    summary_text <- table_text[summary_index[1]]
    deliveries_units <- parse_number(str_match(summary_text, regex("Number of (?:new )?homes delivered\\s+([0-9,]+)", ignore_case = TRUE))[, 2])
    average_selling_price_dollars <- 1000 * parse_number(str_match(summary_text, regex("Average sales price of homes delivered\\s+\\$\\s*([0-9,.]+)", ignore_case = TRUE))[, 2])
    orders_units <- parse_number(str_match(summary_text, regex("Net new home contracts\\s+([0-9,]+)", ignore_case = TRUE))[, 2])
    backlog_units <- parse_number(str_match(summary_text, regex("Backlog at end of period, number of homes\\s+([0-9,]+)", ignore_case = TRUE))[, 2])
    backlog_value_thousands <- parse_number(str_match(summary_text, regex("Backlog at end of period, aggregate sales value\\s+\\$\\s*([0-9,]+)", ignore_case = TRUE))[, 2])
    active_communities <- parse_number(str_match(summary_text, regex("Selling communities.*?([0-9,]+)", ignore_case = TRUE))[, 2])
    source_table_text <- summary_text
    extraction_method <- "ccs_annual_operating_summary"
  }

  if (filing$ticker == "LGIH") {
    summary_index <- which(
      str_detect(table_text, regex("Other Financial and Operating Data", ignore_case = TRUE)) &
        str_detect(table_text, regex("Home closings", ignore_case = TRUE))
    )
    backlog_index <- which(str_detect(table_text, regex("Backlog Data", ignore_case = TRUE)))
    summary_text <- table_text[summary_index[1]]
    backlog_text <- table_text[backlog_index[1]]
    deliveries_units <- parse_number(str_match(summary_text, regex("Home closings\\s+([0-9,]+)", ignore_case = TRUE))[, 2])
    average_selling_price_dollars <- parse_number(str_match(summary_text, regex("Average sales price per home closed\\s+\\$\\s*([0-9,]+)", ignore_case = TRUE))[, 2])
    average_community_count <- parse_number(str_match(summary_text, regex("Average community count\\s+([0-9,.]+)", ignore_case = TRUE))[, 2])
    active_communities <- parse_number(str_match(summary_text, regex("Community count at end of period\\s+([0-9,]+)", ignore_case = TRUE))[, 2])
    orders_units <- parse_number(str_match(backlog_text, regex("Net orders\\s*(?:\\([0-9]+\\))?\\s+([0-9,]+)", ignore_case = TRUE))[, 2])
    cancellation_rate_pct <- parse_number(str_match(backlog_text, regex("Cancellation rate.*?([0-9.]+)\\s*%", ignore_case = TRUE))[, 2])
    backlog_units <- parse_number(str_match(backlog_text, regex("Ending backlog [-–] homes\\s*(?:\\([0-9]+\\))?\\s+([0-9,]+)", ignore_case = TRUE))[, 2])
    backlog_value_thousands <- parse_number(str_match(backlog_text, regex("Ending backlog [-–] value\\s*(?:\\([0-9]+\\))?\\s+\\$\\s*([0-9,]+)", ignore_case = TRUE))[, 2])
    source_table_text <- paste(c(summary_text, backlog_text), collapse = " || ")
    extraction_method <- "lgih_annual_operating_and_backlog_tables"
  }

  if (filing$ticker == "GRBK") {
    deliveries_index <- which(str_detect(table_text, regex("Home closings revenue.*New homes delivered", ignore_case = TRUE)))
    orders_index <- which(str_detect(table_text, regex("Net new home orders.*Cancellation rate", ignore_case = TRUE)))
    deliveries_text <- table_text[deliveries_index[1]]
    orders_text <- table_text[orders_index[1]]
    deliveries_value_thousands <- parse_number(str_match(deliveries_text, regex("Home closings revenue\\s+\\$\\s*([0-9,]+)", ignore_case = TRUE))[, 2])
    deliveries_units <- parse_number(str_match(deliveries_text, regex("New homes delivered\\s+([0-9,]+)", ignore_case = TRUE))[, 2])
    average_selling_price_dollars <- 1000 * parse_number(str_match(deliveries_text, regex("Average sales price of homes delivered\\s+\\$\\s*([0-9,.]+)", ignore_case = TRUE))[, 2])
    orders_units <- parse_number(str_match(orders_text, regex("Net new home orders\\s+([0-9,]+)", ignore_case = TRUE))[, 2])
    orders_value_thousands <- parse_number(str_match(orders_text, regex("Revenue from net new home orders\\s+\\$\\s*([0-9,]+)", ignore_case = TRUE))[, 2])
    cancellation_rate_pct <- parse_number(str_match(orders_text, regex("Cancellation rate\\s+([0-9.]+)\\s*%", ignore_case = TRUE))[, 2])
    backlog_units <- parse_number(str_match(orders_text, regex("Backlog(?: \\(units\\)| units)\\s+([0-9,]+)", ignore_case = TRUE))[, 2])
    backlog_value_thousands <- parse_number(str_match(orders_text, regex("Backlog(?: \\(dollars in thousands\\)| revenue)\\s+\\$\\s*([0-9,]+)", ignore_case = TRUE))[, 2])
    average_community_count <- parse_number(str_match(orders_text, regex("Average active selling communities\\s+([0-9,]+)", ignore_case = TRUE))[, 2])
    active_communities <- parse_number(str_match(orders_text, regex("Active selling communities at end of period\\s+([0-9,]+)", ignore_case = TRUE))[, 2])
    source_table_text <- paste(c(deliveries_text, orders_text), collapse = " || ")
    extraction_method <- "grbk_annual_operating_tables"
  }

  if (filing$ticker %in% c("DFH", "SDHC", "UHG")) {
    summary_index <- which(
      str_detect(table_text, regex("Other Financial and Operating Data|Other operating data", ignore_case = TRUE)) &
        str_detect(table_text, regex("Home closings", ignore_case = TRUE))
    )
    summary_text <- table_text[summary_index[1]]
    operating_text <- str_extract(summary_text, regex("Other (?:Financial and Operating Data|operating data):.*", ignore_case = TRUE))
    if (filing$ticker != "SDHC") operating_text <- summary_text
    deliveries_units <- parse_number(str_match(operating_text, regex("Home closings\\s+([0-9,]+)", ignore_case = TRUE))[, 2])
    orders_units <- parse_number(str_match(operating_text, regex("(?:Net sales|Net new (?:home )?orders(?: \\(units\\))?)\\s+([0-9,]+)", ignore_case = TRUE))[, 2])
    backlog_units <- parse_number(str_match(operating_text, regex("Backlog(?: \\(at period end\\)(?: - homes)?| - units| homes \\(period end\\))?\\s*(?:\\([0-9]+\\))?\\s+([0-9,]+)", ignore_case = TRUE))[, 2])
    backlog_value_thousands <- parse_number(str_match(summary_text, regex("(?:Backlog - value|Contract value of backlog homes).*?\\$\\s*([0-9,]+)", ignore_case = TRUE))[, 2])
    cancellation_rate_pct <- parse_number(str_match(summary_text, regex("Cancellation rate.*?([0-9.]+)\\s*%", ignore_case = TRUE))[, 2])
    active_communities <- parse_number(str_match(summary_text, regex("Active communities.*?([0-9,]+)", ignore_case = TRUE))[, 2])
    source_table_text <- summary_text
    extraction_method <- "recent_ipo_annual_operating_summary"

    if (filing$ticker == "DFH" && (is.na(orders_units) || is.na(backlog_units))) {
      orders_index <- which(str_detect(table_text, regex("Net New Orders", ignore_case = TRUE)) & str_detect(table_text, regex("Cancellation Rate", ignore_case = TRUE)))
      backlog_index <- which(str_detect(table_text, regex("Ending Backlog", ignore_case = TRUE)))
      if (length(orders_index) >= 1) orders_units <- parse_number(str_match(table_text[orders_index[1]], regex("Net New Orders\\s+([0-9,]+)", ignore_case = TRUE))[, 2])
      if (length(backlog_index) >= 1) {
        backlog_units <- parse_number(str_match(table_text[backlog_index[1]], regex("Ending Backlog - Homes\\s+([0-9,]+)", ignore_case = TRUE))[, 2])
        backlog_value_thousands <- parse_number(str_match(table_text[backlog_index[1]], regex("Ending Backlog - Value.*?\\$\\s*([0-9,]+)", ignore_case = TRUE))[, 2])
      }
    }
  }

  if (filing$ticker == "LSEA") {
    orders_index <- which(str_detect(table_text, regex("New Home Orders.*Monthly Absorption", ignore_case = TRUE)))
    orders_text <- table_text[orders_index[1]]
    orders_match <- str_match_all(orders_text, regex("Total\\s+([0-9,]+)\\s+\\$\\s*([0-9,]+)", ignore_case = TRUE))[[1]]
    orders_units <- parse_number(orders_match[nrow(orders_match), 2])
    orders_value_thousands <- parse_number(orders_match[nrow(orders_match), 3])
    operating_match <- str_match(
      filing_text,
      regex("new home orders.*?were\\s+([0-9,]+).*?delivered\\s+([0-9,]+) homes.*?sales revenue of \\$([0-9.]+) million.*?backlog of\\s+([0-9,]+).*?sales value of \\$([0-9.]+) million", ignore_case = TRUE)
    )
    if (filing$fiscal_year == 2021) {
      operating_match <- str_match(
        filing_text,
        regex("Net new home orders for Landsea Homes.*?were approximately\\s+([0-9,]+).*?Landsea Homes delivered approximately\\s+([0-9,]+) homes.*?sales revenue of \\$([0-9.]+) million.*?backlog of\\s+([0-9,]+).*?sales value of \\$([0-9.]+) million", ignore_case = TRUE)
      )
      orders_units <- NA_real_
    }
    if (is.na(orders_units)) orders_units <- parse_number(operating_match[, 2])
    deliveries_units <- parse_number(operating_match[, 3])
    deliveries_value_thousands <- 1000 * parse_number(operating_match[, 4])
    backlog_units <- parse_number(operating_match[, 5])
    backlog_value_thousands <- 1000 * parse_number(operating_match[, 6])
    if (is.na(orders_units) || is.na(deliveries_units) || is.na(backlog_units)) {
      overview_match <- str_match(
        filing_text,
        regex("new home orders for Landsea Homes.*?were\\s+([0-9,]+).*?delivered\\s+([0-9,]+) homes.*?backlog of\\s+([0-9,]+)", ignore_case = TRUE)
      )
      if (is.na(orders_units)) orders_units <- parse_number(overview_match[, 2])
      if (is.na(deliveries_units)) deliveries_units <- parse_number(overview_match[, 3])
      if (is.na(backlog_units)) backlog_units <- parse_number(overview_match[, 4])
    }
    operating_context <- str_extract(
      filing_text,
      regex("Net new home orders for Landsea Homes.*?sales value of \\$[0-9.]+ million", ignore_case = TRUE)
    )
    source_table_text <- paste(c(orders_text, operating_context)[!is.na(c(orders_text, operating_context))], collapse = " || ")
    if (source_table_text == "") source_table_text <- NA_character_
    extraction_method <- "lsea_annual_order_table_and_operating_prose"
  }

  rows[[i]] <- tibble(
    ticker = filing$ticker,
    company = filing$sec_company_name,
    cik10 = filing$cik10,
    fiscal_year = filing$fiscal_year,
    report_date = filing$report_date,
    filing_date = filing$filing_date,
    accession_number = filing$accession_number,
    orders_units, orders_value_thousands, deliveries_units, deliveries_value_thousands,
    backlog_units, backlog_value_thousands, cancellation_rate_pct,
    active_communities, average_community_count, average_selling_price_dollars,
    extraction_method, filing_url = filing$filing_url,
    source_local_path = filing$primary_document_local_path,
    source_checksum_sha256 = filing$primary_document_checksum_sha256,
    source_table_text
  )
}

panel <- bind_rows(rows) |>
  arrange(ticker, fiscal_year)

if (nrow(panel) != 54 || panel |> count(ticker, fiscal_year) |> filter(n != 1) |> nrow() > 0) {
  stop("Nine-firm annual operating panel is not unique and complete by public firm-year.")
}

write_csv_if_changed(panel, "../output/nine_firm_2018_2025_annual_operating_panel.csv")

cat("Wrote nine-firm annual operating panel to ../output\n")
