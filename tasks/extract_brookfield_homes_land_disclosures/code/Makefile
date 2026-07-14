SHELL := bash
include ../../shell_functions.make

all: ../output/bhs_2004_2010_land_panel.csv ../output/bhs_2004_2010_extraction_audit.csv ../output/bhs_2004_2010_source_notes.csv

../output/bhs_2004_2010_land_panel.csv: extract_brookfield_homes_land_disclosures.py ../input/land_light_firm_year_measures.csv | ../output
	python3 $<

../output/bhs_2004_2010_extraction_audit.csv: ../output/bhs_2004_2010_land_panel.csv
	@test -s "$@"

../output/bhs_2004_2010_source_notes.csv: ../output/bhs_2004_2010_land_panel.csv
	@test -s "$@"

../input/land_light_firm_year_measures.csv: ../../build_land_light_measures/output/land_light_firm_year_measures.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

link-inputs: ../input/land_light_firm_year_measures.csv

include ../../generic.make
