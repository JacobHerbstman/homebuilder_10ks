# setwd("/Users/jacobherbstman/Desktop/homebuilder_10ks/tasks/extract_nine_firm_quarterly_operating_disclosures/code")

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(rvest)
  library(stringr)
  library(tibble)
})

source("../../_lib/homebuilder_pipeline_utils.R")

inventory <- read_csv(
  "../input/tier1_2018_2025_sec_10q_download_inventory.csv",
  show_col_types = FALSE,
  col_types = cols(cik10 = col_character(), accession_number = col_character())
) |>
  filter(
    selected_for_panel,
    ticker %in% c("TMHC", "TPH", "CCS", "LGIH", "GRBK", "DFH", "SDHC", "UHG", "LSEA"),
    primary_document_status %in% c("downloaded", "already_present")
  ) |>
  mutate(
    report_date = as.Date(report_date),
    filing_date = as.Date(filing_date),
    fiscal_year = calendar_year,
    fiscal_quarter = calendar_quarter
  ) |>
  arrange(ticker, report_date)

if (nrow(inventory) != 163 || inventory |> count(ticker, report_date) |> filter(n != 1) |> nrow() > 0) {
  stop("Expected 163 unique 10-Q filings for the nine-firm public reporting episodes.")
}

rows <- vector("list", nrow(inventory))

