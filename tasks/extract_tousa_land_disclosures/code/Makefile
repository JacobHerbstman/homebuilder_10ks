SHELL := bash
include ../../shell_functions.make

all: ../output/toa_2004_2007_land_panel.csv ../output/toa_2004_2007_extraction_audit.csv ../output/toa_2004_2007_source_notes.csv

../output/toa_2004_2007_land_panel.csv: extract_tousa_land_disclosures.py ../input/land_light_firm_year_measures.csv | ../output
	python3 $<

../output/toa_2004_2007_extraction_audit.csv: ../output/toa_2004_2007_land_panel.csv
	@test -s "$@"

../output/toa_2004_2007_source_notes.csv: ../output/toa_2004_2007_land_panel.csv
	@test -s "$@"

../input/land_light_firm_year_measures.csv: ../../build_land_light_measures/output/land_light_firm_year_measures.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

link-inputs: ../input/land_light_firm_year_measures.csv

include ../../generic.make
