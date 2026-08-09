# setwd("/Users/jacobherbstman/Desktop/homebuilder_10ks/tasks/audits/audit_tier1_annual_panel/code")

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(tibble)
  library(tidyr)
})

source("../../../_lib/homebuilder_pipeline_utils.R")

panel <- read_csv(
  "../input/tier1_2018_2025_annual_panel.csv",
  show_col_types = FALSE,
  na = c("", "NA"),
  col_types = cols(
    cik10 = col_character(),
    operating_accession_number = col_character(),
    land_accession_number = col_character()
  )
)

operating <- read_csv(
  "../input/tier1_2018_2025_annual_operating_panel.csv",
  show_col_types = FALSE,
  na = c("", "NA"),
  col_types = cols(cik10 = col_character(), accession_number = col_character())
)

land <- read_csv(
  "../input/expanded_builder_2004_2025_land_panel.csv",
  show_col_types = FALSE,
  na = c("", "NA"),
  col_types = cols(candidate_cik10 = col_character(), selected_accession_number = col_character())
) |>
  filter(tier == 1, fiscal_year %in% 2018:2025)

filings <- read_csv(
  "../input/sec_10k_filing_index.csv",
  show_col_types = FALSE,
  na = c("", "NA"),
  col_types = cols(cik10 = col_character(), accession_number = col_character())
)

preferred <- read_csv(
  "../input/tenk_land_preferred_values.csv",
  show_col_types = FALSE,
  na = c("", "NA"),
  col_types = cols(cik10 = col_character(), accession_number = col_character())
)

expected_columns <- c(
  "universe_episode_id", "universe_firm_id", "ticker", "company", "cik10",
  "sec_company_name", "fiscal_year", "panel_state",
  "public_reporting_episode_indicator", "public_filing_observed",
  "pre_public_indicator", "death_indicator", "valid_from_year", "valid_to_year",
  "filing_window", "fiscal_year_warning", "merger_splice_flag", "recent_ipo_flag",
  "fate_and_splicing_notes", "operating_data_observed", "report_date", "filing_date",
  "operating_accession_number", "orders_units", "orders_value_thousands",
  "orders_raw_label", "deliveries_units", "deliveries_value_thousands",
  "deliveries_raw_label", "backlog_units", "backlog_value_thousands",
  "cancellation_rate_pct", "active_communities", "average_community_count",
  "average_selling_price_dollars", "homebuilding_revenue_thousands",
  "operating_source_scope", "operating_extraction_method", "operating_filing_url",
  "operating_source_local_path", "operating_source_checksum_sha256",
  "operating_source_task", "land_share_observed", "owned_lots_or_homesites",
  "omega_numerator_lots_or_homesites", "total_lots_or_homesites",
  "omega_nonowned_controlled_share", "land_component_identity_gap",
  "land_component_identity_status", "land_unit_type", "land_measure_definition",
  "land_source", "land_source_note", "land_accession_number", "land_source_url",
  "land_source_local_path", "land_main_plot_eligible", "land_manual_review_flag",
  "land_share_missing_reason"
)

expected_episodes <- tribble(
  ~ticker, ~expected_first_year, ~expected_last_year, ~expected_public_years,
  "BZH", 2018L, 2025L, 8L,
  "CCS", 2018L, 2025L, 8L,
  "DFH", 2021L, 2025L, 5L,
  "DHI", 2018L, 2025L, 8L,
  "GRBK", 2018L, 2025L, 8L,
  "HOV", 2018L, 2025L, 8L,
  "KBH", 2018L, 2025L, 8L,
  "LEN", 2018L, 2025L, 8L,
  "LGIH", 2018L, 2025L, 8L,
  "LSEA", 2021L, 2024L, 4L,
  "MDC", 2018L, 2024L, 7L,
  "MHO", 2018L, 2025L, 8L,
  "MTH", 2018L, 2025L, 8L,
  "NVR", 2018L, 2025L, 8L,
  "PHM", 2018L, 2025L, 8L,
  "SDHC", 2024L, 2025L, 2L,
  "TMHC", 2018L, 2025L, 8L,
  "TOL", 2018L, 2025L, 8L,
  "TPH", 2018L, 2025L, 8L,
  "UHG", 2023L, 2025L, 3L
)

