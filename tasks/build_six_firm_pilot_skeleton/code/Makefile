SHELL := bash
include ../../shell_functions.make

all: ../output/six_firm_2006_2025_skeleton.csv ../output/six_firm_2006_2025_recovery_audit.csv ../output/six_firm_2006_2025_review_pdf_manifest.csv ../output/six_firm_2006_2025_qc.csv ../output/review_pdfs/review_pdf_inventory.csv

../output/six_firm_2006_2025_skeleton.csv: build_six_firm_pilot_skeleton.R ../../_lib/homebuilder_pipeline_utils.R ../input/sec_10k_filing_index.csv ../input/sec_10k_download_inventory.csv ../input/land_light_firm_year_measures.csv | ../output
	$(R) $<

../output/review_pdfs/review_pdf_inventory.csv: convert_review_pdfs.R ../../_lib/homebuilder_pipeline_utils.R ../output/six_firm_2006_2025_review_pdf_manifest.csv | ../output/review_pdfs
	$(R) $<

../output/six_firm_2006_2025_recovery_audit.csv: ../output/six_firm_2006_2025_skeleton.csv
	@test -s "$@"

../output/six_firm_2006_2025_review_pdf_manifest.csv: ../output/six_firm_2006_2025_skeleton.csv
	@test -s "$@"

../output/six_firm_2006_2025_qc.csv: ../output/six_firm_2006_2025_skeleton.csv
	@test -s "$@"

../input/sec_10k_filing_index.csv: ../../build_sec_10k_filing_index/output/sec_10k_filing_index.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

../input/sec_10k_download_inventory.csv: ../../fetch_sec_10k_filings/output/sec_10k_download_inventory.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

../input/land_light_firm_year_measures.csv: ../../build_land_light_measures/output/land_light_firm_year_measures.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

link-inputs: ../input/sec_10k_filing_index.csv ../input/sec_10k_download_inventory.csv ../input/land_light_firm_year_measures.csv

../output/review_pdfs:
	mkdir -p $@

include ../../generic.make
