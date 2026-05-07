SHELL := bash
PYTHON := python3

all: ../output/sec_submissions_files.csv ../output/sec_submissions_failures.csv ../output/sec_submissions_qc.csv

../output/sec_submissions_files.csv: fetch_sec_submissions.py ../../_lib/sec_fetch_utils.py Makefile ../input/builder_sec_crosswalk.csv ../input/.env | ../output
	set -a; source ../input/.env; set +a; $(PYTHON) $<

../output/sec_submissions_failures.csv: ../output/sec_submissions_files.csv
	@test -s "$@"

../output/sec_submissions_qc.csv: ../output/sec_submissions_files.csv
	@test -s "$@"

../input/builder_sec_crosswalk.csv: ../../build_builder_sec_crosswalk/output/builder_sec_crosswalk.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

../input/.env: ../../../.env | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

../../../.env:
	@echo "Missing ../../../.env. Copy .env.example to .env and set SEC_USER_AGENT." >&2
	@exit 1

link-inputs: ../input/builder_sec_crosswalk.csv ../input/.env

include ../../generic.make
