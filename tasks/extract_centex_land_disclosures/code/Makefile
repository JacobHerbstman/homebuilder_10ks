SHELL := bash
include ../../shell_functions.make

all: ../output/ctx_2004_2009_land_panel.csv ../output/ctx_2004_2009_extraction_audit.csv ../output/ctx_2004_2009_source_notes.csv

../output/ctx_2004_2009_land_panel.csv: extract_centex_land_disclosures.py ../input/land_light_firm_year_measures.csv | ../output
	python3 $<

../output/ctx_2004_2009_extraction_audit.csv: ../output/ctx_2004_2009_land_panel.csv
	@test -s "$@"

../output/ctx_2004_2009_source_notes.csv: ../output/ctx_2004_2009_land_panel.csv
	@test -s "$@"

../input/land_light_firm_year_measures.csv: ../../build_land_light_measures/output/land_light_firm_year_measures.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

link-inputs: ../input/land_light_firm_year_measures.csv

include ../../generic.make
