# setwd("/Users/jacobherbstman/Desktop/homebuilder_10ks/tasks/extract_wreco_operating_disclosures/code")

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(rvest)
  library(stringr)
  library(tidyr)
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
  )

source_metadata <- inventory |>
  filter(
    cik10 == "0000106535",
    form == "10-K",
    accession_number %in% c(
      "0001193125-07-044292",
      "0001193125-09-039546",
      "0001193125-10-041278",
      "0000106535-14-000010"
    )
  ) |>
  transmute(
    source_accession_number = accession_number,
    source_filing_date = filing_date,
    source_report_date = report_date,
    source_url = filing_url,
    source_local_path = primary_document_local_path,
    source_checksum_sha256 = primary_document_checksum_sha256
  )

if (nrow(source_metadata) != 4 || n_distinct(source_metadata$source_accession_number) != 4) {
  stop("Expected four distinct Weyerhaeuser source filings for the WRECO operating extraction.")
}

if (any(!file.exists(source_metadata$source_local_path))) {
  stop("At least one required Weyerhaeuser 10-K HTML file is missing.")
}

html_2006 <- read_html(
  source_metadata |>
    filter(source_accession_number == "0001193125-07-044292") |>
    pull(source_local_path)
)
html_2008 <- read_html(
  source_metadata |>
    filter(source_accession_number == "0001193125-09-039546") |>
    pull(source_local_path)
)
html_2009 <- read_html(
  source_metadata |>
    filter(source_accession_number == "0001193125-10-041278") |>
    pull(source_local_path)
)
html_2013 <- read_html(
  source_metadata |>
    filter(source_accession_number == "0000106535-14-000010") |>
    pull(source_local_path)
)

tables_2006 <- html_elements(html_2006, "table")
table_text_2006 <- vapply(
  tables_2006,
  function(x) str_squish(html_text2(x)),
  character(1)
)
tables_2008 <- html_elements(html_2008, "table")
table_text_2008 <- vapply(
  tables_2008,
  function(x) str_squish(html_text2(x)),
  character(1)
)
tables_2009 <- html_elements(html_2009, "table")
table_text_2009 <- vapply(
  tables_2009,
  function(x) str_squish(html_text2(x)),
  character(1)
)
tables_2013 <- html_elements(html_2013, "table")
table_text_2013 <- vapply(
  tables_2013,
  function(x) str_squish(html_text2(x)),
  character(1)
)

key_table_2006_index <- which(
  str_detect(table_text_2006, fixed("DOLLAR AMOUNTS IN MILLIONS, EXCEPT AVERAGE SALES PRICE")) &
    str_detect(table_text_2006, fixed("Net sales and revenues")) &
    str_detect(table_text_2006, fixed("2006")) &
    str_detect(table_text_2006, fixed("2004"))
)
unit_table_2008_index <- which(
  str_detect(table_text_2008, fixed("SINGLE-FAMILY UNIT STATISTICS")) &
    str_detect(table_text_2008, fixed("Homes sold")) &
    str_detect(table_text_2008, fixed("2008")) &
    str_detect(table_text_2008, fixed("2004"))
)
key_table_2008_index <- which(
  str_detect(table_text_2008, fixed("DOLLAR AMOUNTS IN MILLIONS, EXCEPT AVERAGE SALES PRICE")) &
    str_detect(table_text_2008, fixed("Net sales and revenues")) &
    str_detect(table_text_2008, fixed("2008")) &
    str_detect(table_text_2008, fixed("2006"))
)
unit_table_2009_index <- which(
  str_detect(table_text_2009, fixed("SINGLE-FAMILY UNIT STATISTICS")) &
    str_detect(table_text_2009, fixed("Cancellation rate")) &
    str_detect(table_text_2009, fixed("2009")) &
    str_detect(table_text_2009, fixed("2005"))
)
unit_table_2013_index <- which(
  str_detect(table_text_2013, fixed("SINGLE-FAMILY UNIT STATISTICS")) &
    str_detect(table_text_2013, fixed("Cancellation rate")) &
    str_detect(table_text_2013, fixed("2013")) &
    str_detect(table_text_2013, fixed("2009"))
)
revenue_table_2013_index <- which(
  str_detect(table_text_2013, fixed("REVENUE IN MILLIONS OF DOLLARS")) &
    str_detect(table_text_2013, fixed("Single-family housing")) &
    str_detect(table_text_2013, fixed("2013")) &
    str_detect(table_text_2013, fixed("2009"))
)

