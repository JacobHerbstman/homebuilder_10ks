SHELL := bash
include ../../shell_functions.make

all: ../output/uhg_2022_2025_land_panel.csv ../output/uhg_2022_2025_segment_land_rows.csv ../output/uhg_2020_2021_prebuilder_filing_exclusions.csv ../output/uhg_2022_2025_extraction_audit.csv ../output/uhg_2022_2025_source_notes.csv

../output/uhg_2022_2025_land_panel.csv: extract_uhg_land_disclosures.py ../input/land_light_firm_year_measures.csv | ../output
	python3 $<

../output/uhg_2022_2025_segment_land_rows.csv: ../output/uhg_2022_2025_land_panel.csv
	@test -s "$@"

../output/uhg_2020_2021_prebuilder_filing_exclusions.csv: ../output/uhg_2022_2025_land_panel.csv
	@test -s "$@"

../output/uhg_2022_2025_extraction_audit.csv: ../output/uhg_2022_2025_land_panel.csv
	@test -s "$@"

../output/uhg_2022_2025_source_notes.csv: ../output/uhg_2022_2025_land_panel.csv
	@test -s "$@"

../input/land_light_firm_year_measures.csv: ../../build_land_light_measures/output/land_light_firm_year_measures.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

link-inputs: ../input/land_light_firm_year_measures.csv

include ../../generic.make
