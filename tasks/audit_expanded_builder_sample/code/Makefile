SHELL := bash
include ../../shell_functions.make

all: ../output/builder_public_universe_reconciliation.csv ../output/land_gap_retrieval_audit.csv ../output/operating_measure_readiness.csv ../output/expanded_builder_sample_audit_qc.csv

../output/builder_public_universe_reconciliation.csv: audit_expanded_builder_sample.R manual_builder_scope_decisions.csv manual_land_gap_reviews.csv ../../_lib/homebuilder_pipeline_utils.R ../input/builder_panel.parquet ../input/builder_public_firm_harmonized.csv ../input/builder_universe_sec_crosswalk.csv ../input/expanded_builder_2004_2025_land_panel.csv ../input/expanded_builder_land_gap_audit.csv ../input/tenk_land_preferred_values.csv ../input/six_firm_boom_bust_response_panel.csv ../input/sec_10k_filing_index.csv | ../output
	$(R) $<

../output/land_gap_retrieval_audit.csv: ../output/builder_public_universe_reconciliation.csv
	@test -s "$@"

../output/operating_measure_readiness.csv: ../output/builder_public_universe_reconciliation.csv
	@test -s "$@"

../output/expanded_builder_sample_audit_qc.csv: ../output/builder_public_universe_reconciliation.csv
	@test -s "$@"

../input/builder_panel.parquet: ../../stage_builder_panel/output/builder_panel.parquet | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

../input/builder_public_firm_harmonized.csv: ../../harmonize_builder_public_firms/output/builder_public_firm_harmonized.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

../input/builder_universe_sec_crosswalk.csv: ../../stage_builder_universe_roster/output/builder_universe_sec_crosswalk.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

../input/expanded_builder_2004_2025_land_panel.csv: ../../build_expanded_builder_land_panel/output/expanded_builder_2004_2025_land_panel.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

../input/expanded_builder_land_gap_audit.csv: ../../build_expanded_builder_land_panel/output/expanded_builder_land_gap_audit.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

../input/tenk_land_preferred_values.csv: ../../build_10k_land_panel/output/tenk_land_preferred_values.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

../input/six_firm_boom_bust_response_panel.csv: ../../analyze_six_firm_boom_bust_response/output/six_firm_boom_bust_response_panel.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

../input/sec_10k_filing_index.csv: ../../build_sec_10k_filing_index/output/sec_10k_filing_index.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

link-inputs: ../input/builder_panel.parquet ../input/builder_public_firm_harmonized.csv ../input/builder_universe_sec_crosswalk.csv ../input/expanded_builder_2004_2025_land_panel.csv ../input/expanded_builder_land_gap_audit.csv ../input/tenk_land_preferred_values.csv ../input/six_firm_boom_bust_response_panel.csv ../input/sec_10k_filing_index.csv

include ../../generic.make
