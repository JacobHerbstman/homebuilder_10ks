SHELL := bash
R := Rscript

all: ../output/tier1_2018_2025_annual_panel_audit.csv ../output/tier1_2018_2025_annual_panel_coverage.csv

../output/tier1_2018_2025_annual_panel_audit.csv: audit_tier1_annual_panel.R ../../../_lib/homebuilder_pipeline_utils.R ../input/tier1_2018_2025_annual_panel.csv ../input/tier1_2018_2025_annual_operating_panel.csv ../input/expanded_builder_2004_2025_land_panel.csv ../input/sec_10k_filing_index.csv ../input/tenk_land_preferred_values.csv ../input/six_firm_2012_2023_operating_benchmark_audit.csv ../input/five_firm_annual_operating_benchmark_audit.csv ../input/nine_firm_annual_operating_benchmark_audit.csv ../input/tier1_annual_operating_benchmark_audit.csv | ../output
	$(R) $<

../output/tier1_2018_2025_annual_panel_coverage.csv: ../output/tier1_2018_2025_annual_panel_audit.csv
	@test -s "$@"

../input/tier1_2018_2025_annual_panel.csv: ../../../build_tier1_annual_panel/output/tier1_2018_2025_annual_panel.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

../input/tier1_2018_2025_annual_operating_panel.csv: ../../../build_tier1_annual_operating_panel/output/tier1_2018_2025_annual_operating_panel.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

../input/expanded_builder_2004_2025_land_panel.csv: ../../../build_expanded_builder_land_panel/output/expanded_builder_2004_2025_land_panel.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

../input/sec_10k_filing_index.csv: ../../../build_sec_10k_filing_index/output/sec_10k_filing_index.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

../input/tenk_land_preferred_values.csv: ../../../build_10k_land_panel/output/tenk_land_preferred_values.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

../input/six_firm_2012_2023_operating_benchmark_audit.csv: ../../audit_six_firm_annual_operating_disclosures/output/six_firm_2012_2023_operating_benchmark_audit.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

../input/five_firm_annual_operating_benchmark_audit.csv: ../../audit_five_firm_annual_operating_disclosures/output/five_firm_annual_operating_benchmark_audit.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

../input/nine_firm_annual_operating_benchmark_audit.csv: ../../audit_nine_firm_annual_operating_disclosures/output/nine_firm_annual_operating_benchmark_audit.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

../input/tier1_annual_operating_benchmark_audit.csv: ../../audit_tier1_annual_operating_panel/output/tier1_annual_operating_benchmark_audit.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

link-inputs: ../input/tier1_2018_2025_annual_panel.csv ../input/tier1_2018_2025_annual_operating_panel.csv ../input/expanded_builder_2004_2025_land_panel.csv ../input/sec_10k_filing_index.csv ../input/tenk_land_preferred_values.csv ../input/six_firm_2012_2023_operating_benchmark_audit.csv ../input/five_firm_annual_operating_benchmark_audit.csv ../input/nine_firm_annual_operating_benchmark_audit.csv ../input/tier1_annual_operating_benchmark_audit.csv

include ../../../generic.make
