SHELL := bash
include ../../shell_functions.make

all: ../output/wreco_2004_2013_operating_panel.csv ../output/wreco_2004_2013_operating_candidates.csv ../output/wreco_2004_2013_operating_audit.csv

../output/wreco_2004_2013_operating_panel.csv: extract_wreco_operating_disclosures.R manual_wreco_operating_benchmarks.csv ../../_lib/homebuilder_pipeline_utils.R ../input/sec_10k_download_inventory.csv | ../output
	$(R) $<

../output/wreco_2004_2013_operating_candidates.csv: ../output/wreco_2004_2013_operating_panel.csv
	@test -s "$@"

../output/wreco_2004_2013_operating_audit.csv: ../output/wreco_2004_2013_operating_panel.csv
	@test -s "$@"

../input/sec_10k_download_inventory.csv: ../../fetch_sec_10k_filings/output/sec_10k_download_inventory.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

link-inputs: ../input/sec_10k_download_inventory.csv

include ../../generic.make
