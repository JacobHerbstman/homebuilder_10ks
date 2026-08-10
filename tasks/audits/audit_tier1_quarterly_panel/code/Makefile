R := Rscript

all: ../output/tier1_quarterly_panel_audit.csv

../output/tier1_quarterly_panel_audit.csv: audit_tier1_quarterly_panel.R ../../../_lib/homebuilder_pipeline_utils.R ../input/tier1_2018_2025_quarterly_panel.csv ../input/tier1_2018_2025_annual_operating_panel.csv | ../output
	$(R) $<

../input/tier1_2018_2025_quarterly_panel.csv: ../../../build_tier1_quarterly_panel/output/tier1_2018_2025_quarterly_panel.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

../input/tier1_2018_2025_annual_operating_panel.csv: ../../../build_tier1_annual_operating_panel/output/tier1_2018_2025_annual_operating_panel.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

link-inputs: ../input/tier1_2018_2025_quarterly_panel.csv ../input/tier1_2018_2025_annual_operating_panel.csv

include ../../../generic.make
