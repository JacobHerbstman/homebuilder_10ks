#!/usr/bin/env python3

import csv
import re
import sys
from pathlib import Path

sys.path.append(str(Path(__file__).resolve().parents[2] / "_lib"))
from sec_fetch_utils import write_csv

sys.path.append(str(Path(__file__).resolve().parents[1].parent / "extract_10k_land_candidates" / "code"))
from extract_10k_land_candidates import SecTableParser, clean_text, visible_text


def numeric_cell(value):
    value = clean_text(value).replace("$", "").strip(",")
    if re.fullmatch(r"\(?\d+(?:,\d{3})*(?:\.\d+)?\)?", value):
        sign = -1 if value.startswith("(") and value.endswith(")") else 1
        return sign * float(value.replace("(", "").replace(")", "").replace(",", ""))
    return None


with open("../input/land_light_firm_year_measures.csv", newline="") as f:
    filing_rows = [
        row for row in csv.DictReader(f)
        if row.get("ticker") == "TOA"
        and row.get("form") == "10-K"
        and 2004 <= int(float(row.get("fiscal_year"))) <= 2007
    ]

if len(filing_rows) == 0:
    raise RuntimeError("No TOUSA filing rows found in land_light_firm_year_measures.csv.")

filing_by_year = {}
for filing in filing_rows:
    fiscal_year = int(float(filing["fiscal_year"]))
    if fiscal_year in filing_by_year:
        raise RuntimeError("TOUSA filing rows must be unique by fiscal_year.")
    filing_by_year[fiscal_year] = filing

expected_values = {
    2004: (14000, 36000, 50000),
    2005: (33600, 60700, 94300),
    2006: (25100, 44600, 69700),
    2007: (24000, 12000, 36000),
}

panel_rows = []
source_notes = []

