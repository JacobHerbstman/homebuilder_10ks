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
        if row.get("ticker") == "TPH"
        and row.get("form") == "10-K"
        and 2012 <= int(float(row.get("fiscal_year"))) <= 2025
    ]

if len(filing_rows) == 0:
    raise RuntimeError("No Tri Pointe filing rows found in land_light_firm_year_measures.csv.")

panel_rows = []
segment_rows = []
source_notes = []

for filing in sorted(filing_rows, key=lambda row: int(float(row["fiscal_year"]))):
    fiscal_year = int(float(filing["fiscal_year"]))
    source_path = Path(filing["primary_document_local_path"])

    if not source_path.exists():
        raise RuntimeError(f"Missing Tri Pointe source file: {source_path}")

    raw_text = source_path.read_text(encoding="utf-8", errors="ignore")
    table_parser = SecTableParser()
    table_parser.feed(raw_text)

    owned_lots = None
    controlled_lots = None
    total_lots = None
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

        if not parsed_rows:
            continue

        header = " | ".join(parsed_rows[0]).lower()
        if "lots owned" not in header or "lots controlled" not in header:
            continue
        if "lots owned or controlled" not in header and "lots owned and controlled" not in header:
            continue

        table_text = clean_text(" || ".join(" | ".join(cells) for cells in parsed_rows))

        for cells in parsed_rows[1:]:
            if len(cells) < 4:
                continue

            numeric_values = []
            for cell in cells[1:]:
                if re.fullmatch(r"\d+(?:,\d{3})*", cell):
                    numeric_values.append(float(cell.replace(",", "")))
                elif cell in ("—", "-", "--"):
                    numeric_values.append(0.0)

            if len(numeric_values) < 3:
                continue

            row_owned_lots = numeric_values[0]
            row_controlled_lots = numeric_values[1]
            row_total_lots = numeric_values[2]
            row_label = cells[0]

            segment_rows.append({
                "ticker": "TPH",
                "cik10": filing["cik10"],
                "fiscal_year": fiscal_year,
                "accession_number": filing["accession_number"],
                "source_table_index": table_index,
                "segment_label": row_label,
                "row_type": "total" if row_label.lower() == "total" else "region_or_brand",
                "owned_lots": row_owned_lots,
                "controlled_lots": row_controlled_lots,
                "total_lots": row_total_lots,
                "component_identity_gap": row_owned_lots + row_controlled_lots - row_total_lots,
            })

            if row_label.lower() == "total":
                owned_lots = row_owned_lots
                controlled_lots = row_controlled_lots
                total_lots = row_total_lots
                extraction_method = "compact_owned_controlled_total_row"
                source_table_index = str(table_index)
                source_excerpt = table_text[:1400]

        if extraction_method != "":
            break

    if extraction_method == "":
        for table_index, table in enumerate(table_parser.tables):
            parsed_rows = []
            for html_row in table["rows"]:
                cells = [clean_text(cell.get("text", "")) for cell in html_row]
                cells = [cell for cell in cells if cell]
                if cells:
                    parsed_rows.append(cells)

            table_text = clean_text(" || ".join(" | ".join(cells) for cells in parsed_rows))
            table_text_lower = table_text.lower()

            if "lots owned" not in table_text_lower or "lots controlled" not in table_text_lower:
                continue
            if "total lots owned or controlled" not in table_text_lower:
                continue
            if str(fiscal_year) not in table_text or str(fiscal_year - 1) not in table_text:
                continue

            comparison_segments = {}
            table_section = ""

            for cells in parsed_rows:
                row_label = cells[0]
                row_label_lower = row_label.lower()

                if row_label_lower.startswith("lots owned"):
                    table_section = "owned"
                    continue

                if row_label_lower.startswith("lots controlled"):
                    table_section = "controlled"
                    continue

                numeric_values = []
                for cell in cells[1:]:
                    if re.fullmatch(r"\d+(?:,\d{3})*", cell):
                        numeric_values.append(float(cell.replace(",", "")))
                    elif cell in ("—", "-", "--"):
                        numeric_values.append(0.0)

                if row_label_lower.startswith("total lots owned or controlled") and numeric_values:
                    total_lots = numeric_values[0]
                    continue

                if table_section not in ("owned", "controlled") or not numeric_values:
                    continue

                if row_label not in comparison_segments:
                    comparison_segments[row_label] = {"owned": None, "controlled": None}

                comparison_segments[row_label][table_section] = numeric_values[0]

                if row_label_lower == "total" and table_section == "owned":
                    owned_lots = numeric_values[0]

                if row_label_lower == "total" and table_section == "controlled":
                    controlled_lots = numeric_values[0]

            for segment_label, segment_values in comparison_segments.items():
                if segment_values["owned"] is None or segment_values["controlled"] is None:
                    continue

                segment_total_lots = None
                if segment_label.lower() == "total":
                    segment_total_lots = total_lots

                segment_rows.append({
                    "ticker": "TPH",
                    "cik10": filing["cik10"],
                    "fiscal_year": fiscal_year,
                    "accession_number": filing["accession_number"],
                    "source_table_index": table_index,
                    "segment_label": segment_label,
                    "row_type": "total" if segment_label.lower() == "total" else "region_or_brand",
                    "owned_lots": segment_values["owned"],
                    "controlled_lots": segment_values["controlled"],
                    "total_lots": segment_total_lots,
                    "component_identity_gap": (
                        segment_values["owned"] + segment_values["controlled"] - segment_total_lots
                        if segment_total_lots is not None
                        else ""
                    ),
                })

            if owned_lots is not None and controlled_lots is not None and total_lots is not None:
                extraction_method = "current_year_column_from_yoy_land_table"
                source_table_index = str(table_index)
                source_excerpt = table_text[:1400]
                break

    component_gap = ""
    if owned_lots is not None and controlled_lots is not None and total_lots is not None:
        component_gap = owned_lots + controlled_lots - total_lots

    source_note = "Tri Pointe recurring company-wide Total row: Lots Owned plus Lots Controlled equals Lots Owned or Controlled. Controlled lots are coded as nonowned controlled lots, not pure optioned lots."
    if fiscal_year == 2012:
        source_note = source_note + " 2012 controlled lots include land option contracts, purchase contracts, and non-binding letters of intent."
    if fiscal_year == 2019:
        source_note = source_note + " 2019 controlled lots include 135 Trendmaker expected-share lots from an unconsolidated land development joint venture."

    panel_rows.append({
        "ticker": "TPH",
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
        "source_total_row_used": extraction_method != "",
        "source_table_type": (
            "yoy_land_table_current_year_column"
            if extraction_method == "current_year_column_from_yoy_land_table"
            else "compact_owned_controlled_total_table" if extraction_method != "" else ""
        ),
        "controlled_definition_raw": "Lots Controlled",
        "broad_loi_definition_flag": fiscal_year == 2012,
        "jv_expected_share_flag": fiscal_year == 2019,
        "large_portfolio_scope_change_flag": fiscal_year == 2014,
        "segment_schema_change_flag": fiscal_year == 2021,
        "panel_use_flag": extraction_method != "",
        "manual_review_flag": extraction_method == "",
        "manual_review_reason": "missing_owned_controlled_total_row" if extraction_method == "" else "",
        "source_note": source_note,
    })

    source_notes.append({
        "ticker": "TPH",
        "fiscal_year": fiscal_year,
        "extraction_method": extraction_method if extraction_method != "" else "not_found",
        "source_excerpt": source_excerpt,
    })

