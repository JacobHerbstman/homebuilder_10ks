all: ../output/tier1_early_2004_2005_land_panel.csv ../output/tier1_early_2004_2005_extraction_audit.csv ../output/tier1_early_2004_2005_source_notes.csv

../output/tier1_early_2004_2005_land_panel.csv: extract_tier1_early_land_disclosures.py ../input/land_light_firm_year_measures.csv | ../output
	python3 $<

../output/tier1_early_2004_2005_extraction_audit.csv: ../output/tier1_early_2004_2005_land_panel.csv
	@test -s "$@"

../output/tier1_early_2004_2005_source_notes.csv: ../output/tier1_early_2004_2005_land_panel.csv
	@test -s "$@"

../input/land_light_firm_year_measures.csv: ../../build_land_light_measures/output/land_light_firm_year_measures.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

link-inputs: ../input/land_light_firm_year_measures.csv

include ../../generic.make
