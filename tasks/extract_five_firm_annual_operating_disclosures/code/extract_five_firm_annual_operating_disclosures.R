# setwd("/Users/jacobherbstman/Desktop/homebuilder_10ks/tasks/extract_five_firm_annual_operating_disclosures/code")

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(rvest)
  library(stringr)
})

source("../../_lib/homebuilder_pipeline_utils.R")

inventory <- read_csv(
  "../input/sec_10k_download_inventory.csv",
  show_col_types = FALSE,
  col_types = cols(.default = col_character())
) |>
  mutate(
    fiscal_year = as.integer(fiscal_year),
    filing_date = as.Date(filing_date),
    report_date = as.Date(report_date)
  ) |>
  filter(
    ticker %in% c("BZH", "MHO", "MTH", "TOL", "MDC"),
    form == "10-K",
    fiscal_year %in% 2006:2025,
    ticker != "MDC" | fiscal_year <= 2024
  ) |>
  arrange(ticker, fiscal_year)

if (nrow(inventory) != 99 || inventory |> count(ticker, fiscal_year) |> filter(n != 1) |> nrow() > 0) {
  stop("Expected 99 unique annual filings for the five public-firm episodes.")
}

if (any(!file.exists(inventory$primary_document_local_path))) {
  stop("At least one required annual 10-K HTML file is missing.")
}

rows <- vector("list", nrow(inventory))

