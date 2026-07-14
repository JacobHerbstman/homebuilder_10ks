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
        if row.get("ticker") == "LSEA"
        and row.get("form") == "10-K"
        and 2018 <= int(float(row.get("fiscal_year"))) <= 2024
    ]

if len(filing_rows) == 0:
    raise RuntimeError("No Landsea filing rows found in land_light_firm_year_measures.csv.")

filing_by_year = {}
for filing in filing_rows:
    fiscal_year = int(float(filing["fiscal_year"]))
    if fiscal_year in filing_by_year:
        raise RuntimeError("Landsea filing rows must be unique by fiscal year.")
    filing_by_year[fiscal_year] = filing

panel_rows = []
segment_rows = []
source_notes = []

for fiscal_year in range(2020, 2025):
    if fiscal_year == 2020:
        source_fiscal_year = 2021
        target_column_group = 2
    else:
        source_fiscal_year = fiscal_year
        target_column_group = 1

    filing = filing_by_year[source_fiscal_year]
    source_path = Path(filing["primary_document_local_path"])

    if not source_path.exists():
        raise RuntimeError(f"Missing Landsea source file: {source_path}")

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

        if len(parsed_rows) < 3:
            continue

        table_text = clean_text(" || ".join(" | ".join(cells) for cells in parsed_rows))
        table_text_lower = table_text.lower()

        if "lots owned" not in table_text_lower or "lots controlled" not in table_text_lower:
            continue
        if "total" not in table_text_lower or str(fiscal_year) not in table_text:
            continue

        for cells in parsed_rows:
            if len(cells) < 4 or cells[0].lower() == "total" and len(cells) < 7:
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
                "ticker": "LSEA",
                "cik10": filing["cik10"],
                "fiscal_year": fiscal_year,
                "source_fiscal_year": source_fiscal_year,
                "accession_number": filing["accession_number"],
                "source_table_index": table_index,
                "segment_label": row_label,
                "row_type": "total" if row_label.lower() == "total" else "region",
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
                    "prior_year_column_from_2021_owned_controlled_table"
                    if fiscal_year == 2020
                    else "current_year_column_from_owned_controlled_table"
                )

        if extraction_method != "":
            break

    current_2020_total_lots = None
    current_2020_total_lots_table = None
    current_2020_owned_lots_approx = None
    current_2020_controlled_lots_approx = None

    if fiscal_year == 2020:
        current_filing = filing_by_year[2020]
        current_html = Path(current_filing["primary_document_local_path"]).read_text(encoding="utf-8", errors="ignore")
        current_table_parser = SecTableParser()
        current_table_parser.feed(current_html)

        for table in current_table_parser.tables:
            parsed_rows = []
            for html_row in table["rows"]:
                cells = [clean_text(cell.get("text", "")) for cell in html_row]
                cells = [cell for cell in cells if cell]
                if cells:
                    parsed_rows.append(cells)

            current_table_text = clean_text(" || ".join(" | ".join(cells) for cells in parsed_rows))
            if "Lots Owned or Controlled" not in current_table_text:
                continue

            for cells in parsed_rows:
                if cells[0].lower() != "grand totals":
                    continue

                numeric_values = []
                for cell in cells[1:]:
                    if re.fullmatch(r"\d+(?:,\d{3})*", cell):
                        numeric_values.append(float(cell.replace(",", "")))

                if len(numeric_values) >= 2:
                    current_2020_total_lots_table = numeric_values[1]
                    break

            if current_2020_total_lots_table is not None:
                break

        visible_parser = VisibleTextParser()
        visible_parser.feed(current_html)
        visible_text = clean_text(visible_parser.text())

        total_match = re.search(r"owned or controlled almost ([0-9,]+) lots", visible_text, re.IGNORECASE)
        controlled_match = re.search(
            r"more than ([0-9,]+) lots were under land option contracts or purchase contracts",
            visible_text,
            re.IGNORECASE,
        )
        owned_match = re.search(r"more than ([0-9,]+) lots were owned", visible_text, re.IGNORECASE)

        if total_match is not None:
            current_2020_total_lots = float(total_match.group(1).replace(",", ""))
        if controlled_match is not None:
            current_2020_controlled_lots_approx = float(controlled_match.group(1).replace(",", ""))
        if owned_match is not None:
            current_2020_owned_lots_approx = float(owned_match.group(1).replace(",", ""))

    component_gap = ""
    if owned_lots is not None and controlled_lots is not None and total_lots is not None:
        component_gap = owned_lots + controlled_lots - total_lots

    source_note = "Landsea recurring table row: Lots Controlled is coded as nonowned controlled lots; do not confuse it with broader prose phrases such as lots under control."
    if fiscal_year == 2020:
        source_note = source_note + " Fiscal 2020 uses the exact December 31, 2020 prior-year row from the 2021 10-K; the 2020 10-K has only total lots and approximate prose split."

    panel_rows.append({
        "ticker": "LSEA",
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
        "source_fiscal_year": source_fiscal_year,
        "source_table_index": source_table_index,
        "source_row_label": "Total",
        "source_total_row_used": extraction_method != "",
        "controlled_definition_raw": "Lots Controlled",
        "controlled_treated_as_nonowned_controlled": True,
        "controlled_not_labeled_pure_optioned": True,
        "optioned_lots_exact_unavailable": True,
        "owned_plus_controlled_equals_total": (
            abs(component_gap) <= 1
            if isinstance(component_gap, float)
            else False
        ),
        "region_rows_retained_as_provenance": True,
        "current_2020_total_lots_approx": current_2020_total_lots,
        "current_2020_total_lots_table": current_2020_total_lots_table,
        "current_2020_owned_lots_approx": current_2020_owned_lots_approx,
        "current_2020_controlled_lots_approx": current_2020_controlled_lots_approx,
        "uses_later_comparative_prior_year_row": fiscal_year == 2020,
        "current_year_total_cross_checked_to_original_2020_10k": (
            fiscal_year == 2020
            and current_2020_total_lots_table == total_lots
        ),
        "panel_use_flag": extraction_method != "",
        "manual_review_flag": extraction_method == "",
        "manual_review_reason": (
            "missing_owned_controlled_total_row" if extraction_method == "" else ""
        ),
        "source_note": source_note,
    })

    source_notes.append({
        "ticker": "LSEA",
        "fiscal_year": fiscal_year,
        "source_fiscal_year": source_fiscal_year,
        "extraction_method": extraction_method if extraction_method != "" else "not_found",
        "source_excerpt": source_excerpt,
    })

