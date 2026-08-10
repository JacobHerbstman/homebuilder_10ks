R := Rscript

all: ../output/tier1_quarterly_land_panel_audit.csv

../output/tier1_quarterly_land_panel_audit.csv: audit_tier1_quarterly_land_panel.R ../../../_lib/homebuilder_pipeline_utils.R ../input/tier1_2018_2025_quarterly_land_panel.csv ../input/tier1_2018_2025_annual_panel.csv | ../output
	$(R) $<

../input/tier1_2018_2025_quarterly_land_panel.csv: ../../../build_tier1_quarterly_land_panel/output/tier1_2018_2025_quarterly_land_panel.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

../input/tier1_2018_2025_annual_panel.csv: ../../../build_tier1_annual_panel/output/tier1_2018_2025_annual_panel.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

link-inputs: ../input/tier1_2018_2025_quarterly_land_panel.csv ../input/tier1_2018_2025_annual_panel.csv

include ../../../generic.make
