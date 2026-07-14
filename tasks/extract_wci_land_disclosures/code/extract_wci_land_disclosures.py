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
        if row.get("cik10") in {"0001137778", "0001574532"}
        and row.get("form") == "10-K"
        and 2004 <= int(float(row.get("fiscal_year"))) <= 2015
    ]

if len(filing_rows) == 0:
    raise RuntimeError("No WCI filing rows found in land_light_firm_year_measures.csv.")

filing_by_cik_year = {}
for filing in filing_rows:
    fiscal_year = int(float(filing["fiscal_year"]))
    key = (filing["cik10"], fiscal_year)
    if key in filing_by_cik_year:
        raise RuntimeError("WCI filing rows must be unique by cik10/fiscal_year.")
    filing_by_cik_year[key] = filing

expected_values = {
    ("0001137778", 2004): (27800, 4800, 32600),
    ("0001137778", 2005): (30100, 5300, 35400),
    ("0001137778", 2006): (28600, 3300, 31900),
    ("0001137778", 2007): (26900, 1100, 28000),
    ("0001137778", 2008): (23700, 0, 23700),
    ("0001574532", 2013): (7831, 676, 8507),
    ("0001574532", 2014): (8613, 4006, 12619),
    ("0001574532", 2015): (7884, 5428, 13312),
}

old_wci_detail = {
    2004: (17530, 3300, 68, 11),
    2005: (17625, 3400, 79, 14),
    2006: (15420, 1285, 55, 7),
    2007: (13950, 470, 53, 4),
    2008: (11700, 0, 48, 0),
}

panel_rows = []
source_notes = []

