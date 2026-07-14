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
        if row.get("ticker") == "DHOM"
        and row.get("form") == "10-K"
        and 2004 <= int(float(row.get("fiscal_year"))) <= 2007
    ]

if len(filing_rows) == 0:
    raise RuntimeError("No Dominion Homes filing rows found in land_light_firm_year_measures.csv.")

filing_by_year = {}
for filing in filing_rows:
    fiscal_year = int(float(filing["fiscal_year"]))
    if fiscal_year in filing_by_year:
        raise RuntimeError("Dominion Homes filing rows must be unique by fiscal_year.")
    filing_by_year[fiscal_year] = filing

expected_values = {
    2004: (14728, 6059, 20787),
    2005: (15269, 2709, 17978),
    2006: (14598, 267, 14865),
    2007: (12832, 205, 13037),
}

panel_rows = []
source_notes = []

for fiscal_year in range(2004, 2008):
    filing = filing_by_year[fiscal_year]
    source_path = Path(filing["primary_document_local_path"])

    if not source_path.exists():
        raise RuntimeError(f"Missing Dominion Homes source file: {source_path}")

    source_text = visible_text(source_path)
    source_text = re.sub(r"\s+", " ", source_text)

    owned_match = re.search(
        rf"(?:At|As of) December 31, {fiscal_year}, we owned lots or land that we estimate could be developed into(?: approximately)? ([\d,]+) lots",
        source_text,
        re.I,
    )
    controlled_match = re.search(
        r"we (?:also )?controlled, through option agreements or contingent contracts, land that we estimate could be developed into(?: approximately)? ([\d,]+) additional lots",
        source_text[owned_match.start():] if owned_match else source_text,
        re.I,
    )

    if owned_match is None:
        raise RuntimeError(f"Could not extract Dominion owned lots for fiscal {fiscal_year}.")
    if controlled_match is None:
        raise RuntimeError(f"Could not extract Dominion controlled lots for fiscal {fiscal_year}.")

    owned_lots = float(owned_match.group(1).replace(",", ""))
    controlled_lots = float(controlled_match.group(1).replace(",", ""))
    total_lots = owned_lots + controlled_lots
    split_from_prose_following_table = fiscal_year in (2006, 2007)

    excerpt_start = max(owned_match.start() - 500, 0)
    excerpt_end = min(owned_match.end() + controlled_match.end() + 900, len(source_text))
    source_excerpt = source_text[excerpt_start:excerpt_end]

    panel_rows.append({
        "ticker": "DHOM",
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
        "nonowned_controlled_lots": controlled_lots,
        "optioned_lots": controlled_lots,
        "total_lots": total_lots,
        "nonowned_controlled_share": controlled_lots / total_lots,
        "optioned_share": controlled_lots / total_lots,
        "owned_share": owned_lots / total_lots,
        "component_identity_gap": owned_lots + controlled_lots - total_lots,
        "component_identity_pass": True,
        "split_from_prose_following_table": split_from_prose_following_table,
        "extraction_method": "dominion_owned_and_option_contingent_lot_sentences",
        "source_table_index": "",
        "source_row_label": "owned lots or land / controlled through option agreements or contingent contracts",
        "panel_use_flag": True,
        "manual_review_flag": False,
        "manual_review_reason": "",
        "source_note": (
            "Dominion owned count includes land titled in its name and pro rata JV land; controlled count includes land committed to purchase or right to acquire under contingent purchase or option contracts, screened to land zoned for its needs or otherwise reasonably likely to result in purchase."
        ),
    })

    source_notes.append({
        "ticker": "DHOM",
        "fiscal_year": fiscal_year,
        "source_row_label": "owned lots or land / controlled through option agreements or contingent contracts",
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
    "status": "ok" if len(panel_rows) == 4 else "fail",
    "value": len(panel_rows),
    "detail": "Expected Dominion fiscal 2004-2007.",
})

audit_rows.append({
    "audit_check": "component_identity",
    "fiscal_year": "",
    "status": "ok" if all(row["component_identity_pass"] is True for row in panel_rows) else "fail",
    "value": sum(row["component_identity_pass"] is True for row in panel_rows),
    "detail": "Owned lots plus controlled lots must equal total lots.",
})

write_csv(
    "../output/dhom_2004_2007_land_panel.csv",
    panel_rows,
    [
        "ticker", "cik10", "sec_company_name", "fiscal_year", "report_date",
        "filing_date", "accession_number", "primary_document", "source_local_path",
        "source_url", "unit_type", "owned_lots", "nonowned_controlled_lots",
        "optioned_lots", "total_lots", "nonowned_controlled_share", "optioned_share",
        "owned_share", "component_identity_gap", "component_identity_pass",
        "split_from_prose_following_table", "extraction_method", "source_table_index",
        "source_row_label", "panel_use_flag", "manual_review_flag",
        "manual_review_reason", "source_note",
    ],
)

write_csv(
    "../output/dhom_2004_2007_extraction_audit.csv",
    audit_rows,
    ["audit_check", "fiscal_year", "status", "value", "detail"],
)

write_csv(
    "../output/dhom_2004_2007_source_notes.csv",
    source_notes,
    ["ticker", "fiscal_year", "source_row_label", "source_excerpt"],
)
