# setwd("/Users/jacobherbstman/Desktop/homebuilder_10ks/tasks/build_six_firm_pilot_skeleton/code")

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(tidyr)
  library(tibble)
})

source("../../_lib/homebuilder_pipeline_utils.R")

pilot_firms <- tribble(
  ~ticker, ~pilot_builder_name, ~pilot_role,
  "DHI", "D.R. Horton", "high-volume production builder",
  "LEN", "Lennar", "high-volume production builder",
  "KBH", "KB Home", "large production builder with total-lot disclosure",
  "NVR", "NVR", "land-light/LPA-oriented builder",
  "PHM", "PulteGroup", "large production builder",
  "HOV", "Hovnanian", "laggard/high-leverage historical builder"
)

pilot_years <- tibble(fiscal_year = 2006:2025)

filing_index <- read_csv("../input/sec_10k_filing_index.csv", show_col_types = FALSE, na = c("", "NA")) |>
  mutate(
    fiscal_year = suppressWarnings(as.integer(as.character(fiscal_year))),
    filing_date = suppressWarnings(as.Date(filing_date)),
    report_date = suppressWarnings(as.Date(report_date)),
    ticker = as.character(ticker),
    accession_number = as.character(accession_number)
  ) |>
  filter(ticker %in% pilot_firms$ticker, fiscal_year %in% pilot_years$fiscal_year) |>
  arrange(ticker, fiscal_year, desc(form == "10-K"), desc(filing_date), accession_number) |>
  group_by(ticker, fiscal_year) |>
  slice(1) |>
  ungroup() |>
  select(
    ticker, fiscal_year,
    indexed_accession_number = accession_number,
    indexed_form = form,
    indexed_filing_date = filing_date,
    indexed_report_date = report_date,
    indexed_primary_document = primary_document,
    indexed_filing_url = filing_url
  )

download_inventory <- read_csv("../input/sec_10k_download_inventory.csv", show_col_types = FALSE, na = c("", "NA")) |>
  mutate(
    fiscal_year = suppressWarnings(as.integer(as.character(fiscal_year))),
    filing_date = suppressWarnings(as.Date(filing_date)),
    report_date = suppressWarnings(as.Date(report_date)),
    ticker = as.character(ticker),
    accession_number = as.character(accession_number),
    downloaded_10k = primary_document_status %in% c("downloaded", "already_present")
  ) |>
  filter(ticker %in% pilot_firms$ticker, fiscal_year %in% pilot_years$fiscal_year) |>
  arrange(ticker, fiscal_year, desc(downloaded_10k), desc(form == "10-K"), desc(filing_date), accession_number) |>
  group_by(ticker, fiscal_year) |>
  slice(1) |>
  ungroup() |>
  select(
    ticker, fiscal_year,
    downloaded_accession_number = accession_number,
    downloaded_form = form,
    downloaded_filing_date = filing_date,
    downloaded_report_date = report_date,
    primary_document,
    filing_url,
    primary_document_local_path,
    primary_document_status,
    downloaded_10k
  )

land_light <- read_csv("../input/land_light_firm_year_measures.csv", show_col_types = FALSE, na = c("", "NA")) |>
  mutate(
    fiscal_year = suppressWarnings(as.integer(as.character(fiscal_year))),
    ticker = as.character(ticker),
    across(
      c(
        nonowned_controlled_share, owned_lots, optioned_lots, controlled_lots, total_lots,
        owned_homesites, controlled_homesites, total_homesites, lot_purchase_agreements,
        closings, owned_physical_count, nonowned_physical_count, total_controlled_physical_count
      ),
      \(x) suppressWarnings(as.numeric(as.character(x)))
    ),
    across(
      c(main_plot_eligible, robustness_plot_eligible, manual_review_flag, provenance_review_flag),
      \(x) x %in% c(TRUE, "TRUE", "true", "True", "1", 1)
    )
  ) |>
  filter(ticker %in% pilot_firms$ticker, fiscal_year %in% pilot_years$fiscal_year) |>
  arrange(ticker, fiscal_year, desc(main_plot_eligible), desc(robustness_plot_eligible), accession_number) |>
  group_by(ticker, fiscal_year) |>
  slice(1) |>
  ungroup() |>
  select(
    ticker, fiscal_year, builder_name_key, builder_name_clean, cik10, sec_company_name,
    land_light_accession_number = accession_number,
    harmonized_builder_id, harmonized_builder_name,
    best_builder_rank, total_closings, gross_revenue_homebuilding_millions,
    owned_lots, optioned_lots, controlled_lots, total_lots,
    owned_homesites, controlled_homesites, total_homesites, lot_purchase_agreements,
    closings, owned_physical_count, nonowned_physical_count,
    total_controlled_physical_count, physical_unit_type, nonowned_controlled_share,
    source_metric_meaning, share_comparability_tier, physical_share_tier,
    nonowned_value_source, total_value_source, denominator_basis,
    main_plot_eligible, robustness_plot_eligible, manual_review_flag,
    manual_review_reason, provenance_review_flag, provenance_review_reason,
    not_eligible_reason, financial_deposit_balance, financial_deposit_metric,
    financial_purchase_obligation_balance, financial_purchase_obligation_metric
  )

