all: ../output/tmhc_2013_2025_land_panel.csv ../output/tmhc_2013_2025_segment_land_rows.csv ../output/tmhc_2013_2025_extraction_audit.csv ../output/tmhc_2013_2025_source_notes.csv

../output/tmhc_2013_2025_land_panel.csv: extract_tmhc_land_disclosures.py ../input/land_light_firm_year_measures.csv | ../output
	python3 $<

../output/tmhc_2013_2025_segment_land_rows.csv: ../output/tmhc_2013_2025_land_panel.csv

../output/tmhc_2013_2025_extraction_audit.csv: ../output/tmhc_2013_2025_land_panel.csv

../output/tmhc_2013_2025_source_notes.csv: ../output/tmhc_2013_2025_land_panel.csv

../input/land_light_firm_year_measures.csv: ../../build_land_light_measures/output/land_light_firm_year_measures.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

link-inputs: ../input/land_light_firm_year_measures.csv

include ../../generic.make
