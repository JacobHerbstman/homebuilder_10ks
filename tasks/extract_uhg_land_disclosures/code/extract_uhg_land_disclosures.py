#!/usr/bin/env python3

import csv
import re
import sys
from pathlib import Path

sys.path.append(str(Path(__file__).resolve().parents[2] / "_lib"))
from sec_fetch_utils import write_csv

sys.path.append(str(Path(__file__).resolve().parents[1].parent / "extract_10k_land_candidates" / "code"))
from extract_10k_land_candidates import SecTableParser, VisibleTextParser, clean_text


with open("../input/land_light_firm_year_measures.csv", newline="") as f:
    filing_rows = [
        row for row in csv.DictReader(f)
        if row.get("ticker") == "UHG"
        and row.get("form") == "10-K"
        and 2020 <= int(float(row.get("fiscal_year"))) <= 2025
    ]

if len(filing_rows) == 0:
    raise RuntimeError("No United Homes Group filing rows found in land_light_firm_year_measures.csv.")

filing_by_year = {}
for filing in filing_rows:
    fiscal_year = int(float(filing["fiscal_year"]))
    if fiscal_year in filing_by_year:
        raise RuntimeError("United Homes Group filing rows must be unique by fiscal year.")
    filing_by_year[fiscal_year] = filing

panel_rows = []
segment_rows = []
source_notes = []

for fiscal_year in range(2022, 2026):
    source_fiscal_year = fiscal_year
    target_column_group = 1

    if fiscal_year == 2022:
        source_fiscal_year = 2023
        target_column_group = 2

    filing = filing_by_year[source_fiscal_year]
    source_path = Path(filing["primary_document_local_path"])

    if not source_path.exists():
        raise RuntimeError(f"Missing United Homes Group source file: {source_path}")

    raw_text = source_path.read_text(encoding="utf-8", errors="ignore")
    table_parser = SecTableParser()
    table_parser.feed(raw_text)

    owned_lots = None
    controlled_lots = None
    total_lots = None
    source_table_index = ""
    source_excerpt = ""
    extraction_method = ""

    for table_index, table in enumerate(table_parser.tables):
        parsed_rows = []
        for html_row in table["rows"]:
            cells = [clean_text(cell.get("text", "")) for cell in html_row]
            cells = [cell for cell in cells if cell]
            if cells:
                parsed_rows.append(cells)

        table_text = clean_text(" || ".join(" | ".join(cells) for cells in parsed_rows))
        table_text_lower = table_text.lower()

        if "market/division" not in table_text_lower:
            continue
        if "owned" not in table_text_lower or "controlled" not in table_text_lower:
            continue
        if str(fiscal_year) not in table_text:
            continue

        for cells in parsed_rows:
            if len(cells) < 4:
                continue

            row_label = cells[0]
            if target_column_group == 1:
                lot_cells = cells[1:4]
            else:
                lot_cells = cells[4:7]

            numeric_values = []
            for cell in lot_cells:
                if re.fullmatch(r"\d+(?:,\d{3})*", cell):
                    numeric_values.append(float(cell.replace(",", "")))
                elif cell in ("—", "-", "--"):
                    numeric_values.append(0.0)

            if len(numeric_values) != 3:
                continue

            segment_rows.append({
                "ticker": "UHG",
                "cik10": filing["cik10"],
                "fiscal_year": fiscal_year,
                "source_fiscal_year": source_fiscal_year,
                "accession_number": filing["accession_number"],
                "source_table_index": table_index,
                "segment_label": row_label,
                "row_type": "total" if row_label.lower() == "total" else "market",
                "owned_lots": numeric_values[0],
                "controlled_lots": numeric_values[1],
                "total_lots": numeric_values[2],
                "component_identity_gap": numeric_values[0] + numeric_values[1] - numeric_values[2],
            })

            if row_label.lower() == "total":
                owned_lots = numeric_values[0]
                controlled_lots = numeric_values[1]
                total_lots = numeric_values[2]
                source_table_index = str(table_index)
                source_excerpt = table_text[:1400]
                extraction_method = (
                    "prior_year_column_from_2023_owned_controlled_table"
                    if fiscal_year == 2022
                    else "current_year_column_from_owned_controlled_table"
                )

        if extraction_method != "":
            break

    if extraction_method == "":
        raise RuntimeError(f"Could not find United Homes Group owned/controlled table row for {fiscal_year}.")

    component_gap = owned_lots + controlled_lots - total_lots
    source_note = "UHG recurring owned/controlled lots table; Controlled is coded as nonowned controlled lots."

    if fiscal_year == 2022:
        source_note = (
            "Uses exact December 31, 2022 comparative row from the 2023 UHG 10-K. "
            "This is a Great Southern predecessor-business disclosure after the de-SPAC, not a contemporaneous DiamondHead operating-builder 10-K."
        )

    panel_rows.append({
        "ticker": "UHG",
        "cik10": filing["cik10"],
        "sec_company_name": filing["sec_company_name"],
        "fiscal_year": fiscal_year,
        "report_date": filing_by_year[fiscal_year]["report_date"],
        "filing_date": filing["filing_date"],
        "accession_number": filing_by_year[fiscal_year]["accession_number"],
        "source_accession_number": filing["accession_number"],
        "primary_document": filing["primary_document"],
        "source_local_path": filing["primary_document_local_path"],
        "source_url": filing["filing_url"],
        "unit_type": "lots",
        "owned_lots": owned_lots,
        "nonowned_controlled_lots": controlled_lots,
        "controlled_lots": controlled_lots,
        "total_lots": total_lots,
        "nonowned_controlled_share": controlled_lots / total_lots,
        "owned_share": owned_lots / total_lots,
        "component_identity_gap": component_gap,
        "component_identity_pass": abs(component_gap) <= 1,
        "extraction_method": extraction_method,
        "precision": "reported_table",
        "source_fiscal_year": source_fiscal_year,
        "source_table_index": source_table_index,
        "source_row_label": "Total",
        "source_total_row_used": True,
        "controlled_definition_raw": "Controlled",
        "controlled_treated_as_nonowned_controlled": True,
        "controlled_definition_not_fully_observed": True,
        "controlled_not_pure_optioned_lots": True,
        "owned_plus_controlled_equals_total": abs(component_gap) <= 1,
        "segment_rows_retained": True,
        "uses_later_comparative_prior_year_row": fiscal_year == 2022,
        "pre_public_predecessor_business_disclosure": fiscal_year == 2022,
        "pre_public_operating_builder_observation": fiscal_year == 2022,
        "contemporaneous_spac_10k_not_operating_builder": fiscal_year == 2022,
        "panel_use_flag": True,
        "manual_review_flag": fiscal_year == 2022,
        "manual_review_reason": (
            "uses_2023_comparative_prior_year_row_for_pre_public_great_southern_2022"
            if fiscal_year == 2022
            else ""
        ),
        "source_note": source_note,
    })

    source_notes.append({
        "ticker": "UHG",
        "fiscal_year": fiscal_year,
        "source_fiscal_year": source_fiscal_year,
        "extraction_method": extraction_method,
        "source_excerpt": source_excerpt,
    })

