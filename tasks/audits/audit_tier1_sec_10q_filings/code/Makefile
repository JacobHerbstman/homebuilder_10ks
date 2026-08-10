R := Rscript

all: ../output/tier1_2018_2025_sec_10q_audit.csv ../output/tier1_2018_2025_sec_10q_coverage.csv

../output/tier1_2018_2025_sec_10q_audit.csv: audit_tier1_sec_10q_filings.R ../../../_lib/homebuilder_pipeline_utils.R ../input/tier1_2018_2025_sec_10q_filing_index.csv ../input/tier1_2018_2025_sec_10q_download_inventory.csv | ../output
	$(R) $<

../output/tier1_2018_2025_sec_10q_coverage.csv: ../output/tier1_2018_2025_sec_10q_audit.csv
	@test -s "$@"

../input/tier1_2018_2025_sec_10q_filing_index.csv: ../../../build_tier1_sec_10q_filing_index/output/tier1_2018_2025_sec_10q_filing_index.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

../input/tier1_2018_2025_sec_10q_download_inventory.csv: ../../../fetch_tier1_sec_10q_filings/output/tier1_2018_2025_sec_10q_download_inventory.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

link-inputs: ../input/tier1_2018_2025_sec_10q_filing_index.csv ../input/tier1_2018_2025_sec_10q_download_inventory.csv

include ../../../generic.make
