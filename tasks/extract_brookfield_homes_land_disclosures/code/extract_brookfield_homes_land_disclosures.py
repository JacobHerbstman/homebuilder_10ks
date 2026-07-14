#!/usr/bin/env python3

import csv
import re
import sys
from pathlib import Path

sys.path.append(str(Path(__file__).resolve().parents[2] / "_lib"))
from sec_fetch_utils import write_csv

sys.path.append(str(Path(__file__).resolve().parents[1].parent / "extract_10k_land_candidates" / "code"))
from extract_10k_land_candidates import visible_text


with open("../input/land_light_firm_year_measures.csv", newline="") as f:
    filing_rows = [
        row for row in csv.DictReader(f)
        if row.get("cik10") == "0001202157"
        and row.get("form") == "10-K"
        and 2004 <= int(float(row.get("fiscal_year"))) <= 2010
    ]

if len(filing_rows) == 0:
    raise RuntimeError("No Brookfield Homes filing rows found in land_light_firm_year_measures.csv.")

filing_by_year = {}
for filing in filing_rows:
    fiscal_year = int(float(filing["fiscal_year"]))
    if fiscal_year in filing_by_year:
        raise RuntimeError("Brookfield Homes filing rows must be unique by fiscal_year.")
    filing_by_year[fiscal_year] = filing

expected_values = {
    2004: (13047, 14919, 27966),
    2005: (12333, 17179, 29512),
    2006: (12719, 14897, 27616),
    2007: (13078, 12293, 25371),
    2008: (13084, 11025, 24109),
    2009: (15979, 8266, 24245),
    2010: (17623, 9194, 26817),
}

panel_rows = []
source_notes = []

for fiscal_year in range(2004, 2011):
    filing = filing_by_year[fiscal_year]
    source_path = Path(filing["primary_document_local_path"])

    if not source_path.exists():
        raise RuntimeError(f"Missing Brookfield Homes source file: {source_path}")

    source_text = re.sub(r"\s+", " ", visible_text(source_path))
    table_match = re.search(
        r"Lots controlled(?: \(units at end of year\))?: (.*?)(?:Year Ended December 31|Results of Operations)",
        source_text,
        re.I,
    )

    if table_match is None:
        raise RuntimeError(f"Could not find Brookfield Homes lots controlled table for fiscal {fiscal_year}.")

    table_text = table_match.group(1)
    option_match = re.search(r"Lots under option(?: \(\d+\))? ([\d,]+) [\d,]+ [\d,]+", table_text, re.I)
    total_match = re.search(r"Total ([\d,]+) [\d,]+ [\d,]+", table_text, re.I)

    if option_match is None:
        raise RuntimeError(f"Could not extract Brookfield Homes lots under option for fiscal {fiscal_year}.")
    if total_match is None:
        raise RuntimeError(f"Could not extract Brookfield Homes total controlled lots for fiscal {fiscal_year}.")

    numeric_prefix = table_text[:option_match.start()]
    numeric_values = re.findall(r"\d{1,3}(?:,\d{3})+|\d+", numeric_prefix)
    if len(numeric_values) < 3:
        raise RuntimeError(f"Could not extract Brookfield Homes owned subtotal for fiscal {fiscal_year}.")

    owned_lots = float(numeric_values[-3].replace(",", ""))
    optioned_lots = float(option_match.group(1).replace(",", ""))
    total_lots = float(total_match.group(1).replace(",", ""))
    component_identity_gap = owned_lots + optioned_lots - total_lots

    definition_match = re.search(
        rf"As of December 31, {fiscal_year}, we controlled [\d,]+ lots\..*?The number of residential building lots",
        source_text,
        re.I,
    )
    source_excerpt = table_text[:2200]
    if definition_match is not None:
        source_excerpt = definition_match.group(0) + " " + source_excerpt

    panel_rows.append({
        "ticker": "BHS",
        "cik10": filing["cik10"],
        "sec_company_name": filing["sec_company_name"],
        "fiscal_year": fiscal_year,
        "report_date": filing["report_date"],
        "filing_date": filing["filing_date"],
        "accession_number": filing["accession_number"],
        "primary_document": filing["primary_document"],
        "source_local_path": filing["primary_document_local_path"],
        "source_url": filing["filing_url"],
        "unit_type": "lots_or_lot_equivalent_land_inventory",
        "owned_lots": owned_lots,
        "nonowned_controlled_lots": optioned_lots,
        "optioned_lots": optioned_lots,
        "total_lots": total_lots,
        "nonowned_controlled_share": optioned_lots / total_lots,
        "optioned_share": optioned_lots / total_lots,
        "owned_share": owned_lots / total_lots,
        "component_identity_gap": component_identity_gap,
        "component_identity_pass": abs(component_identity_gap) <= 1,
        "owned_includes_jv_unconsolidated_share": True,
        "optioned_may_include_jv_unconsolidated_share": fiscal_year >= 2007,
        "extraction_method": "brookfield_homes_lots_controlled_table",
        "source_table_index": "",
        "source_row_label": "Lots controlled: owned subtotal / Lots under option / Total",
        "panel_use_flag": True,
        "manual_review_flag": False,
        "manual_review_reason": "",
        "source_note": (
            "Brookfield Homes defines controlled lots as a proportionate-share land-position universe. "
            "Owned includes directly owned lots plus company share of lots owned through joint ventures or unconsolidated entities; optioned lots are the Lots under option row in the same table."
        ),
    })

    source_notes.append({
        "ticker": "BHS",
        "fiscal_year": fiscal_year,
        "source_row_label": "Lots controlled: owned subtotal / Lots under option / Total",
        "source_excerpt": source_excerpt,
    })

