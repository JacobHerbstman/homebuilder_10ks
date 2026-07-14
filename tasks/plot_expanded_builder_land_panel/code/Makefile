SHELL := bash
include ../../shell_functions.make

all: ../output/expanded_builder_nonowned_controlled_share_timeseries.png ../output/expanded_builder_nonowned_controlled_share_timeseries.pdf ../output/expanded_builder_nonowned_controlled_share_plot_data.csv ../output/unbalanced_2006_2025_nonowned_controlled_share_timeseries.png ../output/unbalanced_2006_2025_nonowned_controlled_share_timeseries.pdf ../output/unbalanced_2006_2025_nonowned_controlled_share_plot_data.csv ../output/balanced_2006_2025_nonowned_controlled_share_timeseries.png ../output/balanced_2006_2025_nonowned_controlled_share_timeseries.pdf ../output/balanced_2006_2025_nonowned_controlled_share_plot_data.csv

../output/expanded_builder_nonowned_controlled_share_timeseries.png: plot_expanded_builder_land_panel.R ../../_lib/homebuilder_pipeline_utils.R ../input/expanded_builder_land_plot_data.csv | ../output
	$(R) $<

../output/expanded_builder_nonowned_controlled_share_timeseries.pdf: ../output/expanded_builder_nonowned_controlled_share_timeseries.png
	@test -s "$@"

../output/expanded_builder_nonowned_controlled_share_plot_data.csv: ../output/expanded_builder_nonowned_controlled_share_timeseries.png
	@test -s "$@"

../output/unbalanced_2006_2025_nonowned_controlled_share_timeseries.png: ../output/expanded_builder_nonowned_controlled_share_timeseries.png
	@test -s "$@"

../output/unbalanced_2006_2025_nonowned_controlled_share_timeseries.pdf: ../output/expanded_builder_nonowned_controlled_share_timeseries.png
	@test -s "$@"

../output/unbalanced_2006_2025_nonowned_controlled_share_plot_data.csv: ../output/expanded_builder_nonowned_controlled_share_timeseries.png
	@test -s "$@"

../output/balanced_2006_2025_nonowned_controlled_share_timeseries.png: ../output/expanded_builder_nonowned_controlled_share_timeseries.png
	@test -s "$@"

../output/balanced_2006_2025_nonowned_controlled_share_timeseries.pdf: ../output/expanded_builder_nonowned_controlled_share_timeseries.png
	@test -s "$@"

../output/balanced_2006_2025_nonowned_controlled_share_plot_data.csv: ../output/expanded_builder_nonowned_controlled_share_timeseries.png
	@test -s "$@"

../input/expanded_builder_land_plot_data.csv: ../../build_expanded_builder_land_panel/output/expanded_builder_land_plot_data.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

link-inputs: ../input/expanded_builder_land_plot_data.csv

include ../../generic.make
