SHELL := bash
include ../../shell_functions.make

all: ../output/six_firm_2006_2025_operating_panel.csv ../output/six_firm_2006_2025_operating_candidates.csv ../output/six_firm_2012_2023_operating_benchmark_audit.csv ../output/six_firm_2006_2025_operating_coverage_audit.csv

../output/six_firm_2006_2025_operating_panel.csv: extract_six_firm_annual_operating_disclosures.R ../../_lib/homebuilder_pipeline_utils.R ../input/sec_10k_download_inventory.csv ../input/manual_six_firm_operating_scale_2012_2023.csv | ../output
	$(R) $<

../output/six_firm_2006_2025_operating_candidates.csv: ../output/six_firm_2006_2025_operating_panel.csv
	@test -s "$@"

../output/six_firm_2012_2023_operating_benchmark_audit.csv: ../output/six_firm_2006_2025_operating_panel.csv
	@test -s "$@"

../output/six_firm_2006_2025_operating_coverage_audit.csv: ../output/six_firm_2006_2025_operating_panel.csv
	@test -s "$@"

../input/sec_10k_download_inventory.csv: ../../fetch_sec_10k_filings/output/sec_10k_download_inventory.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

../input/manual_six_firm_operating_scale_2012_2023.csv: ../../analyze_six_firm_boom_bust_response/code/manual_six_firm_operating_scale_2012_2023.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

link-inputs: ../input/sec_10k_download_inventory.csv ../input/manual_six_firm_operating_scale_2012_2023.csv

include ../../generic.make
