all: ../output/nvr_2004_2009_early_land_panel.csv ../output/nvr_2004_2009_early_land_audit.csv ../output/nvr_2004_2009_early_source_notes.csv

../output/nvr_2004_2009_early_land_panel.csv: extract_nvr_early_land_disclosures.py ../input/land_light_firm_year_measures.csv | ../output
	python3 $<

../output/nvr_2004_2009_early_land_audit.csv: ../output/nvr_2004_2009_early_land_panel.csv

../output/nvr_2004_2009_early_source_notes.csv: ../output/nvr_2004_2009_early_land_panel.csv

../input/land_light_firm_year_measures.csv: ../../build_land_light_measures/output/land_light_firm_year_measures.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

link-inputs: ../input/land_light_firm_year_measures.csv

include ../../generic.make
