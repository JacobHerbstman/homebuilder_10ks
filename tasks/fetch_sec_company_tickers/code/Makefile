SHELL := bash
PYTHON := python3

all: ../output/sec_company_tickers_files.csv ../output/sec_company_tickers_checksums.csv ../output/sec_company_tickers_qc.csv

../output/sec_company_tickers_files.csv: fetch_sec_company_tickers.py ../../_lib/sec_fetch_utils.py Makefile ../input/.env | ../output
	set -a; source ../input/.env; set +a; $(PYTHON) $<

../output/sec_company_tickers_checksums.csv: ../output/sec_company_tickers_files.csv
	@test -s "$@"

../output/sec_company_tickers_qc.csv: ../output/sec_company_tickers_files.csv
	@test -s "$@"

../input/.env: ../../../.env | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

../../../.env:
	@echo "Missing ../../../.env. Copy .env.example to .env and set SEC_USER_AGENT." >&2
	@exit 1

link-inputs: ../input/.env

include ../../generic.make
