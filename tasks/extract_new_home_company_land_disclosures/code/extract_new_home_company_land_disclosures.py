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
        if row.get("cik10") == "0001574596"
        and row.get("form") == "10-K"
        and 2013 <= int(float(row.get("fiscal_year"))) <= 2020
    ]

if len(filing_rows) == 0:
    raise RuntimeError("No New Home Company filing rows found in land_light_firm_year_measures.csv.")

filing_by_year = {}
for filing in filing_rows:
    fiscal_year = int(float(filing["fiscal_year"]))
    if fiscal_year in filing_by_year:
        raise RuntimeError("New Home Company filing rows must be unique by fiscal_year.")
    filing_by_year[fiscal_year] = filing

expected_values = {
    2013: (386, 407, 793, 1311),
    2014: (390, 539, 929, 1105),
    2015: (412, 906, 1318, 1422),
    2016: (590, 986, 1576, 935),
    2017: (946, 1806, 2752, 920),
    2018: (1667, 1145, 2812, 806),
    2019: (1578, 1123, 2701, 1135),
    2020: (1340, 678, 2018, 54),
}

panel_rows = []
source_notes = []

for fiscal_year in range(2013, 2021):
    filing = filing_by_year[fiscal_year]
    source_path = Path("../../build_land_light_measures/code") / filing["primary_document_local_path"]
    source_path = source_path.resolve()

    if not source_path.exists():
        raise RuntimeError(f"Missing New Home Company source file: {source_path}")

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
        if fiscal_year <= 2015:
            if "lots owned" in table_text_lower and "lots controlled" in table_text_lower and "fee building" in table_text_lower:
                if "company total" in table_text_lower or "wholly-owned total" in table_text_lower:
                    source_table_index = str(table_index)
                    source_table_text = table_text
                    break
        else:
            if "lots owned and controlled - wholly owned" in table_text_lower and "fee building" in table_text_lower:
                source_table_index = str(table_index)
                source_table_text = table_text
                break

    if source_table_text == "":
        raise RuntimeError(f"Could not find New Home Company owned/controlled lot table for fiscal {fiscal_year}.")

    if fiscal_year <= 2015:
        main_match = re.search(
            r"(?:Company Total|Wholly-Owned Total)\s*\|\s*([\d,]+)\s*\|\s*([\d,]+)\s*\|\s*([\d,]+)",
            source_table_text,
        )
    else:
        main_match = re.search(
            r"Lots Owned\s*\|?\s*([\d,]+).*?Lots Controlled(?:\s*\(\d+\))?\s*\|?\s*([\d,]+).*?(?:Total\s+)?Lots Owned and Controlled - Wholly Owned\s*\|?\s*([\d,]+)",
            source_table_text,
            re.I,
        )

    if main_match is None:
        raise RuntimeError(f"Could not extract New Home Company main owned/controlled split for fiscal {fiscal_year}.")

    owned_lots = int(main_match.group(1).replace(",", ""))
    controlled_lots = int(main_match.group(2).replace(",", ""))
    total_lots = int(main_match.group(3).replace(",", ""))

    if fiscal_year <= 2015:
        fee_match = re.search(
            r"Fee Building Total\s*\|\s*[^|]+\|\s*([\d,]+)\s*\|\s*([\d,]+)",
            source_table_text,
        )
    else:
        fee_match = re.search(
            r"Fee Building(?: Lots)?(?:\s*\(\d+\))?\s*\|?\s*([\d,]+)",
            source_table_text,
            re.I,
        )

    if fee_match is None:
        raise RuntimeError(f"Could not extract New Home Company fee-building lots for fiscal {fiscal_year}.")

    fee_building_lots = int(fee_match.group(2 if fiscal_year <= 2015 else 1).replace(",", ""))

    jv_owned_lots = ""
    jv_controlled_lots = ""
    jv_total_lots = ""
    jv_match = re.search(
        r"Unconsolidated Joint Ventures Total\s*\|\s*([\d,]+)\s*\|\s*([\d,]+)\s*\|\s*([\d,]+)",
        source_table_text,
    )
    if jv_match is not None:
        jv_owned_lots = int(jv_match.group(1).replace(",", ""))
        jv_controlled_lots = int(jv_match.group(2).replace(",", ""))
        jv_total_lots = int(jv_match.group(3).replace(",", ""))

    definition_match = re.search(
        r"Summary of Owned and Controlled Lots.*?(?:Backlog|Acquisition Process|Table of Contents Backlog)",
        source_text,
        re.I,
    )
    if definition_match is None:
        definition_match = re.search(
            r"As of December 31, \d{4}, we owned or controlled.*?(?:Backlog|Acquisition Process)",
            source_text,
            re.I,
        )

    source_excerpt = source_table_text[:2200]
    if definition_match is not None:
        source_excerpt = definition_match.group(0)[:2200]

    component_identity_gap = owned_lots + controlled_lots - total_lots
    panel_rows.append({
        "ticker": "NWHM",
        "cik10": filing["cik10"],
        "sec_company_name": filing["sec_company_name"],
        "fiscal_year": fiscal_year,
        "report_date": filing["report_date"],
        "filing_date": filing["filing_date"],
        "accession_number": filing["accession_number"],
        "primary_document": filing["primary_document"],
        "source_local_path": filing["primary_document_local_path"],
        "source_url": filing["filing_url"],
        "unit_type": "lots",
        "owned_lots": owned_lots,
        "nonowned_controlled_lots": controlled_lots,
        "optioned_lots": controlled_lots,
        "total_lots": total_lots,
        "nonowned_controlled_share": controlled_lots / total_lots,
        "optioned_share": controlled_lots / total_lots,
        "owned_share": owned_lots / total_lots,
        "component_identity_gap": component_identity_gap,
        "component_identity_pass": abs(component_identity_gap) <= 1,
        "fee_building_lots": fee_building_lots,
        "total_lots_including_fee_building": total_lots + fee_building_lots,
        "mdna_controlled_including_fee_building": controlled_lots + fee_building_lots if fiscal_year <= 2015 else "",
        "unconsolidated_jv_owned_lots": jv_owned_lots,
        "unconsolidated_jv_controlled_lots": jv_controlled_lots,
        "unconsolidated_jv_total_lots": jv_total_lots,
        "fee_building_excluded_from_main": True,
        "unconsolidated_jv_excluded_from_main": True,
        "controlled_definition": "purchase or sale agreements, option agreements, purchase contracts, or non-binding letters of intent subject to customary conditions",
        "extraction_method": "new_home_company_wholly_owned_summary_table",
        "source_table_index": source_table_index,
        "source_row_label": "Company/Wholly-Owned owned lots, controlled lots, and owned plus controlled lots",
        "panel_use_flag": True,
        "manual_review_flag": False,
        "manual_review_reason": "",
        "source_note": (
            "Main series excludes fee-building lots because those are owned by third-party property owners for which NWHM performs general contracting or construction management services. "
            "Unconsolidated joint venture lots are retained separately when the main summary table discloses them."
        ),
    })

    source_notes.append({
        "ticker": "NWHM",
        "fiscal_year": fiscal_year,
        "source_table_index": source_table_index,
        "source_row_label": "Company/Wholly-Owned owned lots, controlled lots, and owned plus controlled lots",
        "source_excerpt": source_excerpt,
    })

