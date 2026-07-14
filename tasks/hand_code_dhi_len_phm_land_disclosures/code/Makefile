SHELL := bash
include ../../shell_functions.make

all: ../output/dhi_len_phm_2006_2025_manual_land_panel.csv ../output/dhi_len_phm_2006_2025_manual_land_audit.csv ../output/dhi_len_phm_2006_2025_source_notes.csv

../output/dhi_len_phm_2006_2025_manual_land_panel.csv: build_dhi_len_phm_manual_land_panel.R manual_dhi_len_phm_land_disclosures.csv ../../_lib/homebuilder_pipeline_utils.R ../input/six_firm_2006_2025_skeleton.csv | ../output
	$(R) $<

../output/dhi_len_phm_2006_2025_manual_land_audit.csv: ../output/dhi_len_phm_2006_2025_manual_land_panel.csv
	@test -s "$@"

../output/dhi_len_phm_2006_2025_source_notes.csv: ../output/dhi_len_phm_2006_2025_manual_land_panel.csv
	@test -s "$@"

../input/six_firm_2006_2025_skeleton.csv: ../../build_six_firm_pilot_skeleton/output/six_firm_2006_2025_skeleton.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

link-inputs: ../input/six_firm_2006_2025_skeleton.csv

include ../../generic.make
