# setwd("/Users/jacobherbstman/Desktop/homebuilder_10ks/tasks/extract_six_firm_annual_operating_disclosures/code")

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
    ticker %in% c("DHI", "LEN", "PHM", "KBH", "HOV", "NVR"),
    form == "10-K",
    fiscal_year %in% 2006:2025
  ) |>
  arrange(ticker, fiscal_year)

if (nrow(inventory) != 120 || inventory |> count(ticker, fiscal_year) |> filter(n != 1) |> nrow() > 0) {
  stop("Expected one annual 10-K for each of six firms in every fiscal year from 2006 through 2025.")
}

if (any(!file.exists(inventory$primary_document_local_path))) {
  stop("At least one required six-firm annual 10-K HTML file is missing.")
}

dhi_total_row_pattern <- paste0(
  "([0-9][0-9,]*)\\s+[0-9][0-9,]*\\s+",
  "(?:\\([0-9]+\\s*\\)|[0-9]+|—)\\s*%\\s*\\$\\s*([0-9,.]+)\\s*\\$?\\s*[0-9,.]+\\s+",
  "(?:\\([0-9]+\\s*\\)|[0-9]+|—)\\s*%\\s*\\$\\s*([0-9,]+)"
)

candidate_rows <- vector("list", nrow(inventory))

