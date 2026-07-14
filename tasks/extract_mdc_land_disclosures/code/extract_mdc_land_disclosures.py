#!/usr/bin/env python3

import csv
import re
import sys
from pathlib import Path

sys.path.append(str(Path(__file__).resolve().parents[2] / "_lib"))
from sec_fetch_utils import write_csv

sys.path.append(str(Path(__file__).resolve().parents[1].parent / "extract_10k_land_candidates" / "code"))
from extract_10k_land_candidates import SecTableParser, clean_text


with open("../input/land_light_firm_year_measures.csv", newline="") as f:
    filing_rows = [
        row for row in csv.DictReader(f)
        if row.get("ticker") == "MDC" and 2004 <= int(float(row.get("fiscal_year"))) <= 2025
    ]

if len(filing_rows) == 0:
    raise RuntimeError("No MDC filing rows found in land_light_firm_year_measures.csv.")

panel_rows = []
segment_rows = []
source_notes = []

for filing in sorted(filing_rows, key=lambda row: int(float(row["fiscal_year"]))):
    fiscal_year = int(float(filing["fiscal_year"]))
    source_path = Path(filing["primary_document_local_path"])

    if not source_path.exists():
        raise RuntimeError(f"Missing MDC source file: {source_path}")

    raw_text = source_path.read_text(encoding="utf-8", errors="ignore")
    table_parser = SecTableParser()
    table_parser.feed(raw_text)

    owned_lots = None
    optioned_lots = None
    total_lots = None
    extraction_method = ""
    source_table_index = ""
    source_excerpt = ""
    pending_owned_lots = None
    pending_owned_table_index = ""
    pending_owned_excerpt = ""

    for table_index, table in enumerate(table_parser.tables):
        parsed_rows = []
        for html_row in table["rows"]:
            cells = [clean_text(cell.get("text", "")) for cell in html_row]
            cells = [cell for cell in cells if cell]
            if cells:
                parsed_rows.append(cells)

        table_text = clean_text(" || ".join(" | ".join(cells) for cells in parsed_rows))
        table_text_lower = table_text.lower()

        if "lots owned" not in table_text_lower:
            continue

        if "lots optioned" in table_text_lower:
            for cells in parsed_rows:
                if len(cells) < 4 or cells[0].lower() == "region":
                    continue

                numeric_values = []
                for cell in cells[1:]:
                    if re.fullmatch(r"\(?-?\d+(?:,\d{3})*\)?", cell):
                        numeric_values.append(float(cell.replace(",", "").replace("(", "-").replace(")", "")))

                if len(numeric_values) < 3:
                    continue

                row_label = cells[0]
                row_owned_lots = numeric_values[0]
                row_optioned_lots = numeric_values[1]
                row_total_lots = numeric_values[2]

                if row_label.lower() != "total":
                    segment_rows.append({
                        "ticker": "MDC",
                        "cik10": filing["cik10"],
                        "fiscal_year": fiscal_year,
                        "accession_number": filing["accession_number"],
                        "source_table_index": table_index,
                        "segment_label": row_label,
                        "owned_lots": row_owned_lots,
                        "optioned_lots": row_optioned_lots,
                        "total_lots": row_total_lots,
                        "component_identity_gap": row_owned_lots + row_optioned_lots - row_total_lots,
                    })

                if row_label.lower() == "total":
                    owned_lots = row_owned_lots
                    optioned_lots = row_optioned_lots
                    total_lots = row_total_lots
                    extraction_method = "lots_owned_optioned_total_row"
                    source_table_index = str(table_index)
                    source_excerpt = table_text[:1200]
                    break

        if extraction_method != "":
            break

        if "lots owned" in table_text_lower and "option" not in table_text_lower:
            for cells in parsed_rows:
                if len(cells) < 2 or cells[0].lower() != "total":
                    continue

                numeric_values = []
                for cell in cells[1:]:
                    if re.fullmatch(r"\d+(?:,\d{3})*", cell):
                        numeric_values.append(float(cell.replace(",", "")))

                if numeric_values:
                    pending_owned_lots = numeric_values[0]
                    pending_owned_table_index = str(table_index)
                    pending_owned_excerpt = table_text[:700]
                    break

            continue

        if "lots controlled under option" in table_text_lower and "total lots owned and controlled" in table_text_lower:
            table_optioned_lots = None
            table_total_lots = None

            for cells in parsed_rows:
                if len(cells) < 2:
                    continue

                numeric_values = []
                for cell in cells[1:]:
                    if re.fullmatch(r"\d+(?:,\d{3})*", cell):
                        numeric_values.append(float(cell.replace(",", "")))

                if cells[0].lower() == "total" and numeric_values:
                    table_optioned_lots = numeric_values[0]
                if cells[0].lower() == "total lots owned and controlled" and numeric_values:
                    table_total_lots = numeric_values[0]

            if pending_owned_lots is not None and table_optioned_lots is not None:
                owned_lots = pending_owned_lots
                optioned_lots = table_optioned_lots
                total_lots = table_total_lots if table_total_lots is not None else pending_owned_lots + table_optioned_lots
                extraction_method = "split_section_tables_lots_owned_under_option"
                source_table_index = pending_owned_table_index + " | " + str(table_index)
                source_excerpt = pending_owned_excerpt + " || " + table_text[:700]
                break

        if "lots under option" in table_text_lower or "lots controlled under option" in table_text_lower:
            table_owned_lots = None
            table_optioned_lots = None
            table_total_lots = None
            active_section = ""

            for cells in parsed_rows:
                row_label = cells[0].lower()
                numeric_values = []
                for cell in cells[1:]:
                    if re.fullmatch(r"\d+(?:,\d{3})*", cell):
                        numeric_values.append(float(cell.replace(",", "")))

                if row_label == "lots owned":
                    active_section = "owned"
                    continue
                if row_label in ("lots under option", "lots controlled under option"):
                    active_section = "optioned"
                    continue
                if row_label == "total lots owned and controlled" and numeric_values:
                    table_total_lots = numeric_values[0]
                    continue

                if len(numeric_values) == 0:
                    continue

                if row_label != "total":
                    if active_section in ("owned", "optioned"):
                        segment_rows.append({
                            "ticker": "MDC",
                            "cik10": filing["cik10"],
                            "fiscal_year": fiscal_year,
                            "accession_number": filing["accession_number"],
                            "source_table_index": table_index,
                            "segment_label": cells[0],
                            "owned_lots": numeric_values[0] if active_section == "owned" else None,
                            "optioned_lots": numeric_values[0] if active_section == "optioned" else None,
                            "total_lots": None,
                            "component_identity_gap": None,
                        })
                    continue

                if active_section == "owned":
                    table_owned_lots = numeric_values[0]
                if active_section == "optioned":
                    table_optioned_lots = numeric_values[0]

            if table_owned_lots is not None and table_optioned_lots is not None:
                owned_lots = table_owned_lots
                optioned_lots = table_optioned_lots
                total_lots = table_total_lots if table_total_lots is not None else table_owned_lots + table_optioned_lots
                extraction_method = "section_table_lots_owned_under_option"
                source_table_index = str(table_index)
                source_excerpt = table_text[:1200]
                break

    component_gap = ""
    if owned_lots is not None and optioned_lots is not None and total_lots is not None:
        component_gap = owned_lots + optioned_lots - total_lots

    panel_rows.append({
        "ticker": "MDC",
        "cik10": filing["cik10"],
        "sec_company_name": filing["sec_company_name"],
        "fiscal_year": fiscal_year,
        "report_date": filing["report_date"],
        "filing_date": filing["filing_date"],
        "accession_number": filing["accession_number"],
        "primary_document": filing["primary_document"],
        "source_local_path": filing["primary_document_local_path"],
        "source_url": filing["filing_url"],
        "unit_type": "lots",
        "owned_lots": owned_lots,
        "optioned_lots": optioned_lots,
        "nonowned_controlled_lots": optioned_lots,
        "total_lots": total_lots,
        "nonowned_controlled_share": (
            optioned_lots / total_lots
            if optioned_lots is not None and total_lots not in (None, 0)
            else None
        ),
        "owned_share": (
            owned_lots / total_lots
            if owned_lots is not None and total_lots not in (None, 0)
            else None
        ),
        "component_identity_gap": component_gap,
        "component_identity_pass": (
            abs(component_gap) <= 1
            if isinstance(component_gap, float)
            else False
        ),
        "extraction_method": extraction_method if extraction_method != "" else "not_found",
        "precision": "reported_table" if extraction_method != "" else "",
        "source_table_index": source_table_index,
        "source_row_label": "Total",
        "panel_use_flag": extraction_method != "",
        "manual_review_flag": extraction_method == "",
        "manual_review_reason": "missing_mdc_lot_control_table_total_row" if extraction_method == "" else "",
        "source_note": "MDC reports lots owned and lots under/controlled under option in older tables and lots owned/lots optioned/total in newer tables. Optioned lots are coded as nonowned controlled lots.",
    })

    source_notes.append({
        "ticker": "MDC",
        "fiscal_year": fiscal_year,
        "extraction_method": extraction_method if extraction_method != "" else "not_found",
        "source_excerpt": source_excerpt,
    })

