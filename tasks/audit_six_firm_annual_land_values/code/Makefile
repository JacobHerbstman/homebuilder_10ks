R := Rscript

all: ../output/six_firm_2006_2025_annual_land_gold_comparison.csv ../output/six_firm_2006_2025_annual_land_review_queue.csv ../output/six_firm_2006_2025_annual_land_gold_summary.csv

../output/six_firm_2006_2025_annual_land_gold_comparison.csv: audit_six_firm_annual_land_values.R ../../_lib/homebuilder_pipeline_utils.R ../input/six_firm_2006_2025_annual_land_machine_values.csv ../input/six_firm_2006_2025_manual_land_panel.csv | ../output
	$(R) $<

../output/six_firm_2006_2025_annual_land_review_queue.csv: ../output/six_firm_2006_2025_annual_land_gold_comparison.csv
	@test -s "$@"

../output/six_firm_2006_2025_annual_land_gold_summary.csv: ../output/six_firm_2006_2025_annual_land_gold_comparison.csv
	@test -s "$@"

../input/six_firm_2006_2025_annual_land_machine_values.csv: ../../extract_six_firm_annual_land_values/output/six_firm_2006_2025_annual_land_machine_values.csv | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/six_firm_2006_2025_manual_land_panel.csv: ../../build_six_firm_manual_land_panel/output/six_firm_2006_2025_manual_land_panel.csv | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

link-inputs: ../input/six_firm_2006_2025_annual_land_machine_values.csv ../input/six_firm_2006_2025_manual_land_panel.csv

include ../../generic.make