coverage <- panel |>
  group_by(ticker, company) |>
  summarise(
    panel_rows = n(),
    observed_first_year = min(fiscal_year[public_reporting_episode_indicator]),
    observed_last_year = max(fiscal_year[public_reporting_episode_indicator]),
    public_reporting_years = sum(public_reporting_episode_indicator),
    orders_years = sum(!is.na(orders_units)),
    deliveries_years = sum(!is.na(deliveries_units)),
    backlog_years = sum(!is.na(backlog_units)),
    omega_years = sum(!is.na(omega_nonowned_controlled_share)),
    owned_land_years = sum(!is.na(owned_lots_or_homesites)),
    active_community_years = sum(!is.na(active_communities)),
    cancellation_rate_years = sum(!is.na(cancellation_rate_pct)),
    average_selling_price_years = sum(!is.na(average_selling_price_dollars)),
    homebuilding_revenue_years = sum(!is.na(homebuilding_revenue_thousands)),
    .groups = "drop"
  ) |>
  left_join(expected_episodes, by = "ticker", relationship = "one-to-one") |>
  mutate(
    episode_pass = panel_rows == 8 &
      observed_first_year == expected_first_year &
      observed_last_year == expected_last_year &
      public_reporting_years == expected_public_years
  ) |>
  arrange(ticker)

panel_operating_long <- panel |>
  filter(public_reporting_episode_indicator) |>
  select(
    ticker, fiscal_year, orders_units, orders_value_thousands, deliveries_units,
    deliveries_value_thousands, backlog_units, backlog_value_thousands,
    cancellation_rate_pct, active_communities, average_community_count,
    average_selling_price_dollars, homebuilding_revenue_thousands
  ) |>
  pivot_longer(-c(ticker, fiscal_year), names_to = "metric", values_to = "panel_value")

upstream_operating_long <- operating |>
  select(
    ticker, fiscal_year, orders_units, orders_value_thousands, deliveries_units,
    deliveries_value_thousands, backlog_units, backlog_value_thousands,
    cancellation_rate_pct, active_communities, average_community_count,
    average_selling_price_dollars, homebuilding_revenue_thousands
  ) |>
  pivot_longer(-c(ticker, fiscal_year), names_to = "metric", values_to = "upstream_value")

operating_value_comparison <- panel_operating_long |>
  left_join(
    upstream_operating_long,
    by = c("ticker", "fiscal_year", "metric"),
    relationship = "one-to-one"
  ) |>
  mutate(
    value_match = (is.na(panel_value) & is.na(upstream_value)) |
      (!is.na(panel_value) & !is.na(upstream_value) & panel_value == upstream_value)
  )

six_firm_benchmarks <- read_csv("../input/six_firm_2012_2023_operating_benchmark_audit.csv", show_col_types = FALSE)
five_firm_benchmarks <- read_csv("../input/five_firm_annual_operating_benchmark_audit.csv", show_col_types = FALSE)
nine_firm_benchmarks <- read_csv("../input/nine_firm_annual_operating_benchmark_audit.csv", show_col_types = FALSE)
tier1_benchmarks <- read_csv("../input/tier1_annual_operating_benchmark_audit.csv", show_col_types = FALSE)

operating_benchmark_checks <- nrow(six_firm_benchmarks) + nrow(five_firm_benchmarks) + nrow(nine_firm_benchmarks) + nrow(tier1_benchmarks)
operating_benchmark_passes <- sum(six_firm_benchmarks$status == "pass") + sum(five_firm_benchmarks$pass) + sum(nine_firm_benchmarks$pass) + sum(tier1_benchmarks$pass)

panel_land_long <- panel |>
  select(
    ticker, fiscal_year, owned_lots_or_homesites,
    omega_numerator_lots_or_homesites, total_lots_or_homesites,
    omega_nonowned_controlled_share
  ) |>
  pivot_longer(-c(ticker, fiscal_year), names_to = "metric", values_to = "panel_value")