audit_rows = [
    {
        "audit_check": "firm_year_rows",
        "status": "ok" if len(panel_rows) == 22 else "fail",
        "value": len(panel_rows),
        "detail": "Expected MDC fiscal years 2004 through 2025 from current filing inventory.",
    },
    {
        "audit_check": "missing_extractions",
        "status": "ok" if sum(row["extraction_method"] == "not_found" for row in panel_rows) == 0 else "fail",
        "value": sum(row["extraction_method"] == "not_found" for row in panel_rows),
        "detail": "Firm-years without an MDC lots-owned/optioned total row.",
    },
    {
        "audit_check": "share_in_range",
        "status": "ok" if all(
            row["nonowned_controlled_share"] is not None and 0 <= row["nonowned_controlled_share"] <= 1
            for row in panel_rows
        ) else "fail",
        "value": sum(
            row["nonowned_controlled_share"] is not None and 0 <= row["nonowned_controlled_share"] <= 1
            for row in panel_rows
        ),
        "detail": "Extracted optioned-lot share is between zero and one.",
    },
    {
        "audit_check": "component_identity",
        "status": "ok" if all(row["component_identity_pass"] for row in panel_rows) else "fail",
        "value": sum(row["component_identity_pass"] for row in panel_rows),
        "detail": "Owned lots plus optioned lots equals total lots.",
    },
]

write_csv("../output/mdc_2004_2025_land_panel.csv", panel_rows, [
    "ticker", "cik10", "sec_company_name", "fiscal_year", "report_date",
    "filing_date", "accession_number", "primary_document", "source_local_path",
    "source_url", "unit_type", "owned_lots", "optioned_lots",
    "nonowned_controlled_lots", "total_lots", "nonowned_controlled_share",
    "owned_share", "component_identity_gap", "component_identity_pass",
    "extraction_method", "precision", "source_table_index", "source_row_label",
    "panel_use_flag", "manual_review_flag", "manual_review_reason", "source_note",
])
write_csv("../output/mdc_2004_2025_segment_land_rows.csv", segment_rows, [
    "ticker", "cik10", "fiscal_year", "accession_number", "source_table_index",
    "segment_label", "owned_lots", "optioned_lots", "total_lots",
    "component_identity_gap",
])
write_csv("../output/mdc_2004_2025_extraction_audit.csv", audit_rows, [
    "audit_check", "status", "value", "detail",
])
write_csv("../output/mdc_2004_2025_source_notes.csv", source_notes, [
    "ticker", "fiscal_year", "extraction_method", "source_excerpt",
])

print("Wrote MDC land disclosure extraction outputs to ../output")
