SHELL := bash
include ../../shell_functions.make

all: ../output/wci_2004_2015_land_panel.csv ../output/wci_2004_2015_extraction_audit.csv ../output/wci_2004_2015_source_notes.csv

../output/wci_2004_2015_land_panel.csv: extract_wci_land_disclosures.py ../input/land_light_firm_year_measures.csv | ../output
	python3 $<

../output/wci_2004_2015_extraction_audit.csv: ../output/wci_2004_2015_land_panel.csv
	@test -s "$@"

../output/wci_2004_2015_source_notes.csv: ../output/wci_2004_2015_land_panel.csv
	@test -s "$@"

../input/land_light_firm_year_measures.csv: ../../build_land_light_measures/output/land_light_firm_year_measures.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

link-inputs: ../input/land_light_firm_year_measures.csv

include ../../generic.make
