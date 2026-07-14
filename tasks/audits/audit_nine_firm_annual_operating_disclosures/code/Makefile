SHELL := bash
R := Rscript

all: ../output/nine_firm_annual_operating_benchmark_audit.csv

../output/nine_firm_annual_operating_benchmark_audit.csv: audit_nine_firm_annual_operating_disclosures.R ../../../_lib/homebuilder_pipeline_utils.R ../input/nine_firm_2018_2025_annual_operating_panel.csv | ../output
	$(R) $<

../input/nine_firm_2018_2025_annual_operating_panel.csv: ../../../extract_nine_firm_annual_operating_disclosures/output/nine_firm_2018_2025_annual_operating_panel.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

link-inputs: ../input/nine_firm_2018_2025_annual_operating_panel.csv

include ../../../generic.make