for (i in seq_len(nrow(inventory))) {
  filing <- inventory[i, ]
  filing_html <- read_html(filing$source_local_path)
  filing_text <- str_squish(html_text2(filing_html))
  table_text <- html_elements(filing_html, "table") |>
    lapply(html_text2) |>
    unlist() |>
    str_replace_all(fixed("\u200B"), "") |>
    str_squish()

  orders_units <- NA_real_
  orders_value_thousands <- NA_real_
  orders_period_basis <- "current_quarter"
  deliveries_units <- NA_real_
  deliveries_value_thousands <- NA_real_
  deliveries_period_basis <- "current_quarter"
  backlog_units <- NA_real_
  backlog_value_thousands <- NA_real_
  cancellation_rate_pct <- NA_real_
  active_communities <- NA_real_
  average_community_count <- NA_real_
  average_selling_price_dollars <- NA_real_
  source_table_text <- NA_character_
  extraction_method <- NA_character_

  if (filing$ticker == "TMHC") {
    orders_index <- which(
      str_detect(table_text, regex("Three Months Ended", ignore_case = TRUE)) &
        str_detect(table_text, regex("Net Sales Orders.*Sales Value.*Average Selling Price", ignore_case = TRUE))
    )
    deliveries_index <- which(
      str_detect(table_text, regex("Three Months Ended", ignore_case = TRUE)) &
        str_detect(table_text, regex("Homes Closed.*Home Closings Revenue", ignore_case = TRUE))
    )
    backlog_index <- which(str_detect(table_text, regex("Sold Homes in Backlog.*Sales Value", ignore_case = TRUE)))
    orders_text <- table_text[orders_index[1]]
    deliveries_text <- table_text[deliveries_index[1]]
    backlog_text <- table_text[backlog_index[1]]
    orders_match <- str_match_all(orders_text, regex("Total\\s+([0-9,]+).*?\\$\\s*([0-9,]+)", ignore_case = TRUE))[[1]]
    deliveries_match <- str_match_all(deliveries_text, regex("Total\\s+([0-9,]+).*?\\$\\s*([0-9,]+)", ignore_case = TRUE))[[1]]
    backlog_match <- str_match_all(backlog_text, regex("Total\\s+([0-9,]+).*?\\$\\s*([0-9,]+)", ignore_case = TRUE))[[1]]
    if (nrow(orders_match) > 0) {
      orders_units <- parse_number(orders_match[1, 2])
      orders_value_thousands <- parse_number(orders_match[1, 3])
    }
    if (nrow(deliveries_match) > 0) {
      deliveries_units <- parse_number(deliveries_match[1, 2])
      deliveries_value_thousands <- parse_number(deliveries_match[1, 3])
    }
    if (nrow(backlog_match) > 0) {
      backlog_units <- parse_number(backlog_match[1, 2])
      backlog_value_thousands <- parse_number(backlog_match[1, 3])
    }
    source_table_text <- paste(orders_text, deliveries_text, backlog_text, sep = " || ")
    extraction_method <- "tmhc_three_month_total_rows"
  }

  if (filing$ticker == "TPH") {
    orders_index <- which(
      str_detect(table_text, regex("Three Months Ended", ignore_case = TRUE)) &
        str_detect(table_text, regex("New\\s*Home\\s*Orders", ignore_case = TRUE)) &
        str_detect(table_text, regex("Average\\s*Selling\\s*Communities", ignore_case = TRUE))
    )
    orders_text <- table_text[orders_index[1]]
    orders_total <- str_match_all(orders_text, regex("Total\\s+([0-9,]+)", ignore_case = TRUE))[[1]]
    if (nrow(orders_total) > 0) orders_units <- parse_number(orders_total[1, 2])
    orders_match <- str_match(
      filing_text,
      regex("Net new home orders for the quarter were\\s+([0-9,]+)", ignore_case = TRUE)
    )
    if (is.na(orders_units)) {
      orders_units <- parse_number(orders_match[, 2])
    }
    if (is.na(orders_units)) {
      orders_match <- str_match(
        filing_text,
        regex("net new home orders.*?(?:were|of)\\s+([0-9,]+)\\s+for the three months ended", ignore_case = TRUE)
      )
      orders_units <- parse_number(orders_match[, 2])
    }

    deliveries_index <- which(
      str_detect(table_text, regex("Three Months Ended", ignore_case = TRUE)) &
        str_detect(table_text, regex("New ?Homes ?Delivered", ignore_case = TRUE)) &
        str_detect(table_text, regex("Home ?Sales ?Revenue", ignore_case = TRUE))
    )
    deliveries_text <- table_text[deliveries_index[1]]
    deliveries_match <- str_match_all(deliveries_text, regex("Total\\s+([0-9,]+).*?\\$\\s*([0-9,]+)", ignore_case = TRUE))[[1]]
    if (nrow(deliveries_match) > 0) {
      deliveries_units <- parse_number(deliveries_match[1, 2])
      deliveries_value_thousands <- parse_number(deliveries_match[1, 3])
    }

    backlog_index <- which(
      str_detect(table_text, regex("Backlog\\s*Units", ignore_case = TRUE)) &
        str_detect(table_text, regex("Backlog\\s*Dollar\\s*Value", ignore_case = TRUE))
    )
    backlog_text <- table_text[backlog_index[1]]
    backlog_match <- str_match_all(backlog_text, regex("Total\\s+([0-9,]+)\\s+\\$\\s*([0-9,]+)", ignore_case = TRUE))[[1]]
    if (nrow(backlog_match) > 0) {
      backlog_units <- parse_number(backlog_match[1, 2])
      backlog_value_thousands <- parse_number(backlog_match[1, 3])
    }
    source_table_text <- paste(orders_text, orders_match[, 1], deliveries_text, backlog_text, sep = " || ")
    extraction_method <- "tph_quarter_prose_and_total_tables"
  }

  if (filing$ticker == "CCS") {
    summary_index <- which(
      str_detect(table_text, regex("Other Operating Information", ignore_case = TRUE)) &
        str_detect(table_text, regex("Net new home contracts", ignore_case = TRUE))
    )
    summary_text <- table_text[summary_index[1]]
    deliveries_units <- parse_number(str_match(summary_text, regex("Number of (?:new )?homes delivered\\s+([0-9,]+)", ignore_case = TRUE))[, 2])
    deliveries_value_thousands <- parse_number(str_match(summary_text, regex("Home sales revenues\\s+\\$\\s*([0-9,]+)", ignore_case = TRUE))[, 2])
    average_selling_price_dollars <- 1000 * parse_number(str_match(summary_text, regex("Average sales price of homes delivered\\s+\\$\\s*([0-9,.]+)", ignore_case = TRUE))[, 2])
    orders_units <- parse_number(str_match(summary_text, regex("Net new home contracts\\s+([0-9,]+)", ignore_case = TRUE))[, 2])
    backlog_units <- parse_number(str_match(summary_text, regex("Backlog at end of period, number of homes\\s+([0-9,]+)", ignore_case = TRUE))[, 2])
    backlog_value_thousands <- parse_number(str_match(summary_text, regex("Backlog at end of period, aggregate sales value\\s+\\$\\s*([0-9,]+)", ignore_case = TRUE))[, 2])
    active_communities <- parse_number(str_match(summary_text, regex("Selling communities at period end\\s*(?:\\([0-9a-z]+\\))?\\s+([0-9,]+)", ignore_case = TRUE))[, 2])
    average_community_count <- parse_number(str_match(summary_text, regex("Average selling communities\\s+([0-9,.]+)", ignore_case = TRUE))[, 2])
    source_table_text <- summary_text
    extraction_method <- "ccs_three_month_operating_summary"
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
    deliveries_value_thousands <- parse_number(str_match(summary_text, regex("Home sales revenues\\s+\\$\\s*([0-9,]+)", ignore_case = TRUE))[, 2])
    average_selling_price_dollars <- parse_number(str_match(summary_text, regex("Average sales price per home closed\\s+\\$\\s*([0-9,]+)", ignore_case = TRUE))[, 2])
    average_community_count <- parse_number(str_match(summary_text, regex("Average community count\\s+([0-9,.]+)", ignore_case = TRUE))[, 2])
    active_communities <- parse_number(str_match(summary_text, regex("Community count at end of period\\s+([0-9,]+)", ignore_case = TRUE))[, 2])
    orders_units <- parse_number(str_match(backlog_text, regex("Net orders\\s*(?:\\([0-9]+\\))?\\s+([0-9,]+)", ignore_case = TRUE))[, 2])
    orders_period_basis <- "fiscal_ytd"
    cancellation_rate_pct <- parse_number(str_match(backlog_text, regex("Cancellation rate.*?([0-9.]+)\\s*%", ignore_case = TRUE))[, 2])
    backlog_units <- parse_number(str_match(backlog_text, regex("Ending backlog [-–] homes\\s*(?:\\([0-9]+\\))?\\s+([0-9,]+)", ignore_case = TRUE))[, 2])
    backlog_value_thousands <- parse_number(str_match(backlog_text, regex("Ending backlog [-–] value\\s*(?:\\([0-9]+\\))?\\s+\\$\\s*([0-9,]+)", ignore_case = TRUE))[, 2])
    source_table_text <- paste(summary_text, backlog_text, sep = " || ")
    extraction_method <- "lgih_three_month_closings_and_ytd_orders"
  }

  if (filing$ticker == "GRBK") {
    deliveries_index <- which(
      str_detect(table_text, regex("Three Months Ended", ignore_case = TRUE)) &
        str_detect(table_text, regex("Home closings revenue.*New homes delivered|New Homes Delivered.*Home Sales Revenue", ignore_case = TRUE))
    )
    orders_index <- which(
      str_detect(table_text, regex("Three Months Ended", ignore_case = TRUE)) &
        str_detect(table_text, regex("Net new home orders.*Cancellation rate", ignore_case = TRUE))
    )
    deliveries_text <- table_text[deliveries_index[1]]
    orders_text <- table_text[orders_index[1]]
    deliveries_value_thousands <- parse_number(str_match(deliveries_text, regex("(?:Home closings revenue|Home sales revenue)(?: \\(\\$? in thousands\\)| \\(dollars in thousands\\))?\\s+\\$\\s*([0-9,]+)", ignore_case = TRUE))[, 2])
    deliveries_units <- parse_number(str_match(deliveries_text, regex("New homes delivered\\s+([0-9,]+)", ignore_case = TRUE))[, 2])
    average_selling_price_dollars <- parse_number(str_match(deliveries_text, regex("Average sales price of homes delivered\\s+\\$\\s*([0-9,.]+)", ignore_case = TRUE))[, 2])
    if (!is.na(average_selling_price_dollars) && average_selling_price_dollars < 5000) {
      average_selling_price_dollars <- 1000 * average_selling_price_dollars
    }
    orders_units <- parse_number(str_match(orders_text, regex("Net new home orders\\s+([0-9,]+)", ignore_case = TRUE))[, 2])
    orders_value_thousands <- parse_number(str_match(orders_text, regex("Revenue from net new home orders\\s+\\$\\s*([0-9,]+)", ignore_case = TRUE))[, 2])
    cancellation_rate_pct <- parse_number(str_match(orders_text, regex("Cancellation rate\\s+([0-9.]+)\\s*%", ignore_case = TRUE))[, 2])
    backlog_units <- parse_number(str_match(orders_text, regex("Backlog(?: \\(units\\)| units)\\s+([0-9,]+)", ignore_case = TRUE))[, 2])
    backlog_value_thousands <- parse_number(str_match(orders_text, regex("Backlog(?: \\(dollars in thousands\\)| revenue)\\s+\\$\\s*([0-9,]+)", ignore_case = TRUE))[, 2])
    average_community_count <- parse_number(str_match(orders_text, regex("Average (?:active )?selling communities\\s+([0-9,]+)", ignore_case = TRUE))[, 2])
    active_communities <- parse_number(str_match(orders_text, regex("(?:Active )?selling communities at end of period\\s+([0-9,]+)", ignore_case = TRUE))[, 2])
    source_table_text <- paste(deliveries_text, orders_text, sep = " || ")
    extraction_method <- "grbk_three_month_operating_tables"
  }

  if (filing$ticker %in% c("DFH", "SDHC", "UHG")) {
    summary_index <- which(
      str_detect(table_text, regex("Other Financial and Operating Data|Other operating data", ignore_case = TRUE)) &
        str_detect(table_text, regex("Home closings", ignore_case = TRUE)) &
        str_detect(table_text, regex("Net (?:sales|new (?:home )?orders)", ignore_case = TRUE)) &
        str_detect(table_text, regex("Three months ended|Three Months Ended", ignore_case = TRUE))
    )
    summary_text <- table_text[summary_index[1]]
    deliveries_units <- parse_number(str_match(summary_text, regex("Home closings\\s+([0-9,]+)", ignore_case = TRUE))[, 2])
    if (filing$ticker == "SDHC") {
      deliveries_units <- parse_number(str_match(summary_text, regex("Other operating data:\\s+Home closings\\s+([0-9,]+)", ignore_case = TRUE))[, 2])
    }
    deliveries_value_thousands <- parse_number(str_match(summary_text, regex("Home closing revenue\\s+\\$\\s*([0-9,]+)", ignore_case = TRUE))[, 2])
    orders_units <- parse_number(str_match(summary_text, regex("(?:Net sales|Net new (?:home )?orders)(?: \\(units\\))?\\s+([0-9,]+)", ignore_case = TRUE))[, 2])
    orders_value_thousands <- parse_number(str_match(summary_text, regex("Contract value of net new home orders\\s+\\$\\s*([0-9,]+)", ignore_case = TRUE))[, 2])
    backlog_units <- parse_number(str_match(summary_text, regex("Backlog(?: as of period end - units| \\(at period end\\) - homes| - units| homes \\(period end\\)|)(?:\\([0-9]+\\))?\\s+([0-9,]+)", ignore_case = TRUE))[, 2])
    backlog_value_thousands <- parse_number(str_match(summary_text, regex("(?:Backlog as of period end - value \\(in thousands\\)|Backlog \\(at period end, in thousands\\) - value|Backlog - value \\(in thousands\\)|Contract value of backlog homes \\(period end\\))(?:\\([0-9]+\\))?\\s+\\$\\s*([0-9,]+)", ignore_case = TRUE))[, 2])
    cancellation_rate_pct <- parse_number(str_match(summary_text, regex("Cancellation rate(?:\\([0-9]+\\))?\\s+([0-9.]+)\\s*%", ignore_case = TRUE))[, 2])
    active_communities <- parse_number(str_match(summary_text, regex("Active communities(?: as of period end| at end of period| \\(period end\\))?(?:\\([0-9a-z]+\\))?\\s+([0-9,]+)", ignore_case = TRUE))[, 2])
    average_selling_price_dollars <- parse_number(str_match(summary_text, regex("Average sales price of homes closed(?:\\([0-9]+\\))?\\s+\\$\\s*([0-9,]+)", ignore_case = TRUE))[, 2])
    if (is.na(deliveries_value_thousands) && !is.na(deliveries_units) && !is.na(average_selling_price_dollars)) {
      deliveries_value_thousands <- deliveries_units * average_selling_price_dollars / 1000
    }
    if (filing$ticker == "DFH" && is.na(backlog_units)) {
      backlog_index <- which(
        str_detect(table_text, regex("Backlog.*(?:units|homes)", ignore_case = TRUE)) &
          str_detect(table_text, regex("Backlog.*value", ignore_case = TRUE))
      )
      backlog_text <- table_text[backlog_index[1]]
      backlog_units <- parse_number(str_match(backlog_text, regex("(?:Ending Backlog - Homes|Backlog as of period end - units)\\s+([0-9,]+)", ignore_case = TRUE))[, 2])
      backlog_value_thousands <- parse_number(str_match(backlog_text, regex("(?:Ending Backlog - Value|Backlog as of period end - value)(?: \\(in thousands\\))?\\s+\\$\\s*([0-9,]+)", ignore_case = TRUE))[, 2])
      summary_text <- paste(summary_text, backlog_text, sep = " || ")
    }
    source_table_text <- summary_text
    extraction_method <- "recent_ipo_three_month_operating_summary"
  }

  if (filing$ticker == "LSEA") {
    orders_index <- which(
      str_detect(table_text, regex("Three Months Ended", ignore_case = TRUE)) &
        str_detect(table_text, regex("Monthly Absorption Rate", ignore_case = TRUE))
    )
    deliveries_index <- which(
      str_detect(table_text, regex("Three Months Ended", ignore_case = TRUE)) &
        str_detect(table_text, regex("Home Deliveries|Homes Dollar Value ASP", ignore_case = TRUE)) &
        !str_detect(table_text, regex("Monthly Absorption Rate", ignore_case = TRUE))
    )
    orders_text <- table_text[orders_index[1]]
    deliveries_text <- table_text[deliveries_index[length(deliveries_index)]]
    orders_match <- str_match_all(orders_text, regex("Total\\s+([0-9,]+)\\s+\\$\\s*([0-9,]+)", ignore_case = TRUE))[[1]]
    deliveries_match <- str_match_all(deliveries_text, regex("Total\\s+([0-9,]+)\\s+\\$\\s*([0-9,]+)", ignore_case = TRUE))[[1]]
    if (nrow(orders_match) > 0) {
      orders_units <- parse_number(orders_match[1, 2])
      orders_value_thousands <- parse_number(orders_match[1, 3])
    }
    if (nrow(deliveries_match) > 0) {
      deliveries_units <- parse_number(deliveries_match[1, 2])
      deliveries_value_thousands <- parse_number(deliveries_match[1, 3])
    }
    backlog_context <- str_extract(
      filing_text,
      regex("Backlog Backlog reflects the number of homes.*?Total\\s+[0-9,]+\\s+\\$\\s*[0-9,]+", ignore_case = TRUE)
    )
    backlog_match <- str_match(backlog_context, regex("Total\\s+([0-9,]+)\\s+\\$\\s*([0-9,]+)", ignore_case = TRUE))
    backlog_units <- parse_number(backlog_match[, 2])
    backlog_value_thousands <- parse_number(backlog_match[, 3])
    source_table_text <- paste(orders_text, deliveries_text, backlog_context, sep = " || ")
    extraction_method <- "lsea_three_month_order_delivery_tables_and_backlog_prose"
  }

  rows[[i]] <- tibble(
    ticker = filing$ticker,
    company = filing$company,
    cik10 = filing$cik10,
    calendar_year = filing$calendar_year,
    calendar_quarter = filing$calendar_quarter,
    calendar_quarter_label = filing$calendar_quarter_label,
    fiscal_year = filing$fiscal_year,
    fiscal_quarter = filing$fiscal_quarter,
    form = filing$form,
    filing_date = filing$filing_date,
    report_date = filing$report_date,
    accession_number = filing$accession_number,
    orders_units,
    orders_value_thousands,
    orders_period_basis,
    deliveries_units,
    deliveries_value_thousands,
    deliveries_period_basis,
    backlog_units,
    backlog_value_thousands,
    cancellation_rate_pct,
    active_communities,
    average_community_count,
    average_selling_price_dollars,
    operating_extraction_method = extraction_method,
    operating_context_snippet = source_table_text,
    filing_url = filing$filing_url,
    source_local_path = filing$source_local_path,
    source_checksum_sha256 = filing$source_checksum_sha256
  )
}

disclosures <- bind_rows(rows) |>
  arrange(ticker, report_date)

if (
  nrow(disclosures) != 163 ||
  disclosures |> count(ticker, report_date) |> filter(n != 1) |> nrow() > 0 ||
  disclosures |> filter(is.na(orders_units) | is.na(deliveries_units) | is.na(backlog_units)) |> nrow() > 0
) {
  stop("Nine-firm quarterly disclosures are not unique and complete by source filing.")
}

write_csv_if_changed(disclosures, "../output/nine_firm_2018_2025_quarterly_operating_disclosures.csv")

cat("Wrote nine-firm quarterly operating disclosures to ../output\n")