for fiscal_year in range(2004, 2009):
    filing = filing_by_cik_year[("0001137778", fiscal_year)]
    source_path = Path(filing["primary_document_local_path"])

    if not source_path.exists():
        raise RuntimeError(f"Missing old WCI source file: {source_path}")

    source_text = re.sub(r"\s+", " ", visible_text(source_path))
    table_match = re.search(
        rf"Our communities As of December 31, {fiscal_year}.*?(?:EMPLOYEES|SEASONALITY)",
        source_text,
        re.I,
    )

    if table_match is None:
        raise RuntimeError(f"Could not find old WCI communities table for fiscal {fiscal_year}.")

    table_text = table_match.group(0)
    total_match = re.search(r"Total(?: \(\d+\))? [\d,]+ ([\d,]+) ([\d,]+) ([\d,]+|—)", table_text)

    if total_match is None:
        raise RuntimeError(f"Could not extract old WCI total entitled units for fiscal {fiscal_year}.")

    total_acres = float(total_match.group(1).replace(",", ""))
    total_units = float(total_match.group(2).replace(",", ""))
    total_tower_sites = 0.0 if total_match.group(3) == "—" else float(total_match.group(3).replace(",", ""))

    footnote_match = re.search(
        r"approximately ([\d,]+) acres, ([\d,]+) units and ([\d,]+) tower sites, respectively, were not owned by us, but were controlled through options or contracts",
        table_text,
        re.I,
    )

    if footnote_match is None and fiscal_year != 2008:
        raise RuntimeError(f"Could not extract old WCI nonowned controlled footnote for fiscal {fiscal_year}.")

    if fiscal_year == 2008:
        no_options_sentence = "no remaining active land or lot option purchase contracts" in source_text.lower()
        if not no_options_sentence:
            raise RuntimeError("Old WCI fiscal 2008 must explicitly state no remaining active land or lot option purchase contracts.")
        nonowned_acres = 0.0
        nonowned_units = 0.0
        nonowned_tower_sites = 0.0
    else:
        nonowned_acres = float(footnote_match.group(1).replace(",", ""))
        nonowned_units = float(footnote_match.group(2).replace(",", ""))
        nonowned_tower_sites = float(footnote_match.group(3).replace(",", ""))

    owned_units = total_units - nonowned_units
    component_identity_gap = owned_units + nonowned_units - total_units

    panel_rows.append({
        "ticker": "WCI/WCIC",
        "source_ticker": "WCI",
        "cik10": filing["cik10"],
        "sec_company_name": filing["sec_company_name"],
        "fiscal_year": fiscal_year,
        "report_date": filing["report_date"],
        "filing_date": filing["filing_date"],
        "accession_number": filing["accession_number"],
        "primary_document": filing["primary_document"],
        "source_local_path": filing["primary_document_local_path"],
        "source_url": filing["filing_url"],
        "unit_type": "entitled_units",
        "owned_lots": owned_units,
        "nonowned_controlled_lots": nonowned_units,
        "optioned_lots": nonowned_units,
        "total_lots": total_units,
        "nonowned_controlled_share": nonowned_units / total_units,
        "optioned_share": nonowned_units / total_units,
        "owned_share": owned_units / total_units,
        "component_identity_gap": component_identity_gap,
        "component_identity_pass": abs(component_identity_gap) <= 1,
        "total_remaining_acres": total_acres,
        "nonowned_controlled_acres": nonowned_acres,
        "total_tower_sites": total_tower_sites,
        "nonowned_controlled_tower_sites": nonowned_tower_sites,
        "controlled_home_sites_section_value": "",
        "classification_difference_controlled_sites": "",
        "denominator_is_entitlement_capacity": True,
        "not_physical_lots_or_home_sites": True,
        "includes_multifamily_midrise_highrise_units": True,
        "company_usually_builds_fewer_than_max_entitled_units": True,
        "tower_sites_reported_separately": True,
        "fy2008_zero_controlled_supported_by_no_active_option_contracts": fiscal_year == 2008,
        "tower_sites_in_owned_total": False,
        "tower_sites_owned": "",
        "single_multi_family_ex_tower_total_available": False,
        "single_multi_family_ex_tower_total": "",
        "main_panel_eligible": False,
        "alternate_land_control_share_eligible": True,
        "manual_review_flag": True,
        "manual_review_reason": "Old WCI reports entitlement-capacity units rather than lots or home sites; keep as alternate/review-coded series.",
        "extraction_method": "old_wci_entitled_units_communities_table",
        "source_table_index": "",
        "source_row_label": "Our Communities total entitled units and nonowned options/contracts footnote",
        "source_note": (
            "Old WCI numerator is nonowned controlled entitled units from the communities-table footnote; denominator is approximate remaining entitled units. "
            "This is internally coherent but not directly comparable to physical lots or home sites."
        ),
    })

    source_notes.append({
        "ticker": "WCI/WCIC",
        "source_ticker": "WCI",
        "cik10": filing["cik10"],
        "fiscal_year": fiscal_year,
        "source_row_label": "Our Communities total entitled units and nonowned options/contracts footnote",
        "source_excerpt": table_text[:2400],
    })

