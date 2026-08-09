SHELL := bash
R := Rscript

all: ../output/tier1_2018_2025_annual_panel.csv

../output/tier1_2018_2025_annual_panel.csv: build_tier1_annual_panel.R ../../_lib/homebuilder_pipeline_utils.R ../input/expanded_builder_2004_2025_land_panel.csv ../input/tier1_2018_2025_annual_operating_panel.csv | ../output
	$(R) $<

../input/expanded_builder_2004_2025_land_panel.csv: ../../build_expanded_builder_land_panel/output/expanded_builder_2004_2025_land_panel.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

../input/tier1_2018_2025_annual_operating_panel.csv: ../../build_tier1_annual_operating_panel/output/tier1_2018_2025_annual_operating_panel.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

link-inputs: ../input/expanded_builder_2004_2025_land_panel.csv ../input/tier1_2018_2025_annual_operating_panel.csv

include ../../generic.make
