SHELL := bash
include ../../shell_functions.make

all: ../output/builder_universe_sec_crosswalk.csv ../output/builder_universe_roster_staged.csv ../output/builder_universe_match_candidates.csv ../output/builder_universe_manual_review.csv ../output/builder_universe_qc.csv

../output/builder_universe_sec_crosswalk.csv: stage_builder_universe_roster.R manual_builder_universe_additions.csv ../../_lib/homebuilder_pipeline_utils.R ../input/builder_universe_roster.csv ../input/builder_sec_crosswalk.csv ../input/sec_company_tickers_files.csv ../input/sec_sic_1531_companies.csv | ../output
	$(R) $<

../output/builder_universe_roster_staged.csv: ../output/builder_universe_sec_crosswalk.csv
	@test -s "$@"

../output/builder_universe_match_candidates.csv: ../output/builder_universe_sec_crosswalk.csv
	@test -s "$@"

../output/builder_universe_manual_review.csv: ../output/builder_universe_sec_crosswalk.csv
	@test -s "$@"

../output/builder_universe_qc.csv: ../output/builder_universe_sec_crosswalk.csv
	@test -s "$@"

../input/builder_universe_roster.csv: ../../../data_raw/builder_universe_roster/builder_universe_roster.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

../input/builder_sec_crosswalk.csv: ../../build_builder_sec_crosswalk/output/builder_sec_crosswalk.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

../input/sec_company_tickers_files.csv: ../../fetch_sec_company_tickers/output/sec_company_tickers_files.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

../input/sec_sic_1531_companies.csv: ../../fetch_sec_sic_1531_universe/output/sec_sic_1531_companies.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

link-inputs: ../input/builder_universe_roster.csv ../input/builder_sec_crosswalk.csv ../input/sec_company_tickers_files.csv ../input/sec_sic_1531_companies.csv

include ../../generic.make
