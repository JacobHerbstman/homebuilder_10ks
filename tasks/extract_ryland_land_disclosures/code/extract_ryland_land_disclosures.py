#!/usr/bin/env python3

import csv
import re
import sys
from pathlib import Path

sys.path.append(str(Path(__file__).resolve().parents[2] / "_lib"))
from sec_fetch_utils import write_csv

sys.path.append(str(Path(__file__).resolve().parents[1].parent / "extract_10k_land_candidates" / "code"))
from extract_10k_land_candidates import SecTableParser, clean_text, visible_text


with open("../input/land_light_firm_year_measures.csv", newline="") as f:
    filing_rows = [
        row for row in csv.DictReader(f)
        if row.get("cik10") == "0000085974"
        and row.get("form") == "10-K"
        and 2004 <= int(float(row.get("fiscal_year"))) <= 2014
    ]

if len(filing_rows) == 0:
    raise RuntimeError("No Ryland filing rows found in land_light_firm_year_measures.csv.")

filing_by_year = {}
for filing in filing_rows:
    fiscal_year = int(float(filing["fiscal_year"]))
    if fiscal_year in filing_by_year:
        raise RuntimeError("Ryland filing rows must be unique by fiscal_year.")
    filing_by_year[fiscal_year] = filing

expected_values = {
    2005: (30201, 45470, 75671),
    2006: (31251, 29067, 60318),
    2007: (26647, 13253, 39900),
    2008: (19239, 4316, 23555),
    2009: (15866, 4036, 19902),
    2010: (16556, 6659, 23215),
    2011: (14337, 7242, 21579),
    2012: (17781, 10524, 28305),
    2013: (23540, 14602, 38142),
    2014: (25303, 13670, 38973),
}

panel_rows = []
source_notes = []