if (any(c(
  length(key_table_2006_index),
  length(unit_table_2008_index),
  length(key_table_2008_index),
  length(unit_table_2009_index),
  length(unit_table_2013_index),
  length(revenue_table_2013_index)
) != 1)) {
  stop("A WRECO operating table was missing or matched more than once.")
}

key_table_2006 <- html_table(
  tables_2006[[key_table_2006_index]],
  header = FALSE,
  fill = TRUE,
  trim = TRUE
) |>
  mutate(across(everything(), as.character))
unit_table_2008 <- html_table(
  tables_2008[[unit_table_2008_index]],
  header = FALSE,
  fill = TRUE,
  trim = TRUE
) |>
  mutate(across(everything(), as.character))
key_table_2008 <- html_table(
  tables_2008[[key_table_2008_index]],
  header = FALSE,
  fill = TRUE,
  trim = TRUE
) |>
  mutate(across(everything(), as.character))
unit_table_2009 <- html_table(
  tables_2009[[unit_table_2009_index]],
  header = FALSE,
  fill = TRUE,
  trim = TRUE
) |>
  mutate(across(everything(), as.character))
unit_table_2013 <- html_table(
  tables_2013[[unit_table_2013_index]],
  header = FALSE,
  fill = TRUE,
  trim = TRUE
) |>
  mutate(across(everything(), as.character))
revenue_table_2013 <- html_table(
  tables_2013[[revenue_table_2013_index]],
  header = FALSE,
  fill = TRUE,
  trim = TRUE
) |>
  mutate(across(everything(), as.character))

key_table_2006_year_columns <- which(
  str_detect(unlist(key_table_2006[4, ], use.names = FALSE), "^20(04|05|06)$") &
    str_detect(unlist(key_table_2006[8, ], use.names = FALSE), "[0-9]")
)
key_candidates_2006 <- tibble(
  fiscal_year = parse_integer(unlist(key_table_2006[4, key_table_2006_year_columns], use.names = FALSE)),
  homebuilding_revenue_thousands = unlist(key_table_2006[6, key_table_2006_year_columns], use.names = FALSE),
  deliveries_units = unlist(key_table_2006[7, key_table_2006_year_columns], use.names = FALSE),
  average_selling_price_dollars = unlist(key_table_2006[8, key_table_2006_year_columns], use.names = FALSE)
) |>
  pivot_longer(-fiscal_year, names_to = "metric_name", values_to = "raw_value") |>
  mutate(
    numeric_value = parse_number(raw_value),
    numeric_value = if_else(metric_name == "homebuilding_revenue_thousands", numeric_value * 1000, numeric_value),
    scale_factor_applied = if_else(metric_name == "homebuilding_revenue_thousands", 1000, 1),
    source_accession_number = "0001193125-07-044292",
    source_table_label = "single_family_key_data",
    source_table_text = table_text_2006[[key_table_2006_index]]
  )

unit_table_2008_year_columns <- which(
  str_detect(unlist(unit_table_2008[3, ], use.names = FALSE), "^20(04|05|06|07|08)$") &
    str_detect(unlist(unit_table_2008[4, ], use.names = FALSE), "[0-9]")
)
unit_candidates_2008 <- tibble(
  fiscal_year = parse_integer(unlist(unit_table_2008[3, unit_table_2008_year_columns], use.names = FALSE)),
  orders_units = unlist(unit_table_2008[4, unit_table_2008_year_columns], use.names = FALSE),
  deliveries_units = unlist(unit_table_2008[5, unit_table_2008_year_columns], use.names = FALSE),
  backlog_units = unlist(unit_table_2008[6, unit_table_2008_year_columns], use.names = FALSE),
  homebuilding_gross_margin_excluding_impairments_pct = unlist(unit_table_2008[7, unit_table_2008_year_columns], use.names = FALSE)
) |>
  pivot_longer(-fiscal_year, names_to = "metric_name", values_to = "raw_value") |>
  mutate(
    numeric_value = parse_number(raw_value),
    numeric_value = if_else(str_detect(raw_value, fixed("(")), -abs(numeric_value), numeric_value),
    scale_factor_applied = 1,
    source_accession_number = "0001193125-09-039546",
    source_table_label = "single_family_unit_statistics",
    source_table_text = table_text_2008[[unit_table_2008_index]]
  )

