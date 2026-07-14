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
        if row.get("cik10") == "0000039677"
        and row.get("form") == "10-K"
        and 2004 <= int(float(row.get("fiscal_year"))) <= 2017
    ]

if len(filing_rows) == 0:
    raise RuntimeError("No AV Homes / Avatar filing rows found in land_light_firm_year_measures.csv.")

filing_by_year = {}
for filing in filing_rows:
    fiscal_year = int(float(filing["fiscal_year"]))
    if fiscal_year in filing_by_year:
        raise RuntimeError("AV Homes / Avatar filing rows must be unique by fiscal_year.")
    filing_by_year[fiscal_year] = filing

expected_acres = {
    2004: 21000,
    2005: 22000,
    2006: 17000,
    2007: 17000,
    2008: 16700,
}

expected_land_rows = {
    2009: {"scope": "full_residential_land_holdings", "developed": 3543, "partial": 2369, "raw": 15340, "total": 21252, "llc": 775},
    2010: {"scope": "full_residential_land_holdings", "developed": 4133, "partial": 3606, "raw": 16404, "total": 24143, "llc": 775},
    2011: {"scope": "principal_communities", "developed": 2250, "partial": 1980, "raw": 3695, "total": 7925, "grand": 20445, "jv": 1285},
    2012: {"scope": "principal_communities", "developed": 1975, "partial": 1965, "raw": 3695, "total": 7635, "grand": 17155, "jv": 235},
    2013: {"scope": "principal_communities", "developed": 1994, "partial": 2703, "raw": 9665, "total": 14362, "grand": 19871},
    2014: {"scope": "principal_communities", "developed": 3232, "partial": 2656, "raw": 9948, "total": 15836},
    2015: {"scope": "principal_communities", "developed": 4511, "partial": 2983, "raw": 8621, "total": 16115},
    2016: {"scope": "principal_communities_including_land_under_option_contracts", "developed": 4172, "partial": 2376, "raw": 7883, "total": 14431},
    2017: {"scope": "principal_communities_including_land_under_option_contracts", "developed": 4911, "partial": 2395, "raw": 8776, "total": 16082},
}

panel_rows = []
source_notes = []

