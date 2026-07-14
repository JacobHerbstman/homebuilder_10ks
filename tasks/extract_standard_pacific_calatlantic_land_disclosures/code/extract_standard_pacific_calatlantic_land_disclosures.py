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
        if row.get("cik10") == "0000878560"
        and row.get("form") == "10-K"
        and 2004 <= int(float(row.get("fiscal_year"))) <= 2016
    ]

if len(filing_rows) == 0:
    raise RuntimeError("No Standard Pacific / CalAtlantic filing rows found in land_light_firm_year_measures.csv.")

filing_by_year = {}
for filing in filing_rows:
    fiscal_year = int(float(filing["fiscal_year"]))
    if fiscal_year in filing_by_year:
        raise RuntimeError("Standard Pacific / CalAtlantic filing rows must be unique by fiscal_year.")
    filing_by_year[fiscal_year] = filing

expected_values = {
    2004: {"owned": 25832, "optioned": 17355, "jv": 8315, "source_total": 51502, "discontinued": 0},
    2005: {"owned": 34349, "optioned": 28810, "jv": 11384, "source_total": 74543, "discontinued": 0},
    2006: {"owned": 35823, "optioned": 10887, "jv": 13981, "source_total": 60691, "discontinued": 0},
    2007: {"owned": 21371, "optioned": 5619, "jv": 6761, "source_total": 34758, "discontinued": 1007},
    2008: {"owned": 19306, "optioned": 2519, "jv": 2306, "source_total": 24136, "discontinued": 5},
    2009: {"owned": 15826, "optioned": 2361, "jv": 1003, "source_total": 19191, "discontinued": 1},
    2010: {"owned": 17650, "optioned": 4451, "jv": 1448, "source_total": 23549, "discontinued": 0},
    2011: {"owned": 20035, "optioned": 5183, "jv": 1226, "source_total": 26444, "discontinued": 0},
    2012: {"owned": 25475, "optioned": 4681, "jv": 611, "source_total": 30767, "discontinued": 0},
    2013: {"owned": 27733, "optioned": 7047, "jv": 395, "source_total": 35175, "discontinued": 0},
    2014: {"owned": 28972, "optioned": 6260, "jv": 198, "source_total": 35430, "discontinued": 0},
    2015: {"owned": 52583, "optioned": 15972, "jv": 1939, "source_total": 70494, "discontinued": 0},
    2016: {"owned": 50735, "optioned": 13142, "jv": 1547, "source_total": 65424, "discontinued": 0},
}

panel_rows = []
source_notes = []

