PYTHON := python3

all: ../output/tier1_2018_2025_sec_10q_download_inventory.csv

../output/tier1_2018_2025_sec_10q_download_inventory.csv: fetch_tier1_sec_10q_filings.py ../../_lib/sec_fetch_utils.py ../input/tier1_2018_2025_sec_10q_filing_index.csv ../input/.env | ../output
	set -a; source ../input/.env; set +a; $(PYTHON) $<

../input/tier1_2018_2025_sec_10q_filing_index.csv: ../../build_tier1_sec_10q_filing_index/output/tier1_2018_2025_sec_10q_filing_index.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

../input/.env: ../../../.env | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

../../../.env:
	@echo "Missing ../../../.env. Copy .env.example to .env and set SEC_USER_AGENT." >&2
	@exit 1

link-inputs: ../input/tier1_2018_2025_sec_10q_filing_index.csv ../input/.env

include ../../generic.make