prebuilder_rows = []
for fiscal_year in (2020, 2021):
    if fiscal_year in filing_by_year:
        raw_text = Path(filing_by_year[fiscal_year]["primary_document_local_path"]).read_text(
            encoding="utf-8",
            errors="ignore",
        )
        visible_parser = VisibleTextParser()
        visible_parser.feed(raw_text)
        visible_text = clean_text(visible_parser.text())
        shell_phrase_found = re.search(r"early stage blank check company", visible_text, re.IGNORECASE) is not None

        prebuilder_rows.append({
            "ticker": "UHG",
            "fiscal_year": fiscal_year,
            "accession_number": filing_by_year[fiscal_year]["accession_number"],
            "source_url": filing_by_year[fiscal_year]["filing_url"],
            "source_local_path": filing_by_year[fiscal_year]["primary_document_local_path"],
            "blank_check_phrase_found": shell_phrase_found,
            "exclusion_reason": "DiamondHead Holdings Corp. SPAC filing before the Great Southern Homes business combination; no operating homebuilder land disclosure.",
        })

forward_comparison_matches = []
for fiscal_year, source_fiscal_year in ((2023, 2024), (2024, 2025)):
    filing = filing_by_year[source_fiscal_year]
    source_path = Path(filing["primary_document_local_path"])
    raw_text = source_path.read_text(encoding="utf-8", errors="ignore")
    table_parser = SecTableParser()
    table_parser.feed(raw_text)

    comparative_values = None
    for table in table_parser.tables:
        parsed_rows = []
        for html_row in table["rows"]:
            cells = [clean_text(cell.get("text", "")) for cell in html_row]
            cells = [cell for cell in cells if cell]
            if cells:
                parsed_rows.append(cells)

        table_text = clean_text(" || ".join(" | ".join(cells) for cells in parsed_rows))
        table_text_lower = table_text.lower()

        if "market/division" not in table_text_lower:
            continue
        if "owned" not in table_text_lower or "controlled" not in table_text_lower:
            continue
        if str(fiscal_year) not in table_text:
            continue

        for cells in parsed_rows:
            if len(cells) < 7 or cells[0].lower() != "total":
                continue

            numeric_values = []
            for cell in cells[4:7]:
                if re.fullmatch(r"\d+(?:,\d{3})*", cell):
                    numeric_values.append(float(cell.replace(",", "")))
                elif cell in ("—", "-", "--"):
                    numeric_values.append(0.0)

            if len(numeric_values) == 3:
                comparative_values = numeric_values
                break

        if comparative_values is not None:
            break

    selected_row = next(row for row in panel_rows if row["fiscal_year"] == fiscal_year)
    forward_comparison_matches.append(
        comparative_values is not None
        and comparative_values[0] == selected_row["owned_lots"]
        and comparative_values[1] == selected_row["controlled_lots"]
        and comparative_values[2] == selected_row["total_lots"]
    )

