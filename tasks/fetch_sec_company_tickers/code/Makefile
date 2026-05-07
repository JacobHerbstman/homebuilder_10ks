SHELL := bash
PYTHON := python3

all: ../output/sec_company_tickers_files.csv ../output/sec_company_tickers_checksums.csv ../output/sec_company_tickers_qc.csv

../output/sec_company_tickers_files.csv: fetch_sec_company_tickers.py ../../_lib/sec_fetch_utils.py | ../output
	$(PYTHON) $<

../output/sec_company_tickers_checksums.csv: ../output/sec_company_tickers_files.csv
	@test -s "$@"

../output/sec_company_tickers_qc.csv: ../output/sec_company_tickers_files.csv
	@test -s "$@"

link-inputs:

include ../../generic.make
