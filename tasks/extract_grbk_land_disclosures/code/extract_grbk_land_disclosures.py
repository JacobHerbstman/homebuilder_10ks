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
    all_grbk_rows = [
        row for row in csv.DictReader(f)
        if row.get("ticker") == "GRBK" and row.get("form") == "10-K"
    ]

filing_rows = [
    row for row in all_grbk_rows
    if 2014 <= int(float(row.get("fiscal_year"))) <= 2025
]

prebuilder_rows = [
    row for row in all_grbk_rows
    if int(float(row.get("fiscal_year"))) < 2014
]

if len(filing_rows) == 0:
    raise RuntimeError("No Green Brick builder-era filing rows found in land_light_firm_year_measures.csv.")

panel_rows = []
segment_rows = []
source_notes = []
prebuilder_exclusions = []

for filing in sorted(prebuilder_rows, key=lambda row: int(float(row["fiscal_year"]))):
    prebuilder_exclusions.append({
        "ticker": "GRBK",
        "cik10": filing["cik10"],
        "fiscal_year": int(float(filing["fiscal_year"])),
        "report_date": filing["report_date"],
        "filing_date": filing["filing_date"],
        "accession_number": filing["accession_number"],
        "primary_document": filing["primary_document"],
        "source_local_path": filing["primary_document_local_path"],
        "source_url": filing["filing_url"],
        "exclusion_reason": "pre_2014_biofuel_energy_predecessor_shell_filing",
    })

