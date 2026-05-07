SHELL := bash
PYTHON := python3

all: ../output/builder_magazine_html_files.csv ../output/builder_magazine_html_checksums.csv ../output/builder_magazine_fetch_qc.csv

../output/builder_magazine_html_files.csv: fetch_builder_magazine_lists.py ../input/source_catalog.csv | ../output
	$(PYTHON) $<

../output/builder_magazine_html_checksums.csv: ../output/builder_magazine_html_files.csv
	@test -s "$@"

../output/builder_magazine_fetch_qc.csv: ../output/builder_magazine_html_files.csv
	@test -s "$@"

../input/source_catalog.csv: ../../source_registry/code/source_catalog.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

link-inputs: ../input/source_catalog.csv

include ../../generic.make
