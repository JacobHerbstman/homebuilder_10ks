SHELL := bash
include ../../shell_functions.make

all: ../output/ryl_2004_2014_land_panel.csv ../output/ryl_2004_2014_extraction_audit.csv ../output/ryl_2004_2014_source_notes.csv

../output/ryl_2004_2014_land_panel.csv: extract_ryland_land_disclosures.py ../input/land_light_firm_year_measures.csv | ../output
	python3 $<

../output/ryl_2004_2014_extraction_audit.csv: ../output/ryl_2004_2014_land_panel.csv
	@test -s "$@"

../output/ryl_2004_2014_source_notes.csv: ../output/ryl_2004_2014_land_panel.csv
	@test -s "$@"

../input/land_light_firm_year_measures.csv: ../../build_land_light_measures/output/land_light_firm_year_measures.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

link-inputs: ../input/land_light_firm_year_measures.csv

include ../../generic.make
