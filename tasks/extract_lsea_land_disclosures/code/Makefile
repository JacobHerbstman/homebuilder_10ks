all: ../output/lsea_2020_2024_land_panel.csv ../output/lsea_2020_2024_segment_land_rows.csv ../output/lsea_2018_2019_prebuilder_filing_exclusions.csv ../output/lsea_2020_2024_extraction_audit.csv ../output/lsea_2020_2024_source_notes.csv

../output/lsea_2020_2024_land_panel.csv: extract_lsea_land_disclosures.py ../input/land_light_firm_year_measures.csv | ../output
	python3 $<

../output/lsea_2020_2024_segment_land_rows.csv: ../output/lsea_2020_2024_land_panel.csv

../output/lsea_2018_2019_prebuilder_filing_exclusions.csv: ../output/lsea_2020_2024_land_panel.csv

../output/lsea_2020_2024_extraction_audit.csv: ../output/lsea_2020_2024_land_panel.csv

../output/lsea_2020_2024_source_notes.csv: ../output/lsea_2020_2024_land_panel.csv

../input/land_light_firm_year_measures.csv: ../../build_land_light_measures/output/land_light_firm_year_measures.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

link-inputs: ../input/land_light_firm_year_measures.csv

include ../../generic.make
