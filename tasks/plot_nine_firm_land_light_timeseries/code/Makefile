SHELL := bash
include ../../shell_functions.make

all: ../output/nine_firm_land_light_timeseries.png ../output/nine_firm_land_light_timeseries.pdf

../output/nine_firm_land_light_timeseries.png: plot_nine_firm_land_light_timeseries.R ../input/expanded_builder_2004_2025_land_panel.csv | ../output
	$(R) $<

../output/nine_firm_land_light_timeseries.pdf: ../output/nine_firm_land_light_timeseries.png
	@test -s "$@"

../input/expanded_builder_2004_2025_land_panel.csv: ../../build_expanded_builder_land_panel/output/expanded_builder_2004_2025_land_panel.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

link-inputs: ../input/expanded_builder_2004_2025_land_panel.csv

include ../../generic.make