upstream_land_long <- land |>
  transmute(
    ticker, fiscal_year,
    owned_lots_or_homesites = selected_owned_physical_count,
    omega_numerator_lots_or_homesites = selected_nonowned_physical_count,
    total_lots_or_homesites = selected_total_physical_count,
    omega_nonowned_controlled_share = selected_nonowned_controlled_share
  ) |>
  pivot_longer(-c(ticker, fiscal_year), names_to = "metric", values_to = "upstream_value")

land_value_comparison <- panel_land_long |>
  left_join(
    upstream_land_long,
    by = c("ticker", "fiscal_year", "metric"),
    relationship = "one-to-one"
  ) |>
  mutate(
    value_match = (is.na(panel_value) & is.na(upstream_value)) |
      (!is.na(panel_value) & !is.na(upstream_value) & panel_value == upstream_value)
  )

operating_metadata <- panel |>
  filter(public_reporting_episode_indicator) |>
  select(
    ticker, fiscal_year, cik10, report_date, filing_date,
    operating_accession_number, operating_filing_url,
    operating_source_local_path, operating_source_checksum_sha256
  ) |>
  left_join(
    operating |>
      select(
        ticker, fiscal_year, upstream_cik10 = cik10,
        upstream_report_date = report_date, upstream_filing_date = filing_date,
        upstream_accession_number = accession_number,
        upstream_filing_url = filing_url,
        upstream_source_local_path = source_local_path,
        upstream_source_checksum_sha256 = source_checksum_sha256
      ),
    by = c("ticker", "fiscal_year"),
    relationship = "one-to-one"
  )

operating_index <- panel |>
  filter(public_reporting_episode_indicator) |>
  left_join(
    filings |>
      select(
        operating_accession_number = accession_number,
        index_cik10 = cik10, index_form = form,
        index_filing_date = filing_date, index_report_date = report_date,
        index_primary_document = primary_document,
        index_filing_url = filing_url
      ),
    by = "operating_accession_number",
    relationship = "many-to-one"
  )

land_index <- panel |>
  filter(public_reporting_episode_indicator) |>
  left_join(
    filings |>
      select(
        land_accession_number = accession_number,
        index_cik10 = cik10, index_form = form,
        index_primary_document = primary_document,
        index_filing_url = filing_url
      ),
    by = "land_accession_number",
    relationship = "many-to-one"
  )

operating_source_files <- file.path("..", panel$operating_source_local_path[panel$public_reporting_episode_indicator])
land_source_files <- file.path("..", panel$land_source_local_path[panel$public_reporting_episode_indicator])
operating_source_hashes <- vapply(
  operating_source_files,
  digest::digest,
  character(1),
  algo = "sha256",
  file = TRUE,
  serialize = FALSE
)

generic_rows <- panel |>
  filter(land_source == "generic_parser_main")

generic_expected <- bind_rows(
  generic_rows |>
    transmute(
      ticker, fiscal_year, accession_number = land_accession_number,
      variable_name = "owned_lots", expected_value = owned_lots_or_homesites
    ),
  generic_rows |>
    transmute(
      ticker, fiscal_year, accession_number = land_accession_number,
      variable_name = if_else(ticker == "BZH", "optioned_lots", "controlled_lots"),
      expected_value = omega_numerator_lots_or_homesites
    ),
  generic_rows |>
    transmute(
      ticker, fiscal_year, accession_number = land_accession_number,
      variable_name = if_else(ticker == "BZH", "controlled_lots", "total_lots"),
      expected_value = total_lots_or_homesites
    )
)

generic_evidence <- generic_expected |>
  left_join(
    preferred |>
      select(
        accession_number, variable_name, preferred_value, source_scope,
        source_row_label, extraction_method, confidence,
        metric_is_exact_table_value
      ),
    by = c("accession_number", "variable_name"),
    relationship = "one-to-one"
  ) |>
  mutate(
    pass = expected_value == preferred_value &
      source_scope == "firm_year" &
      source_row_label == "Total" &
      extraction_method == "table_cell_structured" &
      confidence == "high" &
      metric_is_exact_table_value
  )

