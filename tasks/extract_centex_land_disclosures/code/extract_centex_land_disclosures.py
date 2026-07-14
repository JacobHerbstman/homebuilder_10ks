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
        if row.get("ticker") == "CTX"
        and row.get("form") == "10-K"
        and 2004 <= int(float(row.get("fiscal_year"))) <= 2009
    ]

if len(filing_rows) == 0:
    raise RuntimeError("No Centex filing rows found in land_light_firm_year_measures.csv.")

filing_by_year = {}
for filing in filing_rows:
    fiscal_year = int(float(filing["fiscal_year"]))
    if fiscal_year in filing_by_year:
        raise RuntimeError("Centex filing rows must be unique by fiscal_year.")
    filing_by_year[fiscal_year] = filing

expected_values = {
    2004: (77475, 115366, 192841),
    2005: (96945, 168350, 265295),
    2006: (108828, 186893, 295721),
    2007: (98311, 61709, 160020),
    2008: (70222, 18147, 88369),
    2009: (57289, 7045, 64334),
}

panel_rows = []
source_notes = []

for fiscal_year in range(2004, 2010):
    filing = filing_by_year[fiscal_year]
    source_path = Path(filing["primary_document_local_path"])

    if not source_path.exists():
        raise RuntimeError(f"Missing Centex source file: {source_path}")

    raw_text = source_path.read_text(encoding="utf-8", errors="ignore")
    table_parser = SecTableParser()
    table_parser.feed(raw_text)

    owned_lots = None
    controlled_lots = None
    total_lots = None
    source_table_index = ""
    source_row_label = ""
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

        if "controlled" not in table_text_lower or "total lots" not in table_text_lower:
            continue
        if "lots owned" not in table_text_lower and "owned" not in table_text_lower:
            continue
        if str(fiscal_year) not in table_text:
            continue

        row_owned = None
        row_controlled = None
        row_total = None

        for cells in parsed_rows:
            if len(cells) < 2:
                continue

            if cells[0] == "Lots Owned" and re.fullmatch(r"\d+(?:,\d{3})*", cells[1]):
                row_owned = float(cells[1].replace(",", ""))
            if cells[0] == "Lots Controlled" and re.fullmatch(r"\d+(?:,\d{3})*", cells[1]):
                row_controlled = float(cells[1].replace(",", ""))
            if cells[0] == "Total Lots Owned and Controlled" and re.fullmatch(r"\d+(?:,\d{3})*", cells[1]):
                row_total = float(cells[1].replace(",", ""))

        if row_owned is not None and row_controlled is not None and row_total is not None:
            owned_lots = row_owned
            controlled_lots = row_controlled
            total_lots = row_total
            source_table_index = str(table_index)
            source_row_label = "Lots Owned / Lots Controlled / Total Lots Owned and Controlled"
            source_excerpt = table_text[:1800]
            break

        for cells in parsed_rows:
            if len(cells) == 0 or not re.fullmatch(r"\d+(?:,\d{3})*", cells[0]):
                continue

            numeric_values = []
            for cell in cells:
                if re.fullmatch(r"\d+(?:,\d{3})*", cell):
                    numeric_values.append(float(cell.replace(",", "")))

            if len(numeric_values) >= 6:
                owned_lots = numeric_values[0]
                controlled_lots = numeric_values[1]
                total_lots = numeric_values[2]
                source_table_index = str(table_index)
                source_row_label = "unlabeled total row"
                source_excerpt = table_text[:2200]
                break

        if total_lots is not None:
            break

    if total_lots is None:
        raise RuntimeError(f"Could not find Centex land-position table for fiscal {fiscal_year}.")

    component_identity_gap = owned_lots + controlled_lots - total_lots

    panel_rows.append({
        "ticker": "CTX",
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
        "nonowned_controlled_lots": controlled_lots,
        "optioned_lots": controlled_lots,
        "total_lots": total_lots,
        "nonowned_controlled_share": controlled_lots / total_lots,
        "optioned_share": controlled_lots / total_lots,
        "owned_share": owned_lots / total_lots,
        "component_identity_gap": component_identity_gap,
        "component_identity_pass": abs(component_identity_gap) <= 1,
        "extraction_method": "centex_lots_owned_controlled_total_table",
        "source_table_index": source_table_index,
        "source_row_label": source_row_label,
        "panel_use_flag": True,
        "manual_review_flag": False,
        "manual_review_reason": "",
        "source_note": "Centex Lots Controlled is coded as nonowned/option-controlled lots based on the land-position table and nearby option-agreement prose. Fiscal year ends March 31; Centex was acquired by Pulte after fiscal 2009 year-end.",
    })

    source_notes.append({
        "ticker": "CTX",
        "fiscal_year": fiscal_year,
        "source_table_index": source_table_index,
        "source_row_label": source_row_label,
        "source_excerpt": source_excerpt,
    })

audit_rows = []
for row in panel_rows:
    expected_owned, expected_controlled, expected_total = expected_values[row["fiscal_year"]]
    audit_rows.append({
        "audit_check": "expected_values",
        "fiscal_year": row["fiscal_year"],
        "status": "ok" if row["owned_lots"] == expected_owned and row["nonowned_controlled_lots"] == expected_controlled and row["total_lots"] == expected_total else "fail",
        "value": f'{row["owned_lots"]}|{row["nonowned_controlled_lots"]}|{row["total_lots"]}',
        "detail": f"Expected {expected_owned}|{expected_controlled}|{expected_total}.",
    })

audit_rows.append({
    "audit_check": "firm_year_rows",
    "fiscal_year": "",
    "status": "ok" if len(panel_rows) == 6 else "fail",
    "value": len(panel_rows),
    "detail": "Expected Centex fiscal 2004-2009.",
})

audit_rows.append({
    "audit_check": "component_identity",
    "fiscal_year": "",
    "status": "ok" if all(row["component_identity_pass"] for row in panel_rows) else "fail",
    "value": sum(row["component_identity_pass"] for row in panel_rows),
    "detail": "Owned lots plus controlled lots must equal total lots.",
})

write_csv(
    "../output/ctx_2004_2009_land_panel.csv",
    panel_rows,
    [
        "ticker", "cik10", "sec_company_name", "fiscal_year", "report_date",
        "filing_date", "accession_number", "primary_document", "source_local_path",
        "source_url", "unit_type", "owned_lots", "nonowned_controlled_lots",
        "optioned_lots", "total_lots", "nonowned_controlled_share", "optioned_share",
        "owned_share", "component_identity_gap", "component_identity_pass",
        "extraction_method", "source_table_index", "source_row_label",
        "panel_use_flag", "manual_review_flag", "manual_review_reason", "source_note",
    ],
)

write_csv(
    "../output/ctx_2004_2009_extraction_audit.csv",
    audit_rows,
    ["audit_check", "fiscal_year", "status", "value", "detail"],
)

write_csv(
    "../output/ctx_2004_2009_source_notes.csv",
    source_notes,
    ["ticker", "fiscal_year", "source_table_index", "source_row_label", "source_excerpt"],
)
