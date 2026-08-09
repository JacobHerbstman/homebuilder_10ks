SHELL := bash
R := Rscript

all: ../output/expanded_builder_land_coverage_by_firm.csv ../output/expanded_builder_land_coverage_by_year.csv ../output/expanded_builder_land_review_queue.csv ../output/expanded_builder_land_gap_audit.csv

../output/expanded_builder_land_coverage_by_firm.csv: audit_expanded_builder_land_panel.R ../../../_lib/homebuilder_pipeline_utils.R ../input/expanded_builder_2004_2025_land_panel.csv | ../output
	$(R) $<

../output/expanded_builder_land_coverage_by_year.csv: ../output/expanded_builder_land_coverage_by_firm.csv
	@test -s "$@"

../output/expanded_builder_land_review_queue.csv: ../output/expanded_builder_land_coverage_by_firm.csv
	@test -s "$@"

../output/expanded_builder_land_gap_audit.csv: ../output/expanded_builder_land_coverage_by_firm.csv
	@test -s "$@"

../input/expanded_builder_2004_2025_land_panel.csv: ../../../build_expanded_builder_land_panel/output/expanded_builder_2004_2025_land_panel.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

link-inputs: ../input/expanded_builder_2004_2025_land_panel.csv

include ../../../generic.make
