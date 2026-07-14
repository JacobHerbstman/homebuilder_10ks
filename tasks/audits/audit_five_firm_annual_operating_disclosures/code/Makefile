SHELL := bash
R := Rscript

all: ../output/five_firm_annual_operating_benchmark_audit.csv

../output/five_firm_annual_operating_benchmark_audit.csv: audit_five_firm_annual_operating_disclosures.R ../../../_lib/homebuilder_pipeline_utils.R ../input/five_firm_2006_2025_annual_operating_panel.csv | ../output
	$(R) $<

../input/five_firm_2006_2025_annual_operating_panel.csv: ../../../extract_five_firm_annual_operating_disclosures/output/five_firm_2006_2025_annual_operating_panel.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

link-inputs: ../input/five_firm_2006_2025_annual_operating_panel.csv

include ../../../generic.make
