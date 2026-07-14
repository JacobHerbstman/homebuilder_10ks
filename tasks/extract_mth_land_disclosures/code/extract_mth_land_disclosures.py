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
        if row.get("ticker") == "MTH"
        and row.get("form") == "10-K"
        and 2004 <= int(float(row.get("fiscal_year"))) <= 2025
    ]

if len(filing_rows) == 0:
    raise RuntimeError("No Meritage filing rows found in land_light_firm_year_measures.csv.")

panel_rows = []
segment_rows = []
source_notes = []

for filing in sorted(filing_rows, key=lambda row: int(float(row["fiscal_year"]))):
    fiscal_year = int(float(filing["fiscal_year"]))
    source_path = Path(filing["primary_document_local_path"])

    if not source_path.exists():
        raise RuntimeError(f"Missing Meritage source file: {source_path}")

    raw_text = source_path.read_text(encoding="utf-8", errors="ignore")
    table_parser = SecTableParser()
    table_parser.feed(raw_text)
    visible_parser = VisibleTextParser()
    visible_parser.feed(raw_text)
    visible_text = clean_text(visible_parser.text())

    owned_lots = None
    nonowned_controlled_lots = None
    total_lots = None
    note_committed_lots = None
    note_total_contract_lots = None
    purchase_price_thousands = None
    deposit_cash_thousands = None
    extraction_method = ""
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

        if fiscal_year >= 2018:
            if "projected number of lots" not in table_text_lower:
                continue
            if "total committed" not in table_text_lower or "total lots under contract or option" not in table_text_lower:
                continue

            for cells in parsed_rows:
                row_label = cells[0].lower()
                numeric_values = []
                for cell in cells[1:]:
                    if re.fullmatch(r"\d+(?:,\d{3})*", cell):
                        numeric_values.append(float(cell.replace(",", "")))
                    elif cell in ("—", "-", "--"):
                        numeric_values.append(0.0)

                if row_label == "total committed" and len(numeric_values) >= 3:
                    note_committed_lots = numeric_values[0]
                    purchase_price_thousands = numeric_values[1]
                    deposit_cash_thousands = numeric_values[2]
                if row_label == "total lots under contract or option" and numeric_values:
                    note_total_contract_lots = numeric_values[0]

            if note_committed_lots is not None:
                source_table_index = str(table_index)
                source_excerpt = table_text[:1400]
                break

        if fiscal_year == 2004:
            if "land owned" not in table_text_lower or "land under contract or option" not in table_text_lower:
                continue

            for cells in parsed_rows:
                numeric_values = []
                for cell in cells[1:]:
                    if re.fullmatch(r"\d+(?:,\d{3})*", cell):
                        numeric_values.append(float(cell.replace(",", "")))
                    elif cell in ("—", "-", "--"):
                        numeric_values.append(0.0)

                if cells[0].lower() == "total" and len(numeric_values) >= 7:
                    owned_lots = sum(numeric_values[0:3])
                    nonowned_controlled_lots = sum(numeric_values[3:6])
                    total_lots = numeric_values[6]
                    source_table_index = str(table_index)
                    source_row_label = "TOTAL"
                    source_excerpt = table_text[:1400]
                    extraction_method = "business_land_owned_contract_option_split_columns"
                    break

                if len(numeric_values) >= 7 and cells[0].lower() not in ("total book cost (3)",):
                    segment_rows.append({
                        "ticker": "MTH",
                        "cik10": filing["cik10"],
                        "fiscal_year": fiscal_year,
                        "accession_number": filing["accession_number"],
                        "source_table_index": table_index,
                        "segment_label": cells[0],
                        "owned_lots": sum(numeric_values[0:3]),
                        "nonowned_controlled_lots": sum(numeric_values[3:6]),
                        "total_lots": numeric_values[6],
                        "component_identity_gap": sum(numeric_values[0:6]) - numeric_values[6],
                    })

            if extraction_method != "":
                break

        if fiscal_year <= 2017:
            if "lots owned" not in table_text_lower:
                continue
            if "under contract" not in table_text_lower or "total" not in table_text_lower:
                continue

            for cells in parsed_rows:
                if cells[0].lower() not in ("total", "total company"):
                    continue

                numeric_values = []
                for cell in cells[1:]:
                    if re.fullmatch(r"\d+(?:,\d{3})*", cell):
                        numeric_values.append(float(cell.replace(",", "")))
                    elif cell in ("—", "-", "--"):
                        numeric_values.append(0.0)

                if len(numeric_values) == 3:
                    owned_lots = numeric_values[0]
                    nonowned_controlled_lots = numeric_values[1]
                    total_lots = numeric_values[2]
                    source_table_index = str(table_index)
                    source_row_label = cells[0]
                    source_excerpt = table_text[:1400]
                    extraction_method = "business_lots_owned_contract_total_row"
                    break

                if len(numeric_values) >= 4:
                    owned_lots = numeric_values[0] + numeric_values[1]
                    nonowned_controlled_lots = numeric_values[2]
                    total_lots = numeric_values[3]
                    source_table_index = str(table_index)
                    source_row_label = cells[0]
                    source_excerpt = table_text[:1400]
                    extraction_method = "business_lots_owned_split_contract_total_row"
                    break

            if extraction_method != "":
                for cells in parsed_rows:
                    if len(cells) == 0 or cells[0].lower() in ("total", "total company", "total book cost (3)"):
                        continue

                    numeric_values = []
                    for cell in cells[1:]:
                        if re.fullmatch(r"\d+(?:,\d{3})*", cell):
                            numeric_values.append(float(cell.replace(",", "")))
                        elif cell in ("—", "-", "--"):
                            numeric_values.append(0.0)

                    if len(numeric_values) == 3:
                        segment_rows.append({
                            "ticker": "MTH",
                            "cik10": filing["cik10"],
                            "fiscal_year": fiscal_year,
                            "accession_number": filing["accession_number"],
                            "source_table_index": table_index,
                            "segment_label": cells[0],
                            "owned_lots": numeric_values[0],
                            "nonowned_controlled_lots": numeric_values[1],
                            "total_lots": numeric_values[2],
                            "component_identity_gap": numeric_values[0] + numeric_values[1] - numeric_values[2],
                        })

                    if len(numeric_values) >= 4:
                        segment_rows.append({
                            "ticker": "MTH",
                            "cik10": filing["cik10"],
                            "fiscal_year": fiscal_year,
                            "accession_number": filing["accession_number"],
                            "source_table_index": table_index,
                            "segment_label": cells[0],
                            "owned_lots": numeric_values[0] + numeric_values[1],
                            "nonowned_controlled_lots": numeric_values[2],
                            "total_lots": numeric_values[3],
                            "component_identity_gap": numeric_values[0] + numeric_values[1] + numeric_values[2] - numeric_values[3],
                        })
                break

    if fiscal_year >= 2018:
        owned_match = re.search(
            r"in addition to our ([0-9,]+) owned lots, we also had ([0-9,]+) lots under (?:committed |non-refundable )?purchase or option contracts",
            visible_text,
            re.IGNORECASE,
        )
        total_match = re.search(
            rf"(?:total number of lots under control at December 31, {fiscal_year} was|ended the year with|lot supply with) ([0-9,]+) lots under control",
            visible_text,
            re.IGNORECASE,
        )
        if total_match is None:
            total_match = re.search(
                rf"([0-9,]+) lots under control at December 31, {fiscal_year}",
                visible_text,
                re.IGNORECASE,
            )

        if owned_match is not None:
            owned_lots = float(owned_match.group(1).replace(",", ""))
            nonowned_controlled_lots = float(owned_match.group(2).replace(",", ""))
        if total_match is not None:
            total_lots = float(total_match.group(1).replace(",", ""))
        if owned_lots is not None and nonowned_controlled_lots is not None and total_lots is not None:
            extraction_method = "prose_total_control_owned_committed_contracts"
            source_row_label = "prose owned lots plus committed purchase/option contracts"

        if source_excerpt == "" and owned_match is not None:
            source_excerpt = visible_text[
                max(0, owned_match.start() - 500):min(len(visible_text), owned_match.end() + 700)
            ]

    component_gap = ""
    if owned_lots is not None and nonowned_controlled_lots is not None and total_lots is not None:
        component_gap = owned_lots + nonowned_controlled_lots - total_lots

    note_committed_gap = ""
    if note_committed_lots is not None and nonowned_controlled_lots is not None:
        note_committed_gap = note_committed_lots - nonowned_controlled_lots

    panel_rows.append({
        "ticker": "MTH",
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
        "nonowned_controlled_lots": nonowned_controlled_lots,
        "total_lots": total_lots,
        "nonowned_controlled_share": (
            nonowned_controlled_lots / total_lots
            if nonowned_controlled_lots is not None and total_lots not in (None, 0)
            else None
        ),
        "owned_share": (
            owned_lots / total_lots
            if owned_lots is not None and total_lots not in (None, 0)
            else None
        ),
        "note_committed_lots": note_committed_lots,
        "note_total_contract_lots": note_total_contract_lots,
        "purchase_price_thousands": purchase_price_thousands,
        "deposit_cash_thousands": deposit_cash_thousands,
        "component_identity_gap": component_gap,
        "component_identity_pass": (
            abs(component_gap) <= 1
            if isinstance(component_gap, float)
            else False
        ),
        "note_committed_identity_gap": note_committed_gap,
        "note_committed_identity_pass": (
            abs(note_committed_gap) <= 1
            if isinstance(note_committed_gap, float)
            else ""
        ),
        "extraction_method": extraction_method if extraction_method != "" else "not_found",
        "precision": "reported_table_or_prose" if extraction_method != "" else "",
        "source_table_index": source_table_index,
        "source_row_label": source_row_label,
        "panel_use_flag": extraction_method != "",
        "manual_review_flag": extraction_method == "",
        "manual_review_reason": "missing_meritage_lot_control_disclosure" if extraction_method == "" else "",
        "source_note": "Meritage physical omega uses the business land-supply table through 2017 and total lots under control with committed purchase/option contracts from 2018 forward. Uncommitted refundable contract lots from Note 3 are preserved separately, not included in the omega numerator.",
    })

    source_notes.append({
        "ticker": "MTH",
        "fiscal_year": fiscal_year,
        "extraction_method": extraction_method if extraction_method != "" else "not_found",
        "source_excerpt": source_excerpt,
    })