key_table_2008_year_columns <- which(
  str_detect(unlist(key_table_2008[4, ], use.names = FALSE), "^20(06|07|08)$") &
    str_detect(unlist(key_table_2008[7, ], use.names = FALSE), "[0-9]")
)
key_candidates_2008 <- tibble(
  fiscal_year = parse_integer(unlist(key_table_2008[4, key_table_2008_year_columns], use.names = FALSE)),
  homebuilding_revenue_thousands = unlist(key_table_2008[5, key_table_2008_year_columns], use.names = FALSE),
  deliveries_units = unlist(key_table_2008[6, key_table_2008_year_columns], use.names = FALSE),
  average_selling_price_dollars = unlist(key_table_2008[7, key_table_2008_year_columns], use.names = FALSE)
) |>
  pivot_longer(-fiscal_year, names_to = "metric_name", values_to = "raw_value") |>
  mutate(
    numeric_value = parse_number(raw_value),
    numeric_value = if_else(metric_name == "homebuilding_revenue_thousands", numeric_value * 1000, numeric_value),
    scale_factor_applied = if_else(metric_name == "homebuilding_revenue_thousands", 1000, 1),
    source_accession_number = "0001193125-09-039546",
    source_table_label = "single_family_key_data",
    source_table_text = table_text_2008[[key_table_2008_index]]
  )

unit_table_2009_year_columns <- which(
  str_detect(unlist(unit_table_2009[3, ], use.names = FALSE), "^20(05|06|07|08|09)$") &
    str_detect(unlist(unit_table_2009[4, ], use.names = FALSE), "[0-9]")
)
unit_candidates_2009 <- tibble(
  fiscal_year = parse_integer(unlist(unit_table_2009[3, unit_table_2009_year_columns], use.names = FALSE)),
  orders_units = unlist(unit_table_2009[4, unit_table_2009_year_columns], use.names = FALSE),
  deliveries_units = unlist(unit_table_2009[5, unit_table_2009_year_columns], use.names = FALSE),
  backlog_units = unlist(unit_table_2009[6, unit_table_2009_year_columns], use.names = FALSE),
  cancellation_rate_pct = unlist(unit_table_2009[7, unit_table_2009_year_columns], use.names = FALSE),
  buyer_traffic = unlist(unit_table_2009[8, unit_table_2009_year_columns], use.names = FALSE),
  average_selling_price_dollars = unlist(unit_table_2009[9, unit_table_2009_year_columns], use.names = FALSE),
  homebuilding_gross_margin_excluding_impairments_pct = unlist(unit_table_2009[10, unit_table_2009_year_columns], use.names = FALSE)
) |>
  pivot_longer(-fiscal_year, names_to = "metric_name", values_to = "raw_value") |>
  mutate(
    numeric_value = parse_number(raw_value),
    period_as_thousands_separator = metric_name %in% c("orders_units", "deliveries_units", "backlog_units", "buyer_traffic") &
      str_detect(raw_value, "^[0-9]+\\.[0-9]{3}$"),
    numeric_value = if_else(period_as_thousands_separator, numeric_value * 1000, numeric_value),
    numeric_value = if_else(str_detect(raw_value, fixed("(")), -abs(numeric_value), numeric_value),
    scale_factor_applied = if_else(period_as_thousands_separator, 1000, 1),
    source_accession_number = "0001193125-10-041278",
    source_table_label = "single_family_unit_statistics",
    source_table_text = table_text_2009[[unit_table_2009_index]]
  ) |>
  select(-period_as_thousands_separator)

