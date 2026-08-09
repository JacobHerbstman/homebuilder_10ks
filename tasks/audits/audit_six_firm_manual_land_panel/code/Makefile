SHELL := bash
R := Rscript

all: ../output/six_firm_2006_2025_manual_land_audit.csv ../output/six_firm_2006_2025_manual_land_trends.csv

../output/six_firm_2006_2025_manual_land_audit.csv: audit_six_firm_manual_land_panel.R ../../../_lib/homebuilder_pipeline_utils.R ../input/six_firm_2006_2025_manual_land_panel.csv | ../output
	$(R) $<

../output/six_firm_2006_2025_manual_land_trends.csv: ../output/six_firm_2006_2025_manual_land_audit.csv
	@test -s "$@"

../input/six_firm_2006_2025_manual_land_panel.csv: ../../../build_six_firm_manual_land_panel/output/six_firm_2006_2025_manual_land_panel.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

link-inputs: ../input/six_firm_2006_2025_manual_land_panel.csv

include ../../../generic.make
