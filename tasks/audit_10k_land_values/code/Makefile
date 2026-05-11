SHELL := bash
include ../../shell_functions.make

all: ../output/tenk_land_sanity_summary.csv ../output/tenk_land_sanity_flags.csv ../output/tenk_land_sanity_sample.csv ../output/tenk_land_panel_sanity_flags.csv ../output/tenk_land_panel_column_coverage.csv ../output/tenk_land_benchmark_status.csv

../output/tenk_land_sanity_summary.csv: audit_10k_land_values.R ../../_lib/homebuilder_pipeline_utils.R ../input/tenk_land_preferred_values.csv ../input/tenk_land_value_selection_audit.csv ../input/public_builder_10k_land_panel.csv ../input/tenk_land_benchmark_audit.csv | ../output
	$(R) $<

../output/tenk_land_sanity_flags.csv: ../output/tenk_land_sanity_summary.csv
	@test -s "$@"

../output/tenk_land_sanity_sample.csv: ../output/tenk_land_sanity_summary.csv
	@test -s "$@"

../output/tenk_land_panel_sanity_flags.csv: ../output/tenk_land_sanity_summary.csv
	@test -s "$@"

../output/tenk_land_panel_column_coverage.csv: ../output/tenk_land_sanity_summary.csv
	@test -s "$@"

../output/tenk_land_benchmark_status.csv: ../output/tenk_land_sanity_summary.csv
	@test -s "$@"

../input/tenk_land_preferred_values.csv: ../../build_10k_land_panel/output/tenk_land_preferred_values.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

../input/tenk_land_value_selection_audit.csv: ../../build_10k_land_panel/output/tenk_land_value_selection_audit.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

../input/public_builder_10k_land_panel.csv: ../../build_10k_land_panel/output/public_builder_10k_land_panel.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

../input/tenk_land_benchmark_audit.csv: ../../build_10k_land_panel/output/tenk_land_benchmark_audit.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

link-inputs: ../input/tenk_land_preferred_values.csv ../input/tenk_land_value_selection_audit.csv ../input/public_builder_10k_land_panel.csv ../input/tenk_land_benchmark_audit.csv

include ../../generic.make