expected_2024_land <- tribble(
  ~ticker, ~owned_lots_or_homesites, ~omega_numerator_lots_or_homesites, ~total_lots_or_homesites,
  "BZH", 12413, 16125, 28538,
  "CCS", 35756, 44876, 80632,
  "DFH", NA, 54698, NA,
  "DHI", 152500, 480400, 632900,
  "GRBK", 32716, 5115, 37831,
  "HOV", 6632, 35259, 41895,
  "KBH", 38862, 37841, 76703,
  "LEN", 85428, 393649, 479077,
  "LGIH", 53317, 17582, 70899,
  "LSEA", 4822, 6122, 10944,
  "MDC", 18838, 7155, 25993,
  "MHO", 23836, 28320, 52156,
  "MTH", 53335, 32278, 85613,
  "NVR", NA, 159800, 162400,
  "PHM", 102176, 132413, 234589,
  "SDHC", 1776, 17746, 19522,
  "TMHC", 36718, 49435, 86153,
  "TOL", 34000, 40800, 74700,
  "TPH", 16609, 19881, 36490,
  "UHG", 125, 7565, 7690
) |>
  pivot_longer(-ticker, names_to = "metric", values_to = "expected_value")

benchmark_2024_land <- panel |>
  filter(fiscal_year == 2024, public_reporting_episode_indicator) |>
  select(
    ticker, owned_lots_or_homesites, omega_numerator_lots_or_homesites,
    total_lots_or_homesites
  ) |>
  pivot_longer(-ticker, names_to = "metric", values_to = "observed_value") |>
  left_join(expected_2024_land, by = c("ticker", "metric"), relationship = "one-to-one") |>
  mutate(
    pass = (is.na(observed_value) & is.na(expected_value)) |
      (!is.na(observed_value) & !is.na(expected_value) & observed_value == expected_value)
  )

expected_2025_lennar <- tribble(
  ~metric, ~expected_value,
  "owned_lots_or_homesites", 9525,
  "omega_numerator_lots_or_homesites", 496250,
  "total_lots_or_homesites", 505775
)

benchmark_2025_lennar <- panel |>
  filter(ticker == "LEN", fiscal_year == 2025) |>
  select(
    ticker, owned_lots_or_homesites, omega_numerator_lots_or_homesites,
    total_lots_or_homesites
  ) |>
  pivot_longer(-ticker, names_to = "metric", values_to = "observed_value") |>
  left_join(expected_2025_lennar, by = "metric", relationship = "one-to-one") |>
  mutate(
    pass = observed_value == expected_value
  )

expected_2018_grbk_operating <- tribble(
  ~metric, ~expected_value,
  "deliveries_value_thousands", 571177,
  "average_selling_price_dollars", 443805,
  "active_communities", 76,
  "average_community_count", 66
)

benchmark_2018_grbk_operating <- panel |>
  filter(ticker == "GRBK", fiscal_year == 2018) |>
  select(
    ticker, deliveries_value_thousands, average_selling_price_dollars,
    active_communities, average_community_count
  ) |>
  pivot_longer(-ticker, names_to = "metric", values_to = "observed_value") |>
  left_join(expected_2018_grbk_operating, by = "metric", relationship = "one-to-one") |>
  mutate(pass = observed_value == expected_value)

core_operating <- panel |>
  filter(public_reporting_episode_indicator) |>
  select(ticker, fiscal_year, orders_units, deliveries_units, backlog_units) |>
  pivot_longer(-c(ticker, fiscal_year), names_to = "metric", values_to = "value")

core_land <- panel |>
  filter(public_reporting_episode_indicator) |>
  select(
    ticker, fiscal_year, owned_lots_or_homesites,
    omega_numerator_lots_or_homesites, total_lots_or_homesites
  ) |>
  pivot_longer(-c(ticker, fiscal_year), names_to = "metric", values_to = "value")

expected_panel_state <- case_when(
  panel$pre_public_indicator ~ "pre_public",
  panel$death_indicator ~ "post_exit",
  panel$public_reporting_episode_indicator & panel$public_filing_observed ~ "public_filing_observed",
  panel$public_reporting_episode_indicator ~ "missing_sec_filing",
  TRUE ~ "outside_public_reporting_episode"
)

