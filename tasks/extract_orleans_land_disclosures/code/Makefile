SHELL := bash
include ../../shell_functions.make

all: ../output/ohb_2004_2008_land_panel.csv ../output/ohb_2004_2008_extraction_audit.csv ../output/ohb_2004_2008_source_notes.csv

../output/ohb_2004_2008_land_panel.csv: extract_orleans_land_disclosures.py ../input/land_light_firm_year_measures.csv | ../output
	python3 $<

../output/ohb_2004_2008_extraction_audit.csv: ../output/ohb_2004_2008_land_panel.csv
	@test -s "$@"

../output/ohb_2004_2008_source_notes.csv: ../output/ohb_2004_2008_land_panel.csv
	@test -s "$@"

../input/land_light_firm_year_measures.csv: ../../build_land_light_measures/output/land_light_firm_year_measures.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

link-inputs: ../input/land_light_firm_year_measures.csv

include ../../generic.make
