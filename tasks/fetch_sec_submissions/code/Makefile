SHELL := bash
PYTHON := python3

all: ../output/sec_submissions_files.csv ../output/sec_submissions_failures.csv ../output/sec_submissions_qc.csv

../output/sec_submissions_files.csv: fetch_sec_submissions.py ../../_lib/sec_fetch_utils.py ../input/builder_sec_crosswalk.csv | ../output
	$(PYTHON) $<

../output/sec_submissions_failures.csv: ../output/sec_submissions_files.csv
	@test -s "$@"

../output/sec_submissions_qc.csv: ../output/sec_submissions_files.csv
	@test -s "$@"

../input/builder_sec_crosswalk.csv: ../../build_builder_sec_crosswalk/output/builder_sec_crosswalk.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

link-inputs: ../input/builder_sec_crosswalk.csv

include ../../generic.make