death_rows <- panel |>
  filter(death_indicator) |>
  transmute(key = paste(ticker, fiscal_year, sep = "-")) |>
  pull(key) |>
  sort()

active_omega_gaps <- panel |>
  filter(public_reporting_episode_indicator, !land_share_observed) |>
  transmute(key = paste(ticker, fiscal_year, sep = "-")) |>
  pull(key) |>
  sort()

duplicate_firm_years <- panel |>
  count(ticker, fiscal_year) |>
  filter(n != 1) |>
  nrow()

indicator_partition_rows <- rowSums(cbind(
  panel$public_reporting_episode_indicator,
  panel$pre_public_indicator,
  panel$death_indicator
))

one_cik_per_firm <- panel |>
  group_by(ticker) |>
  summarise(n = n_distinct(cik10), .groups = "drop")

operating_metadata_match <-
  operating_metadata$cik10 == operating_metadata$upstream_cik10 &
  as.character(operating_metadata$report_date) == as.character(operating_metadata$upstream_report_date) &
  as.character(operating_metadata$filing_date) == as.character(operating_metadata$upstream_filing_date) &
  operating_metadata$operating_accession_number == operating_metadata$upstream_accession_number &
  operating_metadata$operating_filing_url == operating_metadata$upstream_filing_url &
  operating_metadata$operating_source_local_path == operating_metadata$upstream_source_local_path &
  operating_metadata$operating_source_checksum_sha256 == operating_metadata$upstream_source_checksum_sha256

operating_index_match <-
  !is.na(operating_index$index_form) &
  operating_index$cik10 == operating_index$index_cik10 &
  operating_index$index_form %in% c("10-K", "10-K/A", "10-KT") &
  as.character(operating_index$filing_date) == as.character(operating_index$index_filing_date) &
  as.character(operating_index$report_date) == as.character(operating_index$index_report_date) &
  operating_index$operating_filing_url == operating_index$index_filing_url

public_filing_lags <- as.integer(
  as.Date(panel$filing_date[panel$public_reporting_episode_indicator]) -
  as.Date(panel$report_date[panel$public_reporting_episode_indicator])
)

land_index_match <-
  !is.na(land_index$index_form) &
  land_index$cik10 == land_index$index_cik10 &
  land_index$index_form %in% c("10-K", "10-K/A", "10-KT") &
  land_index$land_source_url == land_index$index_filing_url

public_land_metadata_missing <-
  is.na(panel$land_accession_number[panel$public_reporting_episode_indicator]) |
  is.na(panel$land_source_url[panel$public_reporting_episode_indicator]) |
  is.na(panel$land_source_local_path[panel$public_reporting_episode_indicator]) |
  is.na(panel$land_source[panel$public_reporting_episode_indicator]) |
  panel$land_source[panel$public_reporting_episode_indicator] == ""

omega_ratio_difference <- abs(
  panel$omega_nonowned_controlled_share -
  panel$omega_numerator_lots_or_homesites / panel$total_lots_or_homesites
)

asp_identity_failures <- panel |>
  filter(
    public_reporting_episode_indicator,
    !is.na(average_selling_price_dollars),
    !is.na(deliveries_value_thousands)
  ) |>
  mutate(
    implied_asp = deliveries_value_thousands * 1000 / deliveries_units,
    relative_difference = abs(average_selling_price_dollars - implied_asp) / implied_asp
  ) |>
  filter(relative_difference > 0.05) |>
  nrow()

secondary_value_failures <- panel |>
  filter(public_reporting_episode_indicator) |>
  filter(
    (!is.na(cancellation_rate_pct) & (cancellation_rate_pct < 0 | cancellation_rate_pct > 100)) |
    (!is.na(active_communities) & (active_communities <= 0 | active_communities > 5000 | active_communities != floor(active_communities))) |
    (!is.na(average_community_count) & (average_community_count <= 0 | average_community_count > 5000)) |
    (!is.na(average_selling_price_dollars) & (average_selling_price_dollars < 100000 | average_selling_price_dollars > 2000000)) |
    (!is.na(homebuilding_revenue_thousands) & homebuilding_revenue_thousands <= 0)
  ) |>
  nrow()

