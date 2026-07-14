#!/usr/bin/env python3

import csv
import re
import sys
from pathlib import Path

sys.path.append(str(Path(__file__).resolve().parents[2] / "_lib"))
from sec_fetch_utils import write_csv

sys.path.append(str(Path(__file__).resolve().parents[1].parent / "extract_10k_land_candidates" / "code"))
from extract_10k_land_candidates import clean_text, visible_text


with open("../input/land_light_firm_year_measures.csv", newline="") as f:
    filing_rows = [
        row for row in csv.DictReader(f)
        if row.get("cik10") == "0001218320"
        and row.get("form") == "10-K"
        and 2004 <= int(float(row.get("fiscal_year"))) <= 2007
    ]

if len(filing_rows) != 4:
    raise RuntimeError("Expected four Levitt/Woodbridge 10-K rows for fiscal 2004-2007.")

filing_by_year = {}
for filing in filing_rows:
    fiscal_year = int(float(filing["fiscal_year"]))
    if fiscal_year in filing_by_year:
        raise RuntimeError("Levitt filing rows must be unique by fiscal_year.")
    filing_by_year[fiscal_year] = filing

expected_values = {
    2004: (12287, 4605, 7682, 1814, 5868, 2442, 14729, 8310),
    2005: (16915, 6417, 10498, 1792, 8706, 4073, 20988, 12779),
    2006: (17900, 6462, 11438, 1248, 10190, 690, 18590, 10880),
}

panel_rows = []
source_notes = []

for fiscal_year in range(2004, 2008):
    filing = filing_by_year[fiscal_year]
    source_path = Path(filing["primary_document_local_path"])
    if not source_path.exists():
        raise RuntimeError(f"Missing Levitt source file: {source_path}")

    source_text = clean_text(visible_text(source_path))
    current_planned_units = ""
    current_closed_units = ""
    current_net_inventory_units = ""
    current_backlog_units = ""
    current_available_units = ""
    properties_under_contract_units = ""
    total_pipeline_units = ""
    total_available_units = ""
    source_excerpt = ""
    extraction_method = "levitt_bankruptcy_and_deconsolidation_prose"

    if fiscal_year <= 2006:
        table_match = re.search(
            r"TOTAL HOMEBUILDING Current Developments \(includes optioned lots\)\s+"
            r"([\d,]+)\s+([\d,]+)\s+([\d,]+)\s+([\d,]+)\s+([\d,]+)\s+([\d,]+).*?"
            r"Properties Under Contract to be Acquired.*?\s+([\d,]+)\s+(?:[\d,]+|—)\s+([\d,]+)\s+(?:[\d,]+|—)\s+([\d,]+).*?"
            r"TOTAL HOMEBUILDING\s+([\d,]+)\s+([\d,]+)\s+([\d,]+)\s+([\d,]+)\s+([\d,]+)\s+([\d,]+)",
            source_text,
            re.I,
        )
        if table_match is None:
            raise RuntimeError(f"Could not find Levitt homebuilding pipeline table for fiscal {fiscal_year}.")

        contract_match = re.search(
            r"Properties Under Contract to be Acquired.*?\s+[\d,]+\s+([\d,]+)",
            table_match.group(0),
            re.I,
        )
        if contract_match is None:
            raise RuntimeError(f"Could not find Levitt properties-under-contract units for fiscal {fiscal_year}.")

        current_planned_units = int(table_match.group(2).replace(",", ""))
        current_closed_units = int(table_match.group(3).replace(",", ""))
        current_net_inventory_units = int(table_match.group(4).replace(",", ""))
        current_backlog_units = int(table_match.group(5).replace(",", ""))
        current_available_units = int(table_match.group(6).replace(",", ""))
        properties_under_contract_units = int(contract_match.group(1).replace(",", ""))
        total_pipeline_units = int(table_match.group(11).replace(",", ""))
        total_available_units = int(table_match.group(15).replace(",", ""))
        source_excerpt = source_text[table_match.start():table_match.end()]
        extraction_method = "levitt_current_development_and_contract_pipeline_table"
    else:
        bankruptcy_match = re.search(
            r"Levitt and Sons ceased development at its projects at September 30, 2007.*?"
            r"deconsolidated Levitt and Sons as of November 9, 2007, eliminating all future operations from its financial results",
            source_text,
            re.I,
        )
        if bankruptcy_match is None:
            raise RuntimeError("Could not find Levitt 2007 bankruptcy and deconsolidation disclosure.")
        source_excerpt = source_text[bankruptcy_match.start():bankruptcy_match.end()]

    panel_rows.append({
        "ticker": "LEV",
        "cik10": filing["cik10"],
        "sec_company_name": filing["sec_company_name"],
        "fiscal_year": fiscal_year,
        "report_date": filing["report_date"],
        "filing_date": filing["filing_date"],
        "accession_number": filing["accession_number"],
        "primary_document": filing["primary_document"],
        "source_local_path": filing["primary_document_local_path"],
        "source_url": filing["filing_url"],
        "unit_type": "planned_homebuilding_units",
        "owned_lots": "",
        "nonowned_controlled_lots": "",
        "optioned_lots": "",
        "total_lots": "",
        "nonowned_controlled_share": "",
        "current_planned_units_including_optioned_lots": current_planned_units,
        "current_closed_units": current_closed_units,
        "current_net_inventory_units": current_net_inventory_units,
        "current_backlog_units": current_backlog_units,
        "current_available_units": current_available_units,
        "properties_under_contract_units": properties_under_contract_units,
        "total_pipeline_units": total_pipeline_units,
        "total_available_units": total_available_units,
        "current_developments_include_unquantified_optioned_lots": fiscal_year <= 2006,
        "owned_optioned_split_not_disclosed": fiscal_year <= 2006,
        "chapter_11_filing_year": fiscal_year == 2007,
        "homebuilding_deconsolidated": fiscal_year == 2007,
        "main_panel_eligible": False,
        "panel_use_flag": True,
        "manual_review_flag": True,
        "manual_review_reason": (
            "Current developments combine owned and optioned lots, so the owned-versus-optioned physical split is not recoverable."
            if fiscal_year <= 2006 else
            "Levitt and Sons ceased development, filed Chapter 11, and was deconsolidated during 2007; no year-end comparable land position remained in the parent filing."
        ),
        "extraction_method": extraction_method,
        "source_row_label": "TOTAL HOMEBUILDING" if fiscal_year <= 2006 else "bankruptcy and deconsolidation prose",
        "source_note": "Retain Levitt pipeline and operating scale as auxiliary data only; do not infer omega from a table that says current developments include optioned lots without quantifying that subset.",
    })

    source_notes.append({
        "ticker": "LEV",
        "fiscal_year": fiscal_year,
        "source_row_label": "TOTAL HOMEBUILDING" if fiscal_year <= 2006 else "bankruptcy and deconsolidation prose",
        "source_excerpt": source_excerpt,
    })

