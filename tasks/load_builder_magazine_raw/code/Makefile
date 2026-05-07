SHELL := bash
include ../../shell_functions.make

all: ../output/builder_magazine_raw_rows.csv ../output/builder_magazine_parse_qc.csv

../output/builder_magazine_raw_rows.csv: load_builder_magazine_raw.R ../../_lib/homebuilder_pipeline_utils.R ../input/builder_magazine_html_files.csv | ../output
	$(R) $<

../output/builder_magazine_parse_qc.csv: ../output/builder_magazine_raw_rows.csv
	@test -s "$@"

../input/builder_magazine_html_files.csv: ../../fetch_builder_magazine_lists/output/builder_magazine_html_files.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

link-inputs: ../input/builder_magazine_html_files.csv

include ../../generic.make
