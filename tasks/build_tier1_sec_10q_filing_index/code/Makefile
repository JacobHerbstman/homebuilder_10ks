R := Rscript
INDEX_START_DATE := 20171001
INDEX_END_DATE := 20251231

all: ../output/tier1_2018_2025_sec_10q_filing_index.csv

../output/tier1_2018_2025_sec_10q_filing_index.csv: build_tier1_sec_10q_filing_index.R ../../_lib/homebuilder_pipeline_utils.R ../input/tier1_2018_2025_annual_panel.csv ../input/sec_submissions_files.csv | ../output
	$(R) $< $(INDEX_START_DATE) $(INDEX_END_DATE)

../input/tier1_2018_2025_annual_panel.csv: ../../build_tier1_annual_panel/output/tier1_2018_2025_annual_panel.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

../input/sec_submissions_files.csv: ../../fetch_sec_submissions/output/sec_submissions_files.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

link-inputs: ../input/tier1_2018_2025_annual_panel.csv ../input/sec_submissions_files.csv

include ../../generic.make
