SHELL := bash
R := Rscript

all: ../output/six_firm_2012_2023_operating_benchmark_audit.csv ../output/six_firm_2006_2025_operating_coverage_audit.csv

../output/six_firm_2012_2023_operating_benchmark_audit.csv: audit_six_firm_annual_operating_disclosures.R ../../../_lib/homebuilder_pipeline_utils.R ../input/six_firm_2006_2025_operating_panel.csv ../input/manual_six_firm_operating_scale_2012_2023.csv | ../output
	$(R) $<

../output/six_firm_2006_2025_operating_coverage_audit.csv: ../output/six_firm_2012_2023_operating_benchmark_audit.csv
	@test -s "$@"

../input/six_firm_2006_2025_operating_panel.csv: ../../../extract_six_firm_annual_operating_disclosures/output/six_firm_2006_2025_operating_panel.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

../input/manual_six_firm_operating_scale_2012_2023.csv: ../../../analyze_six_firm_boom_bust_response/code/manual_six_firm_operating_scale_2012_2023.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

link-inputs: ../input/six_firm_2006_2025_operating_panel.csv ../input/manual_six_firm_operating_scale_2012_2023.csv

include ../../../generic.make
