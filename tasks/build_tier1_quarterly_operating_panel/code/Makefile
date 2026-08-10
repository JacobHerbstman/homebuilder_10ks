R := Rscript

all: ../output/tier1_2018_2025_quarterly_operating_panel.csv

../output/tier1_2018_2025_quarterly_operating_panel.csv: build_tier1_quarterly_operating_panel.R ../../_lib/homebuilder_pipeline_utils.R ../input/six_firm_2018_2025_quarterly_operating_disclosures.csv ../input/five_firm_2018_2025_quarterly_operating_disclosures.csv ../input/nine_firm_2018_2025_quarterly_operating_disclosures.csv ../input/tier1_2018_2025_annual_operating_panel.csv | ../output
	$(R) $<

../input/six_firm_2018_2025_quarterly_operating_disclosures.csv: ../../extract_six_firm_quarterly_operating_disclosures/output/six_firm_2018_2025_quarterly_operating_disclosures.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

../input/five_firm_2018_2025_quarterly_operating_disclosures.csv: ../../extract_five_firm_quarterly_operating_disclosures/output/five_firm_2018_2025_quarterly_operating_disclosures.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

../input/nine_firm_2018_2025_quarterly_operating_disclosures.csv: ../../extract_nine_firm_quarterly_operating_disclosures/output/nine_firm_2018_2025_quarterly_operating_disclosures.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

../input/tier1_2018_2025_annual_operating_panel.csv: ../../build_tier1_annual_operating_panel/output/tier1_2018_2025_annual_operating_panel.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

link-inputs: ../input/six_firm_2018_2025_quarterly_operating_disclosures.csv ../input/five_firm_2018_2025_quarterly_operating_disclosures.csv ../input/nine_firm_2018_2025_quarterly_operating_disclosures.csv ../input/tier1_2018_2025_annual_operating_panel.csv

include ../../generic.make