for (i in seq_len(nrow(inventory))) {
  filing <- inventory[i, ]
  filing_html <- read_html(filing$primary_document_local_path)
  filing_tables <- html_elements(filing_html, "table")
  table_text <- vapply(filing_tables, function(x) str_squish(html_text2(x)), character(1))
  filing_text <- NA_character_
  if (filing$ticker %in% c("HOV", "LEN")) {
    filing_text <- str_squish(html_text2(filing_html))
  }

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
  orders_source_table_text <- NA_character_
  deliveries_source_table_text <- NA_character_
  backlog_source_table_text <- NA_character_
  community_source_table_text <- NA_character_
  extraction_method <- NA_character_
  extraction_confidence <- "high"
  manual_review_flag <- FALSE
  manual_review_reason <- NA_character_

  if (filing$ticker == "DHI") {
    orders_index <- which(
      str_detect(table_text, regex("^Net Sales Orders", ignore_case = TRUE)) &
        str_detect(table_text, fixed(as.character(filing$fiscal_year)))
    )
    backlog_index <- which(
      str_detect(table_text, regex("^Sales Order Backlog", ignore_case = TRUE)) &
        str_detect(table_text, fixed(as.character(filing$fiscal_year)))
    )
    deliveries_index <- which(
      str_detect(table_text, regex("^Homes Closed|^Home Closings", ignore_case = TRUE)) &
        str_detect(table_text, fixed(as.character(filing$fiscal_year)))
    )

    if (length(orders_index) >= 1 && length(backlog_index) >= 1 && length(deliveries_index) >= 1) {
      orders_source_table_text <- table_text[orders_index[1]]
      backlog_source_table_text <- table_text[backlog_index[1]]
      deliveries_source_table_text <- table_text[deliveries_index[1]]
      orders_match <- str_match_all(orders_source_table_text, dhi_total_row_pattern)[[1]]
      backlog_match <- str_match_all(backlog_source_table_text, dhi_total_row_pattern)[[1]]
      deliveries_match <- str_match_all(deliveries_source_table_text, dhi_total_row_pattern)[[1]]

      if (nrow(orders_match) > 0) {
        orders_units <- parse_number(orders_match[nrow(orders_match), 2])
        orders_value_thousands <- 1000 * parse_number(orders_match[nrow(orders_match), 3])
      }
      if (nrow(backlog_match) > 0) {
        backlog_units <- parse_number(backlog_match[nrow(backlog_match), 2])
        backlog_value_thousands <- 1000 * parse_number(backlog_match[nrow(backlog_match), 3])
      }
      if (nrow(deliveries_match) > 0) {
        deliveries_units <- parse_number(deliveries_match[nrow(deliveries_match), 2])
        deliveries_value_thousands <- 1000 * parse_number(deliveries_match[nrow(deliveries_match), 3])
        average_selling_price_dollars <- parse_number(deliveries_match[nrow(deliveries_match), 4])
        homebuilding_revenue_thousands <- deliveries_value_thousands
      }

      if (is.na(orders_units)) {
        orders_units_match <- str_match(
          orders_source_table_text,
          regex("([0-9][0-9,]*)\\s+[0-9][0-9,]*\\s+[0-9][0-9,]*\\s+(?:\\([0-9]+\\s*\\)|[0-9]+|—)\\s*%\\s+(?:\\([0-9]+\\s*\\)|[0-9]+|—)\\s*%\\s+Value", ignore_case = TRUE)
        )
        orders_value_match <- str_match(
          orders_source_table_text,
          regex("\\$\\s*([0-9,.]+)\\s+\\$?\\s*[0-9,.]+\\s+\\$?\\s*[0-9,.]+\\s+(?:\\([0-9]+\\s*\\)|[0-9]+|—)\\s*%\\s+(?:\\([0-9]+\\s*\\)|[0-9]+|—)\\s*%\\s+Average Selling Price", ignore_case = TRUE)
        )
        orders_units <- parse_number(orders_units_match[, 2])
        orders_value_thousands <- 1000 * parse_number(orders_value_match[, 2])
      }
      if (is.na(backlog_units)) {
        backlog_units_match <- str_match(
          backlog_source_table_text,
          regex("([0-9][0-9,]*)\\s+[0-9][0-9,]*\\s+[0-9][0-9,]*\\s+(?:\\([0-9]+\\s*\\)|[0-9]+|—)\\s*%\\s+(?:\\([0-9]+\\s*\\)|[0-9]+|—)\\s*%\\s+Value", ignore_case = TRUE)
        )
        backlog_value_match <- str_match(
          backlog_source_table_text,
          regex("\\$\\s*([0-9,.]+)\\s+\\$?\\s*[0-9,.]+\\s+\\$?\\s*[0-9,.]+\\s+(?:\\([0-9]+\\s*\\)|[0-9]+|—)\\s*%\\s+(?:\\([0-9]+\\s*\\)|[0-9]+|—)\\s*%\\s+Average Selling Price", ignore_case = TRUE)
        )
        backlog_units <- parse_number(backlog_units_match[, 2])
        backlog_value_thousands <- 1000 * parse_number(backlog_value_match[, 2])
      }
      if (is.na(deliveries_units)) {
        deliveries_units_match <- str_match(
          deliveries_source_table_text,
          regex("([0-9][0-9,]*)\\s+[0-9][0-9,]*\\s+[0-9][0-9,]*\\s+(?:\\([0-9]+\\s*\\)|[0-9]+|—)\\s*%\\s+(?:\\([0-9]+\\s*\\)|[0-9]+|—)\\s*%\\s+Home Sales Revenue", ignore_case = TRUE)
        )
        deliveries_value_match <- str_match(
          deliveries_source_table_text,
          regex("\\$\\s*([0-9,.]+)\\s+\\$?\\s*[0-9,.]+\\s+\\$?\\s*[0-9,.]+\\s+(?:\\([0-9]+\\s*\\)|[0-9]+|—)\\s*%\\s+(?:\\([0-9]+\\s*\\)|[0-9]+|—)\\s*%\\s+Average Selling Price", ignore_case = TRUE)
        )
        deliveries_asp_match <- str_match_all(
          deliveries_source_table_text,
          regex("\\$\\s*([0-9,]+)\\s+\\$?\\s*[0-9,]+\\s+\\$?\\s*[0-9,]+\\s+(?:\\([0-9]+\\s*\\)|[0-9]+|—)\\s*%\\s+(?:\\([0-9]+\\s*\\)|[0-9]+|—)\\s*%", ignore_case = TRUE)
        )[[1]]
        deliveries_units <- parse_number(deliveries_units_match[, 2])
        deliveries_value_thousands <- 1000 * parse_number(deliveries_value_match[, 2])
        if (nrow(deliveries_asp_match) > 0) {
          average_selling_price_dollars <- parse_number(deliveries_asp_match[nrow(deliveries_asp_match), 2])
        }
        homebuilding_revenue_thousands <- deliveries_value_thousands
      }
    }

    orders_raw_label <- "Net homes sold / net sales orders"
    deliveries_raw_label <- "Homes closed"
    extraction_method <- "dhi_annual_total_rows"
  }

  if (filing$ticker == "PHM") {
    supplemental_index <- which(
      str_detect(table_text, regex("Net new orders", ignore_case = TRUE)) &
        str_detect(table_text, regex("Backlog", ignore_case = TRUE)) &
        str_detect(table_text, fixed(as.character(filing$fiscal_year))) &
        str_detect(table_text, regex("Closings|settlements", ignore_case = TRUE))
    )

    if (length(supplemental_index) >= 1) {
      detailed_supplemental_index <- supplemental_index[
        str_detect(table_text[supplemental_index], regex("Dollars", ignore_case = TRUE)) &
          str_detect(table_text[supplemental_index], regex("Backlog at", ignore_case = TRUE))
      ]
      if (length(detailed_supplemental_index) >= 1) {
        supplemental_text <- table_text[detailed_supplemental_index[1]]
      } else {
        supplemental_text <- table_text[supplemental_index[1]]
      }
      deliveries_source_table_text <- supplemental_text
      orders_source_table_text <- supplemental_text
      backlog_source_table_text <- supplemental_text

      deliveries_match <- str_match(
        supplemental_text,
        regex("(?:Closings \\(units\\)|Unit settlements|Total settlements[^0-9]*units)\\s+([0-9,]+)", ignore_case = TRUE)
      )
      asp_match <- str_match(supplemental_text, regex("Average selling price\\s+\\$\\s*([0-9,]+)", ignore_case = TRUE))
      orders_match <- str_match(
        supplemental_text,
        regex("(?:Net new orders|Total net new orders)[^0-9]{0,40}(?:Units|units)?[^0-9]*([0-9,]+)", ignore_case = TRUE)
      )
      orders_value_match <- str_match(
        supplemental_text,
        regex("Net new orders.*?Dollars(?:\\s+\\([^)]*\\))?\\s+\\$\\s*([0-9,]+)", ignore_case = TRUE)
      )
      cancellation_match <- str_match(supplemental_text, regex("Cancellation rate\\s+([0-9.]+)\\s*%", ignore_case = TRUE))
      community_match <- str_match(
        supplemental_text,
        regex("(?:Average active communities|Active communities at (?:December 31|year-end)|Active communities|Total active communities)\\s+([0-9,]+)", ignore_case = TRUE)
      )
      backlog_match <- str_match(supplemental_text, regex("Backlog[^:]*:?\\s+Units\\s+([0-9,]+)", ignore_case = TRUE))
      backlog_value_match <- str_match(
        supplemental_text,
        regex("Backlog.*?Dollars\\s+\\$\\s*([0-9,]+)", ignore_case = TRUE)
      )
      revenue_match <- str_match(
        supplemental_text,
        regex("Home sale revenue(?:s| \\(settlements\\))?\\s+\\$\\s*([0-9,]+)", ignore_case = TRUE)
      )

      deliveries_units <- parse_number(deliveries_match[, 2])
      orders_units <- parse_number(orders_match[, 2])
      orders_value_thousands <- parse_number(orders_value_match[, 2])
      backlog_units <- parse_number(backlog_match[, 2])
      backlog_value_thousands <- parse_number(backlog_value_match[, 2])
      cancellation_rate_pct <- parse_number(cancellation_match[, 2])
      active_communities <- parse_number(community_match[, 2])
      average_selling_price_dollars <- 1000 * parse_number(asp_match[, 2])
      homebuilding_revenue_thousands <- parse_number(revenue_match[, 2])
    }

    orders_raw_label <- "Net new orders"
    deliveries_raw_label <- if_else(filing$fiscal_year <= 2006, "Unit settlements", "Closings")
    extraction_method <- "phm_annual_supplemental_data"
  }

  if (filing$ticker == "NVR") {
    operating_index <- which(
      str_detect(table_text, fixed("Settlements (units)", ignore_case = TRUE)) &
        str_detect(table_text, fixed("New orders (units)", ignore_case = TRUE)) &
        str_detect(table_text, fixed("Backlog (units)", ignore_case = TRUE)) &
        str_detect(table_text, fixed(as.character(filing$fiscal_year)))
    )

    aggregate_index <- operating_index[
      str_detect(table_text[operating_index], regex("Cost of sales|Operating data", ignore_case = TRUE)) |
        str_count(table_text[operating_index], fixed("Settlements (units)", ignore_case = TRUE)) == 1
    ]

    if (length(aggregate_index) >= 1) {
      operating_text <- table_text[aggregate_index[1]]
      orders_match <- str_match(operating_text, regex("New orders \\(units\\)\\s+([0-9,]+)", ignore_case = TRUE))
      order_price_match <- str_match(operating_text, regex("Average new order price\\s+\\$\\s*([0-9.]+)", ignore_case = TRUE))
      deliveries_match <- str_match(operating_text, regex("Settlements \\(units\\)\\s+([0-9,]+)", ignore_case = TRUE))
      delivery_price_match <- str_match(operating_text, regex("Average settlement price\\s+\\$\\s*([0-9.]+)", ignore_case = TRUE))
      backlog_match <- str_match(operating_text, regex("Backlog \\(units\\)\\s+([0-9,]+)", ignore_case = TRUE))
      backlog_price_match <- str_match(operating_text, regex("Average backlog price\\s+\\$\\s*([0-9.]+)", ignore_case = TRUE))
      cancellation_match <- str_match(operating_text, regex("New order cancellation rate\\s+([0-9.]+)\\s*%", ignore_case = TRUE))
      revenue_match <- str_match(operating_text, regex("Revenues\\s+\\$\\s*([0-9,]+)", ignore_case = TRUE))

      orders_units <- parse_number(orders_match[, 2])
      deliveries_units <- parse_number(deliveries_match[, 2])
      backlog_units <- parse_number(backlog_match[, 2])
      orders_value_thousands <- orders_units * parse_number(order_price_match[, 2])
      deliveries_value_thousands <- deliveries_units * parse_number(delivery_price_match[, 2])
      backlog_value_thousands <- backlog_units * parse_number(backlog_price_match[, 2])
      cancellation_rate_pct <- parse_number(cancellation_match[, 2])
      average_selling_price_dollars <- 1000 * parse_number(delivery_price_match[, 2])
      homebuilding_revenue_thousands <- parse_number(revenue_match[, 2])
      orders_source_table_text <- operating_text
      deliveries_source_table_text <- operating_text
      backlog_source_table_text <- operating_text
    } else if (length(operating_index) >= 1) {
      operating_text <- paste(table_text[operating_index], collapse = " ")
      order_matches <- str_match_all(operating_text, regex("New orders \\(units\\)\\s+([0-9,]+)", ignore_case = TRUE))[[1]]
      order_price_matches <- str_match_all(operating_text, regex("Average new order price\\s+\\$\\s*([0-9.]+)", ignore_case = TRUE))[[1]]
      delivery_matches <- str_match_all(operating_text, regex("Settlements \\(units\\)\\s+([0-9,]+)", ignore_case = TRUE))[[1]]
      delivery_price_matches <- str_match_all(operating_text, regex("Average settlement price\\s+\\$\\s*([0-9.]+)", ignore_case = TRUE))[[1]]
      backlog_matches <- str_match_all(operating_text, regex("Backlog \\(units\\)\\s+([0-9,]+)", ignore_case = TRUE))[[1]]
      backlog_price_matches <- str_match_all(operating_text, regex("Average backlog price\\s+\\$\\s*([0-9.]+)", ignore_case = TRUE))[[1]]
      revenue_matches <- str_match_all(operating_text, regex("Revenues\\s+\\$\\s*([0-9,]+)", ignore_case = TRUE))[[1]]

      orders_by_segment <- parse_number(order_matches[, 2])
      deliveries_by_segment <- parse_number(delivery_matches[, 2])
      backlog_by_segment <- parse_number(backlog_matches[, 2])
      orders_units <- sum(orders_by_segment)
      deliveries_units <- sum(deliveries_by_segment)
      backlog_units <- sum(backlog_by_segment)
      orders_value_thousands <- sum(orders_by_segment * parse_number(order_price_matches[, 2]))
      deliveries_value_thousands <- sum(deliveries_by_segment * parse_number(delivery_price_matches[, 2]))
      backlog_value_thousands <- sum(backlog_by_segment * parse_number(backlog_price_matches[, 2]))
      average_selling_price_dollars <- 1000 * deliveries_value_thousands / deliveries_units
      homebuilding_revenue_thousands <- sum(parse_number(revenue_matches[, 2]))
      orders_source_table_text <- operating_text
      deliveries_source_table_text <- operating_text
      backlog_source_table_text <- operating_text
      extraction_method <- "nvr_complete_segment_sum"
    }

    community_index <- which(
      str_detect(table_text, regex("Average active communities", ignore_case = TRUE)) &
        str_detect(table_text, fixed(as.character(filing$fiscal_year)))
    )
    if (length(community_index) >= 1) {
      community_text <- paste(table_text[community_index], collapse = " ")
      community_total_match <- str_match(community_text, regex("Total\\s+([0-9,]+)", ignore_case = TRUE))
      if (!is.na(community_total_match[, 2])) {
        average_community_count <- parse_number(community_total_match[, 2])
      } else {
        community_matches <- str_match_all(
          community_text,
          regex("Average active communities\\s+([0-9,]+)", ignore_case = TRUE)
        )[[1]]
        if (nrow(community_matches) > 0) {
          average_community_count <- sum(parse_number(community_matches[, 2]))
        }
      }
      community_source_table_text <- community_text
    }

    orders_raw_label <- "New orders"
    deliveries_raw_label <- "Settlements"
    if (is.na(extraction_method)) extraction_method <- "nvr_annual_operating_data"
  }

  if (filing$ticker == "KBH") {
    summary_index <- which(
      str_detect(table_text, regex("Homebuilding Data", ignore_case = TRUE)) &
        str_detect(table_text, regex("Homes delivered", ignore_case = TRUE)) &
        str_detect(table_text, regex("Net orders", ignore_case = TRUE)) &
        str_detect(table_text, fixed(as.character(filing$fiscal_year)))
    )
    if (length(summary_index) >= 1) {
      summary_text <- table_text[summary_index[1]]
      deliveries_units <- parse_number(str_match(summary_text, regex("Homes delivered\\s*([0-9,]+)", ignore_case = TRUE))[, 2])
      average_selling_price_dollars <- parse_number(str_match(summary_text, regex("Average selling price\\s*\\$?\\s*([0-9,]+)", ignore_case = TRUE))[, 2])
      orders_units <- parse_number(str_match(summary_text, regex("Net orders\\s*([0-9,]+)", ignore_case = TRUE))[, 2])
      backlog_units <- parse_number(str_match(summary_text, regex("(?:Ending backlog[^—-]*[—-] homes|Unit backlog)\\s*([0-9,]+)", ignore_case = TRUE))[, 2])
      average_community_count <- parse_number(str_match(summary_text, regex("Average community count\\s*([0-9,]+)", ignore_case = TRUE))[, 2])
      homebuilding_revenue_thousands <- parse_number(str_match(summary_text, regex("Revenues:\\s*Homebuilding\\s*\\$?\\s*([0-9,]+)", ignore_case = TRUE))[, 2])
      orders_source_table_text <- summary_text
      deliveries_source_table_text <- summary_text
      backlog_source_table_text <- summary_text
    }

    if (filing$fiscal_year <= 2011) {
      early_operating_index <- which(
        str_detect(table_text, regex("Homes delivered|Unit deliveries", ignore_case = TRUE)) &
          str_detect(table_text, regex("Net orders", ignore_case = TRUE)) &
          str_detect(table_text, fixed(as.character(filing$fiscal_year)))
      )
      if (length(early_operating_index) >= 1) {
        early_operating_table <- html_table(filing_tables[[early_operating_index[1]]], header = FALSE, fill = TRUE)
        early_labels <- str_squish(as.character(early_operating_table[[1]]))

        deliveries_label_row <- which(str_detect(early_labels, regex("^Homes delivered$|^Unit deliveries$", ignore_case = TRUE)))[1]
        deliveries_year_row <- which(seq_along(early_labels) > deliveries_label_row & early_labels == as.character(filing$fiscal_year))[1]
        deliveries_total_row <- which(seq_along(early_labels) > deliveries_year_row & early_labels == "Total")[1]
        deliveries_cells <- str_squish(as.character(early_operating_table[deliveries_total_row, ]))
        deliveries_numeric_cells <- which(str_detect(deliveries_cells, "^[0-9][0-9,]*$"))
        deliveries_values <- parse_number(deliveries_cells[deliveries_numeric_cells])
        consolidated_position <- NA_integer_
        for (j in 2:length(deliveries_values)) {
          if (deliveries_values[j] == sum(deliveries_values[seq_len(j - 1)])) {
            consolidated_position <- j
            break
          }
        }
        if (!is.na(consolidated_position)) deliveries_units <- deliveries_values[consolidated_position]

        orders_label_row <- which(str_detect(early_labels, regex("^Net orders$", ignore_case = TRUE)))[1]
        orders_year_row <- which(seq_along(early_labels) > orders_label_row & early_labels == as.character(filing$fiscal_year))[1]
        orders_total_row <- which(seq_along(early_labels) > orders_year_row & early_labels == "Total")[1]
        orders_cells <- str_squish(as.character(early_operating_table[orders_total_row, ]))
        orders_values <- parse_number(orders_cells[str_detect(orders_cells, "^[0-9][0-9,]*$")])
        if (!is.na(consolidated_position) && length(orders_values) >= consolidated_position) {
          orders_units <- orders_values[consolidated_position]
        }

        early_secondary_index <- which(
          str_detect(table_text, regex("Cancellation rates?|Ending backlog", ignore_case = TRUE)) &
            str_detect(table_text, fixed(as.character(filing$fiscal_year)))
        )
        early_secondary_table <- early_operating_table
        early_secondary_labels <- early_labels
        if (!any(str_detect(early_labels, regex("Cancellation rates?|Ending backlog", ignore_case = TRUE))) && length(early_secondary_index) >= 1) {
          early_secondary_table <- html_table(filing_tables[[early_secondary_index[1]]], header = FALSE, fill = TRUE)
          early_secondary_labels <- str_squish(as.character(early_secondary_table[[1]]))
        }

        cancellation_label_row <- which(str_detect(early_secondary_labels, regex("^Cancellation rates?", ignore_case = TRUE)))[1]
        if (!is.na(cancellation_label_row)) {
          cancellation_year_row <- which(seq_along(early_secondary_labels) > cancellation_label_row & early_secondary_labels == as.character(filing$fiscal_year))[1]
          cancellation_total_row <- which(seq_along(early_secondary_labels) > cancellation_year_row & early_secondary_labels == "Total")[1]
          cancellation_cells <- str_squish(as.character(early_secondary_table[cancellation_total_row, ]))
          cancellation_values <- parse_number(cancellation_cells[str_detect(cancellation_cells, "^[0-9][0-9,]*%?$")])
          if (!is.na(consolidated_position) && length(cancellation_values) >= consolidated_position) {
            cancellation_rate_pct <- cancellation_values[consolidated_position]
          }
        }

        backlog_label_row <- which(str_detect(early_secondary_labels, regex("^Ending backlog.*(?:homes|units)", ignore_case = TRUE)))[1]
        if (!is.na(backlog_label_row)) {
          backlog_year_row <- which(seq_along(early_secondary_labels) > backlog_label_row & early_secondary_labels == as.character(filing$fiscal_year))[1]
          backlog_fourth_row <- which(seq_along(early_secondary_labels) > backlog_year_row & str_detect(early_secondary_labels, regex("^Fourth", ignore_case = TRUE)))[1]
          backlog_cells <- str_squish(as.character(early_secondary_table[backlog_fourth_row, ]))
          backlog_values <- parse_number(backlog_cells[str_detect(backlog_cells, "^[0-9][0-9,]*$")])
          if (!is.na(consolidated_position) && length(backlog_values) >= consolidated_position) {
            backlog_units <- backlog_values[consolidated_position]
          }
        }

        backlog_value_label_row <- which(str_detect(early_secondary_labels, regex("^Ending backlog.*value", ignore_case = TRUE)))[1]
        if (!is.na(backlog_value_label_row)) {
          backlog_value_year_row <- which(seq_along(early_secondary_labels) > backlog_value_label_row & early_secondary_labels == as.character(filing$fiscal_year))[1]
          backlog_value_fourth_row <- which(seq_along(early_secondary_labels) > backlog_value_year_row & str_detect(early_secondary_labels, regex("^Fourth", ignore_case = TRUE)))[1]
          backlog_value_cells <- str_squish(as.character(early_secondary_table[backlog_value_fourth_row, ]))
          backlog_values_dollars <- parse_number(backlog_value_cells[str_detect(backlog_value_cells, "^[0-9][0-9,]*$")])
          if (!is.na(consolidated_position) && length(backlog_values_dollars) >= consolidated_position) {
            backlog_value_thousands <- backlog_values_dollars[consolidated_position]
          }
        }

        if (is.na(backlog_value_thousands)) {
          early_backlog_value_index <- which(
            str_detect(table_text, regex("Ending backlog.*value", ignore_case = TRUE)) &
              str_detect(table_text, fixed(as.character(filing$fiscal_year)))
          )
          if (length(early_backlog_value_index) >= 1) {
            early_backlog_value_table <- html_table(filing_tables[[early_backlog_value_index[1]]], header = FALSE, fill = TRUE)
            early_backlog_value_labels <- str_squish(as.character(early_backlog_value_table[[1]]))
            early_backlog_value_label_row <- which(str_detect(early_backlog_value_labels, regex("^Ending backlog.*value", ignore_case = TRUE)))[1]
            early_backlog_value_year_row <- which(seq_along(early_backlog_value_labels) > early_backlog_value_label_row & early_backlog_value_labels == as.character(filing$fiscal_year))[1]
            early_backlog_value_fourth_row <- which(seq_along(early_backlog_value_labels) > early_backlog_value_year_row & str_detect(early_backlog_value_labels, regex("^Fourth", ignore_case = TRUE)))[1]
            early_backlog_value_cells <- str_squish(as.character(early_backlog_value_table[early_backlog_value_fourth_row, ]))
            early_backlog_values <- parse_number(early_backlog_value_cells[str_detect(early_backlog_value_cells, "^[0-9][0-9,]*$")])
            if (!is.na(consolidated_position) && length(early_backlog_values) >= consolidated_position) {
              backlog_value_thousands <- early_backlog_values[consolidated_position]
            }
          }
        }

        orders_source_table_text <- table_text[early_operating_index[1]]
        deliveries_source_table_text <- table_text[early_operating_index[1]]
        backlog_source_table_text <- table_text[early_operating_index[1]]
      }
    }

    if (filing$fiscal_year >= 2024) {
      recent_detail_index <- which(
        str_detect(table_text, regex("Net order value", ignore_case = TRUE)) &
          str_detect(table_text, regex("Ending backlog", ignore_case = TRUE)) &
          str_detect(table_text, fixed(as.character(filing$fiscal_year)))
      )
      if (length(recent_detail_index) == 1) {
        recent_detail_table <- html_table(filing_tables[[recent_detail_index]], header = FALSE, fill = TRUE)
        recent_detail_year_row <- which(apply(recent_detail_table, 1, function(x) any(str_squish(as.character(x)) == as.character(filing$fiscal_year))))[1]
        recent_detail_year_column <- which(str_squish(as.character(recent_detail_table[recent_detail_year_row, ])) == as.character(filing$fiscal_year))[1]
        recent_detail_labels <- str_squish(as.character(recent_detail_table[[1]]))
        orders_units <- parse_number(recent_detail_table[which(recent_detail_labels == "Net orders")[1], recent_detail_year_column][[1]])
        orders_value_thousands <- parse_number(recent_detail_table[which(str_detect(recent_detail_labels, regex("^Net order value", ignore_case = TRUE)))[1], recent_detail_year_column][[1]])
        cancellation_rate_pct <- parse_number(recent_detail_table[which(str_detect(recent_detail_labels, regex("^Cancellation rate", ignore_case = TRUE)))[1], recent_detail_year_column][[1]])
        backlog_units <- parse_number(recent_detail_table[which(str_detect(recent_detail_labels, regex("^Ending backlog.*homes", ignore_case = TRUE)))[1], recent_detail_year_column][[1]])
        backlog_value_thousands <- parse_number(recent_detail_table[which(str_detect(recent_detail_labels, regex("^Ending backlog.*value", ignore_case = TRUE)))[1], recent_detail_year_column][[1]])
        active_communities <- parse_number(recent_detail_table[which(recent_detail_labels == "Ending community count")[1], recent_detail_year_column][[1]])
        average_community_count <- parse_number(recent_detail_table[which(recent_detail_labels == "Average community count")[1], recent_detail_year_column][[1]])
        orders_source_table_text <- table_text[recent_detail_index]
        backlog_source_table_text <- table_text[recent_detail_index]
        community_source_table_text <- table_text[recent_detail_index]
      }

      recent_delivery_index <- which(
        str_detect(table_text, regex("Homes delivered", ignore_case = TRUE)) &
          str_detect(table_text, regex("Average selling price", ignore_case = TRUE)) &
          !str_detect(table_text, regex("Net orders", ignore_case = TRUE)) &
          str_detect(table_text, fixed(as.character(filing$fiscal_year)))
      )
      if (length(recent_delivery_index) >= 1) {
        recent_delivery_table <- html_table(filing_tables[[recent_delivery_index[1]]], header = FALSE, fill = TRUE)
        recent_delivery_year_row <- which(apply(recent_delivery_table, 1, function(x) any(str_squish(as.character(x)) == as.character(filing$fiscal_year))))[1]
        recent_delivery_year_column <- which(str_squish(as.character(recent_delivery_table[recent_delivery_year_row, ])) == as.character(filing$fiscal_year))[1]
        recent_delivery_labels <- str_squish(as.character(recent_delivery_table[[1]]))
        deliveries_units <- parse_number(recent_delivery_table[which(recent_delivery_labels == "Homes delivered")[1], recent_delivery_year_column][[1]])
        average_selling_price_dollars <- parse_number(recent_delivery_table[which(recent_delivery_labels == "Average selling price")[1], recent_delivery_year_column][[1]])
        deliveries_source_table_text <- table_text[recent_delivery_index[1]]
      }
    }

    if (is.na(deliveries_units)) {
      consolidated_delivery_index <- which(
        str_detect(table_text, regex("Homes delivered", ignore_case = TRUE)) &
          str_detect(table_text, regex("Average selling price", ignore_case = TRUE)) &
          str_detect(table_text, regex("Operating (?:income|loss) as a percentage of homebuilding revenues", ignore_case = TRUE)) &
          str_detect(table_text, fixed(as.character(filing$fiscal_year)))
      )
      if (length(consolidated_delivery_index) >= 1) {
        consolidated_delivery_text <- table_text[consolidated_delivery_index[1]]
        deliveries_units <- parse_number(str_match(consolidated_delivery_text, regex("Homes delivered\\s+([0-9,]+)", ignore_case = TRUE))[, 2])
        average_selling_price_dollars <- parse_number(str_match(consolidated_delivery_text, regex("Average selling price\\s*\\$?\\s*([0-9,]+)", ignore_case = TRUE))[, 2])
        homebuilding_revenue_thousands <- parse_number(str_match(consolidated_delivery_text, regex("Revenues:\\s*Housing\\s*\\$?\\s*([0-9,]+)", ignore_case = TRUE))[, 2])
        deliveries_value_thousands <- homebuilding_revenue_thousands
        deliveries_source_table_text <- consolidated_delivery_text
      }
    }

    detail_index <- which(
      str_detect(table_text, regex("Net order value", ignore_case = TRUE)) &
        str_detect(table_text, regex("Cancellation rate", ignore_case = TRUE)) &
        str_detect(table_text, regex("Ending backlog", ignore_case = TRUE)) &
        str_detect(table_text, fixed(as.character(filing$fiscal_year)))
    )
    if (length(detail_index) >= 1) {
      detail_text <- table_text[detail_index[1]]
      if (is.na(orders_units)) orders_units <- parse_number(str_match(detail_text, regex("Net orders\\s*([0-9,]+)", ignore_case = TRUE))[, 2])
      orders_value_thousands <- parse_number(str_match(detail_text, regex("Net order value[^$0-9]*\\$?\\s*([0-9,]+)", ignore_case = TRUE))[, 2])
      cancellation_rate_pct <- parse_number(str_match(detail_text, regex("Cancellation rate[^0-9]*([0-9.]+)\\s*%", ignore_case = TRUE))[, 2])
      if (is.na(backlog_units)) backlog_units <- parse_number(str_match(detail_text, regex("Ending backlog[^—-]*[—-] homes\\s*([0-9,]+)", ignore_case = TRUE))[, 2])
      backlog_value_thousands <- parse_number(str_match(detail_text, regex("Ending backlog[^—-]*[—-] value\\s*\\$?\\s*([0-9,]+)", ignore_case = TRUE))[, 2])
      if (is.na(active_communities)) active_communities <- parse_number(str_match(detail_text, regex("Ending community count\\s*([0-9,]+)", ignore_case = TRUE))[, 2])
      if (is.na(average_community_count)) average_community_count <- parse_number(str_match(detail_text, regex("Average community count\\s*([0-9,]+)", ignore_case = TRUE))[, 2])
      orders_source_table_text <- detail_text
      backlog_source_table_text <- detail_text
      community_source_table_text <- detail_text
    }

    if (filing$fiscal_year == 2012 && is.na(average_community_count)) {
      next_filing_path <- inventory |>
        filter(ticker == "KBH", fiscal_year == 2013) |>
        pull(primary_document_local_path)
      next_filing_tables <- read_html(next_filing_path) |>
        html_elements("table")
      next_filing_table_text <- vapply(next_filing_tables, function(x) str_squish(html_text2(x)), character(1))
      comparative_index <- which(
        str_detect(next_filing_table_text, fixed("Years Ended November 30, 2013 2012")) &
          str_detect(next_filing_table_text, fixed("Average community count"))
      )
      if (length(comparative_index) == 1) {
        comparative_match <- str_match(
          next_filing_table_text[comparative_index],
          regex("Average community count\\s+[0-9,]+\\s+([0-9,]+)", ignore_case = TRUE)
        )
        average_community_count <- parse_number(comparative_match[, 2])
        community_source_table_text <- next_filing_table_text[comparative_index]
      }
    }

    orders_raw_label <- "Net orders"
    deliveries_raw_label <- "Homes delivered"
    extraction_method <- "kbh_annual_homebuilding_data"
  }

  if (filing$ticker == "LEN") {
    summary_index <- which(
      str_detect(table_text, regex("Homebuilding Data", ignore_case = TRUE)) &
        str_detect(table_text, regex("homes delivered", ignore_case = TRUE)) &
        str_detect(table_text, regex("New Orders|New orders", ignore_case = TRUE)) &
        str_detect(table_text, fixed(as.character(filing$fiscal_year)))
    )
    if (length(summary_index) >= 1) {
      summary_text <- table_text[summary_index[1]]
      deliveries_units <- parse_number(str_match(summary_text, regex("(?:Number of homes delivered|Homes delivered)\\s+([0-9,]+)", ignore_case = TRUE))[, 2])
      orders_units <- parse_number(str_match(summary_text, regex("New Orders\\s+([0-9,]+)", ignore_case = TRUE))[, 2])
      backlog_units <- parse_number(str_match(summary_text, regex("Backlog of home sales contracts\\s+([0-9,]+)", ignore_case = TRUE))[, 2])
      backlog_value_thousands <- parse_number(str_match(summary_text, regex("Backlog dollar value\\s+\\$\\s*([0-9,]+)", ignore_case = TRUE))[, 2])
      homebuilding_revenue_thousands <- parse_number(str_match(summary_text, regex("Revenues:\\s*(?:Lennar )?Homebuilding\\s+\\$\\s*([0-9,]+)", ignore_case = TRUE))[, 2])
      orders_source_table_text <- summary_text
      deliveries_source_table_text <- summary_text
      backlog_source_table_text <- summary_text
    }

    orders_table_index <- which(
      str_detect(table_text, regex("Active Communities", ignore_case = TRUE)) &
        str_detect(table_text, regex("Dollar Value", ignore_case = TRUE)) &
        str_detect(table_text, fixed(as.character(filing$fiscal_year)))
    )
    if (length(orders_table_index) >= 1) {
      orders_text <- table_text[orders_table_index[1]]
      orders_total_match <- str_match_all(
        orders_text,
        "Total\\s+([0-9,]+)\\s+[0-9,]+\\s+([0-9,]+)\\s+[0-9,]+\\s+\\$\\s*([0-9,]+)"
      )[[1]]
      if (nrow(orders_total_match) > 0) {
        active_communities <- parse_number(orders_total_match[nrow(orders_total_match), 2])
        orders_units <- parse_number(orders_total_match[nrow(orders_total_match), 3])
        orders_value_thousands <- parse_number(orders_total_match[nrow(orders_total_match), 4])
      }
      orders_source_table_text <- orders_text
      community_source_table_text <- orders_text

      if (orders_table_index[1] < length(table_text)) {
        cancellation_text <- table_text[orders_table_index[1] + 1]
        cancellation_total_match <- str_match(cancellation_text, regex("Total\\s+([0-9.]+)\\s*%", ignore_case = TRUE))
        cancellation_rate_pct <- parse_number(cancellation_total_match[, 2])
      }
    }

    if (is.na(cancellation_rate_pct)) {
      cancellation_index <- which(
        str_detect(table_text, regex("Cancellation", ignore_case = TRUE)) &
          str_detect(table_text, regex("Total", ignore_case = TRUE)) &
          str_detect(table_text, fixed(as.character(filing$fiscal_year)))
      )
      if (length(cancellation_index) >= 1) {
        cancellation_text <- paste(table_text[cancellation_index], collapse = " ")
        cancellation_total_matches <- str_match_all(
          cancellation_text,
          regex("Total\\s+([0-9.]+)\\s*%", ignore_case = TRUE)
        )[[1]]
        if (nrow(cancellation_total_matches) > 0) {
          cancellation_rate_pct <- parse_number(cancellation_total_matches[nrow(cancellation_total_matches), 2])
        }
      }
    }

    if (is.na(cancellation_rate_pct)) {
      cancellation_prose_match <- str_match(
        filing_text,
        regex("experienced a cancellation rate of\\s+([0-9.]+)\\s*%\\s+in\\s+[0-9]{4}", ignore_case = TRUE)
      )
      cancellation_rate_pct <- parse_number(cancellation_prose_match[, 2])
    }

    if (is.na(deliveries_units)) {
      delivery_table_index <- which(
        str_detect(table_text, regex("^(?:For the )?Years? Ended", ignore_case = TRUE)) &
          str_detect(table_text, regex("Homes Dollar Value", ignore_case = TRUE)) &
          !str_detect(table_text, regex("Active Communities", ignore_case = TRUE)) &
          str_detect(table_text, fixed(as.character(filing$fiscal_year)))
      )
      if (length(delivery_table_index) >= 1) {
        delivery_text <- table_text[delivery_table_index[1]]
        delivery_total_match <- str_match_all(
          delivery_text,
          "Total\\s+([0-9,]+)\\s+[0-9,]+\\s+\\$\\s*([0-9,]+)"
        )[[1]]
        if (nrow(delivery_total_match) > 0) {
          deliveries_units <- parse_number(delivery_total_match[nrow(delivery_total_match), 2])
          deliveries_value_thousands <- parse_number(delivery_total_match[nrow(delivery_total_match), 3])
          homebuilding_revenue_thousands <- deliveries_value_thousands
        }
        deliveries_source_table_text <- delivery_text
      }
    }

    recent_backlog_index <- which(
      str_detect(table_text, regex("^At November 30, Homes Dollar Value", ignore_case = TRUE)) &
        str_detect(table_text, fixed(as.character(filing$fiscal_year)))
    )
    if (length(recent_backlog_index) >= 1) {
      recent_backlog_text <- table_text[recent_backlog_index[1]]
      backlog_total_match <- str_match_all(
        recent_backlog_text,
        "Total\\s+([0-9,]+)\\s+[0-9,]+\\s+\\$\\s*([0-9,]+)"
      )[[1]]
      if (nrow(backlog_total_match) > 0) {
        backlog_units <- parse_number(backlog_total_match[nrow(backlog_total_match), 2])
        backlog_value_thousands <- parse_number(backlog_total_match[nrow(backlog_total_match), 3])
      }
      backlog_source_table_text <- recent_backlog_text
    }

    orders_raw_label <- "New orders including unconsolidated entities"
    deliveries_raw_label <- "Home deliveries including unconsolidated entities"
    extraction_method <- if_else(length(summary_index) >= 1, "len_annual_homebuilding_summary", "len_recent_separate_operating_tables")
  }

  if (filing$ticker == "HOV") {
    orders_units_match <- str_match(
      filing_text,
      regex("number of homes contracted (?:increased|decreased).*?to\\s+([0-9,]+)\\s+in fiscal", ignore_case = TRUE)
    )
    if (!is.na(orders_units_match[, 2])) {
      orders_units <- parse_number(orders_units_match[, 2])
    }
    if (is.na(orders_units)) {
      orders_units <- parse_number(str_match(
        filing_text,
        regex("Net contracts (?:increased|decreased).*?to\\s+([0-9,]+) for the year ended", ignore_case = TRUE)
      )[, 2])
    }

    delivery_index <- which(
      str_detect(table_text, regex("Consolidated total", ignore_case = TRUE)) &
        str_detect(table_text, regex("Housing revenues", ignore_case = TRUE)) &
        str_detect(table_text, regex("Homes delivered", ignore_case = TRUE)) &
        str_detect(table_text, fixed(as.character(filing$fiscal_year)))
    )
    if (length(delivery_index) >= 1) {
      delivery_text <- table_text[delivery_index[1]]
      delivery_match <- str_match(
        delivery_text,
        regex("Consolidated total:?\\s+Housing revenues\\s+\\$\\s*([0-9,]+).*?Homes delivered\\s+([0-9,]+).*?Average (?:sales )?price\\s+\\$\\s*([0-9,]+)", ignore_case = TRUE)
      )
      homebuilding_revenue_thousands <- parse_number(delivery_match[, 2])
      deliveries_units <- parse_number(delivery_match[, 3])
      average_selling_price_dollars <- parse_number(delivery_match[, 4])
      deliveries_value_thousands <- homebuilding_revenue_thousands
      deliveries_source_table_text <- delivery_text
    }

    contracts_index <- which(
      str_detect(table_text, regex("net sales contracts", ignore_case = TRUE)) &
        str_detect(table_text, regex("Consolidated total", ignore_case = TRUE)) &
        str_detect(table_text, fixed(as.character(filing$fiscal_year)))
    )
    if (length(contracts_index) >= 1) {
      contracts_text <- table_text[contracts_index[1]]
      contracts_match <- str_match(contracts_text, regex("Consolidated total\\s+\\$\\s*([0-9,]+)", ignore_case = TRUE))
      orders_value_thousands <- parse_number(contracts_match[, 2])
      orders_source_table_text <- contracts_text
    }

    quarterly_contracts_index <- which(
      str_detect(table_text, regex("Quarter Ended", ignore_case = TRUE)) &
        str_detect(table_text, regex("Sales contracts \\(net of cancellations\\)", ignore_case = TRUE)) &
        str_detect(table_text, regex("Consolidated total", ignore_case = TRUE)) &
        str_detect(table_text, fixed(as.character(filing$fiscal_year)))
    )
    if (length(quarterly_contracts_index) >= 1) {
      quarterly_contracts_text <- table_text[quarterly_contracts_index[1]]
      quarterly_contracts_match <- str_match(
        quarterly_contracts_text,
        regex("Sales contracts \\(net of cancellations\\):.*?Consolidated total\\s+\\$?\\s*([0-9,]+)\\s+\\$?\\s*([0-9,]+)\\s+\\$?\\s*([0-9,]+)\\s+\\$?\\s*([0-9,]+)", ignore_case = TRUE)
      )
      if (!is.na(quarterly_contracts_match[, 2])) {
        orders_value_thousands <- sum(parse_number(quarterly_contracts_match[, 2:5]))
        orders_source_table_text <- quarterly_contracts_text
      }
    }

    if (filing$fiscal_year >= 2020) {
      annual_contracts_match <- str_match(
        filing_text,
        regex("Information on the dollar value of (?:our )?net sales contracts.*?Consolidated total\\s+\\$\\s*([0-9,]+)", ignore_case = TRUE)
      )
      if (!is.na(annual_contracts_match[, 2])) {
        orders_value_thousands <- parse_number(annual_contracts_match[, 2])
        orders_source_table_text <- str_sub(
          filing_text,
          max(1, str_locate(filing_text, regex("Information on the dollar value of (?:our )?net sales contracts", ignore_case = TRUE))[, 1]),
          str_locate(filing_text, regex("Information on the dollar value of (?:our )?net sales contracts", ignore_case = TRUE))[, 1] + 1500
        )
      }
    }

    backlog_index <- which(
      str_detect(table_text, regex("Total consolidated contract backlog", ignore_case = TRUE)) &
        str_detect(table_text, regex("Number of homes", ignore_case = TRUE)) &
        str_detect(table_text, fixed(as.character(filing$fiscal_year)))
    )
    if (length(backlog_index) >= 1) {
      backlog_text <- table_text[backlog_index[1]]
      backlog_match <- str_match(
        backlog_text,
        regex("Total consolidated contract backlog\\s+\\$\\s*([0-9,]+).*?Number of homes\\s+([0-9,]+)", ignore_case = TRUE)
      )
      backlog_value_thousands <- parse_number(backlog_match[, 2])
      backlog_units <- parse_number(backlog_match[, 3])
      backlog_source_table_text <- backlog_text
    }

    community_index <- which(
      str_detect(table_text, regex("Communities Approved Homes", ignore_case = TRUE)) &
        str_detect(table_text, regex("Remaining Homes Available", ignore_case = TRUE))
    )
    if (length(community_index) >= 1) {
      community_text <- table_text[community_index[1]]
      community_match <- str_match_all(community_text, regex("Total\\s+([0-9,]+)", ignore_case = TRUE))[[1]]
      if (nrow(community_match) > 0) active_communities <- parse_number(community_match[nrow(community_match), 2])
      community_source_table_text <- community_text
    }

    orders_raw_label <- "Number of homes contracted"
    deliveries_raw_label <- "Homes delivered, consolidated"
    extraction_method <- "hov_annual_delivery_contract_backlog_tables"
  }

  if (is.na(deliveries_units) || (is.na(orders_units) && (filing$ticker != "HOV" || filing$fiscal_year >= 2018))) {
    manual_review_flag <- TRUE
    manual_review_reason <- "A core annual operating unit measure was not recovered from the expected firm-era table."
    extraction_confidence <- "low"
  }

  candidate_rows[[i]] <- tibble(
    ticker = filing$ticker,
    company = filing$builder_name_clean,
    cik10 = filing$cik10,
    fiscal_year = filing$fiscal_year,
    report_date = filing$report_date,
    filing_date = filing$filing_date,
    accession_number = filing$accession_number,
    filing_url = filing$filing_url,
    source_local_path = filing$primary_document_local_path,
    source_checksum_sha256 = filing$primary_document_checksum_sha256,
    orders_units,
    orders_value_thousands,
    deliveries_units,
    deliveries_value_thousands,
    backlog_units,
    backlog_value_thousands,
    cancellation_rate_pct,
    active_communities,
    average_community_count,
    average_selling_price_dollars,
    homebuilding_revenue_thousands,
    orders_raw_label,
    deliveries_raw_label,
    extraction_method,
    extraction_confidence,
    manual_review_flag,
    manual_review_reason,
    orders_source_table_text,
    deliveries_source_table_text,
    backlog_source_table_text,
    community_source_table_text
  )
}

