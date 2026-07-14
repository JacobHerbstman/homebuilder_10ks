SHELL := bash
include ../../shell_functions.make

all: ../output/nwhm_2013_2020_land_panel.csv ../output/nwhm_2013_2020_extraction_audit.csv ../output/nwhm_2013_2020_source_notes.csv

../output/nwhm_2013_2020_land_panel.csv: extract_new_home_company_land_disclosures.py ../input/land_light_firm_year_measures.csv | ../output
	python3 $<

../output/nwhm_2013_2020_extraction_audit.csv: ../output/nwhm_2013_2020_land_panel.csv
	@test -s "$@"

../output/nwhm_2013_2020_source_notes.csv: ../output/nwhm_2013_2020_land_panel.csv
	@test -s "$@"

../input/land_light_firm_year_measures.csv: ../../build_land_light_measures/output/land_light_firm_year_measures.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

link-inputs: ../input/land_light_firm_year_measures.csv

include ../../generic.make
