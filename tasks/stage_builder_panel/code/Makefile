SHELL := bash
include ../../shell_functions.make

all: ../output/builder_panel.parquet ../output/builder_firm_roster.csv ../output/builder_public_firm_roster.csv ../output/builder_year_coverage.csv ../output/builder_panel_qc.csv

../output/builder_panel.parquet: stage_builder_panel.R ../../_lib/homebuilder_pipeline_utils.R ../input/builder_magazine_raw_rows.csv | ../output
	$(R) $<

../output/builder_firm_roster.csv: ../output/builder_panel.parquet
	@test -s "$@"

../output/builder_public_firm_roster.csv: ../output/builder_panel.parquet
	@test -s "$@"

../output/builder_year_coverage.csv: ../output/builder_panel.parquet
	@test -s "$@"

../output/builder_panel_qc.csv: ../output/builder_panel.parquet
	@test -s "$@"

../input/builder_magazine_raw_rows.csv: ../../load_builder_magazine_raw/output/builder_magazine_raw_rows.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

link-inputs: ../input/builder_magazine_raw_rows.csv

include ../../generic.make