for fiscal_year in range(2013, 2016):
    filing = filing_by_cik_year[("0001574532", fiscal_year)]
    source_path = Path(filing["primary_document_local_path"])

    if not source_path.exists():
        raise RuntimeError(f"Missing WCIC source file: {source_path}")

    source_text = re.sub(r"\s+", " ", visible_text(source_path))
    status_match = re.search(
        r"Home Sites by Development Status.*?(?:Warranty|Recent and Pending Land Acquisitions)",
        source_text,
        re.I,
    )

    if status_match is None:
        raise RuntimeError(f"Could not find WCIC Home Sites by Development Status table for fiscal {fiscal_year}.")

    status_text = status_match.group(0)
    status_totals = re.findall(r"Total(?: single- and multi-family home sites)? ([\d,]+) ([\d,]+) ([\d,]+)", status_text)

    if len(status_totals) == 0:
        raise RuntimeError(f"Could not extract WCIC development-status totals for fiscal {fiscal_year}.")

    owned_lots = float(status_totals[-1][0].replace(",", ""))
    controlled_lots = float(status_totals[-1][1].replace(",", ""))
    total_lots = float(status_totals[-1][2].replace(",", ""))
    component_identity_gap = owned_lots + controlled_lots - total_lots

    communities_match = re.search(
        r"Total Communities ([\d,]+).*?Total Controlled Home Sites(?:\(\d+\))? ([\d,]+).*?Total Owned and Controlled Home Sites ([\d,]+)",
        source_text,
        re.I,
    )
    controlled_home_sites_section_value = ""
    classification_difference_controlled_sites = ""
    if communities_match is not None:
        controlled_home_sites_section_value = float(communities_match.group(2).replace(",", ""))
        classification_difference_controlled_sites = controlled_lots - controlled_home_sites_section_value

    panel_rows.append({
        "ticker": "WCI/WCIC",
        "source_ticker": "WCIC",
        "cik10": filing["cik10"],
        "sec_company_name": filing["sec_company_name"],
        "fiscal_year": fiscal_year,
        "report_date": filing["report_date"],
        "filing_date": filing["filing_date"],
        "accession_number": filing["accession_number"],
        "primary_document": filing["primary_document"],
        "source_local_path": filing["primary_document_local_path"],
        "source_url": filing["filing_url"],
        "unit_type": "home_sites",
        "owned_lots": owned_lots,
        "nonowned_controlled_lots": controlled_lots,
        "optioned_lots": controlled_lots,
        "total_lots": total_lots,
        "nonowned_controlled_share": controlled_lots / total_lots,
        "optioned_share": controlled_lots / total_lots,
        "owned_share": owned_lots / total_lots,
        "component_identity_gap": component_identity_gap,
        "component_identity_pass": abs(component_identity_gap) <= 1,
        "total_remaining_acres": "",
        "nonowned_controlled_acres": "",
        "total_tower_sites": "",
        "nonowned_controlled_tower_sites": "",
        "controlled_home_sites_section_value": controlled_home_sites_section_value,
        "classification_difference_controlled_sites": classification_difference_controlled_sites,
        "denominator_is_entitlement_capacity": False,
        "not_physical_lots_or_home_sites": False,
        "includes_multifamily_midrise_highrise_units": False,
        "company_usually_builds_fewer_than_max_entitled_units": False,
        "tower_sites_reported_separately": fiscal_year == 2015,
        "fy2008_zero_controlled_supported_by_no_active_option_contracts": False,
        "tower_sites_in_owned_total": fiscal_year == 2015,
        "tower_sites_owned": 1027 if fiscal_year == 2015 else "",
        "single_multi_family_ex_tower_total_available": fiscal_year == 2015,
        "single_multi_family_ex_tower_total": 12285 if fiscal_year == 2015 else "",
        "main_panel_eligible": True,
        "alternate_land_control_share_eligible": True,
        "manual_review_flag": False,
        "manual_review_reason": "",
        "extraction_method": "wcic_development_status_home_sites_table",
        "source_table_index": "",
        "source_row_label": "Home Sites by Development Status total owned / controlled / total",
        "source_note": (
            "Post-reorganization WCIC uses the Home Sites by Development Status table. "
            "For 2015, the development-status controlled total includes 191 controlled sites grouped with active and other communities in the Our Communities table; "
            "the reported total also includes 1,027 owned tower sites."
        ),
    })

    source_notes.append({
        "ticker": "WCI/WCIC",
        "source_ticker": "WCIC",
        "cik10": filing["cik10"],
        "fiscal_year": fiscal_year,
        "source_row_label": "Home Sites by Development Status total owned / controlled / total",
        "source_excerpt": status_text[:2400],
    })