for filing in sorted(filing_rows, key=lambda row: int(float(row["fiscal_year"]))):
    fiscal_year = int(float(filing["fiscal_year"]))
    source_path = Path(filing["primary_document_local_path"])

    if not source_path.exists():
        raise RuntimeError(f"Missing Green Brick source file: {source_path}")

    raw_text = source_path.read_text(encoding="utf-8", errors="ignore")
    table_parser = SecTableParser()
    table_parser.feed(raw_text)

    owned_lots = None
    controlled_lots = None
    total_lots = None
    owned_detail_lots = {}
    controlled_detail_lots = {}
    extraction_method = ""
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

        if "total lots owned" not in table_text_lower:
            continue

        if fiscal_year <= 2017 and "lots controlled" in table_text_lower and "total lots owned and controlled" in table_text_lower:
            active_section = ""
            table_owned_lots = None
            table_controlled_lots = None
            table_total_lots = None

            for cells in parsed_rows:
                row_label = cells[0].lower()
                numeric_values = []
                for cell in cells[1:]:
                    if re.fullmatch(r"\d+(?:,\d{3})*", cell):
                        numeric_values.append(float(cell.replace(",", "")))

                if row_label.startswith("lots owned"):
                    active_section = "owned"
                    continue
                if row_label.startswith("lots controlled"):
                    active_section = "controlled"
                    continue
                if row_label.startswith("total lots owned and controlled") and numeric_values:
                    table_total_lots = numeric_values[0]
                    continue
                if len(numeric_values) == 0:
                    continue

                if row_label == "total" and active_section == "owned":
                    table_owned_lots = numeric_values[0]
                    continue
                if row_label == "total" and active_section == "controlled":
                    table_controlled_lots = numeric_values[0]
                    continue
                if row_label != "total" and active_section in ("owned", "controlled"):
                    segment_rows.append({
                        "ticker": "GRBK",
                        "cik10": filing["cik10"],
                        "fiscal_year": fiscal_year,
                        "accession_number": filing["accession_number"],
                        "source_table_index": str(table_index),
                        "segment_label": cells[0],
                        "component_type": active_section,
                        "current_year_lots": numeric_values[0],
                    })

            if table_owned_lots is not None and table_controlled_lots is not None and table_total_lots is not None:
                owned_lots = table_owned_lots
                controlled_lots = table_controlled_lots
                total_lots = table_total_lots
                extraction_method = "section_table_lots_owned_controlled"
                source_table_index = str(table_index)
                source_excerpt = table_text[:1400]
                break

        if fiscal_year in range(2018, 2022) and "total lots controlled" in table_text_lower and "total lots owned and controlled" in table_text_lower:
            table_owned_lots = None
            table_controlled_lots = None
            table_total_lots = None

            for cells in parsed_rows:
                row_label = cells[0].lower()
                numeric_values = []
                for cell in cells[1:]:
                    if re.fullmatch(r"\d+(?:,\d{3})*", cell):
                        numeric_values.append(float(cell.replace(",", "")))

                if len(numeric_values) == 0:
                    continue

                if row_label in ("central", "southeast"):
                    segment_rows.append({
                        "ticker": "GRBK",
                        "cik10": filing["cik10"],
                        "fiscal_year": fiscal_year,
                        "accession_number": filing["accession_number"],
                        "source_table_index": str(table_index),
                        "segment_label": cells[0],
                        "component_type": "segment_row",
                        "current_year_lots": numeric_values[0],
                    })
                if row_label.startswith("total lots owned and controlled"):
                    table_total_lots = numeric_values[0]
                elif row_label.startswith("total lots owned"):
                    table_owned_lots = numeric_values[0]
                elif row_label.startswith("total lots controlled"):
                    table_controlled_lots = numeric_values[0]

            if table_owned_lots is not None and table_controlled_lots is not None and table_total_lots is not None:
                owned_lots = table_owned_lots
                controlled_lots = table_controlled_lots
                total_lots = table_total_lots
                extraction_method = "two_year_total_rows_lots_owned_controlled"
                source_table_index = str(table_index)
                source_excerpt = table_text[:1400]
                break

        if fiscal_year in range(2022, 2025) and "central" in table_text_lower and "southeast" in table_text_lower and "total lots controlled" in table_text_lower:
            table_owned_lots = None
            table_controlled_lots = None
            table_total_lots = None
            active_section = ""

            for cells in parsed_rows:
                row_label = cells[0].lower()
                current_year_values = []
                for cell in cells[1:]:
                    if re.fullmatch(r"\d+(?:,\d{3})*", cell):
                        current_year_values.append(float(cell.replace(",", "")))
                    elif cell in ("—", "-", "--"):
                        current_year_values.append(0.0)

                if row_label.startswith("lots owned"):
                    active_section = "owned"
                    continue
                if row_label.startswith("lots controlled"):
                    active_section = "controlled"
                    continue
                if len(current_year_values) < 3:
                    continue

                if row_label.startswith("total lots owned and controlled"):
                    table_total_lots = current_year_values[2]
                elif row_label.startswith("total lots owned"):
                    table_owned_lots = current_year_values[2]
                elif row_label.startswith("total lots controlled"):
                    table_controlled_lots = current_year_values[2]
                if active_section in ("owned", "controlled") and not row_label.startswith("total"):
                    segment_rows.append({
                        "ticker": "GRBK",
                        "cik10": filing["cik10"],
                        "fiscal_year": fiscal_year,
                        "accession_number": filing["accession_number"],
                        "source_table_index": str(table_index),
                        "segment_label": cells[0],
                        "component_type": active_section,
                        "current_year_lots": current_year_values[2],
                    })
                    if active_section == "owned":
                        owned_detail_lots[cells[0]] = current_year_values[2]
                    if active_section == "controlled":
                        controlled_detail_lots[cells[0]] = current_year_values[2]

            if table_owned_lots is not None and table_controlled_lots is not None and table_total_lots is not None:
                owned_lots = table_owned_lots
                controlled_lots = table_controlled_lots
                total_lots = table_total_lots
                extraction_method = "multi_region_total_column_lots_owned_controlled"
                source_table_index = str(table_index)
                source_excerpt = table_text[:1600]
                break

        if fiscal_year == 2025 and "total lots under contract" in table_text_lower and "total lots owned and under contract" in table_text_lower:
            table_owned_lots = None
            table_controlled_lots = None
            table_total_lots = None
            active_section = ""

            for cells in parsed_rows:
                row_label = cells[0].lower()
                numeric_values = []
                for cell in cells[1:]:
                    if re.fullmatch(r"\d+(?:,\d{3})*", cell):
                        numeric_values.append(float(cell.replace(",", "")))

                if row_label.startswith("lots owned"):
                    active_section = "owned"
                    continue
                if row_label.startswith("lots under contract"):
                    active_section = "controlled"
                    continue
                if len(numeric_values) == 0:
                    continue

                if row_label.startswith("total lots owned and under contract"):
                    table_total_lots = numeric_values[0]
                elif row_label.startswith("total lots owned"):
                    table_owned_lots = numeric_values[0]
                elif row_label.startswith("total lots under contract"):
                    table_controlled_lots = numeric_values[0]
                if active_section in ("owned", "controlled") and not row_label.startswith("total"):
                    segment_rows.append({
                        "ticker": "GRBK",
                        "cik10": filing["cik10"],
                        "fiscal_year": fiscal_year,
                        "accession_number": filing["accession_number"],
                        "source_table_index": str(table_index),
                        "segment_label": cells[0],
                        "component_type": active_section,
                        "current_year_lots": numeric_values[0],
                    })
                    if active_section == "owned":
                        owned_detail_lots[cells[0]] = numeric_values[0]
                    if active_section == "controlled":
                        controlled_detail_lots[cells[0]] = numeric_values[0]

            if table_owned_lots is not None and table_controlled_lots is not None and table_total_lots is not None:
                owned_lots = table_owned_lots
                controlled_lots = table_controlled_lots
                total_lots = table_total_lots
                extraction_method = "single_year_lots_owned_under_contract"
                source_table_index = str(table_index)
                source_excerpt = table_text[:1600]
                break

    component_gap = ""
    if owned_lots is not None and controlled_lots is not None and total_lots is not None:
        component_gap = owned_lots + controlled_lots - total_lots

    controlled_detail_sum = ""
    if len(controlled_detail_lots) > 0:
        controlled_detail_sum = sum(controlled_detail_lots.values())

    owned_detail_sum = ""
    if len(owned_detail_lots) > 0:
        owned_detail_sum = sum(owned_detail_lots.values())

    panel_rows.append({
        "ticker": "GRBK",
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
        "controlled_lots": controlled_lots,
        "total_lots": total_lots,
        "nonowned_controlled_share": (
            controlled_lots / total_lots
            if controlled_lots is not None and total_lots not in (None, 0)
            else None
        ),
        "owned_share": (
            owned_lots / total_lots
            if owned_lots is not None and total_lots not in (None, 0)
            else None
        ),
        "owned_detail_sum": owned_detail_sum,
        "controlled_detail_sum": controlled_detail_sum,
        "component_identity_gap": component_gap,
        "component_identity_pass": (
            abs(component_gap) <= 1
            if isinstance(component_gap, float)
            else False
        ),
        "controlled_detail_sum_pass": (
            abs(controlled_detail_sum - controlled_lots) <= 1
            if isinstance(controlled_detail_sum, float) and controlled_lots is not None
            else ""
        ),
        "owned_detail_sum_pass": (
            abs(owned_detail_sum - owned_lots) <= 1
            if isinstance(owned_detail_sum, float) and owned_lots is not None
            else ""
        ),
        "extraction_method": extraction_method if extraction_method != "" else "not_found",
        "precision": "reported_table" if extraction_method != "" else "",
        "source_table_index": source_table_index,
        "source_row_label": "Total",
        "panel_use_flag": extraction_method != "",
        "manual_review_flag": extraction_method == "",
        "manual_review_reason": "missing_grbk_lot_control_table_total_row" if extraction_method == "" else "",
        "source_note": "Green Brick builder-era table. Firm-year uses explicit company-wide total rows/columns; 2025 includes the updated-definition controlled-lot adjustment because it is included in Total lots under contract.",
    })

    source_notes.append({
        "ticker": "GRBK",
        "fiscal_year": fiscal_year,
        "extraction_method": extraction_method if extraction_method != "" else "not_found",
        "source_excerpt": source_excerpt,
    })

