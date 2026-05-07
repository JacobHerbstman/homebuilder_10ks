# setwd("/Users/jacobherbstman/Desktop/homebuilder_10ks/tasks/load_builder_magazine_raw/code")

suppressPackageStartupMessages({
  library(dplyr)
  library(purrr)
  library(readr)
  library(rvest)
  library(stringr)
  library(tibble)
  library(xml2)
})

source("../../_lib/homebuilder_pipeline_utils.R")

empty_raw_rows <- tibble(
  source_id = character(),
  pull_date = character(),
  list_year = integer(),
  underlying_closings_year = integer(),
  underlying_revenue_year = integer(),
  prior_rank_year = integer(),
  list_type = character(),
  rank = integer(),
  raw_company_name = character(),
  public_marker_flag = logical(),
  raw_total_closings = character(),
  raw_gross_revenue = character(),
  gross_revenue_units = character(),
  raw_prior_year_rank = character(),
  company_detail_url = character(),
  source_url = character(),
  source_path = character(),
  parse_timestamp_utc = character(),
  parse_method = character()
)

empty_qc_rows <- tibble(
  source_id = character(),
  pull_date = character(),
  list_year = integer(),
  list_type = character(),
  source_url = character(),
  source_path = character(),
  fetch_status = character(),
  parse_status = character(),
  row_count = integer(),
  min_rank = integer(),
  max_rank = integer(),
  public_row_count = integer(),
  closings_year = integer(),
  revenue_year = integer(),
  prior_rank_year = integer(),
  detail = character()
)

extract_first <- function(x, pattern) {
  hits <- str_match(x, pattern)[, 2]
  hits <- hits[!is.na(hits)]
  if (length(hits) == 0) {
    return(NA_character_)
  }
  hits[[1]]
}

parse_int_safe <- function(x) {
  suppressWarnings(as.integer(str_remove_all(as.character(x), "[^0-9-]")))
}

clean_company_for_match <- function(x) {
  out <- str_remove_all(as.character(x), "\\s*\\(p\\)\\s*")
  out <- str_remove_all(out, "[*†‡]+")
  str_squish(out)
}

read_listing_text_lines <- function(doc) {
  lines <- str_split(html_text2(doc), "\n")[[1]]
  lines <- str_squish(lines)
  lines[lines != ""]
}

section_lines <- function(lines) {
  start <- which(str_detect(lines, "Builder 100 Listings"))[1]
  if (is.na(start)) {
    start <- 1L
  }

  end_candidates <- which(seq_along(lines) > start & str_detect(lines, "^Footnotes\\.?$|^Upcoming Events$"))
  end <- if (length(end_candidates) == 0) length(lines) else end_candidates[[1]] - 1L
  lines[start:end]
}

find_detail_url <- function(link_df, raw_company_name, source_url) {
  company_clean <- clean_company_for_match(raw_company_name)
  key <- normalize_text_key(company_clean)

  if (is.na(key)) {
    return(NA_character_)
  }

  hit <- link_df |>
    filter(link_key == key, !is.na(href), href != "", !str_detect(href, "^mailto:|^#")) |>
    slice_head(n = 1)

  if (nrow(hit) == 0) {
    return(NA_character_)
  }

  xml2::url_absolute(hit$href[[1]], source_url)
}

