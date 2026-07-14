SHELL := bash
include ../../shell_functions.make

all: ../output/tol_2004_2025_land_panel.csv ../output/tol_2004_2025_extraction_audit.csv ../output/tol_2004_2025_source_notes.csv

../output/tol_2004_2025_land_panel.csv: extract_tol_land_disclosures.py ../input/land_light_firm_year_measures.csv | ../output
	python3 $<

../output/tol_2004_2025_extraction_audit.csv: ../output/tol_2004_2025_land_panel.csv
	@test -s "$@"

../output/tol_2004_2025_source_notes.csv: ../output/tol_2004_2025_land_panel.csv
	@test -s "$@"

../input/land_light_firm_year_measures.csv: ../../build_land_light_measures/output/land_light_firm_year_measures.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

link-inputs: ../input/land_light_firm_year_measures.csv

include ../../generic.make
