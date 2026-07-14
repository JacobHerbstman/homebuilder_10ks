SHELL := bash
R := Rscript

all: ../output/tier1_land_light_timeseries.png ../output/tier1_land_light_timeseries.pdf

../output/tier1_land_light_timeseries.png: plot_tier1_land_light_timeseries.R ../input/expanded_builder_2004_2025_land_panel.csv | ../output
	$(R) $<

../output/tier1_land_light_timeseries.pdf: ../output/tier1_land_light_timeseries.png
	@test -s "$@"

../input/expanded_builder_2004_2025_land_panel.csv: ../../build_expanded_builder_land_panel/output/expanded_builder_2004_2025_land_panel.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

link-inputs: ../input/expanded_builder_2004_2025_land_panel.csv

include ../../generic.make
