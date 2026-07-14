SHELL := bash
include ../../shell_functions.make

all: ../output/wlh_2004_2018_land_panel.csv ../output/wlh_2004_2018_extraction_audit.csv ../output/wlh_2004_2018_source_notes.csv

../output/wlh_2004_2018_land_panel.csv: extract_william_lyon_land_disclosures.py ../input/land_light_firm_year_measures.csv | ../output
	python3 $<

../output/wlh_2004_2018_extraction_audit.csv: ../output/wlh_2004_2018_land_panel.csv
	@test -s "$@"

../output/wlh_2004_2018_source_notes.csv: ../output/wlh_2004_2018_land_panel.csv
	@test -s "$@"

../input/land_light_firm_year_measures.csv: ../../build_land_light_measures/output/land_light_firm_year_measures.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

link-inputs: ../input/land_light_firm_year_measures.csv

include ../../generic.make
