SHELL := bash
include ../../shell_functions.make

all: ../output/sec_10k_filing_index.csv ../output/sec_10k_benchmark_filings.csv ../output/sec_10k_filing_index_qc.csv

../output/sec_10k_filing_index.csv: build_sec_10k_filing_index.R ../../_lib/homebuilder_pipeline_utils.R ../input/builder_sec_crosswalk.csv ../input/sec_submissions_files.csv | ../output
	$(R) $<

../output/sec_10k_benchmark_filings.csv: ../output/sec_10k_filing_index.csv
	@test -s "$@"

../output/sec_10k_filing_index_qc.csv: ../output/sec_10k_filing_index.csv
	@test -s "$@"

../input/builder_sec_crosswalk.csv: ../../build_builder_sec_crosswalk/output/builder_sec_crosswalk.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

../input/sec_submissions_files.csv: ../../fetch_sec_submissions/output/sec_submissions_files.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

link-inputs: ../input/builder_sec_crosswalk.csv ../input/sec_submissions_files.csv

include ../../generic.make
