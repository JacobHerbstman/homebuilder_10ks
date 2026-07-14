SHELL := bash
include ../../shell_functions.make

OPERATING_START_YEAR := 2012
OPERATING_END_YEAR := 2023

all: ../output/six_firm_boom_bust_response_panel.csv ../output/six_firm_boom_bust_response_summary.csv ../output/six_firm_boom_bust_response_audit.csv ../output/six_firm_order_unit_growth_vs_lagged_omega.png ../output/six_firm_delivery_growth_vs_lagged_omega.png ../output/six_firm_order_unit_growth_vs_lagged_omega.pdf ../output/six_firm_delivery_growth_vs_lagged_omega.pdf ../output/six_firm_order_unit_growth_vs_lagged_omega_2013_2019.png ../output/six_firm_delivery_growth_vs_lagged_omega_2013_2019.png ../output/six_firm_order_unit_growth_vs_lagged_omega_2013_2019.pdf ../output/six_firm_delivery_growth_vs_lagged_omega_2013_2019.pdf

../output/six_firm_boom_bust_response_panel.csv: build_six_firm_boom_bust_response.R ../../_lib/homebuilder_pipeline_utils.R ../input/six_firm_2006_2025_operating_panel.csv ../input/six_firm_2006_2025_manual_land_panel.csv | ../output
	$(R) $< $(OPERATING_START_YEAR) $(OPERATING_END_YEAR)

../output/six_firm_boom_bust_response_summary.csv: ../output/six_firm_boom_bust_response_panel.csv
	@test -s "$@"

../output/six_firm_boom_bust_response_audit.csv: ../output/six_firm_boom_bust_response_panel.csv
	@test -s "$@"

../output/six_firm_order_unit_growth_vs_lagged_omega.png: ../output/six_firm_boom_bust_response_panel.csv
	@test -s "$@"

../output/six_firm_delivery_growth_vs_lagged_omega.png: ../output/six_firm_boom_bust_response_panel.csv
	@test -s "$@"

../output/six_firm_order_unit_growth_vs_lagged_omega.pdf: ../output/six_firm_boom_bust_response_panel.csv
	@test -s "$@"

../output/six_firm_delivery_growth_vs_lagged_omega.pdf: ../output/six_firm_boom_bust_response_panel.csv
	@test -s "$@"

../output/six_firm_order_unit_growth_vs_lagged_omega_2013_2019.png: ../output/six_firm_boom_bust_response_panel.csv
	@test -s "$@"

../output/six_firm_delivery_growth_vs_lagged_omega_2013_2019.png: ../output/six_firm_boom_bust_response_panel.csv
	@test -s "$@"

../output/six_firm_order_unit_growth_vs_lagged_omega_2013_2019.pdf: ../output/six_firm_boom_bust_response_panel.csv
	@test -s "$@"

../output/six_firm_delivery_growth_vs_lagged_omega_2013_2019.pdf: ../output/six_firm_boom_bust_response_panel.csv
	@test -s "$@"

../input/six_firm_2006_2025_manual_land_panel.csv: ../../build_six_firm_manual_land_panel/output/six_firm_2006_2025_manual_land_panel.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

../input/six_firm_2006_2025_operating_panel.csv: ../../extract_six_firm_annual_operating_disclosures/output/six_firm_2006_2025_operating_panel.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

link-inputs: ../input/six_firm_2006_2025_operating_panel.csv ../input/six_firm_2006_2025_manual_land_panel.csv

include ../../generic.make
