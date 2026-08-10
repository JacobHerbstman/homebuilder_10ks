R := Rscript

all: ../output/nine_firm_2018_2025_quarterly_operating_disclosures.csv

../output/nine_firm_2018_2025_quarterly_operating_disclosures.csv: extract_nine_firm_quarterly_operating_disclosures.R ../../_lib/homebuilder_pipeline_utils.R ../input/tier1_2018_2025_sec_10q_download_inventory.csv | ../output
	$(R) $<

../input/tier1_2018_2025_sec_10q_download_inventory.csv: ../../fetch_tier1_sec_10q_filings/output/tier1_2018_2025_sec_10q_download_inventory.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

link-inputs: ../input/tier1_2018_2025_sec_10q_download_inventory.csv

include ../../generic.make
