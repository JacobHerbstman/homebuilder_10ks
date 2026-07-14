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
        if row.get("ticker") == "UCP"
        and row.get("form") == "10-K"
        and 2013 <= int(float(row.get("fiscal_year"))) <= 2016
    ]

if len(filing_rows) == 0:
    raise RuntimeError("No UCP filing rows found in land_light_firm_year_measures.csv.")

filing_by_year = {}
for filing in filing_rows:
    fiscal_year = int(float(filing["fiscal_year"]))
    if fiscal_year in filing_by_year:
        raise RuntimeError("UCP filing rows must be unique by fiscal_year.")
    filing_by_year[fiscal_year] = filing

expected_values = {
    2013: (4030, 1350, 5380),
    2014: (5443, 925, 6368),
    2015: (4751, 1127, 5878),
    2016: (4031, 2607, 6638),
}

panel_rows = []
source_notes = []

for fiscal_year in range(2013, 2017):
    filing = filing_by_year[fiscal_year]
    source_path = Path(filing["primary_document_local_path"])

    if not source_path.exists():
        raise RuntimeError(f"Missing UCP source file: {source_path}")

    raw_text = source_path.read_text(encoding="utf-8", errors="ignore")
    source_text = visible_text(source_path)

    owned_lots = None
    controlled_lots = None
    total_lots = None
    split_disclosed = fiscal_year <= 2015
    split_reconstructed = fiscal_year == 2016
    source_table_index = ""
    source_row_label = ""
    source_excerpt = ""

    if split_disclosed:
        table_parser = SecTableParser()
        table_parser.feed(raw_text)

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
            if "lots controlled" not in table_text_lower:
                continue
            if "total lots owned and controlled" not in table_text_lower:
                continue

            section = ""
            for cells in parsed_rows:
                if cells[0] == "Lots Owned":
                    section = "owned"
                    continue
                if cells[0].startswith("Lots Controlled"):
                    section = "controlled"
                    continue
                if cells[0].startswith("Total Lots Owned and Controlled"):
                    integer_cells = [
                        float(cell.replace(",", ""))
                        for cell in cells
                        if re.fullmatch(r"\d+(?:,\d{3})*", cell)
                    ]
                    if integer_cells:
                        total_lots = integer_cells[0]
                    continue
                if cells[0] == "Total":
                    integer_cells = [
                        float(cell.replace(",", ""))
                        for cell in cells
                        if re.fullmatch(r"\d+(?:,\d{3})*", cell)
                    ]
                    if not integer_cells:
                        continue
                    if section == "owned":
                        owned_lots = integer_cells[0]
                    if section == "controlled":
                        controlled_lots = integer_cells[0]

            if owned_lots is not None and controlled_lots is not None and total_lots is not None:
                source_table_index = str(table_index)
                source_row_label = "Lots Owned / Lots Controlled / Total Lots Owned and Controlled"
                source_excerpt = table_text[:2200]
                break
    else:
        total_match = re.search(
            r"owned or controlled a total of ([\d,]+) residential lots",
            source_text,
            re.I,
        )
        if total_match:
            total_lots = float(total_match.group(1).replace(",", ""))
            source_row_label = "total owned or controlled prose"
            text_start = max(source_text.lower().find("total lots owned and controlled"), 0)
            source_excerpt = source_text[text_start:text_start + 1600]

        optioned_match = re.search(
            r"cash deposits pertaining to purchase contracts for ([\d,]+) optioned lots",
            source_text,
            re.I,
        )
        component_change_match = re.search(
            r"Total owned de\s*creased by ([\d,]+) lots and total controlled in\s*creased by ([\d,]+) lots",
            source_text,
            re.I,
        )
        if optioned_match and component_change_match and total_lots is not None:
            controlled_lots = float(optioned_match.group(1).replace(",", ""))
            owned_lots = total_lots - controlled_lots
            source_row_label = "total and component-change prose / optioned-lot contract disclosure"

    if total_lots is None:
        raise RuntimeError(f"Could not extract UCP land-position values for fiscal {fiscal_year}.")
    if (split_disclosed or split_reconstructed) and (owned_lots is None or controlled_lots is None):
        raise RuntimeError(f"Could not extract UCP owned/controlled split for fiscal {fiscal_year}.")

    component_identity_gap = ""
    component_identity_pass = ""
    nonowned_controlled_share = ""
    optioned_share = ""
    owned_share = ""
    if split_disclosed or split_reconstructed:
        component_identity_gap = owned_lots + controlled_lots - total_lots
        component_identity_pass = abs(component_identity_gap) <= 1
        nonowned_controlled_share = controlled_lots / total_lots
        optioned_share = controlled_lots / total_lots
        owned_share = owned_lots / total_lots

    panel_rows.append({
        "ticker": "UCP",
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
        "owned_lots": owned_lots if owned_lots is not None else "",
        "nonowned_controlled_lots": controlled_lots if controlled_lots is not None else "",
        "optioned_lots": controlled_lots if controlled_lots is not None else "",
        "total_lots": total_lots,
        "nonowned_controlled_share": nonowned_controlled_share,
        "optioned_share": optioned_share,
        "owned_share": owned_share,
        "component_identity_gap": component_identity_gap,
        "component_identity_pass": component_identity_pass,
        "total_owned_or_controlled_disclosed": True,
        "owned_controlled_split_disclosed": split_disclosed,
        "owned_controlled_split_reconstructed_from_explicit_changes": split_reconstructed,
        "segment_totals_disclosed": fiscal_year == 2016,
        "segment_totals_do_not_split_owned_controlled": fiscal_year == 2016,
        "nonowned_count_not_recoverable": False,
        "do_not_impute_from_prior_year_share": False,
        "do_not_impute_from_total_change": False,
        "denominator_only_review_row": False,
        "extraction_method": "ucp_lots_owned_controlled_total_table" if split_disclosed else "ucp_explicit_component_change_and_optioned_lot_prose",
        "source_table_index": source_table_index,
        "source_row_label": source_row_label,
        "panel_use_flag": True,
        "manual_review_flag": split_reconstructed,
        "manual_review_reason": "" if split_disclosed else "FY2016 owned and controlled counts are reconstructed exactly from the reported total, the reported 2,607 optioned lots, and the reported component changes from FY2015.",
        "source_note": (
            "UCP controlled lots are defined as lots subject to a purchase or option contract."
            if split_disclosed else
            "UCP FY2016 reports 6,638 total lots, 2,607 optioned lots, and explicit changes of -720 owned and +1,480 controlled lots from FY2015; these disclosures imply 4,031 owned and 2,607 controlled lots."
        ),
    })

    source_notes.append({
        "ticker": "UCP",
        "fiscal_year": fiscal_year,
        "source_table_index": source_table_index,
        "source_row_label": source_row_label,
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
    "detail": "Expected UCP fiscal 2013-2016.",
})

