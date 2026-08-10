R := Rscript

all: ../output/tier1_2018_2025_quarterly_panel.csv

../output/tier1_2018_2025_quarterly_panel.csv: build_tier1_quarterly_panel.R ../../_lib/homebuilder_pipeline_utils.R ../input/tier1_2018_2025_quarterly_skeleton.csv ../input/tier1_2018_2025_quarterly_operating_panel.csv ../input/tier1_2018_2025_annual_panel.csv ../input/builder_public_lifecycle_events.csv | ../output
	$(R) $<

../input/tier1_2018_2025_quarterly_skeleton.csv: ../../build_tier1_quarterly_skeleton/output/tier1_2018_2025_quarterly_skeleton.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

../input/tier1_2018_2025_quarterly_operating_panel.csv: ../../build_tier1_quarterly_operating_panel/output/tier1_2018_2025_quarterly_operating_panel.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

../input/tier1_2018_2025_annual_panel.csv: ../../build_tier1_annual_panel/output/tier1_2018_2025_annual_panel.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

../input/builder_public_lifecycle_events.csv: ../../harmonize_builder_public_firms/output/builder_public_lifecycle_events.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

link-inputs: ../input/tier1_2018_2025_quarterly_skeleton.csv ../input/tier1_2018_2025_quarterly_operating_panel.csv ../input/tier1_2018_2025_annual_panel.csv ../input/builder_public_lifecycle_events.csv

include ../../generic.make
