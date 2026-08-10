PYTHON := python3

all: ../output/six_firm_2018_2025_quarterly_operating_disclosures.csv

../output/six_firm_2018_2025_quarterly_operating_disclosures.csv: extract_six_firm_quarterly_operating_disclosures.py ../../_lib/sec_fetch_utils.py ../input/tier1_2018_2025_quarterly_skeleton.csv ../input/tier1_2018_2025_sec_10q_download_inventory.csv | ../output
	$(PYTHON) $<

../input/tier1_2018_2025_quarterly_skeleton.csv: ../../build_tier1_quarterly_skeleton/output/tier1_2018_2025_quarterly_skeleton.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

../input/tier1_2018_2025_sec_10q_download_inventory.csv: ../../fetch_tier1_sec_10q_filings/output/tier1_2018_2025_sec_10q_download_inventory.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

link-inputs: ../input/tier1_2018_2025_quarterly_skeleton.csv ../input/tier1_2018_2025_sec_10q_download_inventory.csv

include ../../generic.make
