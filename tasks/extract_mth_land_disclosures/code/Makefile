all: ../output/mth_2004_2025_land_panel.csv ../output/mth_2004_2025_segment_land_rows.csv ../output/mth_2004_2025_extraction_audit.csv ../output/mth_2004_2025_source_notes.csv

../output/mth_2004_2025_land_panel.csv: extract_mth_land_disclosures.py ../input/land_light_firm_year_measures.csv | ../output
	python3 $<

../output/mth_2004_2025_segment_land_rows.csv: ../output/mth_2004_2025_land_panel.csv

../output/mth_2004_2025_extraction_audit.csv: ../output/mth_2004_2025_land_panel.csv

../output/mth_2004_2025_source_notes.csv: ../output/mth_2004_2025_land_panel.csv

../input/land_light_firm_year_measures.csv: ../../build_land_light_measures/output/land_light_firm_year_measures.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

link-inputs: ../input/land_light_firm_year_measures.csv

include ../../generic.make