candidates <- bind_rows(candidate_rows) |>
  mutate(
    company = case_when(
      ticker == "DHI" ~ "D.R. Horton",
      ticker == "LEN" ~ "Lennar",
      ticker == "PHM" ~ "PulteGroup",
      ticker == "KBH" ~ "KB Home",
      ticker == "HOV" ~ "Hovnanian",
      ticker == "NVR" ~ "NVR"
    ),
    operating_panel_use_flag = !manual_review_flag,
    orders_units_available = !is.na(orders_units),
    source_scope = case_when(
      ticker == "LEN" ~ "Homebuilding including unconsolidated entities",
      ticker == "HOV" ~ "Consolidated homebuilding",
      TRUE ~ "Consolidated homebuilding"
    )
  ) |>
  arrange(ticker, fiscal_year)

operating_panel <- candidates |>
  select(
    ticker,
    company,
    cik10,
    fiscal_year,
    report_date,
    filing_date,
    accession_number,
    orders_units,
    orders_value_thousands,
    orders_units_available,
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
    extraction_confidence,
    manual_review_flag,
    manual_review_reason,
    operating_panel_use_flag,
    filing_url,
    source_local_path,
    source_checksum_sha256
  )

if (nrow(operating_panel) != 120L || operating_panel |> count(ticker, fiscal_year) |> filter(n != 1L) |> nrow() > 0L) {
  stop("Six-firm annual operating panel is not unique and complete for 2006-2025.")
}