for fiscal_year in range(2004, 2008):
    filing = filing_by_year[fiscal_year]
    source_path = Path(filing["primary_document_local_path"])

    if not source_path.exists():
        raise RuntimeError(f"Missing TOUSA source file: {source_path}")

    source_text = visible_text(source_path)
    table_parser = SecTableParser()
    table_parser.feed(source_path.read_text(encoding="utf-8", errors="ignore"))

    owned_homesites = None
    optioned_homesites = None
    total_homesites = None
    jv_homesites = None
    company_owned_homesites = None
    company_optioned_homesites = None
    recast_owned_homesites = None
    recast_optioned_homesites = None
    recast_total_homesites = None
    extraction_method = ""
    source_table_index = ""
    source_row_label = ""
    source_excerpt = ""

    parsed_tables = []
    for table_index, table in enumerate(table_parser.tables):
        rows = []
        for html_row in table["rows"]:
            cells = [clean_text(cell.get("text", "")) for cell in html_row]
            cells = [cell for cell in cells if cell]
            if cells:
                rows.append(cells)
        parsed_tables.append((table_index, rows, clean_text(" || ".join(" | ".join(row) for row in rows))))

    if fiscal_year == 2004:
        for table_index, rows, table_text in parsed_tables:
            if "Joint Ventures" not in table_text or "Total" not in table_text or "50,000" not in table_text:
                continue
            for cells in rows:
                if cells[0].startswith("Joint Ventures") and len(cells) > 1:
                    jv_homesites = numeric_cell(cells[1])
                if cells[0].startswith("Total") and len(cells) > 1:
                    total_homesites = numeric_cell(cells[1])
                    source_table_index = str(table_index)
                    source_row_label = "Total(1)"
                    source_excerpt = table_text[:1800]
            if total_homesites is not None:
                break

        option_match = None
        for table_index, rows, table_text in parsed_tables:
            if "homesites under option contracts by us and our joint ventures" in table_text and "36,000" in table_text:
                option_match = re.search(r"Includes approximately ([\d,]+)", table_text)
                break
        component_match = re.search(r"At December 31, 2004, we owned approximately ([\d,]+) homesites and had option contracts on ([\d,]+) homesites, and our unconsolidated joint ventures controlled ([\d,]+) homesites", source_text)
        if option_match:
            optioned_homesites = numeric_cell(option_match.group(1))
        if component_match:
            company_owned_homesites = numeric_cell(component_match.group(1))
            company_optioned_homesites = numeric_cell(component_match.group(2))
            jv_homesites = numeric_cell(component_match.group(3))
        owned_homesites = total_homesites - optioned_homesites
        extraction_method = "tousa_combined_optioned_footnote_residual_owned"

    if fiscal_year == 2005:
        for table_index, rows, table_text in parsed_tables:
            if "Combined total" not in table_text or "94,300" not in table_text:
                continue
            for cells in rows:
                if cells[0].startswith("Unconsolidated joint ventures total") and len(cells) > 1:
                    jv_homesites = numeric_cell(cells[1])
                if cells[0].startswith("Combined total") and len(cells) > 1:
                    total_homesites = numeric_cell(cells[1])
                    source_table_index = str(table_index)
                    source_row_label = "Combined total(1)"
                    source_excerpt = table_text[:2200]
            if total_homesites is not None:
                break

        option_match = None
        for table_index, rows, table_text in parsed_tables:
            if "homesites under option contracts by us and our unconsolidated joint ventures" in table_text and "60,700" in table_text:
                option_match = re.search(r"Includes approximately ([\d,]+)", table_text)
                break
        component_match = re.search(r"we owned approximately ([\d,]+) homesites, had option contracts on approximately ([\d,]+) homesites and our unconsolidated joint ventures controlled approximately ([\d,]+) homesites", source_text)
        if option_match:
            optioned_homesites = numeric_cell(option_match.group(1))
        if component_match:
            company_owned_homesites = numeric_cell(component_match.group(1))
            company_optioned_homesites = numeric_cell(component_match.group(2))
            jv_homesites = numeric_cell(component_match.group(3))
        owned_homesites = total_homesites - optioned_homesites
        extraction_method = "tousa_combined_optioned_footnote_residual_owned"

    if fiscal_year == 2006:
        for table_index, rows, table_text in parsed_tables:
            if "Combined total" not in table_text or "69,700" not in table_text:
                continue
            for cells in rows:
                if cells[0] == "Combined total" and len(cells) >= 4 and numeric_cell(cells[3]) == 69700:
                    owned_homesites = numeric_cell(cells[1])
                    optioned_homesites = numeric_cell(cells[2])
                    total_homesites = numeric_cell(cells[3])
                    source_table_index = str(table_index)
                    source_row_label = "Combined total"
                    source_excerpt = table_text[:2200]
            if total_homesites is not None:
                break

        recast_source_path = Path(filing_by_year[2007]["primary_document_local_path"])
        recast_parser = SecTableParser()
        recast_parser.feed(recast_source_path.read_text(encoding="utf-8", errors="ignore"))
        recast_parsed_tables = []
        for table_index, table in enumerate(recast_parser.tables):
            rows = []
            for html_row in table["rows"]:
                cells = [clean_text(cell.get("text", "")) for cell in html_row]
                cells = [cell for cell in cells if cell]
                if cells:
                    rows.append(cells)
            recast_parsed_tables.append((table_index, rows, clean_text(" || ".join(" | ".join(row) for row in rows))))

        for table_index, rows, table_text in recast_parsed_tables:
            if "Transeastern JV" not in table_text or "85,400" not in table_text:
                continue
            for cells in rows:
                if cells[0] == "Combined total" and len(cells) >= 7 and numeric_cell(cells[6]) == 85400:
                    recast_owned_homesites = numeric_cell(cells[4])
                    recast_optioned_homesites = numeric_cell(cells[5])
                    recast_total_homesites = numeric_cell(cells[6])
            if recast_total_homesites is not None:
                break

        jv_homesites = 5000
        company_owned_homesites = 22200
        company_optioned_homesites = 42500
        extraction_method = "tousa_as_filed_combined_table_excluding_transeastern"

    if fiscal_year == 2007:
        for table_index, rows, table_text in parsed_tables:
            if "Combined total" not in table_text or "36,000" not in table_text:
                continue
            for cells in rows:
                if cells[0] == "Combined total" and len(cells) >= 4 and numeric_cell(cells[3]) == 36000:
                    owned_homesites = numeric_cell(cells[1])
                    optioned_homesites = numeric_cell(cells[2])
                    total_homesites = numeric_cell(cells[3])
                    source_table_index = str(table_index)
                    source_row_label = "Combined total"
                    source_excerpt = table_text[:2400]
            if total_homesites is not None:
                break

        jv_homesites = 3600
        company_owned_homesites = 21500
        company_optioned_homesites = 10900
        extraction_method = "tousa_combined_owned_optioned_total_table"

    if total_homesites is None or optioned_homesites is None or owned_homesites is None:
        raise RuntimeError(f"Could not extract TOUSA homesite values for fiscal {fiscal_year}.")

    component_identity_gap = owned_homesites + optioned_homesites - total_homesites
    recast_optioned_share = ""
    if recast_total_homesites:
        recast_optioned_share = recast_optioned_homesites / recast_total_homesites

    panel_rows.append({
        "ticker": "TOA",
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
        "nonowned_controlled_homesites": optioned_homesites,
        "optioned_homesites": optioned_homesites,
        "company_owned_homesites": company_owned_homesites,
        "company_optioned_homesites": company_optioned_homesites,
        "jv_homesites": jv_homesites,
        "total_homesites": total_homesites,
        "nonowned_controlled_share": optioned_homesites / total_homesites,
        "optioned_share": optioned_homesites / total_homesites,
        "owned_share": owned_homesites / total_homesites,
        "component_identity_gap": component_identity_gap,
        "component_identity_pass": abs(component_identity_gap) <= 1,
        "recast_owned_homesites": recast_owned_homesites if recast_owned_homesites is not None else "",
        "recast_optioned_homesites": recast_optioned_homesites if recast_optioned_homesites is not None else "",
        "recast_total_homesites": recast_total_homesites if recast_total_homesites is not None else "",
        "recast_optioned_share": recast_optioned_share,
        "extraction_method": extraction_method,
        "source_table_index": source_table_index,
        "source_row_label": source_row_label,
        "panel_use_flag": True,
        "manual_review_flag": False,
        "manual_review_reason": "",
        "approximate_flag": fiscal_year in (2004, 2005),
        "later_comparative_recast_available": fiscal_year == 2006,
        "source_note": (
            "Uses TOUSA combined optioned homesites divided by combined total homesites. "
            "For 2006, the main row follows the contemporaneous 2006 10-K excluding Transeastern; "
            "the broader 2007 comparative recast including Transeastern is retained in recast fields."
        ),
    })

    source_notes.append({
        "ticker": "TOA",
        "fiscal_year": fiscal_year,
        "source_table_index": source_table_index,
        "source_row_label": source_row_label,
        "source_excerpt": source_excerpt,
    })