for fiscal_year in range(2004, 2018):
    filing = filing_by_year[fiscal_year]
    source_path = Path(filing["primary_document_local_path"])

    if not source_path.exists():
        raise RuntimeError(f"Missing AV Homes / Avatar source file: {source_path}")

    source_text = re.sub(r"\s+", " ", visible_text(source_path))
    raw_text = source_path.read_text(encoding="utf-8", errors="ignore")
    table_parser = SecTableParser()
    table_parser.feed(raw_text)

    acres_owned_lower_bound = ""
    total_lots = ""
    developed_lots = ""
    partially_developed_lots = ""
    raw_lots = ""
    full_residential_land_position_lots = ""
    consolidated_llc_lots = ""
    principal_communities_remaining_lots = ""
    grand_total_residential_lots = ""
    joint_venture_lots = ""
    option_deposits_millions = ""
    source_scope = "acres_only_real_estate_assets"
    source_table_index = ""
    source_row_label = "Real Estate Assets acres disclosure"
    source_excerpt = ""

    if fiscal_year <= 2008:
        acres_match = re.search(
            r"own(?:ed)? more than ([\d,]+(?:\.\d+)?) acres of developed, partially developed or developable residential, commercial and industrial property",
            source_text,
            re.I,
        )
        if acres_match is None:
            raise RuntimeError(f"Could not find AV Homes / Avatar acres-only disclosure for fiscal {fiscal_year}.")

        acres_owned_lower_bound = float(acres_match.group(1).replace(",", ""))
        source_excerpt = source_text[max(0, acres_match.start() - 500):acres_match.end() + 900]

    else:
        source_scope = expected_land_rows[fiscal_year]["scope"]
        for table_index, table in enumerate(table_parser.tables):
            parsed_rows = []
            for html_row in table["rows"]:
                cells = [clean_text(cell.get("text", "")) for cell in html_row]
                cells = [cell for cell in cells if cell]
                if cells:
                    parsed_rows.append(cells)

            table_text = clean_text(" || ".join(" | ".join(cells) for cells in parsed_rows))
            table_text_lower = table_text.lower()
            if fiscal_year in {2009, 2010} and "total residential" not in table_text_lower:
                continue
            if fiscal_year >= 2011 and "total principal communities" not in table_text_lower:
                continue

            source_table_index = str(table_index)
            source_excerpt = table_text[:2600]

            for cells in parsed_rows:
                label = cells[0].lower()
                row_numbers = []
                for value in cells[1:]:
                    value = value.replace(",", "").replace("$", "").strip()
                    if value in {"", "-", "—"}:
                        continue
                    if re.fullmatch(r"\d+(?:\.\d+)?", value):
                        row_numbers.append(float(value))

                if fiscal_year in {2009, 2010} and label == "total residential":
                    developed_lots = row_numbers[0]
                    partially_developed_lots = row_numbers[1]
                    raw_lots = row_numbers[2]
                    total_lots = row_numbers[3]
                    full_residential_land_position_lots = total_lots

                if fiscal_year in {2009, 2010} and label == "total consolidated llcs":
                    consolidated_llc_lots = row_numbers[2]

                if fiscal_year in {2011, 2012} and label == "total principal communities":
                    developed_lots = row_numbers[1]
                    partially_developed_lots = row_numbers[2]
                    raw_lots = row_numbers[3]
                    total_lots = row_numbers[4]
                    principal_communities_remaining_lots = total_lots

                if fiscal_year in {2011, 2012} and label == "grand total":
                    grand_total_residential_lots = row_numbers[4]

                if fiscal_year in {2011, 2012} and label == "joint venture lots":
                    joint_venture_lots = row_numbers[-1]

                if fiscal_year in {2013, 2014} and label == "total principal communities":
                    developed_lots = row_numbers[2]
                    partially_developed_lots = row_numbers[3]
                    raw_lots = row_numbers[4]
                    total_lots = row_numbers[5]
                    principal_communities_remaining_lots = total_lots

                if fiscal_year == 2013 and label == "grand total":
                    grand_total_residential_lots = row_numbers[5]

                if fiscal_year >= 2015 and label == "total principal communities":
                    developed_lots = row_numbers[0]
                    partially_developed_lots = row_numbers[1]
                    raw_lots = row_numbers[2]
                    total_lots = row_numbers[3]
                    principal_communities_remaining_lots = total_lots

            break

        if source_table_index == "":
            raise RuntimeError(f"Could not find AV Homes / Avatar land-position table for fiscal {fiscal_year}.")

        if total_lots == "":
            raise RuntimeError(f"Could not extract AV Homes / Avatar land-position total for fiscal {fiscal_year}.")

        if fiscal_year in {2016, 2017}:
            deposit_match = re.search(
                rf"As of December 31, {fiscal_year}, we had \$([\d\.]+) million of earnest money deposits outstanding on new land purchases and land option contracts",
                source_text,
                re.I,
            )
            if deposit_match is None:
                raise RuntimeError(f"Could not find AV Homes / Avatar option-deposit disclosure for fiscal {fiscal_year}.")
            option_deposits_millions = float(deposit_match.group(1))

    panel_rows.append({
        "ticker": "AVHI",
        "cik10": filing["cik10"],
        "sec_company_name": filing["sec_company_name"],
        "fiscal_year": fiscal_year,
        "report_date": filing["report_date"],
        "filing_date": filing["filing_date"],
        "accession_number": filing["accession_number"],
        "primary_document": filing["primary_document"],
        "source_local_path": filing["primary_document_local_path"],
        "source_url": filing["filing_url"],
        "unit_type": "lots" if fiscal_year >= 2009 else "acres",
        "owned_lots": "",
        "nonowned_controlled_lots": "",
        "optioned_lots": "",
        "total_lots": total_lots,
        "nonowned_controlled_share": "",
        "optioned_share": "",
        "owned_share": "",
        "component_identity_gap": "",
        "component_identity_pass": "",
        "developed_lots": developed_lots,
        "partially_developed_lots": partially_developed_lots,
        "raw_lots": raw_lots,
        "full_residential_land_position_lots": full_residential_land_position_lots,
        "consolidated_llc_lots": consolidated_llc_lots,
        "principal_communities_remaining_lots": principal_communities_remaining_lots,
        "grand_total_residential_lots": grand_total_residential_lots,
        "joint_venture_lots": joint_venture_lots,
        "acres_owned_lower_bound": acres_owned_lower_bound,
        "source_scope": source_scope,
        "includes_land_under_option_contracts_in_total": fiscal_year in {2016, 2017},
        "option_deposits_millions": option_deposits_millions,
        "option_deposits_used_for_omega": False,
        "land_position_total_only": fiscal_year >= 2009,
        "acres_only_no_lot_conversion": fiscal_year <= 2008,
        "omega_not_computable_no_owned_nonowned_split": True,
        "specific_option_disclosed_not_firmwide": fiscal_year in {2011, 2012},
        "extraction_method": "av_homes_audited_land_position_no_omega",
        "source_table_index": source_table_index,
        "source_row_label": source_row_label if fiscal_year <= 2008 else "Total Residential / Total Principal Communities land-position row",
        "panel_use_flag": True,
        "main_panel_eligible": False,
        "manual_review_flag": True,
        "manual_review_reason": "Audited AV Homes / Avatar filing: owned-vs-nonowned physical lot split is not disclosed, so omega is intentionally missing.",
        "source_note": (
            "AV Homes / Avatar land-position disclosures are retained for audit and scale checks. "
            "The task does not convert acres to lots and does not use option deposits as a physical optioned-lot numerator."
        ),
    })

    source_notes.append({
        "ticker": "AVHI",
        "fiscal_year": fiscal_year,
        "source_scope": source_scope,
        "source_table_index": source_table_index,
        "source_row_label": source_row_label if fiscal_year <= 2008 else "Total Residential / Total Principal Communities land-position row",
        "source_excerpt": source_excerpt,
    })