audit_rows = [
    {
        "audit_check": "firm_year_rows",
        "status": "ok" if len(panel_rows) == 14 else "fail",
        "value": len(panel_rows),
        "detail": "Expected Tri Pointe fiscal years 2012 through 2025 from current filing inventory.",
    },
    {
        "audit_check": "missing_extractions",
        "status": "ok" if sum(row["extraction_method"] == "not_found" for row in panel_rows) == 0 else "fail",
        "value": sum(row["extraction_method"] == "not_found" for row in panel_rows),
        "detail": "Every Tri Pointe filing should expose owned, controlled, and total lot counts.",
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
        "detail": "Nonowned controlled share must be between zero and one.",
    },
    {
        "audit_check": "component_identity",
        "status": "ok" if all(row["component_identity_pass"] for row in panel_rows) else "fail",
        "value": sum(row["component_identity_pass"] for row in panel_rows),
        "detail": "Owned lots plus controlled lots must equal total lots.",
    },
    {
        "audit_check": "broad_loi_definition_flag",
        "status": "ok" if sum(row["broad_loi_definition_flag"] for row in panel_rows) == 1 else "fail",
        "value": sum(row["broad_loi_definition_flag"] for row in panel_rows),
        "detail": "Only 2012 should carry the non-binding LOI caveat.",
    },
    {
        "audit_check": "jv_expected_share_flag",
        "status": "ok" if sum(row["jv_expected_share_flag"] for row in panel_rows) == 1 else "fail",
        "value": sum(row["jv_expected_share_flag"] for row in panel_rows),
        "detail": "Only 2019 should carry the 135-lot unconsolidated JV expected-share caveat.",
    },
    {
        "audit_check": "large_portfolio_scope_change_flag",
        "status": "ok" if sum(row["large_portfolio_scope_change_flag"] for row in panel_rows) == 1 else "fail",
        "value": sum(row["large_portfolio_scope_change_flag"] for row in panel_rows),
        "detail": "Only 2014 should carry the large portfolio/scope change caveat.",
    },
    {
        "audit_check": "segment_schema_change_flag",
        "status": "ok" if sum(row["segment_schema_change_flag"] for row in panel_rows) == 1 else "fail",
        "value": sum(row["segment_schema_change_flag"] for row in panel_rows),
        "detail": "Only 2021 should carry the segment-schema change caveat.",
    },
]

write_csv(
    "../output/tph_2012_2025_land_panel.csv",
    panel_rows,
    [
        "ticker", "cik10", "sec_company_name", "fiscal_year", "report_date", "filing_date",
        "accession_number", "primary_document", "source_local_path", "source_url", "unit_type",
        "owned_lots", "nonowned_controlled_lots", "controlled_lots", "total_lots",
        "nonowned_controlled_share", "owned_share", "component_identity_gap",
        "component_identity_pass", "extraction_method", "precision", "source_table_index",
        "source_row_label", "source_total_row_used", "source_table_type",
        "controlled_definition_raw", "broad_loi_definition_flag",
        "jv_expected_share_flag", "large_portfolio_scope_change_flag",
        "segment_schema_change_flag", "panel_use_flag", "manual_review_flag",
        "manual_review_reason", "source_note",
    ],
)

write_csv(
    "../output/tph_2012_2025_segment_land_rows.csv",
    segment_rows,
    [
        "ticker", "cik10", "fiscal_year", "accession_number", "source_table_index",
        "segment_label", "row_type", "owned_lots", "controlled_lots", "total_lots",
        "component_identity_gap",
    ],
)

write_csv(
    "../output/tph_2012_2025_extraction_audit.csv",
    audit_rows,
    ["audit_check", "status", "value", "detail"],
)

write_csv(
    "../output/tph_2012_2025_source_notes.csv",
    source_notes,
    ["ticker", "fiscal_year", "extraction_method", "source_excerpt"],
)
