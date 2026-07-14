#!/usr/bin/env python3

import csv
import re
import sys
from pathlib import Path

sys.path.append(str(Path(__file__).resolve().parents[2] / "_lib"))
from sec_fetch_utils import write_csv

sys.path.append(str(Path(__file__).resolve().parents[1].parent / "extract_10k_land_candidates" / "code"))
from extract_10k_land_candidates import SecTableParser, VisibleTextParser, clean_text


def number_from_text(x):
    return float(x.replace(",", ""))


with open("../input/land_light_firm_year_measures.csv", newline="") as f:
    filing_rows = [
        row for row in csv.DictReader(f)
        if row.get("ticker") == "TOL" and 2004 <= int(float(row.get("fiscal_year"))) <= 2025
    ]

if len(filing_rows) == 0:
    raise RuntimeError("No Toll Brothers filing rows found in land_light_firm_year_measures.csv.")

panel_rows = []
source_notes = []

for filing in sorted(filing_rows, key=lambda row: int(float(row["fiscal_year"]))):
    fiscal_year = int(float(filing["fiscal_year"]))
    source_path = Path(filing["primary_document_local_path"])

    if not source_path.exists():
        raise RuntimeError(f"Missing Toll Brothers source file: {source_path}")

    raw_text = source_path.read_text(encoding="utf-8", errors="ignore")

    visible_parser = VisibleTextParser()
    visible_parser.feed(raw_text)
    visible_text = clean_text(visible_parser.text())

    table_parser = SecTableParser()
    table_parser.feed(raw_text)

    owned_homesites = None
    controlled_homesites = None
    total_homesites = None
    source_table_index = ""
    source_row_label = ""
    extraction_method = ""
    precision = ""
    source_excerpt = ""
    future_total_homesites = None
    future_owned_homesites = None
    future_controlled_homesites = None

    for table_index, table in enumerate(table_parser.tables):
        parsed_rows = []
        for html_row in table["rows"]:
            cells = [clean_text(cell.get("text", "")) for cell in html_row]
            cells = [cell for cell in cells if cell]
            if cells:
                parsed_rows.append(cells)

        table_text = clean_text(" || ".join(" | ".join(cells) for cells in parsed_rows))
        table_text_lower = table_text.lower()

        if "home sites" not in table_text_lower or "owned" not in table_text_lower or "controlled" not in table_text_lower:
            continue

        table_owned = None
        table_controlled = None
        table_total = None

        for cells in parsed_rows:
            numeric_values = []
            for cell in cells[1:]:
                numeric_values.extend([
                    number_from_text(x)
                    for x in re.findall(r"(?<![A-Za-z])\d{1,3}(?:,\d{3})+(?![A-Za-z])|(?<![A-Za-z])\d{4,}(?![A-Za-z])", cell)
                ])

            if cells[0].lower() == "owned" and numeric_values:
                table_owned = numeric_values[0]
            if cells[0].lower() == "controlled" and numeric_values:
                table_controlled = numeric_values[0]
            if cells[0].lower() == "total" and numeric_values:
                table_total = numeric_values[0]

        if table_owned is not None and table_controlled is not None:
            owned_homesites = table_owned
            controlled_homesites = table_controlled
            total_homesites = table_total if table_total is not None else table_owned + table_controlled
            source_table_index = str(table_index)
            source_row_label = "Home sites: Owned; Controlled; Total"
            extraction_method = "housing_data_table"
            precision = "reported_table"
            source_excerpt = table_text[:1200]
            break

    direct_patterns = [
        re.compile(
            rf"Of the approximately ([0-9,]+) total home sites (?:that )?we owned or controlled through options at October\s*31,\s*{fiscal_year}, we owned approximately ([0-9,]+) and controlled approximately ([0-9,]+) through options",
            re.IGNORECASE,
        ),
        re.compile(
            rf"Of the approximately ([0-9,]+) total home sites (?:that )?we owned or controlled through options at October\s*31,\s*{fiscal_year}, we owned approximately ([0-9,]+) and controlled approximately ([0-9,]+) through land purchase agreements",
            re.IGNORECASE,
        ),
    ]

    for pattern in direct_patterns:
        match = pattern.search(visible_text)
        if match is not None and extraction_method == "":
            total_homesites = number_from_text(match.group(1))
            owned_homesites = number_from_text(match.group(2))
            controlled_homesites = number_from_text(match.group(3))
            extraction_method = "companywide_prose_direct"
            precision = "rounded_prose"
            source_excerpt = visible_text[max(0, match.start() - 450):min(len(visible_text), match.end() + 650)]

    residual_pattern = re.compile(
        rf"Of the approximately ([0-9,]+) total home sites (?:that )?we owned or controlled through options at October\s*31,\s*{fiscal_year}, we owned approximately ([0-9,]+)",
        re.IGNORECASE,
    )
    residual_match = residual_pattern.search(visible_text)

    if residual_match is not None and extraction_method == "":
        total_homesites = number_from_text(residual_match.group(1))
        owned_homesites = number_from_text(residual_match.group(2))
        controlled_homesites = total_homesites - owned_homesites
        extraction_method = "companywide_prose_residual"
        precision = "rounded_residual"
        source_excerpt = visible_text[max(0, residual_match.start() - 450):min(len(visible_text), residual_match.end() + 650)]

    future_pattern = re.compile(
        rf"Of the ([0-9,]+) planned home sites, at October\s*31,\s*{fiscal_year}, we owned ([0-9,]+) and controlled through options and purchase agreements ([0-9,]+)",
        re.IGNORECASE,
    )
    future_match = future_pattern.search(visible_text)

    if future_match is not None:
        future_total_homesites = number_from_text(future_match.group(1))
        future_owned_homesites = number_from_text(future_match.group(2))
        future_controlled_homesites = number_from_text(future_match.group(3))

    if owned_homesites is None or controlled_homesites is None or total_homesites is None:
        extraction_method = "not_found"
        precision = ""
        source_excerpt = ""

    component_gap = ""
    if owned_homesites is not None and controlled_homesites is not None and total_homesites is not None:
        component_gap = owned_homesites + controlled_homesites - total_homesites

    panel_rows.append({
        "ticker": "TOL",
        "cik10": filing["cik10"],
        "sec_company_name": filing["sec_company_name"],
        "fiscal_year": fiscal_year,
        "report_date": filing["report_date"],
        "filing_date": filing["filing_date"],
        "accession_number": filing["accession_number"],
        "primary_document": filing["primary_document"],
        "source_local_path": filing["primary_document_local_path"],
        "source_url": filing["filing_url"],
        "unit_type": "homesites",
        "owned_homesites": owned_homesites,
        "nonowned_controlled_homesites": controlled_homesites,
        "total_homesites": total_homesites,
        "nonowned_controlled_share": (
            controlled_homesites / total_homesites
            if controlled_homesites is not None and total_homesites not in (None, 0)
            else None
        ),
        "owned_share": (
            owned_homesites / total_homesites
            if owned_homesites is not None and total_homesites not in (None, 0)
            else None
        ),
        "component_identity_gap": component_gap,
        "component_identity_pass": (
            abs(component_gap) <= max(5, 0.005 * total_homesites)
            if isinstance(component_gap, float) and total_homesites is not None
            else False
        ),
        "future_total_homesites_check": future_total_homesites,
        "future_owned_homesites_check": future_owned_homesites,
        "future_controlled_homesites_check": future_controlled_homesites,
        "extraction_method": extraction_method,
        "precision": precision,
        "source_table_index": source_table_index,
        "source_row_label": source_row_label,
        "panel_use_flag": extraction_method != "not_found",
        "manual_review_flag": extraction_method in ("not_found", "companywide_prose_residual"),
        "manual_review_reason": (
            "controlled_count_constructed_as_total_minus_owned"
            if extraction_method == "companywide_prose_residual"
            else ("missing_companywide_home_site_values" if extraction_method == "not_found" else "")
        ),
        "source_note": "Toll reports home sites owned or controlled through options. Future-community-only counts are preserved as checks and not used as the company-wide numerator.",
    })

    source_notes.append({
        "ticker": "TOL",
        "fiscal_year": fiscal_year,
        "extraction_method": extraction_method,
        "precision": precision,
        "source_excerpt": source_excerpt,
    })

