SHELL := bash
include ../../shell_functions.make

all: ../output/public_builder_10k_land_panel.csv ../output/tenk_land_preferred_values.csv ../output/tenk_land_segment_year_panel.csv ../output/tenk_land_value_selection_audit.csv ../output/tenk_land_benchmark_audit.csv

../output/public_builder_10k_land_panel.csv: build_10k_land_panel.R ../../_lib/homebuilder_pipeline_utils.R ../input/tenk_land_candidates.csv ../input/sec_10k_download_inventory.csv ../input/builder_public_firm_year_identifiers.csv | ../output
	$(R) $<

../output/tenk_land_preferred_values.csv: ../output/public_builder_10k_land_panel.csv
	@test -s "$@"

../output/tenk_land_segment_year_panel.csv: ../output/public_builder_10k_land_panel.csv
	@test -s "$@"

../output/tenk_land_value_selection_audit.csv: ../output/public_builder_10k_land_panel.csv
	@test -s "$@"

../output/tenk_land_benchmark_audit.csv: ../output/public_builder_10k_land_panel.csv
	@test -s "$@"

../input/tenk_land_candidates.csv: ../../extract_10k_land_candidates/output/tenk_land_candidates.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

../input/sec_10k_download_inventory.csv: ../../fetch_sec_10k_filings/output/sec_10k_download_inventory.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

../input/builder_public_firm_year_identifiers.csv: ../../harmonize_builder_public_firms/output/builder_public_firm_year_identifiers.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

link-inputs: ../input/tenk_land_candidates.csv ../input/sec_10k_download_inventory.csv ../input/builder_public_firm_year_identifiers.csv

include ../../generic.make
