SHELL := bash
include ../../shell_functions.make

all: ../output/builder_public_firm_harmonized.csv ../output/builder_public_harmonization_groups.csv ../output/builder_public_harmonization_review.csv ../output/builder_public_lifecycle_events.csv ../output/builder_public_firm_year_identifiers.csv ../output/builder_public_harmonization_qc.csv

../output/builder_public_firm_harmonized.csv: harmonize_builder_public_firms.R ../../_lib/homebuilder_pipeline_utils.R manual_builder_public_firm_harmonization.csv manual_builder_public_firm_harmonization_pairs.csv manual_builder_public_firm_lifecycle.csv ../input/builder_panel.parquet ../input/builder_public_firm_roster.csv ../input/builder_sec_crosswalk.csv | ../output
	$(R) $<

../output/builder_public_harmonization_groups.csv: ../output/builder_public_firm_harmonized.csv
	@test -s "$@"

../output/builder_public_harmonization_review.csv: ../output/builder_public_firm_harmonized.csv
	@test -s "$@"

../output/builder_public_lifecycle_events.csv: ../output/builder_public_firm_harmonized.csv
	@test -s "$@"

../output/builder_public_firm_year_identifiers.csv: ../output/builder_public_firm_harmonized.csv
	@test -s "$@"

../output/builder_public_harmonization_qc.csv: ../output/builder_public_firm_harmonized.csv
	@test -s "$@"

../input/builder_panel.parquet: ../../stage_builder_panel/output/builder_panel.parquet | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

../input/builder_public_firm_roster.csv: ../../stage_builder_panel/output/builder_public_firm_roster.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

../input/builder_sec_crosswalk.csv: ../../build_builder_sec_crosswalk/output/builder_sec_crosswalk.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

link-inputs: ../input/builder_panel.parquet ../input/builder_public_firm_roster.csv ../input/builder_sec_crosswalk.csv

include ../../generic.make