skeleton <- crossing(pilot_firms, pilot_years) |>
  left_join(filing_index, by = c("ticker", "fiscal_year"), relationship = "one-to-one") |>
  left_join(download_inventory, by = c("ticker", "fiscal_year"), relationship = "one-to-one") |>
  left_join(land_light, by = c("ticker", "fiscal_year"), relationship = "one-to-one") |>
  mutate(
    annual_10k_indexed = !is.na(indexed_accession_number),
    annual_10k_downloaded = coalesce(downloaded_10k, FALSE),
    selected_land_light_row = !is.na(land_light_accession_number),
    selected_accession_matches_download = !is.na(land_light_accession_number) &
      !is.na(downloaded_accession_number) &
      land_light_accession_number == downloaded_accession_number,
    exact_omega_available = !is.na(owned_physical_count) &
      !is.na(nonowned_physical_count) &
      !is.na(total_controlled_physical_count) &
      !is.na(nonowned_controlled_share) &
      main_plot_eligible,
    proxy_share_available = !exact_omega_available &
      !is.na(nonowned_controlled_share) &
      robustness_plot_eligible,
    disclosure_recovery_status = case_when(
      exact_omega_available ~ "exact_or_identity_verified_share",
      proxy_share_available ~ "proxy_or_residual_share_review",
      !annual_10k_downloaded ~ "filing_not_downloaded",
      !selected_land_light_row ~ "not_extracted_yet",
      ticker == "KBH" & !is.na(total_lots) & is.na(nonowned_physical_count) ~ "total_pipeline_only",
      ticker == "NVR" & !is.na(controlled_lots) & is.na(owned_physical_count) ~ "controlled_or_lpa_proxy_only",
      ticker == "HOV" & !is.na(optioned_lots) & is.na(total_controlled_physical_count) ~ "optioned_only_no_denominator",
      !is.na(not_eligible_reason) & not_eligible_reason != "" ~ not_eligible_reason,
      TRUE ~ "needs_hand_read"
    ),
    hand_read_priority = case_when(
      exact_omega_available ~ "confirm_sample",
      proxy_share_available ~ "review_formula",
      disclosure_recovery_status %in% c(
        "total_pipeline_only",
        "controlled_or_lpa_proxy_only",
        "optioned_only_no_denominator"
      ) ~ "high",
      annual_10k_downloaded ~ "medium",
      TRUE ~ "low"
    ),
    pilot_notes = case_when(
      ticker == "NVR" ~ "NVR often reports lots controlled under LPAs rather than owned plus optioned split.",
      ticker == "KBH" ~ "KBH currently yields total lot pipeline but not owned/non-owned split.",
      ticker == "HOV" ~ "HOV currently yields optioned lots but lacks a harmonized denominator.",
      ticker == "DHI" ~ "DHI generally supports owned plus controlled/total land-lot identity from 2012 onward.",
      ticker == "LEN" ~ "Lennar uses homesite terminology and has several gap years to audit.",
      ticker == "PHM" ~ "Pulte supports explicit owned/optioned/controlled lots from 2011 onward.",
      TRUE ~ ""
    )
  ) |>
  arrange(ticker, fiscal_year)

recovery_audit <- skeleton |>
  count(ticker, pilot_builder_name, disclosure_recovery_status, hand_read_priority, name = "firm_years") |>
  arrange(ticker, desc(firm_years), disclosure_recovery_status)

review_pdf_manifest <- skeleton |>
  filter(ticker %in% c("NVR", "KBH", "HOV"), fiscal_year %in% c(2006, 2010, 2020, 2023, 2025)) |>
  select(
    ticker, pilot_builder_name, fiscal_year, accession_number = downloaded_accession_number,
    form = downloaded_form, filing_date = downloaded_filing_date, report_date = downloaded_report_date,
    primary_document, primary_document_local_path, filing_url,
    disclosure_recovery_status, hand_read_priority
  ) |>
  arrange(ticker, fiscal_year)

qc_rows <- tibble(
  check = c(
    "six_firm_skeleton_rows",
    "annual_10k_indexed_rows",
    "annual_10k_downloaded_rows",
    "exact_omega_available_rows",
    "proxy_share_available_rows",
    "high_priority_hand_read_rows",
    "review_pdf_manifest_rows"
  ),
  status = c(
    if_else(nrow(skeleton) == 120, "ok", "fail"),
    if_else(sum(skeleton$annual_10k_indexed, na.rm = TRUE) == 120, "ok", "warn"),
    if_else(sum(skeleton$annual_10k_downloaded, na.rm = TRUE) == 120, "ok", "warn"),
    "ok",
    "ok",
    "ok",
    if_else(nrow(review_pdf_manifest) > 0, "ok", "warn")
  ),
  value = c(
    nrow(skeleton),
    sum(skeleton$annual_10k_indexed, na.rm = TRUE),
    sum(skeleton$annual_10k_downloaded, na.rm = TRUE),
    sum(skeleton$exact_omega_available, na.rm = TRUE),
    sum(skeleton$proxy_share_available, na.rm = TRUE),
    sum(skeleton$hand_read_priority == "high", na.rm = TRUE),
    nrow(review_pdf_manifest)
  ),
  detail = c(
    "Expected six pilot firms times 20 fiscal years.",
    "Rows with an indexed annual 10-K-family filing.",
    "Rows with a downloaded primary 10-K document.",
    "Rows currently selected for main omega/non-owned-share plotting.",
    "Rows with a robustness/proxy selected share.",
    "Rows where a filing exists but denominator or terminology needs hand review.",
    "Review subset for local PDF conversion."
  )
)

write_csv_if_changed(skeleton, "../output/six_firm_2006_2025_skeleton.csv")
write_csv_if_changed(recovery_audit, "../output/six_firm_2006_2025_recovery_audit.csv")
write_csv_if_changed(review_pdf_manifest, "../output/six_firm_2006_2025_review_pdf_manifest.csv")
write_csv_if_changed(qc_rows, "../output/six_firm_2006_2025_qc.csv")

cat("Wrote six-firm 2006-2025 pilot skeleton outputs to ../output\n")