for fiscal_year in range(2005, 2015):
    source_fiscal_year = 2006 if fiscal_year == 2005 else fiscal_year
    filing = filing_by_year[source_fiscal_year]
    source_path = Path("../../build_land_light_measures/code") / filing["primary_document_local_path"]
    source_path = source_path.resolve()

    if not source_path.exists():
        raise RuntimeError(f"Missing Ryland source file: {source_path}")

    raw_text = source_path.read_text(encoding="utf-8", errors="ignore")
    source_text = re.sub(r"\s+", " ", visible_text(source_path))

    table_parser = SecTableParser()
    table_parser.feed(raw_text)

    source_table_index = ""
    source_table_text = ""
    for table_index, table in enumerate(table_parser.tables):
        parsed_rows = []
        for html_row in table["rows"]:
            cells = [clean_text(cell.get("text", "")) for cell in html_row]
            cells = [cell for cell in cells if cell]
            if cells:
                parsed_rows.append(cells)

        table_text = clean_text(" || ".join(" | ".join(cells) for cells in parsed_rows))
        table_text_lower = table_text.lower()
        if "lots owned" not in table_text_lower:
            continue
        if "total" not in table_text_lower:
            continue
        if "lots optioned" not in table_text_lower and "lots controlled under option" not in table_text_lower:
            continue

        total_values = re.findall(r"Total(?: lots owned| lots controlled under option)?\s*\|?\s*([\d,]+)(?:\s*\|\s*|\s+)([\d,]+)?(?:\s*\|\s*|\s+)?([\d,]+)?(?:\s*\|\s*|\s+)?([\d,]+)?(?:\s*\|\s*|\s+)?([\d,]+)?(?:\s*\|\s*|\s+)?([\d,]+)?", table_text)
        numeric_values = [int(value.replace(",", "")) for groups in total_values for value in groups if value]
        if len(numeric_values) == 0 or max(numeric_values) < 10000:
            continue

        source_table_index = str(table_index)
        source_table_text = table_text
        break

    if source_table_text == "":
        raise RuntimeError(f"Could not find Ryland owned/optioned lot table for fiscal {fiscal_year}.")

    if source_fiscal_year == 2006:
        owned_match = re.search(r"Total lots owned\s*\|\s*([\d,]+)\s*\|\s*([\d,]+)", source_table_text, re.I)
        optioned_match = re.search(r"Total lots controlled under option\s*\|\s*([\d,]+)\s*\|\s*([\d,]+)", source_table_text, re.I)
        total_match = re.search(r"TOTAL LOTS OWNED AND CONTROLLED\s*\|\s*([\d,]+)\s*\|\s*([\d,]+)", source_table_text, re.I)

        if owned_match is None or optioned_match is None or total_match is None:
            raise RuntimeError(f"Could not extract Ryland 2005/2006 two-year table values for fiscal {fiscal_year}.")

        group_index = 2 if fiscal_year == 2005 else 1
        owned_lots = int(owned_match.group(group_index).replace(",", ""))
        optioned_lots = int(optioned_match.group(group_index).replace(",", ""))
        total_lots = int(total_match.group(group_index).replace(",", ""))
    else:
        total_match = re.search(
            r"Total\s*\|\s*([\d,]+)\s*\|\s*([\d,]+)\s*\|\s*([\d,]+)\s*\|\s*([\d,]+)\s*\|\s*([\d,]+)\s*\|\s*([\d,]+)",
            source_table_text,
            re.I,
        )

        if total_match is None:
            raise RuntimeError(f"Could not extract Ryland total row for fiscal {fiscal_year}.")

        owned_lots = int(total_match.group(1).replace(",", ""))
        optioned_lots = int(total_match.group(2).replace(",", ""))
        total_lots = int(total_match.group(3).replace(",", ""))

    jv_lots = ""
    jv_match = re.search(
        rf"controlled ([\d,]+) lots .*? under joint venture agreements at December 31, {fiscal_year}",
        source_text,
        re.I,
    )
    if jv_match is not None:
        jv_lots = int(jv_match.group(1).replace(",", ""))

    source_excerpt = source_table_text[:2200]
    context_match = re.search(
        r"The following table summarizes each reporting segment.*?(?:Variable Interest Entities|Additionally, at December 31|Goodwill|Table of Contents)",
        source_text,
        re.I,
    )
    if context_match is not None:
        source_excerpt = context_match.group(0)[:2200]

    component_identity_gap = owned_lots + optioned_lots - total_lots
    panel_rows.append({
        "ticker": "RYL",
        "cik10": filing["cik10"],
        "sec_company_name": filing["sec_company_name"],
        "fiscal_year": fiscal_year,
        "report_date": f"{fiscal_year}-12-31",
        "filing_date": filing["filing_date"],
        "accession_number": filing["accession_number"],
        "primary_document": filing["primary_document"],
        "source_local_path": filing["primary_document_local_path"],
        "source_url": filing["filing_url"],
        "unit_type": "lots",
        "owned_lots": owned_lots,
        "nonowned_controlled_lots": optioned_lots,
        "optioned_lots": optioned_lots,
        "total_lots": total_lots,
        "nonowned_controlled_share": optioned_lots / total_lots,
        "optioned_share": optioned_lots / total_lots,
        "owned_share": owned_lots / total_lots,
        "component_identity_gap": component_identity_gap,
        "component_identity_pass": abs(component_identity_gap) <= 1,
        "source_fiscal_year": source_fiscal_year,
        "uses_later_comparative_prior_year_row": fiscal_year == 2005,
        "current_year_10k_lot_table_absent": fiscal_year == 2005,
        "separately_disclosed_jv_lots": jv_lots,
        "jv_lots_excluded_from_main": True,
        "option_land_purchase_deposits_lc": "",
        "aggregate_option_land_purchase_price": "",
        "qualitative_option_contracts_used": True,
        "physical_lot_count_table_found": True,
        "dollar_exposure_used_for_omega": False,
        "extraction_method": "ryland_reporting_segment_owned_optioned_table",
        "source_table_index": source_table_index,
        "source_row_label": "Total lots owned / lots optioned / total lots owned and controlled",
        "panel_use_flag": True,
        "main_panel_eligible": True,
        "manual_review_flag": fiscal_year == 2005,
        "manual_review_reason": "Uses exact 2005 comparative row from the 2006 10-K because the 2005 10-K does not disclose the owned/optioned lot-count table." if fiscal_year == 2005 else "",
        "source_note": (
            "Main series uses Ryland's recurring reporting-segment owned/optioned table. "
            "Separately disclosed joint venture lots are excluded from the main denominator and retained as auxiliary exposure where the prose discloses them."
        ),
    })

    source_notes.append({
        "ticker": "RYL",
        "fiscal_year": fiscal_year,
        "source_fiscal_year": source_fiscal_year,
        "source_table_index": source_table_index,
        "source_row_label": "Total lots owned / lots optioned / total lots owned and controlled",
        "source_excerpt": source_excerpt,
    })

