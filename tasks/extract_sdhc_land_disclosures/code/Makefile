SHELL := bash
include ../../shell_functions.make

all: ../output/sdhc_2022_2025_land_panel.csv ../output/sdhc_2022_2025_segment_land_rows.csv ../output/sdhc_2022_2025_extraction_audit.csv ../output/sdhc_2022_2025_source_notes.csv

../output/sdhc_2022_2025_land_panel.csv: extract_sdhc_land_disclosures.py ../input/land_light_firm_year_measures.csv | ../output
	python3 $<

../output/sdhc_2022_2025_segment_land_rows.csv: ../output/sdhc_2022_2025_land_panel.csv
	@test -s "$@"

../output/sdhc_2022_2025_extraction_audit.csv: ../output/sdhc_2022_2025_land_panel.csv
	@test -s "$@"

../output/sdhc_2022_2025_source_notes.csv: ../output/sdhc_2022_2025_land_panel.csv
	@test -s "$@"

../input/land_light_firm_year_measures.csv: ../../build_land_light_measures/output/land_light_firm_year_measures.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

link-inputs: ../input/land_light_firm_year_measures.csv

include ../../generic.make
