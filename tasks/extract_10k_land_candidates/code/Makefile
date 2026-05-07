SHELL := bash
PYTHON := python3

all: ../output/tenk_land_candidates.csv ../output/tenk_land_mention_flags.csv ../output/tenk_land_extraction_qc.csv

../output/tenk_land_candidates.csv: extract_10k_land_candidates.py ../../_lib/sec_fetch_utils.py ../input/sec_10k_download_inventory.csv | ../output
	$(PYTHON) $<

../output/tenk_land_mention_flags.csv: ../output/tenk_land_candidates.csv
	@test -s "$@"

../output/tenk_land_extraction_qc.csv: ../output/tenk_land_candidates.csv
	@test -s "$@"

../input/sec_10k_download_inventory.csv: ../../fetch_sec_10k_filings/output/sec_10k_download_inventory.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

link-inputs: ../input/sec_10k_download_inventory.csv

include ../../generic.make
