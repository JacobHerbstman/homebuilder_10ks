PYTHON := python3

all: ../output/six_firm_2006_2025_annual_land_machine_values.csv ../output/six_firm_2006_2025_annual_land_extraction_audit.csv

../output/six_firm_2006_2025_annual_land_machine_values.csv: extract_six_firm_annual_land_values.py ../../_lib/sec_fetch_utils.py ../input/six_firm_2006_2025_skeleton.csv | ../output
	$(PYTHON) $<

../output/six_firm_2006_2025_annual_land_extraction_audit.csv: ../output/six_firm_2006_2025_annual_land_machine_values.csv
	@test -s "$@"

../input/six_firm_2006_2025_skeleton.csv: ../../build_six_firm_pilot_skeleton/output/six_firm_2006_2025_skeleton.csv | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

link-inputs: ../input/six_firm_2006_2025_skeleton.csv

include ../../generic.make