prebuilder_rows = []
for fiscal_year in (2018, 2019):
    if fiscal_year in filing_by_year:
        prebuilder_rows.append({
            "ticker": "LSEA",
            "fiscal_year": fiscal_year,
            "accession_number": filing_by_year[fiscal_year]["accession_number"],
            "source_url": filing_by_year[fiscal_year]["filing_url"],
            "source_local_path": filing_by_year[fiscal_year]["primary_document_local_path"],
            "exclusion_reason": "LF Capital Acquisition Corp. SPAC filing before Landsea operating-builder business combination; no operating homebuilder land disclosure.",
        })

audit_rows = [
    {
        "audit_check": "firm_year_rows",
        "status": "ok" if len(panel_rows) == 5 else "fail",
        "value": len(panel_rows),
        "detail": "Expected Landsea operating-builder fiscal years 2020 through 2024.",
    },
    {
        "audit_check": "prebuilder_exclusion_rows",
        "status": "ok" if len(prebuilder_rows) == 2 else "fail",
        "value": len(prebuilder_rows),
        "detail": "Expected LF Capital SPAC exclusions for 2018 and 2019.",
    },
    {
        "audit_check": "missing_extractions",
        "status": "ok" if sum(row["extraction_method"] == "not_found" for row in panel_rows) == 0 else "fail",
        "value": sum(row["extraction_method"] == "not_found" for row in panel_rows),
        "detail": "Every operating-builder Landsea row should have owned, controlled, and total lot counts.",
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
        "audit_check": "uses_2020_later_comparative_row_once",
        "status": "ok" if sum(row["uses_later_comparative_prior_year_row"] for row in panel_rows) == 1 else "fail",
        "value": sum(row["uses_later_comparative_prior_year_row"] for row in panel_rows),
        "detail": "Only fiscal 2020 should use the 2021 comparative prior-year row.",
    },
    {
        "audit_check": "current_2020_table_total_matches_selected",
        "status": "ok" if all(
            row["fiscal_year"] != 2020 or row["current_2020_total_lots_table"] == row["total_lots"]
            for row in panel_rows
        ) else "fail",
        "value": next(
            row["current_2020_total_lots_table"]
            for row in panel_rows
            if row["fiscal_year"] == 2020
        ),
        "detail": "The current 2020 10-K exact Lots Owned or Controlled table total should match the selected 2020 total from the 2021 comparative row.",
    },
]

write_csv(
    "../output/lsea_2020_2024_land_panel.csv",
    panel_rows,
    [
        "ticker", "cik10", "sec_company_name", "fiscal_year", "report_date", "filing_date",
        "accession_number", "source_accession_number", "primary_document", "source_local_path",
        "source_url", "unit_type", "owned_lots", "nonowned_controlled_lots", "controlled_lots",
        "total_lots", "nonowned_controlled_share", "owned_share", "component_identity_gap",
        "component_identity_pass", "extraction_method", "precision", "source_fiscal_year",
        "source_table_index", "source_row_label", "source_total_row_used", "controlled_definition_raw",
        "controlled_treated_as_nonowned_controlled", "controlled_not_labeled_pure_optioned",
        "optioned_lots_exact_unavailable", "owned_plus_controlled_equals_total",
        "region_rows_retained_as_provenance",
        "current_2020_total_lots_approx", "current_2020_total_lots_table",
        "current_2020_owned_lots_approx",
        "current_2020_controlled_lots_approx", "uses_later_comparative_prior_year_row",
        "current_year_total_cross_checked_to_original_2020_10k",
        "panel_use_flag", "manual_review_flag", "manual_review_reason", "source_note",
    ],
)

write_csv(
    "../output/lsea_2020_2024_segment_land_rows.csv",
    segment_rows,
    [
        "ticker", "cik10", "fiscal_year", "source_fiscal_year", "accession_number",
        "source_table_index", "segment_label", "row_type", "owned_lots",
        "controlled_lots", "total_lots", "component_identity_gap",
    ],
)

write_csv(
    "../output/lsea_2018_2019_prebuilder_filing_exclusions.csv",
    prebuilder_rows,
    [
        "ticker", "fiscal_year", "accession_number", "source_url",
        "source_local_path", "exclusion_reason",
    ],
)

write_csv(
    "../output/lsea_2020_2024_extraction_audit.csv",
    audit_rows,
    ["audit_check", "status", "value", "detail"],
)

write_csv(
    "../output/lsea_2020_2024_source_notes.csv",
    source_notes,
    ["ticker", "fiscal_year", "source_fiscal_year", "extraction_method", "source_excerpt"],
)