audit_rows = [
    {
        "audit_check": "firm_year_rows",
        "status": "ok" if len(panel_rows) == 22 else "fail",
        "value": len(panel_rows),
        "detail": "Expected Meritage fiscal years 2004 through 2025 from current filing inventory.",
    },
    {
        "audit_check": "missing_extractions",
        "status": "ok" if sum(row["extraction_method"] == "not_found" for row in panel_rows) == 0 else "fail",
        "value": sum(row["extraction_method"] == "not_found" for row in panel_rows),
        "detail": "Firm-years without a Meritage land-control extraction.",
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
        "detail": "Extracted nonowned controlled share is between zero and one.",
    },
    {
        "audit_check": "component_identity",
        "status": "ok" if all(row["component_identity_pass"] for row in panel_rows) else "fail",
        "value": sum(row["component_identity_pass"] for row in panel_rows),
        "detail": "Owned lots plus nonowned controlled lots equals total controlled lots.",
    },
    {
        "audit_check": "recent_committed_note_check",
        "status": "ok" if all(
            row["note_committed_identity_pass"] in ("", True)
            for row in panel_rows
        ) else "fail",
        "value": sum(row["note_committed_identity_pass"] is True for row in panel_rows),
        "detail": "For 2018 onward, Note 3 total committed lots equals the nonowned controlled numerator from prose.",
    },
]

