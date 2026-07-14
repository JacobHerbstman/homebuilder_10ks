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
        if row.get("ticker") == "MHO" and 2004 <= int(float(row.get("fiscal_year"))) <= 2025
    ]

if len(filing_rows) == 0:
    raise RuntimeError("No M/I Homes filing rows found in land_light_firm_year_measures.csv.")

panel_rows = []
segment_rows = []
source_notes = []

for filing in sorted(filing_rows, key=lambda row: int(float(row["fiscal_year"]))):
    fiscal_year = int(float(filing["fiscal_year"]))
    source_path = Path(filing["primary_document_local_path"])

    if not source_path.exists():
        raise RuntimeError(f"Missing M/I Homes source file: {source_path}")

    raw_text = source_path.read_text(encoding="utf-8", errors="ignore")
    table_parser = SecTableParser()
    table_parser.feed(raw_text)

    developed_lots = None
    lots_under_development = None
    undeveloped_lots = None
    owned_lots = None
    lots_under_contract = None
    total_lots = None
    source_table_index = ""
    source_excerpt = ""

    for table_index, table in enumerate(table_parser.tables):
        parsed_rows = []
        for html_row in table["rows"]:
            cells = [clean_text(cell.get("text", "")) for cell in html_row]
            cells = [cell for cell in cells if cell]
            if cells:
                parsed_rows.append(cells)

        table_text = clean_text(" || ".join(" | ".join(cells) for cells in parsed_rows))
        table_text_lower = table_text.lower()

        if "lots owned" not in table_text_lower or "contract" not in table_text_lower:
            continue

        table_has_total = False
        for cells in parsed_rows:
            if len(cells) < 2:
                continue

            numeric_values = []
            for cell in cells[1:]:
                if re.fullmatch(r"\d+(?:,\d{3})*", cell):
                    numeric_values.append(float(cell.replace(",", "")))

            if len(numeric_values) < 6:
                continue

            row_label = cells[0]
            row_developed_lots = numeric_values[-6]
            row_lots_under_development = numeric_values[-5]
            row_undeveloped_lots = numeric_values[-4]
            row_owned_lots = numeric_values[-3]
            row_lots_under_contract = numeric_values[-2]
            row_total_lots = numeric_values[-1]

            if row_label.lower() != "region":
                segment_rows.append({
                    "ticker": "MHO",
                    "cik10": filing["cik10"],
                    "fiscal_year": fiscal_year,
                    "accession_number": filing["accession_number"],
                    "source_table_index": table_index,
                    "segment_label": row_label,
                    "developed_lots": row_developed_lots,
                    "lots_under_development": row_lots_under_development,
                    "undeveloped_lots": row_undeveloped_lots,
                    "owned_lots": row_owned_lots,
                    "lots_under_contract": row_lots_under_contract,
                    "total_lots": row_total_lots,
                    "component_identity_gap": row_owned_lots + row_lots_under_contract - row_total_lots,
                })

            if row_label.lower() == "total":
                developed_lots = row_developed_lots
                lots_under_development = row_lots_under_development
                undeveloped_lots = row_undeveloped_lots
                owned_lots = row_owned_lots
                lots_under_contract = row_lots_under_contract
                total_lots = row_total_lots
                source_table_index = str(table_index)
                source_excerpt = table_text[:1200]
                table_has_total = True

        if table_has_total:
            break

    component_gap = ""
    if owned_lots is not None and lots_under_contract is not None and total_lots is not None:
        component_gap = owned_lots + lots_under_contract - total_lots

    panel_rows.append({
        "ticker": "MHO",
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
        "developed_lots": developed_lots,
        "lots_under_development": lots_under_development,
        "undeveloped_lots": undeveloped_lots,
        "owned_lots": owned_lots,
        "nonowned_controlled_lots": lots_under_contract,
        "lots_under_contract": lots_under_contract,
        "total_lots": total_lots,
        "nonowned_controlled_share": (
            lots_under_contract / total_lots
            if lots_under_contract is not None and total_lots not in (None, 0)
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
        "extraction_method": "lots_owned_table_total_row" if total_lots is not None else "not_found",
        "precision": "reported_table" if total_lots is not None else "",
        "source_table_index": source_table_index,
        "source_row_label": "Total",
        "panel_use_flag": total_lots is not None,
        "manual_review_flag": total_lots is None,
        "manual_review_reason": "missing_lots_owned_table_total_row" if total_lots is None else "",
        "source_note": "M/I Homes recurring Lots Owned table. Firm-year uses Total row: Total Lots Owned plus Lots Under Contract equals Total. Lots Under Contract is coded as nonowned controlled lots, not as a generic optioned-lots label.",
    })

    source_notes.append({
        "ticker": "MHO",
        "fiscal_year": fiscal_year,
        "extraction_method": "lots_owned_table_total_row" if total_lots is not None else "not_found",
        "source_excerpt": source_excerpt,
    })

audit_rows = [
    {
        "audit_check": "firm_year_rows",
        "status": "ok" if len(panel_rows) == 22 else "fail",
        "value": len(panel_rows),
        "detail": "Expected M/I Homes fiscal years 2004 through 2025 from current filing inventory.",
    },
    {
        "audit_check": "missing_extractions",
        "status": "ok" if sum(row["extraction_method"] == "not_found" for row in panel_rows) == 0 else "fail",
        "value": sum(row["extraction_method"] == "not_found" for row in panel_rows),
        "detail": "Firm-years without the recurring Lots Owned table total row.",
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
        "detail": "Extracted lots-under-contract share is between zero and one.",
    },
    {
        "audit_check": "component_identity",
        "status": "ok" if all(row["component_identity_pass"] for row in panel_rows) else "fail",
        "value": sum(row["component_identity_pass"] for row in panel_rows),
        "detail": "Total Lots Owned plus Lots Under Contract equals Total in the Total row.",
    },
]

write_csv("../output/mho_2004_2025_land_panel.csv", panel_rows, [
    "ticker", "cik10", "sec_company_name", "fiscal_year", "report_date",
    "filing_date", "accession_number", "primary_document", "source_local_path",
    "source_url", "unit_type", "developed_lots", "lots_under_development",
    "undeveloped_lots", "owned_lots", "nonowned_controlled_lots",
    "lots_under_contract", "total_lots", "nonowned_controlled_share",
    "owned_share", "component_identity_gap", "component_identity_pass",
    "extraction_method", "precision", "source_table_index", "source_row_label",
    "panel_use_flag", "manual_review_flag", "manual_review_reason", "source_note",
])
write_csv("../output/mho_2004_2025_segment_land_rows.csv", segment_rows, [
    "ticker", "cik10", "fiscal_year", "accession_number", "source_table_index",
    "segment_label", "developed_lots", "lots_under_development", "undeveloped_lots",
    "owned_lots", "lots_under_contract", "total_lots", "component_identity_gap",
])
write_csv("../output/mho_2004_2025_extraction_audit.csv", audit_rows, [
    "audit_check", "status", "value", "detail",
])
write_csv("../output/mho_2004_2025_source_notes.csv", source_notes, [
    "ticker", "fiscal_year", "extraction_method", "source_excerpt",
])

print("Wrote M/I Homes land disclosure extraction outputs to ../output")