unit_table_2013_year_columns <- which(
  str_detect(unlist(unit_table_2013[4, ], use.names = FALSE), "^20(09|10|11|12|13)$") &
    str_detect(unlist(unit_table_2013[5, ], use.names = FALSE), "[0-9]") &
    str_detect(unlist(unit_table_2013[10, ], use.names = FALSE), "[0-9]")
)
unit_candidates_2013 <- tibble(
  fiscal_year = parse_integer(unlist(unit_table_2013[4, unit_table_2013_year_columns], use.names = FALSE)),
  orders_units = unlist(unit_table_2013[5, unit_table_2013_year_columns], use.names = FALSE),
  deliveries_units = unlist(unit_table_2013[6, unit_table_2013_year_columns], use.names = FALSE),
  backlog_units = unlist(unit_table_2013[7, unit_table_2013_year_columns], use.names = FALSE),
  cancellation_rate_pct = unlist(unit_table_2013[8, unit_table_2013_year_columns], use.names = FALSE),
  buyer_traffic = unlist(unit_table_2013[9, unit_table_2013_year_columns], use.names = FALSE),
  average_selling_price_dollars = unlist(unit_table_2013[10, unit_table_2013_year_columns], use.names = FALSE),
  homebuilding_gross_margin_pct = unlist(unit_table_2013[11, unit_table_2013_year_columns], use.names = FALSE),
  homebuilding_gross_margin_excluding_impairments_pct = unlist(unit_table_2013[12, unit_table_2013_year_columns], use.names = FALSE)
) |>
  pivot_longer(-fiscal_year, names_to = "metric_name", values_to = "raw_value") |>
  mutate(
    numeric_value = parse_number(raw_value),
    numeric_value = if_else(str_detect(raw_value, fixed("(")), -abs(numeric_value), numeric_value),
    scale_factor_applied = 1,
    source_accession_number = "0000106535-14-000010",
    source_table_label = "single_family_unit_statistics",
    source_table_text = table_text_2013[[unit_table_2013_index]]
  )

revenue_table_2013_year_columns <- which(
  str_detect(unlist(revenue_table_2013[4, ], use.names = FALSE), "^20(09|10|11|12|13)$") &
    str_detect(unlist(revenue_table_2013[5, ], use.names = FALSE), "[0-9]")
)
revenue_candidates_2013 <- tibble(
  fiscal_year = parse_integer(unlist(revenue_table_2013[4, revenue_table_2013_year_columns], use.names = FALSE)),
  homebuilding_revenue_thousands = unlist(revenue_table_2013[5, revenue_table_2013_year_columns], use.names = FALSE)
) |>
  pivot_longer(-fiscal_year, names_to = "metric_name", values_to = "raw_value") |>
  mutate(
    numeric_value = parse_number(raw_value) * 1000,
    scale_factor_applied = 1000,
    source_accession_number = "0000106535-14-000010",
    source_table_label = "real_estate_revenue",
    source_table_text = table_text_2013[[revenue_table_2013_index]]
  )