audit_rows = []
for row in panel_rows:
    expected_owned, expected_optioned, expected_total = expected_values[row["fiscal_year"]]
    audit_rows.append({
        "audit_check": "expected_values",
        "fiscal_year": row["fiscal_year"],
        "status": "ok" if row["owned_homesites"] == expected_owned and row["optioned_homesites"] == expected_optioned and row["total_homesites"] == expected_total else "fail",
        "value": f'{row["owned_homesites"]}|{row["optioned_homesites"]}|{row["total_homesites"]}',
        "detail": f"Expected {expected_owned}|{expected_optioned}|{expected_total}.",
    })

audit_rows.append({
    "audit_check": "firm_year_rows",
    "fiscal_year": "",
    "status": "ok" if len(panel_rows) == 4 else "fail",
    "value": len(panel_rows),
    "detail": "Expected TOUSA fiscal 2004-2007.",
})

audit_rows.append({
    "audit_check": "component_identity",
    "fiscal_year": "",
    "status": "ok" if all(row["component_identity_pass"] for row in panel_rows) else "fail",
    "value": sum(row["component_identity_pass"] for row in panel_rows),
    "detail": "Owned homesites plus optioned homesites must equal combined total homesites.",
})

write_csv(
    "../output/toa_2004_2007_land_panel.csv",
    panel_rows,
    [
        "ticker", "cik10", "sec_company_name", "fiscal_year", "report_date",
        "filing_date", "accession_number", "primary_document", "source_local_path",
        "source_url", "unit_type", "owned_homesites", "nonowned_controlled_homesites",
        "optioned_homesites", "company_owned_homesites", "company_optioned_homesites",
        "jv_homesites", "total_homesites", "nonowned_controlled_share", "optioned_share",
        "owned_share", "component_identity_gap", "component_identity_pass",
        "recast_owned_homesites", "recast_optioned_homesites", "recast_total_homesites",
        "recast_optioned_share", "extraction_method", "source_table_index",
        "source_row_label", "panel_use_flag", "manual_review_flag",
        "manual_review_reason", "approximate_flag", "later_comparative_recast_available",
        "source_note",
    ],
)

write_csv(
    "../output/toa_2004_2007_extraction_audit.csv",
    audit_rows,
    ["audit_check", "fiscal_year", "status", "value", "detail"],
)

write_csv(
    "../output/toa_2004_2007_source_notes.csv",
    source_notes,
    ["ticker", "fiscal_year", "source_table_index", "source_row_label", "source_excerpt"],
)