parse_builder_table_rows <- function(doc, file_row, closings_year, revenue_year, prior_rank_year, gross_revenue_units) {
  row_nodes <- html_elements(doc, "table tbody tr")

  if (length(row_nodes) == 0) {
    return(empty_raw_rows)
  }

  parsed_rows <- list()
  row_id <- 1L

  for (row_node in row_nodes) {
    row_lines <- str_split(html_text2(row_node), "\n")[[1]]
    row_lines <- str_squish(row_lines)
    row_lines <- row_lines[row_lines != ""]

    if (length(row_lines) == 0) {
      next
    }

    first_line <- str_replace_all(row_lines[[1]], "\t+", " ")
    first_match <- str_match(first_line, "^([0-9]{1,3})\\s+(.+)$")

    if (is.na(first_match[1, 1])) {
      next
    }

    rank_value <- parse_int_safe(first_match[1, 2])
    raw_company_name <- str_squish(first_match[1, 3])
    raw_total_closings <- extract_first(row_lines, "Total Closings:\\s*(.+)$")
    raw_gross_revenue <- extract_first(row_lines, "Gross Revenue[s]?:\\s*(.+)$")
    raw_prior_year_rank <- extract_first(row_lines, "^[* ]*20[0-9]{2} Rank:\\s*(.+)$")
    link_node <- html_element(row_node, "a")
    company_detail_url <- html_attr(link_node, "href")
    if (!is.na(company_detail_url) && company_detail_url != "") {
      company_detail_url <- xml2::url_absolute(company_detail_url, file_row$source_url)
    } else {
      company_detail_url <- NA_character_
    }

    parsed_rows[[row_id]] <- tibble(
      source_id = file_row$source_id,
      pull_date = file_row$pull_date,
      list_year = as.integer(file_row$list_year),
      underlying_closings_year = closings_year,
      underlying_revenue_year = revenue_year,
      prior_rank_year = prior_rank_year,
      list_type = file_row$list_type,
      rank = rank_value,
      raw_company_name = raw_company_name,
      public_marker_flag = str_detect(raw_company_name, "\\(p\\)"),
      raw_total_closings = raw_total_closings,
      raw_gross_revenue = raw_gross_revenue,
      gross_revenue_units = gross_revenue_units,
      raw_prior_year_rank = raw_prior_year_rank,
      company_detail_url = company_detail_url,
      source_url = file_row$source_url,
      source_path = file_row$raw_path,
      parse_timestamp_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
      parse_method = "html_table_rows"
    )
    row_id <- row_id + 1L
  }

  bind_rows(parsed_rows)
}

parse_builder_text_rows <- function(doc, file_row, listing_lines, closings_year, revenue_year, prior_rank_year, gross_revenue_units) {
  link_nodes <- html_elements(doc, "a")
  link_df <- tibble(
    link_text = str_squish(html_text2(link_nodes)),
    href = html_attr(link_nodes, "href")
  ) |>
    mutate(
      link_clean = clean_company_for_match(link_text),
      link_key = normalize_text_key(link_clean)
    )

  parsed_rows <- list()
  row_id <- 1L

  for (i in seq_along(listing_lines)) {
    line <- listing_lines[[i]]
    rank_value <- NA_integer_
    raw_company_name <- NA_character_

    combined_match <- str_match(line, "^([0-9]{1,3})\\s+(.+)$")
    if (!is.na(combined_match[1, 1]) && !str_detect(combined_match[1, 2], ",")) {
      rank_value <- parse_int_safe(combined_match[1, 2])
      raw_company_name <- str_squish(combined_match[1, 3])
    } else if (str_detect(line, "^[0-9]{1,3}$") && i < length(listing_lines)) {
      next_line <- listing_lines[[i + 1L]]
      if (!str_detect(next_line, "Rank|Total Closings|Gross Revenue|^[0-9,]+\\s+\\$")) {
        rank_value <- parse_int_safe(line)
        raw_company_name <- str_squish(next_line)
      }
    }

    if (is.na(rank_value) || is.na(raw_company_name) || raw_company_name == "") {
      next
    }

    lookahead <- listing_lines[i:min(length(listing_lines), i + 10L)]
    raw_total_closings <- extract_first(lookahead, "Total Closings:\\s*(.+)$")
    raw_gross_revenue <- extract_first(lookahead, "Gross Revenue[s]?:\\s*(.+)$")
    raw_prior_year_rank <- extract_first(lookahead, "^[* ]*20[0-9]{2} Rank:\\s*(.+)$")

    parsed_rows[[row_id]] <- tibble(
      source_id = file_row$source_id,
      pull_date = file_row$pull_date,
      list_year = as.integer(file_row$list_year),
      underlying_closings_year = closings_year,
      underlying_revenue_year = revenue_year,
      prior_rank_year = prior_rank_year,
      list_type = file_row$list_type,
      rank = rank_value,
      raw_company_name = raw_company_name,
      public_marker_flag = str_detect(raw_company_name, "\\(p\\)"),
      raw_total_closings = raw_total_closings,
      raw_gross_revenue = raw_gross_revenue,
      gross_revenue_units = gross_revenue_units,
      raw_prior_year_rank = raw_prior_year_rank,
      company_detail_url = find_detail_url(link_df, raw_company_name, file_row$source_url),
      source_url = file_row$source_url,
      source_path = file_row$raw_path,
      parse_timestamp_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
      parse_method = "visible_text_listing_lines"
    )
    row_id <- row_id + 1L
  }

  bind_rows(parsed_rows)
}