candidates <- bind_rows(
  key_candidates_2006,
  unit_candidates_2008,
  key_candidates_2008,
  unit_candidates_2009,
  unit_candidates_2013,
  revenue_candidates_2013
) |>
  mutate(
    metric_raw_name = case_when(
      metric_name == "orders_units" ~ "Homes sold",
      metric_name == "deliveries_units" ~ "Homes closed",
      metric_name == "backlog_units" ~ "Homes sold but not closed (backlog)",
      metric_name == "cancellation_rate_pct" ~ "Cancellation rate",
      metric_name == "buyer_traffic" ~ "Buyer traffic",
      metric_name == "average_selling_price_dollars" ~ "Average price of homes closed",
      metric_name == "homebuilding_revenue_thousands" ~ "Single-family housing net sales and revenues",
      metric_name == "homebuilding_gross_margin_pct" ~ "Single-family gross margin",
      metric_name == "homebuilding_gross_margin_excluding_impairments_pct" ~ "Single-family gross margin excluding impairments"
    ),
    unit = case_when(
      metric_name %in% c("orders_units", "deliveries_units", "backlog_units", "buyer_traffic") ~ "units",
      metric_name %in% c("cancellation_rate_pct", "homebuilding_gross_margin_pct", "homebuilding_gross_margin_excluding_impairments_pct") ~ "percent",
      metric_name == "average_selling_price_dollars" ~ "dollars_per_home",
      metric_name == "homebuilding_revenue_thousands" ~ "thousands_of_dollars"
    ),
    source_scope = "WRECO single-family homebuilding operations",
    extraction_method = "firm_specific_sec_html_table",
    extraction_confidence = "high",
    concept_mapping = case_when(
      metric_name == "orders_units" ~ "Homes sold mapped to harmonized orders units; raw WRECO terminology retained.",
      metric_name == "deliveries_units" ~ "Homes closed mapped to harmonized deliveries units.",
      TRUE ~ "Direct mapping from WRECO table label."
    ),
    concept_mapping_confidence = if_else(metric_name == "orders_units", "medium", "high"),
    candidate_priority = case_when(
      source_table_label == "single_family_unit_statistics" & metric_name != "homebuilding_revenue_thousands" ~ 30,
      source_table_label == "single_family_key_data" & metric_name %in% c("average_selling_price_dollars", "homebuilding_revenue_thousands") ~ 30,
      source_table_label == "real_estate_revenue" & metric_name == "homebuilding_revenue_thousands" ~ 30,
      TRUE ~ 20
    )
  ) |>
  left_join(source_metadata, by = "source_accession_number", relationship = "many-to-one") |>
  arrange(fiscal_year, metric_name, desc(candidate_priority), desc(source_report_date), source_accession_number) |>
  group_by(fiscal_year, metric_name) |>
  mutate(
    candidate_count = n(),
    distinct_candidate_values = n_distinct(numeric_value),
    preferred_value = row_number() == 1
  ) |>
  ungroup() |>
  mutate(
    selection_note = case_when(
      preferred_value & distinct_candidate_values > 1 ~ "Preferred latest comparable disclosure; earlier reported value retained as a candidate.",
      preferred_value ~ "Preferred highest-priority table value from the latest selected comparative disclosure.",
      TRUE ~ "Earlier or lower-priority comparative disclosure retained for revision audit."
    )
  )

preferred_values <- candidates |>
  filter(preferred_value) |>
  select(fiscal_year, metric_name, numeric_value)

if (preferred_values |> count(fiscal_year, metric_name) |> filter(n != 1) |> nrow() > 0) {
  stop("WRECO preferred operating values are not unique by fiscal year and metric.")
}

periods <- inventory |>
  filter(cik10 == "0000106535", form == "10-K", fiscal_year %in% 2004:2013) |>
  select(
    fiscal_year,
    fiscal_period_end = report_date,
    contemporaneous_accession_number = accession_number,
    contemporaneous_filing_date = filing_date
  )

if (periods |> count(fiscal_year) |> filter(n != 1) |> nrow() > 0 || nrow(periods) != 10) {
  stop("Expected one contemporaneous Weyerhaeuser 10-K for every fiscal year from 2004 through 2013.")
}

source_summary <- candidates |>
  filter(preferred_value) |>
  group_by(fiscal_year) |>
  summarise(
    preferred_source_accessions = paste(sort(unique(source_accession_number)), collapse = " | "),
    preferred_source_filing_count = n_distinct(source_accession_number),
    source_revision_flag = any(distinct_candidate_values > 1),
    .groups = "drop"
  )

