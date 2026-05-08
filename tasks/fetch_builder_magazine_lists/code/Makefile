SHELL := bash
PYTHON := python3
BUILDER_PULL_DATE := 20260506
BUILDER_START_YEAR := 2004
BUILDER_END_YEAR := 2026

all: ../output/builder_magazine_html_files.csv ../output/builder_magazine_html_checksums.csv ../output/builder_magazine_fetch_qc.csv

../output/builder_magazine_html_files.csv: fetch_builder_magazine_lists.py Makefile ../input/source_catalog.csv | ../output
	BUILDER_PULL_DATE=$(BUILDER_PULL_DATE) BUILDER_START_YEAR=$(BUILDER_START_YEAR) BUILDER_END_YEAR=$(BUILDER_END_YEAR) $(PYTHON) $<

../output/builder_magazine_html_checksums.csv: ../output/builder_magazine_html_files.csv
	@test -s "$@"

../output/builder_magazine_fetch_qc.csv: ../output/builder_magazine_html_files.csv
	@test -s "$@"

../input/source_catalog.csv: ../../source_registry/code/source_catalog.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

link-inputs: ../input/source_catalog.csv

include ../../generic.make