for (i in seq_len(nrow(inventory))) {
  filing <- inventory[i, ]
  filing_html <- read_html(filing$primary_document_local_path)
  filing_tables <- html_elements(filing_html, "table")
  table_text <- vapply(filing_tables, function(x) str_squish(html_text2(x)), character(1))

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
  homebuilding_revenue_thousands <- NA_real_
  orders_raw_label <- NA_character_
  deliveries_raw_label <- NA_character_
  extraction_method <- NA_character_
  source_scope <- "Consolidated homebuilding"
  source_table_text <- NA_character_

  if (filing$ticker == "MHO") {
    operating_index <- which(
      str_detect(table_text, fixed("Total Homebuilding Regions", ignore_case = TRUE)) &
        str_detect(table_text, fixed("Homes delivered", ignore_case = TRUE)) &
        str_detect(table_text, fixed("New contracts, net", ignore_case = TRUE)) &
        str_detect(table_text, fixed(as.character(filing$fiscal_year)))
    )

    if (length(operating_index) >= 1) {
      operating_text <- table_text[operating_index[1]]
      total_text <- str_extract(operating_text, regex("Total Homebuilding Regions.*", ignore_case = TRUE))
      deliveries_units <- parse_number(str_match(total_text, regex("Homes delivered\\s+([0-9,]+)", ignore_case = TRUE))[, 2])
      orders_units <- parse_number(str_match(total_text, regex("New contracts, net\\s+([0-9,]+)", ignore_case = TRUE))[, 2])
      backlog_units <- parse_number(str_match(total_text, regex("Backlog at end of period\\s+([0-9,]+)", ignore_case = TRUE))[, 2])
      average_selling_price_dollars <- 1000 * parse_number(str_match(total_text, regex("Average sales price (?:per home|of homes) delivered\\s+\\$\\s*([0-9,.]+)", ignore_case = TRUE))[, 2])
      backlog_value_thousands <- parse_number(str_match(total_text, regex("Aggregate sales value of homes in backlog\\s+\\$\\s*([0-9,]+)", ignore_case = TRUE))[, 2])
      homebuilding_revenue_thousands <- parse_number(str_match(total_text, regex("(?:Revenue homes|Housing revenue)\\s+\\$\\s*([0-9,]+)", ignore_case = TRUE))[, 2])
      average_community_count <- parse_number(str_match(total_text, regex("Number of average active communities\\s+([0-9,]+)", ignore_case = TRUE))[, 2])
      active_communities <- parse_number(str_match(total_text, regex("Number of active communities(?:, end of period)?\\s+([0-9,]+)", ignore_case = TRUE))[, 2])
      deliveries_value_thousands <- homebuilding_revenue_thousands
      source_table_text <- operating_text
    }

    if (is.na(orders_units) || is.na(backlog_units)) {
      supplemental_index <- which(
        str_detect(table_text, fixed("New contracts, net", ignore_case = TRUE)) &
          str_detect(table_text, fixed("Backlog at end of period", ignore_case = TRUE)) &
          str_detect(table_text, fixed(as.character(filing$fiscal_year)))
      )
      if (length(supplemental_index) >= 1) {
        supplemental_text <- table_text[supplemental_index[which.min(str_length(table_text[supplemental_index]))]]
        orders_units <- parse_number(str_match(supplemental_text, regex("New contracts, net\\s+([0-9,]+)", ignore_case = TRUE))[, 2])
        backlog_units <- parse_number(str_match(supplemental_text, regex("Backlog at end of period\\s+([0-9,]+)", ignore_case = TRUE))[, 2])
        backlog_value_thousands <- parse_number(str_match(supplemental_text, regex("Aggregate sales value of homes in backlog\\s+\\$\\s*([0-9,]+)", ignore_case = TRUE))[, 2])
        active_communities <- parse_number(str_match(supplemental_text, regex("Number of active communities\\s+([0-9,]+)", ignore_case = TRUE))[, 2])
        source_table_text <- paste(source_table_text, supplemental_text, sep = " || ")
      }
    }

    orders_raw_label <- "New contracts, net"
    deliveries_raw_label <- "Homes delivered"
    extraction_method <- "mho_total_homebuilding_regions"
  }

  if (filing$ticker == "MTH") {
    closing_index <- which(
      str_detect(table_text, regex("Home Closing Revenue", ignore_case = TRUE)) &
        str_detect(table_text, regex("Homes closed", ignore_case = TRUE)) &
        str_detect(table_text, fixed(as.character(filing$fiscal_year)))
    )
    orders_index <- which(
      str_detect(table_text, regex("Home Orders", ignore_case = TRUE)) &
        str_detect(table_text, regex("Homes ordered", ignore_case = TRUE)) &
        str_detect(table_text, fixed(as.character(filing$fiscal_year)))
    )
    backlog_index <- which(
      str_detect(table_text, regex("Order Backlog", ignore_case = TRUE)) &
        str_detect(table_text, regex("Homes in backlog", ignore_case = TRUE)) &
        str_detect(table_text, fixed(as.character(filing$fiscal_year)))
    )

    if (length(closing_index) >= 1) {
      closing_text <- table_text[closing_index[1]]
      deliveries_value_thousands <- parse_number(str_match(closing_text, regex("Total Dollars\\s+\\$\\s*([0-9,]+)", ignore_case = TRUE))[, 2])
      deliveries_units <- parse_number(str_match(closing_text, regex("Homes closed\\s+([0-9,]+)", ignore_case = TRUE))[, 2])
      average_selling_price_dollars <- 1000 * parse_number(str_match(closing_text, regex("Average sales price\\s+\\$\\s*([0-9,.]+)", ignore_case = TRUE))[, 2])
      homebuilding_revenue_thousands <- deliveries_value_thousands
    }
    if (length(orders_index) >= 1) {
      orders_text <- table_text[orders_index[1]]
      orders_value_thousands <- parse_number(str_match(orders_text, regex("Total Dollars\\s+\\$\\s*([0-9,]+)", ignore_case = TRUE))[, 2])
      orders_units <- parse_number(str_match(orders_text, regex("Homes ordered\\s+([0-9,]+)", ignore_case = TRUE))[, 2])
    }
    if (length(backlog_index) >= 1) {
      backlog_text <- table_text[backlog_index[1]]
      backlog_value_thousands <- parse_number(str_match(backlog_text, regex("Total Dollars\\s+\\$\\s*([0-9,]+)", ignore_case = TRUE))[, 2])
      backlog_units <- parse_number(str_match(backlog_text, regex("Homes in backlog\\s+([0-9,]+)", ignore_case = TRUE))[, 2])
    }

    community_index <- which(
      str_detect(table_text, regex("Total Company", ignore_case = TRUE)) &
        str_detect(table_text, regex("Actively Selling Communities", ignore_case = TRUE)) &
        str_detect(table_text, fixed(as.character(filing$fiscal_year)))
    )
    if (length(community_index) >= 1) {
      community_match <- str_match_all(
        table_text[community_index[1]],
        regex("Total Company.*?([0-9,]+)\\s*$", ignore_case = TRUE)
      )[[1]]
      if (nrow(community_match) > 0) active_communities <- parse_number(community_match[nrow(community_match), 2])
    }

    orders_raw_label <- "Homes ordered"
    deliveries_raw_label <- "Homes closed"
    extraction_method <- "mth_total_operating_tables"
    source_table_text <- paste(
      table_text[c(closing_index[1], orders_index[1], backlog_index[1])],
      collapse = " || "
    )
  }

  if (filing$ticker == "BZH") {
    annual_index <- which(
      str_detect(table_text, regex("New Orders,? net.*Closings.*Backlog", ignore_case = TRUE)) &
        str_detect(table_text, regex("Total", ignore_case = TRUE)) &
        str_detect(table_text, fixed(as.character(filing$fiscal_year)))
    )
    if (length(annual_index) >= 1) {
      annual_text <- table_text[annual_index[1]]
      annual_match <- str_match(
        annual_text,
        regex("Total\\s+([0-9,]+).*?([0-9,]+).*?([0-9,]+)", ignore_case = TRUE)
      )
      orders_units <- parse_number(annual_match[, 2])
      deliveries_units <- parse_number(annual_match[, 3])
      backlog_units <- parse_number(annual_match[, 4])
      source_table_text <- annual_text
    }

    orders_index <- which(
      str_detect(table_text, regex("New Orders \\(Net of Cancellations\\)", ignore_case = TRUE)) &
        str_detect(table_text, fixed(as.character(filing$fiscal_year)))
    )
    closings_index <- which(
      str_detect(table_text, regex("Closings\\s+1st", ignore_case = TRUE)) &
        str_detect(table_text, fixed(as.character(filing$fiscal_year)))
    )

    if (length(orders_index) >= 1) {
      orders_match <- str_match(
        table_text[orders_index[1]],
        regex(paste0(filing$fiscal_year, "\\s+([0-9,]+)\\s+([0-9,]+)\\s+([0-9,]+)\\s+([0-9,]+)"), ignore_case = TRUE)
      )
      orders_units <- sum(parse_number(orders_match[, 2:5]))
    }
    if (length(closings_index) >= 1) {
      closings_text <- str_extract(table_text[closings_index[1]], regex("Closings.*", ignore_case = TRUE))
      closings_match <- str_match(
        closings_text,
        regex(paste0(filing$fiscal_year, "\\s+([0-9,]+)\\s+([0-9,]+)\\s+([0-9,]+)\\s+([0-9,]+)"), ignore_case = TRUE)
      )
      deliveries_units <- sum(parse_number(closings_match[, 2:5]))
    }

    backlog_index <- which(
      str_detect(table_text, regex("Units in Backlog|Backlog Units", ignore_case = TRUE)) &
        str_detect(table_text, fixed(as.character(filing$fiscal_year)))
    )
    if (length(backlog_index) >= 1) {
      preferred_backlog_index <- backlog_index[
        str_detect(table_text[backlog_index], regex("Total Company|Continuing Operations", ignore_case = TRUE))
      ]
      backlog_text <- table_text[if_else(length(preferred_backlog_index) >= 1, preferred_backlog_index[1], backlog_index[1])]
      company_match <- str_match(backlog_text, regex("Total Company\\s+([0-9,]+)\\s+\\$\\s*([0-9,.]+)", ignore_case = TRUE))
      continuing_match <- str_match(backlog_text, regex("Continuing Operations\\s+([0-9,]+)\\s+\\$\\s*([0-9,]+)", ignore_case = TRUE))
      if (!is.na(company_match[, 2])) {
        backlog_units <- parse_number(company_match[, 2])
        backlog_value_thousands <- parse_number(company_match[, 3]) * if_else(str_detect(backlog_text, regex("in millions", ignore_case = TRUE)), 1000, 1)
      } else if (!is.na(continuing_match[, 2])) {
        backlog_units <- parse_number(continuing_match[, 2])
        backlog_value_thousands <- parse_number(continuing_match[, 3])
        source_scope <- "Continuing homebuilding operations"
      }
    }

    if (is.na(backlog_units)) {
      filing_text <- str_squish(html_text2(filing_html))
      summary_match <- str_match(
        filing_text,
        regex("Total Company\\s+([0-9,]+)\\s+\\$\\s*[0-9,.]+\\s+([0-9,]+)\\s+\\$\\s*([0-9,]+)", ignore_case = TRUE)
      )
      backlog_units <- parse_number(summary_match[, 3])
      backlog_value_thousands <- parse_number(summary_match[, 4])

      if (is.na(backlog_units)) {
        backlog_match <- str_match(
          filing_text,
          regex(paste0("Backlog at September 30,? ", filing$fiscal_year, ".*?Total\\s+([0-9,]+)"), ignore_case = TRUE)
        )
        backlog_units <- parse_number(backlog_match[, 2])
      }
    }

    cancellation_index <- which(
      str_detect(table_text, regex("Cancellation Rates", ignore_case = TRUE)) &
        str_detect(table_text, fixed(as.character(filing$fiscal_year)))
    )
    if (length(cancellation_index) >= 1) {
      cancellation_match <- str_match(
        table_text[cancellation_index[1]],
        regex("Total\\s+[0-9,]+.*?([0-9.]+)\\s*%", ignore_case = TRUE)
      )
      cancellation_rate_pct <- parse_number(cancellation_match[, 2])
    }

    orders_raw_label <- "New orders, net of cancellations"
    deliveries_raw_label <- "Closings"
    extraction_method <- "bzh_quarterly_flow_sum_and_year_end_backlog"
    if (is.na(source_table_text)) {
      source_table_text <- paste(table_text[c(orders_index[1], closings_index[1], backlog_index[1])], collapse = " || ")
    }
  }

  if (filing$ticker == "TOL") {
    operating_index <- which(
      str_detect(table_text, regex("Deliveries.*units", ignore_case = TRUE)) &
        str_detect(table_text, regex("Net contracts signed|Contracts:", ignore_case = TRUE)) &
        str_detect(table_text, fixed(as.character(filing$fiscal_year)))
    )
    if (length(operating_index) >= 1) {
      operating_text <- table_text[operating_index[1]]
      deliveries_units <- parse_number(str_match(operating_text, regex("Deliveries.*?units\\s+([0-9,]+)", ignore_case = TRUE))[, 2])
      average_selling_price_dollars <- 1000 * parse_number(str_match(operating_text, regex("Deliveries.*?average sales price.*?\\$\\s*([0-9,.]+)", ignore_case = TRUE))[, 2])
      orders_value_thousands <- 1000 * parse_number(str_match(operating_text, regex("Net contracts signed.*?value\\s+\\$\\s*([0-9,.]+)", ignore_case = TRUE))[, 2])
      orders_units <- parse_number(str_match(operating_text, regex("Net contracts signed.*?units\\s+([0-9,]+)", ignore_case = TRUE))[, 2])
      cancellation_rate_pct <- parse_number(str_match(operating_text, regex("Cancellation rate\\s+([0-9.]+)\\s*%", ignore_case = TRUE))[, 2])
      homebuilding_revenue_thousands <- 1000 * parse_number(str_match(operating_text, regex("Home sales\\s+\\$\\s*([0-9,.]+)", ignore_case = TRUE))[, 2])
      deliveries_value_thousands <- homebuilding_revenue_thousands
    }

    if (is.na(orders_units) || is.na(deliveries_units)) {
      five_year_index <- which(
        str_detect(table_text, regex("Closings", ignore_case = TRUE)) &
          str_detect(table_text, regex("Net contracts signed|Contracts:", ignore_case = TRUE)) &
          str_detect(table_text, fixed(as.character(filing$fiscal_year)))
      )
      if (length(five_year_index) >= 1) {
        five_year_text <- table_text[five_year_index[1]]
        deliveries_units <- parse_number(str_match(five_year_text, regex("Closings.*?Number of homes\\s+([0-9,]+)", ignore_case = TRUE))[, 2])
        deliveries_value_thousands <- parse_number(str_match(five_year_text, regex("Closings.*?Value.*?\\$\\s*([0-9,]+)", ignore_case = TRUE))[, 2])
        orders_units <- parse_number(str_match(five_year_text, regex("(?:Net contracts signed|Contracts).*?Number of homes\\s+([0-9,]+)", ignore_case = TRUE))[, 2])
        orders_value_thousands <- parse_number(str_match(five_year_text, regex("(?:Net contracts signed|Contracts).*?Value.*?\\$\\s*([0-9,]+)", ignore_case = TRUE))[, 2])
        average_selling_price_dollars <- deliveries_value_thousands * 1000 / deliveries_units
        homebuilding_revenue_thousands <- deliveries_value_thousands
        source_table_text <- paste(source_table_text, five_year_text, sep = " || ")
      }
    }

    if (filing$fiscal_year == 2006 && (is.na(orders_units) || is.na(deliveries_units))) {
      contracts_index <- which(
        str_detect(table_text, regex("^Contracts Geographic Segment", ignore_case = TRUE)) &
          str_detect(table_text, fixed("2006"))
      )
      deliveries_index <- which(
        str_detect(table_text, regex("^Closings Geographic Segment", ignore_case = TRUE)) &
          str_detect(table_text, fixed("2006"))
      )
      if (length(contracts_index) >= 1) {
        contracts_text <- table_text[contracts_index[1]]
        total_matches <- str_match_all(contracts_text, regex("Total\\s+([0-9,]+)", ignore_case = TRUE))[[1]]
        orders_units <- parse_number(total_matches[1, 2])
      }
      backlog_2006_index <- which(
        str_detect(table_text, regex("^Backlog at October 31", ignore_case = TRUE)) &
          str_detect(table_text, fixed("2006"))
      )
      if (length(backlog_2006_index) >= 1) {
        backlog_units <- parse_number(str_match(table_text[backlog_2006_index[1]], regex("Total\\s+([0-9,]+)", ignore_case = TRUE))[, 2])
      }
      if (length(deliveries_index) >= 1) {
        deliveries_units <- parse_number(str_match(table_text[deliveries_index[1]], regex("Total\\s+([0-9,]+)", ignore_case = TRUE))[, 2])
      }
    }

    backlog_index <- which(
      str_detect(table_text, regex("Backlog: Number of homes", ignore_case = TRUE)) &
        str_detect(table_text, fixed(as.character(filing$fiscal_year)))
    )
    if (length(backlog_index) >= 1) {
      backlog_text <- table_text[backlog_index[1]]
      backlog_units <- parse_number(str_match(backlog_text, regex("Number of homes\\s+([0-9,]+)", ignore_case = TRUE))[, 2])
      backlog_value_thousands <- parse_number(str_match(backlog_text, regex("Value \\(in thousands\\).*?\\$\\s*([0-9,]+)", ignore_case = TRUE))[, 2])
      active_communities <- parse_number(str_match(backlog_text, regex("Number of selling communities\\s+([0-9,]+)", ignore_case = TRUE))[, 2])
    }

    if (is.na(backlog_units) && length(operating_index) >= 1) {
      operating_text <- table_text[operating_index[1]]
      backlog_units <- parse_number(str_match(operating_text, regex("Backlog[^0-9]*units\\s+([0-9,]+)", ignore_case = TRUE))[, 2])
      backlog_value_thousands <- 1000 * parse_number(str_match(operating_text, regex("Backlog[^0-9]*value\\s+\\$\\s*([0-9,.]+)", ignore_case = TRUE))[, 2])
    }

    orders_raw_label <- "Net contracts signed"
    deliveries_raw_label <- "Deliveries"
    extraction_method <- "tol_supplemental_operating_and_backlog_tables"
    source_table_text <- paste(table_text[c(operating_index[1], backlog_index[1])], collapse = " || ")
  }

  if (filing$ticker == "MDC") {
    filing_text <- str_squish(html_text2(filing_html))
    selected_index <- which(
      str_detect(table_text, regex("OPERATIONAL DATA|OPERATING DATA", ignore_case = TRUE)) &
        str_detect(table_text, regex("Homes closed|Homes delivered", ignore_case = TRUE)) &
        str_detect(table_text, fixed(as.character(filing$fiscal_year)))
    )

    if (length(selected_index) >= 1) {
      selected_text <- table_text[selected_index[1]]
      deliveries_units <- parse_number(str_match(selected_text, regex("Homes (?:closed|delivered).*?([0-9][0-9,]+)", ignore_case = TRUE))[, 2])
      average_selling_price_dollars <- 1000 * parse_number(str_match(selected_text, regex("Average selling price(?: per home closed)?\\s+\\$\\s*([0-9,.]+)", ignore_case = TRUE))[, 2])
      orders_units <- parse_number(str_match(selected_text, regex("(?:Orders for homes?|Net new orders).*?([0-9][0-9,]+)", ignore_case = TRUE))[, 2])
      backlog_units <- parse_number(str_match(selected_text, regex("Homes in backlog at period end.*?([0-9][0-9,]+)", ignore_case = TRUE))[, 2])
      backlog_value_thousands <- parse_number(str_match(selected_text, regex("Estimated [Bb]acklog sales value at period end\\s+\\$\\s*([0-9,]+)", ignore_case = TRUE))[, 2])
      active_communities <- parse_number(str_match(selected_text, regex("Active subdivisions at (?:year|period)-end\\s+([0-9,]+)", ignore_case = TRUE))[, 2])
      average_community_count <- parse_number(str_match(selected_text, regex("Average active subdivisions\\s+([0-9,]+)", ignore_case = TRUE))[, 2])
      source_table_text <- selected_text
      extraction_method <- "mdc_five_year_operating_data"
    } else {
      orders_section <- str_extract(filing_text, regex("Net New Orders and Active Subdivisions:.*?For the (?:year|twelve months)", ignore_case = TRUE))
      deliveries_section <- str_extract(filing_text, regex("New Home Deliveries & Home Sale Revenues:.*?For the (?:year|twelve months)", ignore_case = TRUE))
      backlog_section <- str_extract(filing_text, regex("Backlog:.*?Homes Completed or Under Construction", ignore_case = TRUE))

      orders_match <- str_match(orders_section, regex("Total\\s+([0-9,]+)\\s+\\$\\s*([0-9,]+)\\s+\\$\\s*([0-9,.]+)", ignore_case = TRUE))
      deliveries_match <- str_match(deliveries_section, regex("Total\\s+([0-9,]+)\\s+\\$\\s*([0-9,]+)\\s+\\$\\s*([0-9,.]+)", ignore_case = TRUE))
      backlog_match <- str_match(backlog_section, regex("Total\\s+([0-9,]+)\\s+\\$\\s*([0-9,]+)\\s+\\$\\s*([0-9,.]+)", ignore_case = TRUE))

      orders_units <- parse_number(orders_match[, 2])
      orders_value_thousands <- parse_number(orders_match[, 3])
      deliveries_units <- parse_number(deliveries_match[, 2])
      deliveries_value_thousands <- parse_number(deliveries_match[, 3])
      average_selling_price_dollars <- 1000 * parse_number(deliveries_match[, 4])
      homebuilding_revenue_thousands <- deliveries_value_thousands
      backlog_units <- parse_number(backlog_match[, 2])
      backlog_value_thousands <- parse_number(backlog_match[, 3])

      community_match <- str_match(orders_section, regex("Total\\s+([0-9,]+)\\s+[0-9,]+.*?Total\\s+([0-9,]+)\\s+[0-9,]+", ignore_case = TRUE))
      active_communities <- parse_number(community_match[, 2])
      average_community_count <- parse_number(community_match[, 3])
      source_table_text <- paste(orders_section, deliveries_section, backlog_section, collapse = " || ")
      extraction_method <- "mdc_mda_total_operating_sections"
    }

    orders_raw_label <- "Net new orders"
    deliveries_raw_label <- if_else(length(selected_index) >= 1, "Homes closed", "Homes delivered")
  }

  rows[[i]] <- tibble(
    ticker = filing$ticker,
    company = case_when(
      filing$ticker == "BZH" ~ "Beazer Homes",
      filing$ticker == "MHO" ~ "M/I Homes",
      filing$ticker == "MTH" ~ "Meritage Homes",
      filing$ticker == "TOL" ~ "Toll Brothers",
      filing$ticker == "MDC" ~ "M.D.C. Holdings"
    ),
    cik10 = filing$cik10,
    fiscal_year = filing$fiscal_year,
    report_date = filing$report_date,
    filing_date = filing$filing_date,
    accession_number = filing$accession_number,
    orders_units,
    orders_value_thousands,
    orders_raw_label,
    deliveries_units,
    deliveries_value_thousands,
    deliveries_raw_label,
    backlog_units,
    backlog_value_thousands,
    cancellation_rate_pct,
    active_communities,
    average_community_count,
    average_selling_price_dollars,
    homebuilding_revenue_thousands,
    source_scope,
    extraction_method,
    filing_url = filing$filing_url,
    source_local_path = filing$primary_document_local_path,
    source_checksum_sha256 = filing$primary_document_checksum_sha256,
    source_table_text
  )
}

panel <- bind_rows(rows) |>
  arrange(ticker, fiscal_year)

if (nrow(panel) != 99 || panel |> count(ticker, fiscal_year) |> filter(n != 1) |> nrow() > 0) {
  stop("Annual operating panel is not unique and complete by target firm-year.")
}

write_csv_if_changed(panel, "../output/five_firm_2006_2025_annual_operating_panel.csv")

cat("Wrote five-firm annual operating panel to ../output\n")
