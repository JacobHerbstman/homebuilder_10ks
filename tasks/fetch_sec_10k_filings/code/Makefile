SHELL := bash
PYTHON := python3

all: ../output/sec_10k_download_inventory.csv ../output/sec_10k_download_failures.csv ../output/sec_10k_download_qc.csv

../output/sec_10k_download_inventory.csv: fetch_sec_10k_filings.py ../../_lib/sec_fetch_utils.py ../input/sec_10k_filing_index.csv | ../output
	$(PYTHON) $<

../output/sec_10k_download_failures.csv: ../output/sec_10k_download_inventory.csv
	@test -s "$@"

../output/sec_10k_download_qc.csv: ../output/sec_10k_download_inventory.csv
	@test -s "$@"

../input/sec_10k_filing_index.csv: ../../build_sec_10k_filing_index/output/sec_10k_filing_index.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

link-inputs: ../input/sec_10k_filing_index.csv

include ../../generic.make
