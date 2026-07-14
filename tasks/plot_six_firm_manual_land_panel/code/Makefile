SHELL := bash
include ../../shell_functions.make

all: ../output/six_firm_nonowned_controlled_share_timeseries.png ../output/six_firm_nonowned_controlled_share_timeseries.pdf ../output/six_firm_nonowned_controlled_share_plot_data.csv

../output/six_firm_nonowned_controlled_share_timeseries.png: plot_six_firm_manual_land_panel.R ../../_lib/homebuilder_pipeline_utils.R ../input/six_firm_2006_2025_manual_land_panel.csv | ../output
	$(R) $<

../output/six_firm_nonowned_controlled_share_timeseries.pdf: ../output/six_firm_nonowned_controlled_share_timeseries.png
	@test -s "$@"

../output/six_firm_nonowned_controlled_share_plot_data.csv: ../output/six_firm_nonowned_controlled_share_timeseries.png
	@test -s "$@"

../input/six_firm_2006_2025_manual_land_panel.csv: ../../build_six_firm_manual_land_panel/output/six_firm_2006_2025_manual_land_panel.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

link-inputs: ../input/six_firm_2006_2025_manual_land_panel.csv

include ../../generic.make
