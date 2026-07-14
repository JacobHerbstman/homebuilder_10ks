SHELL := bash
PYTHON := python3

all: ../output/sec_sic_1531_companies.csv ../output/sec_sic_1531_browse_pages.csv ../output/sec_sic_1531_submission_files.csv ../output/sec_sic_1531_qc.csv

../output/sec_sic_1531_companies.csv: fetch_sec_sic_1531_universe.py ../../_lib/sec_fetch_utils.py Makefile ../input/.env | ../output
	set -a; source ../input/.env; set +a; $(PYTHON) $<

../output/sec_sic_1531_browse_pages.csv: ../output/sec_sic_1531_companies.csv
	@test -s "$@"

../output/sec_sic_1531_submission_files.csv: ../output/sec_sic_1531_companies.csv
	@test -s "$@"

../output/sec_sic_1531_qc.csv: ../output/sec_sic_1531_companies.csv
	@test -s "$@"

../input/.env: ../../../.env | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

../../../.env:
	@echo "Missing ../../../.env. Copy .env.example to .env and set SEC_USER_AGENT." >&2
	@exit 1

link-inputs: ../input/.env

include ../../generic.make