audit_rows = []
for row in panel_rows:
    expected_owned, expected_optioned, expected_total = expected_values[row["fiscal_year"]]
    audit_rows.append({
        "audit_check": "expected_values",
        "fiscal_year": row["fiscal_year"],
        "status": "ok" if row["owned_lots"] == expected_owned and row["optioned_lots"] == expected_optioned and row["total_lots"] == expected_total else "fail",
        "value": f'{row["owned_lots"]}|{row["optioned_lots"]}|{row["total_lots"]}',
        "detail": f"Expected {expected_owned}|{expected_optioned}|{expected_total}.",
    })

audit_rows.append({
    "audit_check": "firm_year_rows",
    "fiscal_year": "",
    "status": "ok" if len(panel_rows) == 7 else "fail",
    "value": len(panel_rows),
    "detail": "Expected Brookfield Homes fiscal 2004-2010.",
})

audit_rows.append({
    "audit_check": "component_identity",
    "fiscal_year": "",
    "status": "ok" if all(row["component_identity_pass"] is True for row in panel_rows) else "fail",
    "value": sum(row["component_identity_pass"] is True for row in panel_rows),
    "detail": "Owned subtotal plus lots under option must equal total controlled lots.",
})

write_csv(
    "../output/bhs_2004_2010_land_panel.csv",
    panel_rows,
    [
        "ticker", "cik10", "sec_company_name", "fiscal_year", "report_date",
        "filing_date", "accession_number", "primary_document", "source_local_path",
        "source_url", "unit_type", "owned_lots", "nonowned_controlled_lots",
        "optioned_lots", "total_lots", "nonowned_controlled_share",
        "optioned_share", "owned_share", "component_identity_gap",
        "component_identity_pass", "owned_includes_jv_unconsolidated_share",
        "optioned_may_include_jv_unconsolidated_share", "extraction_method",
        "source_table_index", "source_row_label", "panel_use_flag",
        "manual_review_flag", "manual_review_reason", "source_note",
    ],
)

write_csv(
    "../output/bhs_2004_2010_extraction_audit.csv",
    audit_rows,
    ["audit_check", "fiscal_year", "status", "value", "detail"],
)

write_csv(
    "../output/bhs_2004_2010_source_notes.csv",
    source_notes,
    ["ticker", "fiscal_year", "source_row_label", "source_excerpt"],
)