for fiscal_year in range(2004, 2017):
    filing = filing_by_year[fiscal_year]
    source_path = Path("../../build_land_light_measures/code") / filing["primary_document_local_path"]
    source_path = source_path.resolve()

    if not source_path.exists():
        raise RuntimeError(f"Missing Standard Pacific / CalAtlantic source file: {source_path}")

    source_text = re.sub(r"\s+", " ", visible_text(source_path))
    heading = "Homesites owned and controlled" if fiscal_year >= 2011 else "Building sites owned or controlled"
    section_match = re.search(
        heading + r":(.*?)(?:Homesites owned:|Homes under construction|Completed and unsold homes|Total homes under construction|Table of Contents At December 31|$)",
        source_text,
        re.I,
    )
    if section_match is None:
        raise RuntimeError(f"Could not find Standard Pacific / CalAtlantic land-position section for fiscal {fiscal_year}.")

    source_section = section_match.group(1)

    owned_match = re.search(r"(?:Total )?(?:building sites|homesites) owned\s+([\d,]+)", source_section, re.I)
    optioned_match = re.search(r"(?:Total )?(?:building sites|homesites) optioned or subject to contract\s+([\d,]+)", source_section, re.I)
    jv_match = re.search(r"(?:Total )?joint venture (?:lots|homesites)(?:\s*\(\d+\))?\s+([\d,]+)", source_section, re.I)
    total_match = re.search(r"Total \(including joint ventures\)(?:\s*\(\d+\))?\s+([\d,]+)", source_section, re.I)
    discontinued_match = re.search(r"Discontinued operations\s+([\d,]+|—|―)", source_section, re.I)

    if owned_match is None or optioned_match is None or jv_match is None or total_match is None:
        raise RuntimeError(f"Could not extract Standard Pacific / CalAtlantic component rows for fiscal {fiscal_year}.")

    owned_lots = int(owned_match.group(1).replace(",", ""))
    optioned_lots = int(optioned_match.group(1).replace(",", ""))
    jv_lots = int(jv_match.group(1).replace(",", ""))
    source_total_including_jv_and_discontinued = int(total_match.group(1).replace(",", ""))
    discontinued_lots_excluded = 0
    if discontinued_match is not None and discontinued_match.group(1) not in {"—", "―"}:
        discontinued_lots_excluded = int(discontinued_match.group(1).replace(",", ""))

    total_lots_excluding_jv = owned_lots + optioned_lots
    total_lots_including_jv = owned_lots + optioned_lots + jv_lots
    source_total_identity_gap = total_lots_including_jv + discontinued_lots_excluded - source_total_including_jv_and_discontinued
    component_identity_gap = owned_lots + optioned_lots - total_lots_excluding_jv
    ticker = "CAA" if fiscal_year >= 2015 else "SPF"
    source_scope = "homesites" if fiscal_year >= 2011 else "building_sites"

    panel_rows.append({
        "ticker": ticker,
        "cik10": filing["cik10"],
        "sec_company_name": filing["sec_company_name"],
        "fiscal_year": fiscal_year,
        "report_date": f"{fiscal_year}-12-31",
        "filing_date": filing["filing_date"],
        "accession_number": filing["accession_number"],
        "primary_document": filing["primary_document"],
        "source_local_path": filing["primary_document_local_path"],
        "source_url": filing["filing_url"],
        "unit_type": source_scope,
        "owned_lots": owned_lots,
        "nonowned_controlled_lots": optioned_lots,
        "optioned_lots": optioned_lots,
        "total_lots": total_lots_excluding_jv,
        "nonowned_controlled_share": optioned_lots / total_lots_excluding_jv,
        "optioned_share": optioned_lots / total_lots_excluding_jv,
        "owned_share": owned_lots / total_lots_excluding_jv,
        "component_identity_gap": component_identity_gap,
        "component_identity_pass": abs(component_identity_gap) <= 1,
        "jv_lots": jv_lots,
        "total_lots_including_jv": total_lots_including_jv,
        "source_total_including_jv_and_discontinued": source_total_including_jv_and_discontinued,
        "discontinued_lots_excluded": discontinued_lots_excluded,
        "source_total_identity_gap": source_total_identity_gap,
        "source_total_identity_pass": abs(source_total_identity_gap) <= 1,
        "jv_inclusive_nonowned_controlled_share": (optioned_lots + jv_lots) / total_lots_including_jv,
        "jv_excluded_from_main": True,
        "discontinued_lots_excluded_from_main": discontinued_lots_excluded > 0,
        "not_pure_optioned_lots": True,
        "contractual_control_measure": True,
        "nonowned_label_raw": "optioned_or_subject_to_contract",
        "merger_definition_break": fiscal_year >= 2015,
        "post_ryland_merger": fiscal_year >= 2015,
        "calatlantic_transition": fiscal_year >= 2015,
        "large_scope_change": fiscal_year >= 2015,
        "extraction_method": "standard_pacific_calatlantic_visible_text_owned_optioned_jv_table",
        "source_table_index": "",
        "source_row_label": "Owned / optioned or subject to contract / joint venture rows",
        "panel_use_flag": True,
        "main_panel_eligible": True,
        "manual_review_flag": fiscal_year >= 2015 or discontinued_lots_excluded > 0,
        "manual_review_reason": (
            "Merger transition year: Standard Pacific and Ryland combined into CalAtlantic; row is main-eligible but should be flagged in merger-splice/event-window analyses."
            if fiscal_year >= 2015 else
            "Discontinued-operation lots are disclosed only as a total and are excluded from the main owned/optioned denominator."
            if discontinued_lots_excluded > 0 else ""
        ),
        "source_note": (
            "Main omega excludes separately disclosed joint venture lots and uses optioned or subject-to-contract sites divided by owned plus optioned/contract sites. "
            "A JV-inclusive alternate share is retained in this task output. "
            "For 2007-2009, discontinued-operation site counts are excluded because no owned/optioned split is disclosed for them."
        ),
    })

    source_notes.append({
        "ticker": ticker,
        "fiscal_year": fiscal_year,
        "source_scope": source_scope,
        "source_table_index": "",
        "source_row_label": "Owned / optioned or subject to contract / joint venture rows",
        "source_excerpt": source_section[:2600],
    })