unit_value_failures <- panel |>
  filter(public_reporting_episode_indicator) |>
  transmute(
    order_value_per_home = orders_value_thousands * 1000 / orders_units,
    delivery_value_per_home = deliveries_value_thousands * 1000 / deliveries_units,
    backlog_value_per_home = backlog_value_thousands * 1000 / backlog_units,
    revenue_per_delivery = homebuilding_revenue_thousands * 1000 / deliveries_units
  ) |>
  filter(if_any(everything(), ~ !is.na(.x) & (.x < 100000 | .x > 2000000))) |>
  nrow()

operating_ratio_failures <- panel |>
  filter(public_reporting_episode_indicator) |>
  mutate(
    orders_to_deliveries = orders_units / deliveries_units,
    ending_to_average_communities = active_communities / average_community_count
  ) |>
  filter(
    orders_to_deliveries < 0.4 | orders_to_deliveries > 2 |
      (!is.na(ending_to_average_communities) & (ending_to_average_communities < 0.5 | ending_to_average_communities > 2))
  ) |>
  nrow()

unresolved_land_rows <- sum(panel$land_component_identity_status == "unresolved", na.rm = TRUE)
nvr_incomplete_component_rows <- sum(
  panel$ticker == "NVR" &
  panel$land_component_identity_status == "components_not_fully_disclosed",
  na.rm = TRUE
)
hov_third_category_rows <- sum(
  panel$land_component_identity_status == "construction_to_permanent_category_excluded_from_omega_numerator",
  na.rm = TRUE
)
toll_rounded_prose_rows <- sum(
  panel$land_component_identity_status == "rounded_companywide_prose",
  na.rm = TRUE
)

