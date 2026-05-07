SHELL := bash
include ../../shell_functions.make

all: ../output/sec_builder_coverage_audit.csv ../output/sec_public_builders_unmatched.csv ../output/sec_matched_no_10k_filings.csv ../output/sec_filings_start_after_builder_public_year.csv ../output/sec_download_status_audit.csv ../output/sec_filings_no_land_hits.csv ../output/sec_benchmark_availability.csv

../output/sec_builder_coverage_audit.csv: audit_sec_coverage.R ../../_lib/homebuilder_pipeline_utils.R ../input/builder_sec_crosswalk.csv ../input/sec_10k_filing_index.csv ../input/sec_10k_download_inventory.csv ../input/tenk_land_candidates.csv ../input/tenk_land_mention_flags.csv | ../output
	$(R) $<

../output/sec_public_builders_unmatched.csv: ../output/sec_builder_coverage_audit.csv
	@test -s "$@"

../output/sec_matched_no_10k_filings.csv: ../output/sec_builder_coverage_audit.csv
	@test -s "$@"

../output/sec_filings_start_after_builder_public_year.csv: ../output/sec_builder_coverage_audit.csv
	@test -s "$@"

../output/sec_download_status_audit.csv: ../output/sec_builder_coverage_audit.csv
	@test -s "$@"

../output/sec_filings_no_land_hits.csv: ../output/sec_builder_coverage_audit.csv
	@test -s "$@"

../output/sec_benchmark_availability.csv: ../output/sec_builder_coverage_audit.csv
	@test -s "$@"

../input/builder_sec_crosswalk.csv: ../../build_builder_sec_crosswalk/output/builder_sec_crosswalk.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

../input/sec_10k_filing_index.csv: ../../build_sec_10k_filing_index/output/sec_10k_filing_index.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

../input/sec_10k_download_inventory.csv: ../../fetch_sec_10k_filings/output/sec_10k_download_inventory.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

../input/tenk_land_candidates.csv: ../../extract_10k_land_candidates/output/tenk_land_candidates.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

../input/tenk_land_mention_flags.csv: ../../extract_10k_land_candidates/output/tenk_land_mention_flags.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

link-inputs: ../input/builder_sec_crosswalk.csv ../input/sec_10k_filing_index.csv ../input/sec_10k_download_inventory.csv ../input/tenk_land_candidates.csv ../input/tenk_land_mention_flags.csv

include ../../generic.make
