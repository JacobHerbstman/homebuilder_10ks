SHELL := bash
include ../../shell_functions.make

all: ../output/ucp_2013_2016_land_panel.csv ../output/ucp_2013_2016_extraction_audit.csv ../output/ucp_2013_2016_source_notes.csv

../output/ucp_2013_2016_land_panel.csv: extract_ucp_land_disclosures.py ../input/land_light_firm_year_measures.csv | ../output
	python3 $<

../output/ucp_2013_2016_extraction_audit.csv: ../output/ucp_2013_2016_land_panel.csv
	@test -s "$@"

../output/ucp_2013_2016_source_notes.csv: ../output/ucp_2013_2016_land_panel.csv
	@test -s "$@"

../input/land_light_firm_year_measures.csv: ../../build_land_light_measures/output/land_light_firm_year_measures.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

link-inputs: ../input/land_light_firm_year_measures.csv

include ../../generic.make
