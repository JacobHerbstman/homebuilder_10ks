SHELL := bash
R := Rscript

all: ../output/tier1_land_adjustment_benchmark_audit.csv ../output/tier1_land_adjustment_coverage_audit.csv

../output/tier1_land_adjustment_benchmark_audit.csv: audit_tier1_land_adjustment_panel.R ../../../_lib/homebuilder_pipeline_utils.R ../input/tier1_2021_2023_land_adjustment_panel.csv | ../output
	$(R) $<

../output/tier1_land_adjustment_coverage_audit.csv: ../output/tier1_land_adjustment_benchmark_audit.csv
	@test -s "$@"

../input/tier1_2021_2023_land_adjustment_panel.csv: ../../../build_tier1_land_adjustment_panel/output/tier1_2021_2023_land_adjustment_panel.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

link-inputs: ../input/tier1_2021_2023_land_adjustment_panel.csv

include ../../../generic.make
