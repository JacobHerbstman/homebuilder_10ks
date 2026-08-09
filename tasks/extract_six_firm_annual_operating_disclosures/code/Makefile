SHELL := bash
R := Rscript

all: ../output/six_firm_2006_2025_operating_panel.csv ../output/six_firm_2006_2025_operating_candidates.csv

../output/six_firm_2006_2025_operating_panel.csv: extract_six_firm_annual_operating_disclosures.R ../../_lib/homebuilder_pipeline_utils.R ../input/sec_10k_download_inventory.csv | ../output
	$(R) $<

../output/six_firm_2006_2025_operating_candidates.csv: ../output/six_firm_2006_2025_operating_panel.csv
	@test -s "$@"

../input/sec_10k_download_inventory.csv: ../../fetch_sec_10k_filings/output/sec_10k_download_inventory.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

link-inputs: ../input/sec_10k_download_inventory.csv

include ../../generic.make
