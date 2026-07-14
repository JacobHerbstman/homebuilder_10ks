SHELL := bash
include ../../shell_functions.make

all: ../output/kbh_hov_2006_2025_manual_land_panel.csv ../output/kbh_hov_2006_2025_manual_land_audit.csv ../output/kbh_hov_2006_2025_source_notes.csv

../output/kbh_hov_2006_2025_manual_land_panel.csv: build_kbh_hov_manual_land_panel.R manual_kbh_hov_land_disclosures.csv ../../_lib/homebuilder_pipeline_utils.R ../input/six_firm_2006_2025_skeleton.csv | ../output
	$(R) $<

../output/kbh_hov_2006_2025_manual_land_audit.csv: ../output/kbh_hov_2006_2025_manual_land_panel.csv
	@test -s "$@"

../output/kbh_hov_2006_2025_source_notes.csv: ../output/kbh_hov_2006_2025_manual_land_panel.csv
	@test -s "$@"

../input/six_firm_2006_2025_skeleton.csv: ../../build_six_firm_pilot_skeleton/output/six_firm_2006_2025_skeleton.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

link-inputs: ../input/six_firm_2006_2025_skeleton.csv

include ../../generic.make
