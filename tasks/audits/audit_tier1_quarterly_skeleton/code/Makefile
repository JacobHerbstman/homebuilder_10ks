R := Rscript

all: ../output/tier1_2018_2025_quarterly_skeleton_audit.csv ../output/tier1_2018_2025_quarterly_skeleton_coverage.csv

../output/tier1_2018_2025_quarterly_skeleton_audit.csv: audit_tier1_quarterly_skeleton.R ../../../_lib/homebuilder_pipeline_utils.R ../input/tier1_2018_2025_quarterly_skeleton.csv ../input/tier1_2018_2025_annual_panel.csv ../input/tier1_2018_2025_sec_10q_download_inventory.csv | ../output
	$(R) $<

../output/tier1_2018_2025_quarterly_skeleton_coverage.csv: ../output/tier1_2018_2025_quarterly_skeleton_audit.csv
	@test -s "$@"

../input/tier1_2018_2025_quarterly_skeleton.csv: ../../../build_tier1_quarterly_skeleton/output/tier1_2018_2025_quarterly_skeleton.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

../input/tier1_2018_2025_annual_panel.csv: ../../../build_tier1_annual_panel/output/tier1_2018_2025_annual_panel.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

../input/tier1_2018_2025_sec_10q_download_inventory.csv: ../../../fetch_tier1_sec_10q_filings/output/tier1_2018_2025_sec_10q_download_inventory.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

link-inputs: ../input/tier1_2018_2025_quarterly_skeleton.csv ../input/tier1_2018_2025_annual_panel.csv ../input/tier1_2018_2025_sec_10q_download_inventory.csv

include ../../../generic.make