write_csv("../output/mth_2004_2025_land_panel.csv", panel_rows, [
    "ticker", "cik10", "sec_company_name", "fiscal_year", "report_date",
    "filing_date", "accession_number", "primary_document", "source_local_path",
    "source_url", "unit_type", "owned_lots", "nonowned_controlled_lots",
    "total_lots", "nonowned_controlled_share", "owned_share",
    "note_committed_lots", "note_total_contract_lots", "purchase_price_thousands",
    "deposit_cash_thousands", "component_identity_gap", "component_identity_pass",
    "note_committed_identity_gap", "note_committed_identity_pass",
    "extraction_method", "precision", "source_table_index", "source_row_label",
    "panel_use_flag", "manual_review_flag", "manual_review_reason", "source_note",
])
write_csv("../output/mth_2004_2025_segment_land_rows.csv", segment_rows, [
    "ticker", "cik10", "fiscal_year", "accession_number", "source_table_index",
    "segment_label", "owned_lots", "nonowned_controlled_lots", "total_lots",
    "component_identity_gap",
])
write_csv("../output/mth_2004_2025_extraction_audit.csv", audit_rows, [
    "audit_check", "status", "value", "detail",
])
write_csv("../output/mth_2004_2025_source_notes.csv", source_notes, [
    "ticker", "fiscal_year", "extraction_method", "source_excerpt",
])