operating_panel <- preferred_values |>
  select(fiscal_year, metric_name, numeric_value) |>
  pivot_wider(names_from = metric_name, values_from = numeric_value) |>
  right_join(tibble(fiscal_year = 2004:2013), by = "fiscal_year", relationship = "one-to-one") |>
  left_join(periods, by = "fiscal_year", relationship = "one-to-one") |>
  left_join(source_summary, by = "fiscal_year", relationship = "one-to-one") |>
  mutate(
    universe_firm_id = "weyerhaeuser real estate co",
    company = "Weyerhaeuser Real Estate Co.",
    ticker = "WY",
    cik10 = "0000106535",
    sec_parent_name = "WEYERHAEUSER CO",
    orders_raw_label = "Homes sold",
    orders_harmonized_definition = "orders_units_proxy_from_homes_sold",
    orders_concept_mapping_confidence = "medium",
    deliveries_raw_label = "Homes closed",
    backlog_raw_label = "Homes sold but not closed (backlog)",
    orders_value_thousands = NA_real_,
    backlog_value_thousands = NA_real_,
    active_communities = NA_real_,
    operating_panel_use_flag = TRUE,
    manual_review_flag = FALSE,
    operating_scope_note = "Distinct WRECO single-family homebuilding operations reported in the Weyerhaeuser parent 10-K; do not splice into Tri Pointe after the 2014 transaction.",
    source_revision_note = if_else(
      fiscal_year == 2008,
      "The fiscal 2009 comparative table revises 2008 homes sold from 2,545 to 2,522 and backlog from 581 to 558; revised values are preferred.",
      NA_character_
    )
  ) |>
  select(
    universe_firm_id,
    company,
    ticker,
    cik10,
    sec_parent_name,
    fiscal_year,
    fiscal_period_end,
    contemporaneous_filing_date,
    contemporaneous_accession_number,
    orders_units,
    orders_value_thousands,
    orders_raw_label,
    orders_harmonized_definition,
    orders_concept_mapping_confidence,
    deliveries_units,
    deliveries_raw_label,
    backlog_units,
    backlog_value_thousands,
    backlog_raw_label,
    cancellation_rate_pct,
    buyer_traffic,
    average_selling_price_dollars,
    homebuilding_revenue_thousands,
    homebuilding_gross_margin_pct,
    homebuilding_gross_margin_excluding_impairments_pct,
    active_communities,
    operating_panel_use_flag,
    manual_review_flag,
    source_revision_flag,
    preferred_source_filing_count,
    preferred_source_accessions,
    operating_scope_note,
    source_revision_note
  ) |>
  arrange(fiscal_year)

benchmarks <- read_csv(
  "manual_wreco_operating_benchmarks.csv",
  show_col_types = FALSE,
  na = c("", "NA")
) |>
  pivot_longer(-fiscal_year, names_to = "metric_name", values_to = "expected_value") |>
  filter(!is.na(expected_value))

operating_audit <- benchmarks |>
  left_join(
    candidates |>
      filter(preferred_value) |>
      select(
        fiscal_year,
        metric_name,
        extracted_value = numeric_value,
        source_accession_number,
        source_report_date,
        source_table_label,
        source_table_text,
        extraction_method,
        extraction_confidence,
        concept_mapping_confidence,
        candidate_count,
        distinct_candidate_values,
        selection_note
      ),
    by = c("fiscal_year", "metric_name"),
    relationship = "one-to-one"
  ) |>
  mutate(
    tolerance = if_else(str_detect(metric_name, "_pct$"), 0.05, 0),
    absolute_difference = abs(extracted_value - expected_value),
    status = if_else(!is.na(extracted_value) & absolute_difference <= tolerance, "pass", "fail")
  ) |>
  arrange(fiscal_year, metric_name)

if (any(operating_audit$status != "pass")) {
  print(
    operating_audit |>
      filter(status != "pass") |>
      select(fiscal_year, metric_name, expected_value, extracted_value, absolute_difference, tolerance)
  )
  stop("At least one WRECO operating benchmark failed.")
}

write_csv_if_changed(operating_panel, "../output/wreco_2004_2013_operating_panel.csv")
write_csv_if_changed(candidates, "../output/wreco_2004_2013_operating_candidates.csv")
write_csv_if_changed(operating_audit, "../output/wreco_2004_2013_operating_audit.csv")

cat("Wrote WRECO operating extraction outputs to ../output\n")
