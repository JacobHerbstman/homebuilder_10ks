PYTHON := python3

all: ../output/tier1_2018_2025_quarterly_land_disclosures.csv

../output/tier1_2018_2025_quarterly_land_disclosures.csv: extract_tier1_quarterly_land_disclosures.py ../../extract_10k_land_candidates/code/extract_10k_land_candidates.py ../../_lib/sec_fetch_utils.py ../input/tier1_2018_2025_quarterly_skeleton.csv | ../output
	$(PYTHON) $<

../input/tier1_2018_2025_quarterly_skeleton.csv: ../../build_tier1_quarterly_skeleton/output/tier1_2018_2025_quarterly_skeleton.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

link-inputs: ../input/tier1_2018_2025_quarterly_skeleton.csv

include ../../generic.make