parse_builder_file <- function(file_row) {
  if (!file.exists(file_row$raw_path)) {
    return(list(
      rows = empty_raw_rows,
      qc = tibble(
        source_id = file_row$source_id,
        pull_date = file_row$pull_date,
        list_year = as.integer(file_row$list_year),
        list_type = file_row$list_type,
        source_url = file_row$source_url,
        source_path = file_row$raw_path,
        fetch_status = file_row$status,
        parse_status = "missing_html",
        row_count = 0L,
        min_rank = NA_integer_,
        max_rank = NA_integer_,
        public_row_count = 0L,
        closings_year = NA_integer_,
        revenue_year = NA_integer_,
        prior_rank_year = NA_integer_,
        detail = "Raw HTML file is not present."
      )
    ))
  }

  doc <- read_html(file_row$raw_path)
  text_lines <- read_listing_text_lines(doc)
  listing_lines <- section_lines(text_lines)

  closings_year <- parse_int_safe(extract_first(listing_lines, "^(20[0-9]{2}) Total Closings"))
  revenue_year <- parse_int_safe(extract_first(listing_lines, "^(20[0-9]{2}) Gross Revenue"))
  prior_rank_year <- parse_int_safe(extract_first(listing_lines, paste0("^(", as.integer(file_row$list_year) - 1L, ") Rank$")))
  if (is.na(prior_rank_year)) {
    prior_rank_year <- parse_int_safe(as.integer(file_row$list_year) - 1L)
  }
  gross_revenue_units <- if_else(str_detect(str_to_lower(paste(text_lines, collapse = " ")), "gross revenue\\s+is home building revenue,? in millions"), "millions", NA_character_)

  parsed_df <- parse_builder_table_rows(doc, file_row, closings_year, revenue_year, prior_rank_year, gross_revenue_units)
  if (nrow(parsed_df) == 0) {
    parsed_df <- parse_builder_text_rows(doc, file_row, listing_lines, closings_year, revenue_year, prior_rank_year, gross_revenue_units)
  }

  parse_status <- case_when(
    nrow(parsed_df) >= 90 ~ "parsed",
    nrow(parsed_df) > 0 ~ "parsed_low_row_count",
    TRUE ~ "no_rows_parsed"
  )

  list(
    rows = if (nrow(parsed_df) == 0) empty_raw_rows else parsed_df,
    qc = tibble(
      source_id = file_row$source_id,
      pull_date = file_row$pull_date,
      list_year = as.integer(file_row$list_year),
      list_type = file_row$list_type,
      source_url = file_row$source_url,
      source_path = file_row$raw_path,
      fetch_status = file_row$status,
      parse_status = parse_status,
      row_count = nrow(parsed_df),
      min_rank = if (nrow(parsed_df) == 0) NA_integer_ else min(parsed_df$rank, na.rm = TRUE),
      max_rank = if (nrow(parsed_df) == 0) NA_integer_ else max(parsed_df$rank, na.rm = TRUE),
      public_row_count = if (nrow(parsed_df) == 0) 0L else sum(parsed_df$public_marker_flag, na.rm = TRUE),
      closings_year = closings_year,
      revenue_year = revenue_year,
      prior_rank_year = prior_rank_year,
      detail = ""
    )
  )
}

file_inventory <- read_csv("../input/builder_magazine_html_files.csv", show_col_types = FALSE, na = c("", "NA")) |>
  mutate(
    list_year = suppressWarnings(as.integer(list_year)),
    raw_path = as.character(raw_path),
    source_url = as.character(source_url)
  ) |>
  arrange(list_year, list_type)

if (nrow(file_inventory) == 0) {
  write_csv_if_changed(empty_raw_rows, "../output/builder_magazine_raw_rows.csv")
  write_csv_if_changed(empty_qc_rows, "../output/builder_magazine_parse_qc.csv")
  quit(save = "no")
}

parsed <- map(seq_len(nrow(file_inventory)), function(i) parse_builder_file(file_inventory[i, ]))

write_csv_if_changed(bind_rows(map(parsed, "rows")), "../output/builder_magazine_raw_rows.csv")
write_csv_if_changed(bind_rows(map(parsed, "qc")), "../output/builder_magazine_parse_qc.csv")

cat("Wrote Builder Magazine raw parse outputs to ../output\n")
