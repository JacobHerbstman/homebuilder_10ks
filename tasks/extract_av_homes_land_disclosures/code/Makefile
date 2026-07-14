SHELL := bash
include ../../shell_functions.make

all: ../output/avhi_2004_2017_land_panel.csv ../output/avhi_2004_2017_extraction_audit.csv ../output/avhi_2004_2017_source_notes.csv

../output/avhi_2004_2017_land_panel.csv: extract_av_homes_land_disclosures.py ../input/land_light_firm_year_measures.csv | ../output
	python3 $<

../output/avhi_2004_2017_extraction_audit.csv: ../output/avhi_2004_2017_land_panel.csv
	@test -s "$@"

../output/avhi_2004_2017_source_notes.csv: ../output/avhi_2004_2017_land_panel.csv
	@test -s "$@"

../input/land_light_firm_year_measures.csv: ../../build_land_light_measures/output/land_light_firm_year_measures.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

link-inputs: ../input/land_light_firm_year_measures.csv

include ../../generic.make