filing = filing_by_year[2004]
panel_rows.insert(0, {
    "ticker": "RYL",
    "cik10": filing["cik10"],
    "sec_company_name": filing["sec_company_name"],
    "fiscal_year": 2004,
    "report_date": "2004-12-31",
    "filing_date": filing["filing_date"],
    "accession_number": filing["accession_number"],
    "primary_document": filing["primary_document"],
    "source_local_path": filing["primary_document_local_path"],
    "source_url": filing["filing_url"],
    "unit_type": "lots",
    "owned_lots": "",
    "nonowned_controlled_lots": "",
    "optioned_lots": "",
    "total_lots": "",
    "nonowned_controlled_share": "",
    "optioned_share": "",
    "owned_share": "",
    "component_identity_gap": "",
    "component_identity_pass": "",
    "source_fiscal_year": 2004,
    "uses_later_comparative_prior_year_row": False,
    "current_year_10k_lot_table_absent": True,
    "separately_disclosed_jv_lots": "",
    "jv_lots_excluded_from_main": True,
    "option_land_purchase_deposits_lc": 134300000,
    "aggregate_option_land_purchase_price": 1900000000,
    "qualitative_option_contracts_used": True,
    "physical_lot_count_table_found": False,
    "dollar_exposure_used_for_omega": False,
    "extraction_method": "ryland_audited_missing_owned_optioned_split",
    "source_table_index": "",
    "source_row_label": "missing owned/optioned lot count",
    "panel_use_flag": True,
    "main_panel_eligible": False,
    "manual_review_flag": True,
    "manual_review_reason": "The 2004 filing discloses dollar commitments for options and land purchase contracts but no owned/optioned physical lot-count table.",
    "source_note": (
        "Ryland 2004 is retained as an audited missing row. "
        "The filing discloses $134.3 million of cash deposits and letters of credit for option and land purchase contracts with a $1.9 billion total purchase price, but those dollar commitments are not converted to physical lots."
    ),
})

source_notes.append({
    "ticker": "RYL",
    "fiscal_year": 2004,
    "source_fiscal_year": 2004,
    "source_table_index": "",
    "source_row_label": "missing owned/optioned lot count",
    "source_excerpt": "The 2004 10-K describes direct acquisition and option contracts and reports dollar exposure for option and land purchase contracts, but no owned/optioned lot-count table was found. Omega is intentionally missing rather than inferred from dollar commitments.",
})

audit_rows = []
for row in panel_rows:
    if row["fiscal_year"] == 2004:
        continue
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
    "status": "ok" if len(panel_rows) == 11 else "fail",
    "value": len(panel_rows),
    "detail": "Expected Ryland fiscal 2004-2014 audited rows.",
})

audit_rows.append({
    "audit_check": "component_identity",
    "fiscal_year": "",
    "status": "ok" if all(row["component_identity_pass"] in {"", True} for row in panel_rows) else "fail",
    "value": sum(row["component_identity_pass"] is True for row in panel_rows),
    "detail": "Owned plus optioned lots must equal total lots owned and controlled.",
})

audit_rows.append({
    "audit_check": "missing_2004_not_inferred",
    "fiscal_year": 2004,
    "status": "ok",
    "value": "missing",
    "detail": "The 2004 filing discloses dollar commitments for options and land purchase contracts but no owned/optioned lot-count table.",
})

write_csv(
    "../output/ryl_2004_2014_land_panel.csv",
    panel_rows,
    [
        "ticker", "cik10", "sec_company_name", "fiscal_year", "report_date",
        "filing_date", "accession_number", "primary_document", "source_local_path",
        "source_url", "unit_type", "owned_lots", "nonowned_controlled_lots",
        "optioned_lots", "total_lots", "nonowned_controlled_share",
        "optioned_share", "owned_share", "component_identity_gap",
        "component_identity_pass", "source_fiscal_year",
        "uses_later_comparative_prior_year_row",
        "current_year_10k_lot_table_absent", "separately_disclosed_jv_lots",
        "jv_lots_excluded_from_main", "option_land_purchase_deposits_lc",
        "aggregate_option_land_purchase_price",
        "qualitative_option_contracts_used", "physical_lot_count_table_found",
        "dollar_exposure_used_for_omega", "extraction_method",
        "source_table_index", "source_row_label", "panel_use_flag",
        "main_panel_eligible", "manual_review_flag", "manual_review_reason",
        "source_note",
    ],
)

write_csv(
    "../output/ryl_2004_2014_extraction_audit.csv",
    audit_rows,
    ["audit_check", "fiscal_year", "status", "value", "detail"],
)

write_csv(
    "../output/ryl_2004_2014_source_notes.csv",
    source_notes,
    ["ticker", "fiscal_year", "source_fiscal_year", "source_table_index", "source_row_label", "source_excerpt"],
)
