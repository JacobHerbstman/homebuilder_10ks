SHELL := bash
include ../../shell_functions.make

all: ../output/spf_caa_2004_2016_land_panel.csv ../output/spf_caa_2004_2016_extraction_audit.csv ../output/spf_caa_2004_2016_source_notes.csv

../output/spf_caa_2004_2016_land_panel.csv: extract_standard_pacific_calatlantic_land_disclosures.py ../input/land_light_firm_year_measures.csv | ../output
	python3 $<

../output/spf_caa_2004_2016_extraction_audit.csv: ../output/spf_caa_2004_2016_land_panel.csv
	@test -s "$@"

../output/spf_caa_2004_2016_source_notes.csv: ../output/spf_caa_2004_2016_land_panel.csv
	@test -s "$@"

../input/land_light_firm_year_measures.csv: ../../build_land_light_measures/output/land_light_firm_year_measures.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

link-inputs: ../input/land_light_firm_year_measures.csv

include ../../generic.make