audit_rows = []
for row in panel_rows:
    if row["fiscal_year"] <= 2006:
        observed = (
            row["current_planned_units_including_optioned_lots"],
            row["current_closed_units"],
            row["current_net_inventory_units"],
            row["current_backlog_units"],
            row["current_available_units"],
            row["properties_under_contract_units"],
            row["total_pipeline_units"],
            row["total_available_units"],
        )
        audit_rows.append({
            "audit_check": "expected_pipeline_values",
            "fiscal_year": row["fiscal_year"],
            "status": "ok" if observed == expected_values[row["fiscal_year"]] else "fail",
            "value": "|".join(str(value) for value in observed),
            "detail": "Expected " + "|".join(str(value) for value in expected_values[row["fiscal_year"]]) + ".",
        })

audit_rows.extend([
    {
        "audit_check": "firm_year_rows",
        "fiscal_year": "",
        "status": "ok" if len(panel_rows) == 4 else "fail",
        "value": len(panel_rows),
        "detail": "Expected Levitt fiscal 2004-2007 rows.",
    },
    {
        "audit_check": "omega_missing_all_years",
        "fiscal_year": "",
        "status": "ok" if all(row["nonowned_controlled_share"] == "" for row in panel_rows) else "fail",
        "value": sum(row["nonowned_controlled_share"] == "" for row in panel_rows),
        "detail": "No reviewed Levitt filing provides a complete owned-versus-optioned physical split.",
    },
    {
        "audit_check": "bankruptcy_exit_2007",
        "fiscal_year": 2007,
        "status": "ok" if panel_rows[-1]["chapter_11_filing_year"] and panel_rows[-1]["homebuilding_deconsolidated"] else "fail",
        "value": panel_rows[-1]["homebuilding_deconsolidated"],
        "detail": "Levitt and Sons ceased development, filed Chapter 11, and was deconsolidated in 2007.",
    },
])

write_csv(
    "../output/lev_2004_2007_land_panel.csv",
    panel_rows,
    [
        "ticker", "cik10", "sec_company_name", "fiscal_year", "report_date", "filing_date",
        "accession_number", "primary_document", "source_local_path", "source_url", "unit_type",
        "owned_lots", "nonowned_controlled_lots", "optioned_lots", "total_lots",
        "nonowned_controlled_share", "current_planned_units_including_optioned_lots",
        "current_closed_units", "current_net_inventory_units", "current_backlog_units",
        "current_available_units", "properties_under_contract_units", "total_pipeline_units",
        "total_available_units", "current_developments_include_unquantified_optioned_lots",
        "owned_optioned_split_not_disclosed", "chapter_11_filing_year",
        "homebuilding_deconsolidated", "main_panel_eligible", "panel_use_flag",
        "manual_review_flag", "manual_review_reason", "extraction_method",
        "source_row_label", "source_note",
    ],
)

write_csv(
    "../output/lev_2004_2007_extraction_audit.csv",
    audit_rows,
    ["audit_check", "fiscal_year", "status", "value", "detail"],
)

write_csv(
    "../output/lev_2004_2007_source_notes.csv",
    source_notes,
    ["ticker", "fiscal_year", "source_row_label", "source_excerpt"],
)