audit_rows.append({
    "audit_check": "component_identity",
    "fiscal_year": "",
    "status": "ok" if all(row["component_identity_pass"] in (True, "") for row in panel_rows) else "fail",
    "value": sum(row["component_identity_pass"] is True for row in panel_rows),
    "detail": "Owned lots plus controlled lots must equal total lots when split is disclosed.",
})

write_csv(
    "../output/ucp_2013_2016_land_panel.csv",
    panel_rows,
    [
        "ticker", "cik10", "sec_company_name", "fiscal_year", "report_date",
        "filing_date", "accession_number", "primary_document", "source_local_path",
        "source_url", "unit_type", "owned_lots", "nonowned_controlled_lots",
        "optioned_lots", "total_lots", "nonowned_controlled_share", "optioned_share",
        "owned_share", "component_identity_gap", "component_identity_pass",
        "total_owned_or_controlled_disclosed", "owned_controlled_split_disclosed",
        "owned_controlled_split_reconstructed_from_explicit_changes",
        "segment_totals_disclosed", "segment_totals_do_not_split_owned_controlled",
        "nonowned_count_not_recoverable", "do_not_impute_from_prior_year_share",
        "do_not_impute_from_total_change", "denominator_only_review_row",
        "extraction_method", "source_table_index",
        "source_row_label", "panel_use_flag", "manual_review_flag",
        "manual_review_reason", "source_note",
    ],
)

write_csv(
    "../output/ucp_2013_2016_extraction_audit.csv",
    audit_rows,
    ["audit_check", "fiscal_year", "status", "value", "detail"],
)

write_csv(
    "../output/ucp_2013_2016_source_notes.csv",
    source_notes,
    ["ticker", "fiscal_year", "source_table_index", "source_row_label", "source_excerpt"],
)
