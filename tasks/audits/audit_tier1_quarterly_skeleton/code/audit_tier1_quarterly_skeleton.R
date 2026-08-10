# setwd("/Users/jacobherbstman/Desktop/homebuilder_10ks/tasks/audits/audit_tier1_quarterly_skeleton/code")

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(tibble)
})

source("../../../_lib/homebuilder_pipeline_utils.R")

skeleton <- read_csv(
  "../input/tier1_2018_2025_quarterly_skeleton.csv",
  show_col_types = FALSE,
  na = c("", "NA"),
  col_types = cols(cik10 = col_character(), source_accession_number = col_character())
)

annual_panel <- read_csv(
  "../input/tier1_2018_2025_annual_panel.csv",
  show_col_types = FALSE,
  na = c("", "NA"),
  col_types = cols(cik10 = col_character(), operating_accession_number = col_character())
)

tenq_inventory <- read_csv(
  "../input/tier1_2018_2025_sec_10q_download_inventory.csv",
  show_col_types = FALSE,
  na = c("", "NA"),
  col_types = cols(cik10 = col_character(), accession_number = col_character())
)

observed <- skeleton |>
  filter(filing_observed)

source_files <- file.path("..", observed$source_local_path)
source_hashes <- vapply(
  source_files,
  digest::digest,
  character(1),
  algo = "sha256",
  file = TRUE,
  serialize = FALSE
)

selected_tenq <- tenq_inventory |>
  filter(selected_for_panel, calendar_panel_window_flag)

expected_tenk_accessions <- annual_panel |>
  filter(public_filing_observed) |>
  pull(operating_accession_number)

coverage <- skeleton |>
  group_by(ticker, company, cik10) |>
  summarise(
    quarters = n(),
    filing_observed_quarters = sum(filing_observed),
    tenq_quarters = sum(source_kind == "interim_10q", na.rm = TRUE),
    tenk_quarters = sum(source_kind == "annual_10k", na.rm = TRUE),
    pre_public_quarters = sum(pre_public_indicator),
    post_exit_quarters = sum(death_indicator),
    missing_public_filing_quarters = sum(panel_state == "public_filing_missing"),
    first_observed_quarter = min(calendar_quarter_label[filing_observed]),
    last_observed_quarter = max(calendar_quarter_label[filing_observed]),
    .groups = "drop"
  ) |>
  arrange(ticker)

audit <- tribble(
  ~check, ~expected, ~observed, ~pass, ~detail,
  "balanced_rows", "640", as.character(nrow(skeleton)), nrow(skeleton) == 640, "The skeleton has 20 firms by 32 calendar quarters.",
  "unique_firm_quarters", "640", as.character(n_distinct(paste(skeleton$ticker, skeleton$calendar_year, skeleton$calendar_quarter))), n_distinct(paste(skeleton$ticker, skeleton$calendar_year, skeleton$calendar_quarter)) == 640, "Firm-calendar-quarter keys are unique.",
  "tier1_firms", "20", as.character(n_distinct(skeleton$ticker)), n_distinct(skeleton$ticker) == 20, "Every Tier-1 firm appears.",
  "observed_source_rows", as.character(nrow(selected_tenq) + length(expected_tenk_accessions)), as.character(nrow(observed)), nrow(observed) == nrow(selected_tenq) + length(expected_tenk_accessions), "Observed quarters equal selected 10-Qs plus audited annual 10-Ks.",
  "selected_10q_sources", as.character(nrow(selected_tenq)), as.character(sum(observed$source_kind == "interim_10q")), setequal(observed$source_accession_number[observed$source_kind == "interim_10q"], selected_tenq$accession_number), "Every selected in-window 10-Q appears exactly once.",
  "annual_10k_sources", as.character(length(expected_tenk_accessions)), as.character(sum(observed$source_kind == "annual_10k")), setequal(observed$source_accession_number[observed$source_kind == "annual_10k"], expected_tenk_accessions), "Every public-reporting annual 10-K appears exactly once.",
  "fiscal_quarter_source_mapping", as.character(nrow(observed)), as.character(sum((observed$fiscal_quarter %in% 1:3 & observed$source_kind == "interim_10q") | (observed$fiscal_quarter == 4 & observed$source_kind == "annual_10k"))), all((observed$fiscal_quarter %in% 1:3 & observed$source_kind == "interim_10q") | (observed$fiscal_quarter == 4 & observed$source_kind == "annual_10k")), "Interim and annual sources map to fiscal quarters 1-3 and 4, respectively.",
  "complete_source_metadata", as.character(nrow(observed)), as.character(sum(!is.na(observed$source_accession_number) & !is.na(observed$source_report_date) & !is.na(observed$source_filing_date) & !is.na(observed$source_url) & !is.na(observed$source_local_path) & !is.na(observed$source_checksum_sha256))), all(!is.na(observed$source_accession_number) & !is.na(observed$source_report_date) & !is.na(observed$source_filing_date) & !is.na(observed$source_url) & !is.na(observed$source_local_path) & !is.na(observed$source_checksum_sha256)), "Every observed quarter has complete SEC provenance.",
  "source_files", as.character(nrow(observed)), as.character(sum(file.exists(source_files))), all(file.exists(source_files)), "Every recorded SEC source file exists.",
  "source_checksums", as.character(nrow(observed)), as.character(sum(source_hashes == observed$source_checksum_sha256)), all(source_hashes == observed$source_checksum_sha256), "Every SEC source file matches its recorded SHA-256 checksum.",
  "state_partition", "640", as.character(sum(skeleton$filing_observed) + sum(skeleton$pre_public_indicator) + sum(skeleton$death_indicator)), all(rowSums(cbind(skeleton$filing_observed, skeleton$pre_public_indicator, skeleton$death_indicator)) == 1), "Observed, pre-public, and post-exit states partition the panel.",
  "missing_public_filings", "0", as.character(sum(skeleton$panel_state == "public_filing_missing")), !any(skeleton$panel_state == "public_filing_missing"), "No quarter inside a retained reporting episode lacks an SEC filing."
)

if (any(!audit$pass)) {
  print(audit |> filter(!pass))
  stop("Tier-1 quarterly skeleton audit failed.")
}

write_csv_if_changed(audit, "../output/tier1_2018_2025_quarterly_skeleton_audit.csv")
write_csv_if_changed(coverage, "../output/tier1_2018_2025_quarterly_skeleton_coverage.csv")

cat("Wrote Tier-1 quarterly skeleton audits to ../output\n")
