SHELL := bash
include ../../shell_functions.make

all: ../output/mho_2004_2025_land_panel.csv ../output/mho_2004_2025_segment_land_rows.csv ../output/mho_2004_2025_extraction_audit.csv ../output/mho_2004_2025_source_notes.csv

../output/mho_2004_2025_land_panel.csv: extract_mho_land_disclosures.py ../input/land_light_firm_year_measures.csv | ../output
	python3 $<

../output/mho_2004_2025_segment_land_rows.csv: ../output/mho_2004_2025_land_panel.csv
	@test -s "$@"

../output/mho_2004_2025_extraction_audit.csv: ../output/mho_2004_2025_land_panel.csv
	@test -s "$@"

../output/mho_2004_2025_source_notes.csv: ../output/mho_2004_2025_land_panel.csv
	@test -s "$@"

../input/land_light_firm_year_measures.csv: ../../build_land_light_measures/output/land_light_firm_year_measures.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

link-inputs: ../input/land_light_firm_year_measures.csv

include ../../generic.make