audit_rows = []
for row in panel_rows:
    expected_owned, expected_controlled, expected_total, expected_fee = expected_values[row["fiscal_year"]]
    audit_rows.append({
        "audit_check": "expected_values",
        "fiscal_year": row["fiscal_year"],
        "status": "ok" if row["owned_lots"] == expected_owned and row["nonowned_controlled_lots"] == expected_controlled and row["total_lots"] == expected_total and row["fee_building_lots"] == expected_fee else "fail",
        "value": f'{row["owned_lots"]}|{row["nonowned_controlled_lots"]}|{row["total_lots"]}|{row["fee_building_lots"]}',
        "detail": f"Expected {expected_owned}|{expected_controlled}|{expected_total}|{expected_fee}.",
    })

audit_rows.append({
    "audit_check": "firm_year_rows",
    "fiscal_year": "",
    "status": "ok" if len(panel_rows) == 8 else "fail",
    "value": len(panel_rows),
    "detail": "Expected New Home Company fiscal 2013-2020.",
})

audit_rows.append({
    "audit_check": "component_identity",
    "fiscal_year": "",
    "status": "ok" if all(row["component_identity_pass"] is True for row in panel_rows) else "fail",
    "value": sum(row["component_identity_pass"] is True for row in panel_rows),
    "detail": "Company or wholly-owned lots owned plus controlled must equal the main total.",
})

audit_rows.append({
    "audit_check": "fee_building_excluded",
    "fiscal_year": "",
    "status": "ok" if all(row["fee_building_excluded_from_main"] is True for row in panel_rows) else "fail",
    "value": sum(row["fee_building_excluded_from_main"] is True for row in panel_rows),
    "detail": "Fee-building lots are third-party-owned service-project lots and are excluded from the main omega denominator.",
})

write_csv(
    "../output/nwhm_2013_2020_land_panel.csv",
    panel_rows,
    [
        "ticker", "cik10", "sec_company_name", "fiscal_year", "report_date",
        "filing_date", "accession_number", "primary_document", "source_local_path",
        "source_url", "unit_type", "owned_lots", "nonowned_controlled_lots",
        "optioned_lots", "total_lots", "nonowned_controlled_share",
        "optioned_share", "owned_share", "component_identity_gap",
        "component_identity_pass", "fee_building_lots",
        "total_lots_including_fee_building", "mdna_controlled_including_fee_building",
        "unconsolidated_jv_owned_lots", "unconsolidated_jv_controlled_lots",
        "unconsolidated_jv_total_lots", "fee_building_excluded_from_main",
        "unconsolidated_jv_excluded_from_main", "controlled_definition",
        "extraction_method", "source_table_index", "source_row_label",
        "panel_use_flag", "manual_review_flag", "manual_review_reason",
        "source_note",
    ],
)

write_csv(
    "../output/nwhm_2013_2020_extraction_audit.csv",
    audit_rows,
    ["audit_check", "fiscal_year", "status", "value", "detail"],
)

write_csv(
    "../output/nwhm_2013_2020_source_notes.csv",
    source_notes,
    ["ticker", "fiscal_year", "source_table_index", "source_row_label", "source_excerpt"],
)