audit <- tribble(
  ~check, ~expected, ~observed, ~pass, ~detail,
  "schema", paste(expected_columns, collapse = " | "), paste(names(panel), collapse = " | "), identical(names(panel), expected_columns), "Final column order and names are stable.",
  "balanced_rows", "160", as.character(nrow(panel)), nrow(panel) == 160, "Twenty firms by eight fiscal years.",
  "unique_firms", "20", as.character(n_distinct(panel$ticker)), n_distinct(panel$ticker) == 20, "Tier-1 firm count.",
  "unique_firm_year_keys", "0 duplicate keys", as.character(duplicate_firm_years), duplicate_firm_years == 0, "Panel key is ticker by fiscal year.",
  "eight_rows_per_firm", "20 firms", as.character(sum(coverage$panel_rows == 8)), all(coverage$panel_rows == 8), "Every firm has a balanced 2018-2025 skeleton.",
  "reporting_episodes", "20 pass", as.character(sum(coverage$episode_pass)), all(coverage$episode_pass), "Public episodes match the reviewed IPO and exit windows.",
  "indicator_partition", "160 rows", as.character(sum(indicator_partition_rows == 1)), all(indicator_partition_rows == 1), "Public, pre-public, and post-exit states are mutually exclusive and exhaustive.",
  "panel_state", "0 mismatches", as.character(sum(panel$panel_state != expected_panel_state)), all(panel$panel_state == expected_panel_state), "State labels agree with the indicator columns.",
  "public_reporting_firm_years", "141", as.character(sum(panel$public_reporting_episode_indicator)), sum(panel$public_reporting_episode_indicator) == 141, "Reviewed public-reporting episode years.",
  "public_filing_coverage", "141", as.character(sum(panel$public_filing_observed & panel$public_reporting_episode_indicator)), all(panel$public_filing_observed == panel$public_reporting_episode_indicator), "No expected Tier-1 annual filing is missing from the current SEC inputs.",
  "post_exit_death_rows", "LSEA-2025 | MDC-2025", paste(death_rows, collapse = " | "), identical(death_rows, c("LSEA-2025", "MDC-2025")), "Only the two reviewed acquisitions create post-exit rows in this window.",
  "cik_format", "0 failures", as.character(sum(!grepl("^[0-9]{10}$", panel$cik10))), all(grepl("^[0-9]{10}$", panel$cik10)), "CIKs are retained as zero-padded ten-character identifiers.",
  "one_cik_per_firm", "20 firms", as.character(sum(one_cik_per_firm$n == 1)), all(one_cik_per_firm$n == 1), "Each Tier-1 firm episode uses one CIK.",
  "core_operating_rows", "141", as.character(sum(panel$operating_data_observed)), sum(panel$operating_data_observed) == 141, "Orders, deliveries, and backlog are complete in every public firm-year.",
  "core_operating_positive", "0 failures", as.character(sum(is.na(core_operating$value) | core_operating$value <= 0)), all(!is.na(core_operating$value) & core_operating$value > 0), "Core operating counts are positive and nonmissing.",
  "core_operating_integer", "0 failures", as.character(sum(core_operating$value != floor(core_operating$value))), all(core_operating$value == floor(core_operating$value)), "Core operating outcomes are unit counts.",
  "operating_outside_public_episode", "0", as.character(sum(panel$operating_data_observed & !panel$public_reporting_episode_indicator)), sum(panel$operating_data_observed & !panel$public_reporting_episode_indicator) == 0, "Pre-public and post-exit outcomes remain missing.",
  "operating_upstream_values", "0 mismatches", as.character(sum(!operating_value_comparison$value_match)), all(operating_value_comparison$value_match), "Final operating values exactly reproduce the canonical operating producer.",
  "operating_upstream_metadata", "0 mismatches", as.character(sum(!operating_metadata_match)), all(operating_metadata_match), "Identifiers and provenance survive the final join unchanged.",
  "operating_sec_index", "141 matches", as.character(sum(!is.na(operating_index$index_form))), all(operating_index_match), "Operating accessions and filing metadata match the SEC index.",
  "operating_source_files", "141", as.character(sum(file.exists(operating_source_files))), all(file.exists(operating_source_files)), "Every operating row points to a local SEC filing.",
  "operating_source_checksums", "141", as.character(sum(operating_source_hashes == panel$operating_source_checksum_sha256[panel$public_reporting_episode_indicator])), all(operating_source_hashes == panel$operating_source_checksum_sha256[panel$public_reporting_episode_indicator]), "Every operating filing still matches its recorded SHA-256 checksum.",
  "filing_date_order", "0 failures", as.character(sum(public_filing_lags < 0)), all(public_filing_lags >= 0), "Filing dates follow report dates.",
  "filing_lag", "0 outside 20-120 days", as.character(sum(!public_filing_lags %in% 20:120)), all(public_filing_lags %in% 20:120), "Annual filing lags are plausible.",
  "land_upstream_values", "0 mismatches", as.character(sum(!land_value_comparison$value_match)), all(land_value_comparison$value_match), "Final land values exactly reproduce the expanded land producer.",
  "land_sec_index", "141 matches", as.character(sum(!is.na(land_index$index_form))), all(land_index_match), "Land accessions and filing metadata match the SEC index.",
  "land_source_files", "141", as.character(sum(file.exists(land_source_files))), all(file.exists(land_source_files)), "Every public land row, including DFH pipeline-only rows, points to a local SEC filing.",
  "land_source_metadata", "0 failures", as.character(sum(public_land_metadata_missing)), all(!public_land_metadata_missing), "Selected land rows retain source accession, URL, path, and extraction rule.",
  "land_share_rows", "139", as.character(sum(panel$land_share_observed)), sum(panel$land_share_observed) == 139, "All public firm-years except the two documented DFH schema breaks have omega.",
  "active_land_share_gaps", "DFH-2024 | DFH-2025", paste(active_omega_gaps, collapse = " | "), identical(active_omega_gaps, c("DFH-2024", "DFH-2025")), "DFH stopped disclosing the owned-lot denominator.",
  "omega_bounds", "0 failures", as.character(sum(panel$land_share_observed & (panel$omega_nonowned_controlled_share < 0 | panel$omega_nonowned_controlled_share > 1))), all(!panel$land_share_observed | (panel$omega_nonowned_controlled_share >= 0 & panel$omega_nonowned_controlled_share <= 1), na.rm = TRUE), "Observed land shares lie between zero and one.",
  "omega_ratio_identity", "maximum difference below 1e-12", format(max(omega_ratio_difference, na.rm = TRUE), scientific = TRUE), max(omega_ratio_difference, na.rm = TRUE) < 1e-12, "Every observed omega equals its disclosed numerator divided by its disclosed denominator.",
  "land_counts_positive", "0 failures", as.character(sum(!is.na(core_land$value) & core_land$value <= 0)), all(is.na(core_land$value) | core_land$value > 0), "Disclosed land counts are positive.",
  "land_counts_integer", "0 failures", as.character(sum(!is.na(core_land$value) & core_land$value != floor(core_land$value))), all(is.na(core_land$value) | core_land$value == floor(core_land$value)), "Land quantities are physical counts, not scaled dollars.",
  "unresolved_land_component_identity", "0", as.character(unresolved_land_rows), unresolved_land_rows == 0, "Every non-additive selected row has an explicit disclosure-based explanation.",
  "nvr_incomplete_component_rows", "8", as.character(nvr_incomplete_component_rows), nvr_incomplete_component_rows == 8, "NVR reports an LPA-based numerator and total controlled lots without a comparable owned component.",
  "hov_third_controlled_category_rows", "8", as.character(hov_third_category_rows), hov_third_category_rows == 8, "HOV excludes construction-to-permanent lots from the optioned numerator.",
  "toll_rounded_prose_rows", "2", as.character(toll_rounded_prose_rows), toll_rounded_prose_rows == 2, "Toll 2023-2024 company-wide counts are rounded to the nearest hundred.",
  "generic_land_table_evidence", "72 exact cells", as.character(sum(generic_evidence$pass)), nrow(generic_evidence) == 72 & all(generic_evidence$pass), "BZH, CCS, and LGIH values come from high-confidence firm-total SEC table cells.",
  "land_2024_benchmarks", "60 cells", as.character(sum(benchmark_2024_land$pass)), nrow(benchmark_2024_land) == 60 & all(benchmark_2024_land$pass), "All 2024 land components match the values reviewed directly in the cited filings, including documented missing components.",
  "lennar_2025_land_benchmark", "3 cells", as.character(sum(benchmark_2025_lennar$pass)), nrow(benchmark_2025_lennar) == 3 & all(benchmark_2025_lennar$pass), "Lennar's post-Millrose 98% controlled-homesite disclosure was reviewed directly in the filing.",
  "grbk_2018_secondary_benchmark", "4 cells", as.character(sum(benchmark_2018_grbk_operating$pass)), nrow(benchmark_2018_grbk_operating) == 4 & all(benchmark_2018_grbk_operating$pass), "GRBK's 2018 dollar units and community counts were reviewed directly in the filing.",
  "operating_benchmark_suite", "550 passes", as.character(operating_benchmark_passes), operating_benchmark_checks == 550 & operating_benchmark_passes == 550, "All filing-level six-, five-, nine-, and Tier-1 operating benchmarks pass.",
  "asp_identity", "0 differences above 5%", as.character(asp_identity_failures), asp_identity_failures == 0, "Reported ASP agrees with home-sales value divided by deliveries, allowing for filing rounding.",
  "secondary_value_ranges", "0 failures", as.character(secondary_value_failures), secondary_value_failures == 0, "Supplemental operating variables have plausible units and ranges.",
  "operating_unit_values", "0 failures", as.character(unit_value_failures), unit_value_failures == 0, "Orders, deliveries, backlog, and revenue imply $100,000-$2,000,000 per home when both components are disclosed.",
  "operating_flow_ratios", "0 failures", as.character(operating_ratio_failures), operating_ratio_failures == 0, "Orders-to-deliveries and ending-to-average community ratios remain in broad filing-plausible ranges."
)

write_csv_if_changed(audit, "../output/tier1_2018_2025_annual_panel_audit.csv")
write_csv_if_changed(coverage, "../output/tier1_2018_2025_annual_panel_coverage.csv")

if (any(!audit$pass)) {
  stop("Tier-1 annual panel audit has one or more failed checks.")
}

cat("Wrote Tier-1 annual panel audits to ../output\n")
