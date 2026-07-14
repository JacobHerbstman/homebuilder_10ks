SHELL := bash
include ../../shell_functions.make

all: ../output/sec_sic_1531_builder_overlap.csv ../output/sec_sic_1531_not_in_builder_crosswalk.csv ../output/builder_public_not_in_sec_sic_1531.csv ../output/sec_sic_1531_universe_qc.csv

../output/sec_sic_1531_builder_overlap.csv: audit_sec_sic_1531_universe.R ../../_lib/homebuilder_pipeline_utils.R ../input/sec_sic_1531_companies.csv ../input/builder_sec_crosswalk.csv | ../output
	$(R) $<

../output/sec_sic_1531_not_in_builder_crosswalk.csv: ../output/sec_sic_1531_builder_overlap.csv
	@test -s "$@"

../output/builder_public_not_in_sec_sic_1531.csv: ../output/sec_sic_1531_builder_overlap.csv
	@test -s "$@"

../output/sec_sic_1531_universe_qc.csv: ../output/sec_sic_1531_builder_overlap.csv
	@test -s "$@"

../input/sec_sic_1531_companies.csv: ../../fetch_sec_sic_1531_universe/output/sec_sic_1531_companies.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

../input/builder_sec_crosswalk.csv: ../../build_builder_sec_crosswalk/output/builder_sec_crosswalk.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

link-inputs: ../input/sec_sic_1531_companies.csv ../input/builder_sec_crosswalk.csv

include ../../generic.make
