SHELL := bash
include ../../shell_functions.make

all: ../output/nvr_2006_2025_manual_land_panel.csv ../output/nvr_2006_2025_manual_land_audit.csv ../output/nvr_2006_2025_source_notes.csv

../output/nvr_2006_2025_manual_land_panel.csv: build_nvr_manual_land_panel.R manual_nvr_land_disclosures.csv ../../_lib/homebuilder_pipeline_utils.R ../input/six_firm_2006_2025_skeleton.csv | ../output
	$(R) $<

../output/nvr_2006_2025_manual_land_audit.csv: ../output/nvr_2006_2025_manual_land_panel.csv
	@test -s "$@"

../output/nvr_2006_2025_source_notes.csv: ../output/nvr_2006_2025_manual_land_panel.csv
	@test -s "$@"

../input/six_firm_2006_2025_skeleton.csv: ../../build_six_firm_pilot_skeleton/output/six_firm_2006_2025_skeleton.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

link-inputs: ../input/six_firm_2006_2025_skeleton.csv

include ../../generic.make