audit_rows = []
audit_rows.append({
    "audit_check": "firm_year_rows",
    "status": "ok" if len(panel_rows) == 22 else "fail",
    "value": len(panel_rows),
    "detail": "Expected Toll Brothers fiscal years 2004 through 2025 from current filing inventory.",
})
audit_rows.append({
    "audit_check": "missing_extractions",
    "status": "ok" if sum(row["extraction_method"] == "not_found" for row in panel_rows) == 0 else "fail",
    "value": sum(row["extraction_method"] == "not_found" for row in panel_rows),
    "detail": "Firm-years without company-wide home-site extraction.",
})
audit_rows.append({
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
})
audit_rows.append({
    "audit_check": "residual_rows",
    "status": "ok",
    "value": sum(row["extraction_method"] == "companywide_prose_residual" for row in panel_rows),
    "detail": "Rows where nonowned controlled homesites are total minus owned because company-wide controlled count is not direct.",
})

write_csv("../output/tol_2004_2025_land_panel.csv", panel_rows, [
    "ticker", "cik10", "sec_company_name", "fiscal_year", "report_date",
    "filing_date", "accession_number", "primary_document", "source_local_path",
    "source_url", "unit_type", "owned_homesites", "nonowned_controlled_homesites",
    "total_homesites", "nonowned_controlled_share", "owned_share",
    "component_identity_gap", "component_identity_pass", "future_total_homesites_check",
    "future_owned_homesites_check", "future_controlled_homesites_check",
    "extraction_method", "precision", "source_table_index", "source_row_label",
    "panel_use_flag", "manual_review_flag", "manual_review_reason", "source_note",
])
write_csv("../output/tol_2004_2025_extraction_audit.csv", audit_rows, [
    "audit_check", "status", "value", "detail",
])
write_csv("../output/tol_2004_2025_source_notes.csv", source_notes, [
    "ticker", "fiscal_year", "extraction_method", "precision", "source_excerpt",
])

print("Wrote Toll Brothers land disclosure extraction outputs to ../output")