audit_rows = []
for fiscal_year in range(2004, 2009):
    row = [r for r in panel_rows if r["fiscal_year"] == fiscal_year][0]
    audit_rows.append({
        "audit_check": "acres_only_disclosure",
        "fiscal_year": fiscal_year,
        "status": "ok" if row["acres_owned_lower_bound"] == expected_acres[fiscal_year] else "fail",
        "value": row["acres_owned_lower_bound"],
        "detail": f"Expected acres lower bound {expected_acres[fiscal_year]}; no lots are coded.",
    })

for fiscal_year in range(2009, 2018):
    row = [r for r in panel_rows if r["fiscal_year"] == fiscal_year][0]
    expected = expected_land_rows[fiscal_year]
    audit_rows.append({
        "audit_check": "land_position_total",
        "fiscal_year": fiscal_year,
        "status": "ok" if row["total_lots"] == expected["total"] else "fail",
        "value": row["total_lots"],
        "detail": f"Expected {expected['scope']} total {expected['total']}.",
    })
    audit_rows.append({
        "audit_check": "land_position_components",
        "fiscal_year": fiscal_year,
        "status": "ok" if row["developed_lots"] == expected["developed"] and row["partially_developed_lots"] == expected["partial"] and row["raw_lots"] == expected["raw"] else "fail",
        "value": f'{row["developed_lots"]}|{row["partially_developed_lots"]}|{row["raw_lots"]}',
        "detail": f"Expected {expected['developed']}|{expected['partial']}|{expected['raw']}.",
    })

audit_rows.append({
    "audit_check": "omega_missing_all_years",
    "fiscal_year": "",
    "status": "ok" if all(row["nonowned_controlled_share"] == "" for row in panel_rows) else "fail",
    "value": sum(row["nonowned_controlled_share"] == "" for row in panel_rows),
    "detail": "AV Homes / Avatar never discloses a physical owned-vs-nonowned split in the reviewed years.",
})

audit_rows.append({
    "audit_check": "firm_year_rows",
    "fiscal_year": "",
    "status": "ok" if len(panel_rows) == 14 else "fail",
    "value": len(panel_rows),
    "detail": "Expected AV Homes / Avatar fiscal 2004-2017 audited rows.",
})

write_csv(
    "../output/avhi_2004_2017_land_panel.csv",
    panel_rows,
    [
        "ticker", "cik10", "sec_company_name", "fiscal_year", "report_date",
        "filing_date", "accession_number", "primary_document", "source_local_path",
        "source_url", "unit_type", "owned_lots", "nonowned_controlled_lots",
        "optioned_lots", "total_lots", "nonowned_controlled_share",
        "optioned_share", "owned_share", "component_identity_gap",
        "component_identity_pass", "developed_lots", "partially_developed_lots",
        "raw_lots", "full_residential_land_position_lots",
        "consolidated_llc_lots", "principal_communities_remaining_lots",
        "grand_total_residential_lots", "joint_venture_lots",
        "acres_owned_lower_bound", "source_scope",
        "includes_land_under_option_contracts_in_total",
        "option_deposits_millions", "option_deposits_used_for_omega",
        "land_position_total_only", "acres_only_no_lot_conversion",
        "omega_not_computable_no_owned_nonowned_split",
        "specific_option_disclosed_not_firmwide", "extraction_method",
        "source_table_index", "source_row_label", "panel_use_flag",
        "main_panel_eligible", "manual_review_flag", "manual_review_reason",
        "source_note",
    ],
)

write_csv(
    "../output/avhi_2004_2017_extraction_audit.csv",
    audit_rows,
    ["audit_check", "fiscal_year", "status", "value", "detail"],
)

write_csv(
    "../output/avhi_2004_2017_source_notes.csv",
    source_notes,
    ["ticker", "fiscal_year", "source_scope", "source_table_index", "source_row_label", "source_excerpt"],
)
