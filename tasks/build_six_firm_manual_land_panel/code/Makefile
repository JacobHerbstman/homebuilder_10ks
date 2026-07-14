SHELL := bash
include ../../shell_functions.make

all: ../output/six_firm_2006_2025_manual_land_panel.csv ../output/six_firm_2006_2025_manual_land_audit.csv ../output/six_firm_2006_2025_manual_land_trends.csv

../output/six_firm_2006_2025_manual_land_panel.csv: build_six_firm_manual_land_panel.R ../../_lib/homebuilder_pipeline_utils.R ../input/dhi_len_phm_2006_2025_manual_land_panel.csv ../input/kbh_hov_2006_2025_manual_land_panel.csv ../input/nvr_2006_2025_manual_land_panel.csv | ../output
	$(R) $<

../output/six_firm_2006_2025_manual_land_audit.csv: ../output/six_firm_2006_2025_manual_land_panel.csv
	@test -s "$@"

../output/six_firm_2006_2025_manual_land_trends.csv: ../output/six_firm_2006_2025_manual_land_panel.csv
	@test -s "$@"

../input/dhi_len_phm_2006_2025_manual_land_panel.csv: ../../hand_code_dhi_len_phm_land_disclosures/output/dhi_len_phm_2006_2025_manual_land_panel.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

../input/kbh_hov_2006_2025_manual_land_panel.csv: ../../hand_code_kbh_hov_land_disclosures/output/kbh_hov_2006_2025_manual_land_panel.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

../input/nvr_2006_2025_manual_land_panel.csv: ../../hand_code_nvr_land_disclosures/output/nvr_2006_2025_manual_land_panel.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

link-inputs: ../input/dhi_len_phm_2006_2025_manual_land_panel.csv ../input/kbh_hov_2006_2025_manual_land_panel.csv ../input/nvr_2006_2025_manual_land_panel.csv

include ../../generic.make
