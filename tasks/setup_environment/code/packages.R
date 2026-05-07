# setwd("/Users/jacobherbstman/Desktop/homebuilder_10ks/tasks/setup_environment/code")

options(repos = c(CRAN = "https://cloud.r-project.org"))

cran_pkgs <- c(
  "arrow", "data.table", "DBI", "duckdb", "dplyr", "fixest",
  "ggplot2", "jsonlite", "lubridate", "optparse", "pdftools", "purrr",
  "readr", "readxl", "rvest", "stringr", "tibble", "tidyr", "xml2"
)

for (pkg in cran_pkgs) {
  if (!requireNamespace(pkg, quietly = TRUE)) install.packages(pkg)
}

pkgs <- as.data.frame(installed.packages()[, c("Package", "Version")])
write.table(pkgs, "../output/R_packages.txt", sep = "\t", row.names = FALSE, quote = FALSE)
cat("Wrote", nrow(pkgs), "packages to ../output/R_packages.txt\n")
