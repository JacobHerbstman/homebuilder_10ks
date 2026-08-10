R := Rscript

all: ../output/tier1_2018_2025_quarterly_land_panel.csv

../output/tier1_2018_2025_quarterly_land_panel.csv: build_tier1_quarterly_land_panel.R ../../_lib/homebuilder_pipeline_utils.R ../input/tier1_2018_2025_quarterly_skeleton.csv ../input/tier1_2018_2025_quarterly_land_disclosures.csv ../input/tier1_2018_2025_annual_panel.csv ../input/sec_10k_download_inventory.csv | ../output
	$(R) $<

../input/tier1_2018_2025_quarterly_skeleton.csv: ../../build_tier1_quarterly_skeleton/output/tier1_2018_2025_quarterly_skeleton.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

../input/tier1_2018_2025_quarterly_land_disclosures.csv: ../../extract_tier1_quarterly_land_disclosures/output/tier1_2018_2025_quarterly_land_disclosures.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

../input/tier1_2018_2025_annual_panel.csv: ../../build_tier1_annual_panel/output/tier1_2018_2025_annual_panel.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

../input/sec_10k_download_inventory.csv: ../../fetch_sec_10k_filings/output/sec_10k_download_inventory.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

link-inputs: ../input/tier1_2018_2025_quarterly_skeleton.csv ../input/tier1_2018_2025_quarterly_land_disclosures.csv ../input/tier1_2018_2025_annual_panel.csv ../input/sec_10k_download_inventory.csv

include ../../generic.make
