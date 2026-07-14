SHELL := bash
R := Rscript

ANALYSIS_START_YEAR := 2019
ANALYSIS_END_YEAR := 2025

all: ../output/tier1_annual_response_panel.csv ../output/tier1_annual_response_summary.csv ../output/tier1_order_growth_vs_lagged_omega.png ../output/tier1_delivery_growth_vs_lagged_omega.png ../output/tier1_backlog_growth_vs_lagged_omega.png ../output/tier1_order_growth_vs_lagged_omega.pdf ../output/tier1_delivery_growth_vs_lagged_omega.pdf ../output/tier1_backlog_growth_vs_lagged_omega.pdf

../output/tier1_annual_response_panel.csv: analyze_tier1_annual_response.R ../../_lib/homebuilder_pipeline_utils.R ../input/tier1_2018_2025_annual_operating_panel.csv ../input/expanded_builder_land_plot_data.csv | ../output
	$(R) $< $(ANALYSIS_START_YEAR) $(ANALYSIS_END_YEAR)

../output/tier1_annual_response_summary.csv: ../output/tier1_annual_response_panel.csv
	@test -s "$@"

../output/tier1_order_growth_vs_lagged_omega.png: ../output/tier1_annual_response_panel.csv
	@test -s "$@"

../output/tier1_delivery_growth_vs_lagged_omega.png: ../output/tier1_annual_response_panel.csv
	@test -s "$@"

../output/tier1_backlog_growth_vs_lagged_omega.png: ../output/tier1_annual_response_panel.csv
	@test -s "$@"

../output/tier1_order_growth_vs_lagged_omega.pdf: ../output/tier1_annual_response_panel.csv
	@test -s "$@"

../output/tier1_delivery_growth_vs_lagged_omega.pdf: ../output/tier1_annual_response_panel.csv
	@test -s "$@"

../output/tier1_backlog_growth_vs_lagged_omega.pdf: ../output/tier1_annual_response_panel.csv
	@test -s "$@"

../input/tier1_2018_2025_annual_operating_panel.csv: ../../build_tier1_annual_operating_panel/output/tier1_2018_2025_annual_operating_panel.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

../input/expanded_builder_land_plot_data.csv: ../../build_expanded_builder_land_panel/output/expanded_builder_land_plot_data.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

link-inputs: ../input/tier1_2018_2025_annual_operating_panel.csv ../input/expanded_builder_land_plot_data.csv

include ../../generic.make
