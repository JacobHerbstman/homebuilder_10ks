SHELL := bash
R := Rscript

all: ../output/tier1_2021_2023_land_adjustment_panel.csv

../output/tier1_2021_2023_land_adjustment_panel.csv: build_tier1_land_adjustment_panel.R ../../_lib/homebuilder_pipeline_utils.R ../input/expanded_builder_2004_2025_land_panel.csv ../input/tier1_2018_2025_annual_operating_panel.csv ../input/six_firm_2006_2025_manual_land_panel.csv | ../output
	$(R) $<

../input/expanded_builder_2004_2025_land_panel.csv: ../../build_expanded_builder_land_panel/output/expanded_builder_2004_2025_land_panel.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

../input/tier1_2018_2025_annual_operating_panel.csv: ../../build_tier1_annual_operating_panel/output/tier1_2018_2025_annual_operating_panel.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

../input/six_firm_2006_2025_manual_land_panel.csv: ../../build_six_firm_manual_land_panel/output/six_firm_2006_2025_manual_land_panel.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

link-inputs: ../input/expanded_builder_2004_2025_land_panel.csv ../input/tier1_2018_2025_annual_operating_panel.csv ../input/six_firm_2006_2025_manual_land_panel.csv

include ../../generic.make
