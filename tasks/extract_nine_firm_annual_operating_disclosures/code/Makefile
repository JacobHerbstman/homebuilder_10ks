SHELL := bash
R := Rscript

all: ../output/nine_firm_2018_2025_annual_operating_panel.csv

../output/nine_firm_2018_2025_annual_operating_panel.csv: extract_nine_firm_annual_operating_disclosures.R ../../_lib/homebuilder_pipeline_utils.R ../input/sec_10k_download_inventory.csv | ../output
	$(R) $<

../input/sec_10k_download_inventory.csv: ../../fetch_sec_10k_filings/output/sec_10k_download_inventory.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

link-inputs: ../input/sec_10k_download_inventory.csv

include ../../generic.make