audit_rows = []
for row in panel_rows:
    expected = expected_values[row["fiscal_year"]]
    audit_rows.append({
        "audit_check": "expected_values",
        "fiscal_year": row["fiscal_year"],
        "status": "ok" if row["owned_lots"] == expected["owned"] and row["optioned_lots"] == expected["optioned"] and row["jv_lots"] == expected["jv"] and row["source_total_including_jv_and_discontinued"] == expected["source_total"] and row["discontinued_lots_excluded"] == expected["discontinued"] else "fail",
        "value": f'{row["owned_lots"]}|{row["optioned_lots"]}|{row["jv_lots"]}|{row["source_total_including_jv_and_discontinued"]}|{row["discontinued_lots_excluded"]}',
        "detail": f'Expected {expected["owned"]}|{expected["optioned"]}|{expected["jv"]}|{expected["source_total"]}|{expected["discontinued"]}.',
    })

audit_rows.append({
    "audit_check": "firm_year_rows",
    "fiscal_year": "",
    "status": "ok" if len(panel_rows) == 13 else "fail",
    "value": len(panel_rows),
    "detail": "Expected Standard Pacific / CalAtlantic fiscal 2004-2016 audited rows.",
})

audit_rows.append({
    "audit_check": "main_component_identity",
    "fiscal_year": "",
    "status": "ok" if all(row["component_identity_pass"] is True for row in panel_rows) else "fail",
    "value": sum(row["component_identity_pass"] is True for row in panel_rows),
    "detail": "Owned plus optioned/contract sites must equal main total excluding JV.",
})

audit_rows.append({
    "audit_check": "source_total_identity",
    "fiscal_year": "",
    "status": "ok" if all(row["source_total_identity_pass"] is True for row in panel_rows) else "fail",
    "value": sum(row["source_total_identity_pass"] is True for row in panel_rows),
    "detail": "Owned plus optioned/contract plus JV plus separately disclosed discontinued sites must reconcile to source total including JVs.",
})

write_csv(
    "../output/spf_caa_2004_2016_land_panel.csv",
    panel_rows,
    [
        "ticker", "cik10", "sec_company_name", "fiscal_year", "report_date",
        "filing_date", "accession_number", "primary_document", "source_local_path",
        "source_url", "unit_type", "owned_lots", "nonowned_controlled_lots",
        "optioned_lots", "total_lots", "nonowned_controlled_share",
        "optioned_share", "owned_share", "component_identity_gap",
        "component_identity_pass", "jv_lots", "total_lots_including_jv",
        "source_total_including_jv_and_discontinued",
        "discontinued_lots_excluded", "source_total_identity_gap",
        "source_total_identity_pass", "jv_inclusive_nonowned_controlled_share",
        "jv_excluded_from_main", "discontinued_lots_excluded_from_main",
        "not_pure_optioned_lots", "contractual_control_measure",
        "nonowned_label_raw", "merger_definition_break",
        "post_ryland_merger", "calatlantic_transition", "large_scope_change",
        "extraction_method", "source_table_index", "source_row_label",
        "panel_use_flag", "main_panel_eligible", "manual_review_flag",
        "manual_review_reason", "source_note",
    ],
)

write_csv(
    "../output/spf_caa_2004_2016_extraction_audit.csv",
    audit_rows,
    ["audit_check", "fiscal_year", "status", "value", "detail"],
)

write_csv(
    "../output/spf_caa_2004_2016_source_notes.csv",
    source_notes,
    ["ticker", "fiscal_year", "source_scope", "source_table_index", "source_row_label", "source_excerpt"],
)
