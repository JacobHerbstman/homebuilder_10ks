# setwd("/Users/jacobherbstman/Desktop/homebuilder_10ks/tasks/build_six_firm_pilot_skeleton/code")

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
})

source("../../_lib/homebuilder_pipeline_utils.R")

if (Sys.which("pandoc") == "") {
  stop("pandoc is required to convert SEC HTML review files to PDF.")
}

if (Sys.which("xelatex") == "") {
  stop("xelatex is required for robust PDF conversion of SEC HTML files.")
}

review_inventory <- read_csv("../output/six_firm_2006_2025_review_pdf_manifest.csv", show_col_types = FALSE, na = c("", "NA")) |>
  mutate(
    source_html_path = file.path("../../fetch_sec_10k_filings/code", primary_document_local_path),
    pdf_local_path = file.path(
      "../output/review_pdfs",
      paste0(ticker, "_", fiscal_year, "_", gsub("-", "", accession_number), ".pdf")
    )
  )

for (i in seq_len(nrow(review_inventory))) {
  status <- system2(
    "pandoc",
    c(
      "--quiet",
      "--pdf-engine=xelatex",
      review_inventory$source_html_path[i],
      "-o",
      review_inventory$pdf_local_path[i]
    )
  )

  if (!identical(status, 0L)) {
    stop(paste("pandoc failed for", review_inventory$source_html_path[i]))
  }
}

review_inventory <- review_inventory |>
  mutate(
    pdf_exists = file.exists(pdf_local_path),
    pdf_bytes = file.info(pdf_local_path)$size
  ) |>
  select(
    ticker, pilot_builder_name, fiscal_year, accession_number, form,
    filing_date, report_date, disclosure_recovery_status, hand_read_priority,
    filing_url, source_html_path, pdf_local_path, pdf_exists, pdf_bytes
  )

write_csv_if_changed(review_inventory, "../output/review_pdfs/review_pdf_inventory.csv")

cat("Wrote six-firm review PDF inventory to ../output/review_pdfs\n")