if (operating_panel |>
    filter(
      is.na(deliveries_units) |
        is.na(backlog_units) |
        (ticker == "HOV" & fiscal_year < 2018L & is.na(orders_value_thousands)) |
        (is.na(orders_units) & (ticker != "HOV" | fiscal_year >= 2018L))
    ) |>
    nrow() > 0L) {
  stop("Six-firm annual operating panel has a missing core operating value.")
}

if (operating_panel |>
    filter(
      if_any(c(orders_units, deliveries_units, backlog_units), ~ !is.na(.x) & (.x <= 0 | .x > 200000)) |
        (!is.na(cancellation_rate_pct) & (cancellation_rate_pct < 0 | cancellation_rate_pct > 100)) |
        (!is.na(active_communities) & (active_communities <= 0 | active_communities > 5000)) |
        (!is.na(average_community_count) & (average_community_count <= 0 | average_community_count > 5000)) |
        (!is.na(average_selling_price_dollars) & (average_selling_price_dollars < 50000 | average_selling_price_dollars > 2000000))
    ) |>
    nrow() > 0L) {
  stop("Six-firm annual operating panel has an implausible value.")
}

write_csv_if_changed(operating_panel, "../output/six_firm_2006_2025_operating_panel.csv")
write_csv_if_changed(candidates, "../output/six_firm_2006_2025_operating_candidates.csv")

cat("Wrote six-firm annual operating panel and candidates to ../output\n")