audit_rows = []
for row in panel_rows:
    expected_owned, expected_controlled, expected_total = expected_values[(row["cik10"], row["fiscal_year"])]
    audit_rows.append({
        "audit_check": "expected_values",
        "cik10": row["cik10"],
        "fiscal_year": row["fiscal_year"],
        "status": "ok" if row["owned_lots"] == expected_owned and row["nonowned_controlled_lots"] == expected_controlled and row["total_lots"] == expected_total else "fail",
        "value": f'{row["owned_lots"]}|{row["nonowned_controlled_lots"]}|{row["total_lots"]}',
        "detail": f"Expected {expected_owned}|{expected_controlled}|{expected_total}.",
    })

for fiscal_year, expected_detail in old_wci_detail.items():
    row = [x for x in panel_rows if x["cik10"] == "0001137778" and x["fiscal_year"] == fiscal_year][0]
    audit_rows.append({
        "audit_check": "old_wci_acres_and_tower_sites",
        "cik10": row["cik10"],
        "fiscal_year": fiscal_year,
        "status": "ok" if (
            row["total_remaining_acres"],
            row["nonowned_controlled_acres"],
            row["total_tower_sites"],
            row["nonowned_controlled_tower_sites"],
        ) == expected_detail else "fail",
        "value": f'{row["total_remaining_acres"]}|{row["nonowned_controlled_acres"]}|{row["total_tower_sites"]}|{row["nonowned_controlled_tower_sites"]}',
        "detail": f"Expected {expected_detail[0]}|{expected_detail[1]}|{expected_detail[2]}|{expected_detail[3]}.",
    })

audit_rows.append({
    "audit_check": "firm_year_rows",
    "cik10": "",
    "fiscal_year": "",
    "status": "ok" if len(panel_rows) == 8 else "fail",
    "value": len(panel_rows),
    "detail": "Expected old WCI fiscal 2004-2008 and WCIC fiscal 2013-2015.",
})

audit_rows.append({
    "audit_check": "component_identity",
    "cik10": "",
    "fiscal_year": "",
    "status": "ok" if all(row["component_identity_pass"] is True for row in panel_rows) else "fail",
    "value": sum(row["component_identity_pass"] is True for row in panel_rows),
    "detail": "Owned plus nonowned controlled count must equal total denominator.",
})

write_csv(
    "../output/wci_2004_2015_land_panel.csv",
    panel_rows,
    [
        "ticker", "source_ticker", "cik10", "sec_company_name", "fiscal_year",
        "report_date", "filing_date", "accession_number", "primary_document",
        "source_local_path", "source_url", "unit_type", "owned_lots",
        "nonowned_controlled_lots", "optioned_lots", "total_lots",
        "nonowned_controlled_share", "optioned_share", "owned_share",
        "component_identity_gap", "component_identity_pass", "total_remaining_acres",
        "nonowned_controlled_acres", "total_tower_sites",
        "nonowned_controlled_tower_sites", "controlled_home_sites_section_value",
        "classification_difference_controlled_sites", "denominator_is_entitlement_capacity",
        "not_physical_lots_or_home_sites", "includes_multifamily_midrise_highrise_units",
        "company_usually_builds_fewer_than_max_entitled_units",
        "tower_sites_reported_separately",
        "fy2008_zero_controlled_supported_by_no_active_option_contracts",
        "tower_sites_in_owned_total", "tower_sites_owned",
        "single_multi_family_ex_tower_total_available",
        "single_multi_family_ex_tower_total", "main_panel_eligible",
        "alternate_land_control_share_eligible", "manual_review_flag",
        "manual_review_reason", "extraction_method", "source_table_index",
        "source_row_label", "source_note",
    ],
)

write_csv(
    "../output/wci_2004_2015_extraction_audit.csv",
    audit_rows,
    ["audit_check", "cik10", "fiscal_year", "status", "value", "detail"],
)

write_csv(
    "../output/wci_2004_2015_source_notes.csv",
    source_notes,
    ["ticker", "source_ticker", "cik10", "fiscal_year", "source_row_label", "source_excerpt"],
)
