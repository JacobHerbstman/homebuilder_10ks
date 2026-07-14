SHELL := bash
include ../../shell_functions.make

all: ../output/builder_operating_extraction_coverage.csv ../output/builder_operating_metric_coverage.csv ../output/builder_operating_extraction_queue.csv ../output/builder_operating_coverage_qc.csv

../output/builder_operating_extraction_coverage.csv: audit_builder_operating_coverage.R ../../_lib/homebuilder_pipeline_utils.R ../input/expanded_builder_land_plot_data.csv ../input/six_firm_2006_2025_operating_panel.csv ../input/wreco_2004_2013_operating_panel.csv | ../output
	$(R) $<

../output/builder_operating_metric_coverage.csv: ../output/builder_operating_extraction_coverage.csv
	@test -s "$@"

../output/builder_operating_extraction_queue.csv: ../output/builder_operating_extraction_coverage.csv
	@test -s "$@"

../output/builder_operating_coverage_qc.csv: ../output/builder_operating_extraction_coverage.csv
	@test -s "$@"

../input/expanded_builder_land_plot_data.csv: ../../build_expanded_builder_land_panel/output/expanded_builder_land_plot_data.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

../input/six_firm_2006_2025_operating_panel.csv: ../../extract_six_firm_annual_operating_disclosures/output/six_firm_2006_2025_operating_panel.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

../input/wreco_2004_2013_operating_panel.csv: ../../extract_wreco_operating_disclosures/output/wreco_2004_2013_operating_panel.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

link-inputs: ../input/expanded_builder_land_plot_data.csv ../input/six_firm_2006_2025_operating_panel.csv ../input/wreco_2004_2013_operating_panel.csv

include ../../generic.make