audit_rows = [
    {
        "audit_check": "firm_year_rows",
        "status": "ok" if len(panel_rows) == 4 else "fail",
        "value": len(panel_rows),
        "detail": "Expected UHG fiscal years 2022 through 2025.",
    },
    {
        "audit_check": "prebuilder_exclusion_rows",
        "status": "ok" if len(prebuilder_rows) == 2 else "fail",
        "value": len(prebuilder_rows),
        "detail": "Expected DiamondHead SPAC exclusions for fiscal 2020 and 2021.",
    },
    {
        "audit_check": "blank_check_phrase_found",
        "status": "ok" if all(row["blank_check_phrase_found"] for row in prebuilder_rows) else "fail",
        "value": sum(row["blank_check_phrase_found"] for row in prebuilder_rows),
        "detail": "Each excluded pre-builder filing should contain the blank-check-company phrase.",
    },
    {
        "audit_check": "component_identity",
        "status": "ok" if all(row["component_identity_pass"] for row in panel_rows) else "fail",
        "value": sum(row["component_identity_pass"] for row in panel_rows),
        "detail": "Owned plus controlled must equal total in each selected row.",
    },
    {
        "audit_check": "uses_2022_later_comparative_row_once",
        "status": "ok" if sum(row["uses_later_comparative_prior_year_row"] for row in panel_rows) == 1 else "fail",
        "value": sum(row["uses_later_comparative_prior_year_row"] for row in panel_rows),
        "detail": "Only fiscal 2022 should use the later comparative prior-year row.",
    },
    {
        "audit_check": "forward_comparative_total_rows",
        "status": "ok" if all(forward_comparison_matches) else "fail",
        "value": sum(forward_comparison_matches),
        "detail": "Expected selected 2023 and 2024 total rows to match the next-year comparative total rows.",
    },
]

write_csv(
    "../output/uhg_2022_2025_land_panel.csv",
    panel_rows,
    [
        "ticker", "cik10", "sec_company_name", "fiscal_year", "report_date", "filing_date",
        "accession_number", "source_accession_number", "primary_document", "source_local_path",
        "source_url", "unit_type", "owned_lots", "nonowned_controlled_lots", "controlled_lots",
        "total_lots", "nonowned_controlled_share", "owned_share", "component_identity_gap",
        "component_identity_pass", "extraction_method", "precision", "source_fiscal_year",
        "source_table_index", "source_row_label", "source_total_row_used", "controlled_definition_raw",
        "controlled_treated_as_nonowned_controlled", "controlled_definition_not_fully_observed",
        "controlled_not_pure_optioned_lots", "owned_plus_controlled_equals_total",
        "segment_rows_retained",
        "uses_later_comparative_prior_year_row", "pre_public_predecessor_business_disclosure",
        "pre_public_operating_builder_observation", "contemporaneous_spac_10k_not_operating_builder",
        "panel_use_flag", "manual_review_flag", "manual_review_reason", "source_note",
    ],
)

write_csv(
    "../output/uhg_2022_2025_segment_land_rows.csv",
    segment_rows,
    [
        "ticker", "cik10", "fiscal_year", "source_fiscal_year", "accession_number",
        "source_table_index", "segment_label", "row_type", "owned_lots", "controlled_lots",
        "total_lots", "component_identity_gap",
    ],
)

write_csv(
    "../output/uhg_2020_2021_prebuilder_filing_exclusions.csv",
    prebuilder_rows,
    [
        "ticker", "fiscal_year", "accession_number", "source_url", "source_local_path",
        "blank_check_phrase_found", "exclusion_reason",
    ],
)

write_csv(
    "../output/uhg_2022_2025_extraction_audit.csv",
    audit_rows,
    ["audit_check", "status", "value", "detail"],
)

write_csv(
    "../output/uhg_2022_2025_source_notes.csv",
    source_notes,
    ["ticker", "fiscal_year", "source_fiscal_year", "extraction_method", "source_excerpt"],
)