audit_rows = [
    {
        "audit_check": "firm_year_rows",
        "status": "ok" if len(panel_rows) == 12 else "fail",
        "value": len(panel_rows),
        "detail": "Expected Green Brick builder-era fiscal years 2014 through 2025.",
    },
    {
        "audit_check": "prebuilder_exclusions",
        "status": "ok" if len(prebuilder_exclusions) > 0 else "fail",
        "value": len(prebuilder_exclusions),
        "detail": "Pre-2014 BioFuel Energy predecessor/shell filings excluded from builder land panel.",
    },
    {
        "audit_check": "missing_extractions",
        "status": "ok" if sum(row["extraction_method"] == "not_found" for row in panel_rows) == 0 else "fail",
        "value": sum(row["extraction_method"] == "not_found" for row in panel_rows),
        "detail": "Builder-era firm-years without a Green Brick lots-owned/controlled table total row.",
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
        "detail": "Extracted controlled-lot share is between zero and one.",
    },
    {
        "audit_check": "component_identity",
        "status": "ok" if all(row["component_identity_pass"] for row in panel_rows) else "fail",
        "value": sum(row["component_identity_pass"] for row in panel_rows),
        "detail": "Owned lots plus controlled/under-contract lots equals the disclosed total denominator.",
    },
]

write_csv("../output/grbk_2014_2025_land_panel.csv", panel_rows, [
    "ticker", "cik10", "sec_company_name", "fiscal_year", "report_date",
    "filing_date", "accession_number", "primary_document", "source_local_path",
    "source_url", "unit_type", "owned_lots", "nonowned_controlled_lots",
    "controlled_lots", "total_lots", "nonowned_controlled_share",
    "owned_share", "owned_detail_sum", "controlled_detail_sum",
    "component_identity_gap", "component_identity_pass",
    "controlled_detail_sum_pass", "owned_detail_sum_pass",
    "extraction_method", "precision", "source_table_index", "source_row_label",
    "panel_use_flag", "manual_review_flag", "manual_review_reason", "source_note",
])
write_csv("../output/grbk_2014_2025_segment_land_rows.csv", segment_rows, [
    "ticker", "cik10", "fiscal_year", "accession_number", "source_table_index",
    "segment_label", "component_type", "current_year_lots",
])
write_csv("../output/grbk_2014_2025_extraction_audit.csv", audit_rows, [
    "audit_check", "status", "value", "detail",
])
write_csv("../output/grbk_prebuilder_filing_exclusions.csv", prebuilder_exclusions, [
    "ticker", "cik10", "fiscal_year", "report_date", "filing_date",
    "accession_number", "primary_document", "source_local_path", "source_url",
    "exclusion_reason",
])
write_csv("../output/grbk_2014_2025_source_notes.csv", source_notes, [
    "ticker", "fiscal_year", "extraction_method", "source_excerpt",
])

print("Wrote Green Brick land disclosure extraction outputs to ../output")
