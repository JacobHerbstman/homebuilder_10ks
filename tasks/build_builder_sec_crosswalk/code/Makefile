SHELL := bash
include ../../shell_functions.make

all: ../output/builder_sec_crosswalk.csv ../output/builder_sec_match_candidates.csv ../output/builder_sec_unmatched_public_firms.csv ../output/builder_sec_crosswalk_qc.csv

../output/builder_sec_crosswalk.csv: build_builder_sec_crosswalk.R ../../_lib/homebuilder_pipeline_utils.R manual_builder_sec_crosswalk.csv ../input/builder_public_firm_roster.csv ../input/sec_company_tickers_files.csv | ../output
	$(R) $<

../output/builder_sec_match_candidates.csv: ../output/builder_sec_crosswalk.csv
	@test -s "$@"

../output/builder_sec_unmatched_public_firms.csv: ../output/builder_sec_crosswalk.csv
	@test -s "$@"

../output/builder_sec_crosswalk_qc.csv: ../output/builder_sec_crosswalk.csv
	@test -s "$@"

../input/builder_public_firm_roster.csv: ../../stage_builder_panel/output/builder_public_firm_roster.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

../input/sec_company_tickers_files.csv: ../../fetch_sec_company_tickers/output/sec_company_tickers_files.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

link-inputs: ../input/builder_public_firm_roster.csv ../input/sec_company_tickers_files.csv

include ../../generic.make
