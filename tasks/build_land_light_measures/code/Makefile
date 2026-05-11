SHELL := bash
include ../../shell_functions.make

all: ../output/land_light_firm_year_measures.csv ../output/land_light_measure_coverage_by_year.csv ../output/land_light_measure_coverage_by_firm.csv ../output/land_light_identity_audit.csv ../output/land_light_metric_provenance.csv ../output/land_light_manual_review.csv ../output/land_light_plot_summary.csv

../output/land_light_firm_year_measures.csv: build_land_light_measures.R ../../_lib/homebuilder_pipeline_utils.R ../input/public_builder_10k_land_panel.csv ../input/tenk_land_preferred_values.csv ../input/tenk_land_value_selection_audit.csv | ../output
	$(R) $<

../output/land_light_measure_coverage_by_year.csv: ../output/land_light_firm_year_measures.csv
	@test -s "$@"

../output/land_light_measure_coverage_by_firm.csv: ../output/land_light_firm_year_measures.csv
	@test -s "$@"

../output/land_light_identity_audit.csv: ../output/land_light_firm_year_measures.csv
	@test -s "$@"

../output/land_light_metric_provenance.csv: ../output/land_light_firm_year_measures.csv
	@test -s "$@"

../output/land_light_manual_review.csv: ../output/land_light_firm_year_measures.csv
	@test -s "$@"

../output/land_light_plot_summary.csv: ../output/land_light_firm_year_measures.csv
	@test -s "$@"

../input/public_builder_10k_land_panel.csv: ../../build_10k_land_panel/output/public_builder_10k_land_panel.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

../input/tenk_land_preferred_values.csv: ../../build_10k_land_panel/output/tenk_land_preferred_values.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

../input/tenk_land_value_selection_audit.csv: ../../build_10k_land_panel/output/tenk_land_value_selection_audit.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

link-inputs: ../input/public_builder_10k_land_panel.csv ../input/tenk_land_preferred_values.csv ../input/tenk_land_value_selection_audit.csv

include ../../generic.make
