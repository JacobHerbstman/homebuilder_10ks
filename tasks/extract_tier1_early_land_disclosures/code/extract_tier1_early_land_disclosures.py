#!/usr/bin/env python3

import csv
import re
import sys
from pathlib import Path

sys.path.append(str(Path(__file__).resolve().parents[2] / "_lib"))
from sec_fetch_utils import write_csv

sys.path.append(str(Path(__file__).resolve().parents[1].parent / "extract_10k_land_candidates" / "code"))
from extract_10k_land_candidates import SecTableParser, VisibleTextParser, clean_text


with open("../input/land_light_firm_year_measures.csv", newline="") as f:
    filing_rows = [
        row for row in csv.DictReader(f)
        if row.get("ticker") in ("BZH", "DHI", "HOV", "KBH", "LEN", "PHM")
        and row.get("form") == "10-K"
        and 2004 <= int(float(row.get("fiscal_year"))) <= 2005
    ]

if len(filing_rows) == 0:
    raise RuntimeError("No Tier-1 early filing rows found in land_light_firm_year_measures.csv.")

filing_by_key = {}
for filing in filing_rows:
    fiscal_year = int(float(filing["fiscal_year"]))
    key = (filing["ticker"], fiscal_year)
    if key in filing_by_key:
        raise RuntimeError("Tier-1 early filing rows must be unique by ticker/fiscal_year.")
    filing_by_key[key] = filing

panel_rows = []
source_notes = []

for ticker, fiscal_year in [
    ("BZH", 2004),
    ("DHI", 2004),
    ("DHI", 2005),
    ("HOV", 2004),
    ("HOV", 2005),
    ("KBH", 2004),
    ("KBH", 2005),
    ("LEN", 2004),
    ("LEN", 2005),
    ("PHM", 2004),
    ("PHM", 2005),
]:
    source_fiscal_year = fiscal_year
    if (ticker, fiscal_year) in (("HOV", 2004), ("LEN", 2004)):
        source_fiscal_year = 2005

    filing = filing_by_key[(ticker, source_fiscal_year)]
    source_path = Path(filing["primary_document_local_path"])

    if not source_path.exists():
        raise RuntimeError(f"Missing source file for {ticker} {fiscal_year}: {source_path}")

    raw_text = source_path.read_text(encoding="utf-8", errors="ignore")
    table_parser = SecTableParser()
    table_parser.feed(raw_text)
    visible_parser = VisibleTextParser()
    visible_parser.feed(raw_text)
    visible_text = clean_text(visible_parser.text())

    owned_lots = None
    nonowned_controlled_lots = None
    optioned_lots = None
    jv_lots = None
    construction_to_perm_lots = None
    total_lots = None
    unit_type = "lots"
    extraction_method = ""
    precision = "reported_table"
    source_table_index = ""
    source_excerpt = ""
    source_note = ""
    manual_review_flag = False
    manual_review_reason = ""
    approximate_flag = False

    if ticker == "BZH":
        match = re.search(
            r"Land Bank Lots Percentage Owned\s+([0-9,]+)\s+47\s+%\s+Optioned\s+([0-9,]+)\s+53\s+%\s+Total\s+([0-9,]+)\s+100\s+%",
            visible_text,
            re.IGNORECASE,
        )
        if match is None:
            raise RuntimeError("Could not find Beazer 2004 land bank table.")

        owned_lots = float(match.group(1).replace(",", ""))
        nonowned_controlled_lots = float(match.group(2).replace(",", ""))
        optioned_lots = nonowned_controlled_lots
        total_lots = float(match.group(3).replace(",", ""))
        extraction_method = "land_bank_owned_optioned_total_table"
        source_excerpt = visible_text[max(0, match.start() - 700):min(len(visible_text), match.end() + 900)]
        source_note = "BZH 2004 Land Bank table reports owned, optioned, and total controlled lots; detailed state table corroborates the same total row."

    if ticker == "DHI":
        for table_index, table in enumerate(table_parser.tables):
            rows = []
            for html_row in table["rows"]:
                cells = [clean_text(cell.get("text", "")) for cell in html_row]
                cells = [cell for cell in cells if cell]
                if cells:
                    rows.append(cells)

            table_text = clean_text(" || ".join(" | ".join(cells) for cells in rows))
            if "Total land/lots controlled" not in table_text:
                continue
            if "Lots controlled under lot option and similar contracts" not in table_text:
                continue
            if str(fiscal_year) not in table_text:
                continue

            for cells in rows:
                if len(cells) < 2:
                    continue
                if cells[0] in ("Total lots owned", "Lots owned — developed and under development"):
                    owned_lots = float(cells[1].replace(",", ""))
                if cells[0] == "Lots controlled under lot option and similar contracts":
                    nonowned_controlled_lots = float(cells[1].replace(",", ""))
                    optioned_lots = nonowned_controlled_lots
                if cells[0] == "Total land/lots controlled":
                    total_lots = float(cells[1].replace(",", ""))

            source_table_index = str(table_index)
            source_excerpt = table_text[:1400]
            extraction_method = "dhi_land_lot_position_table"
            source_note = "DHI early table reports lots owned, lots controlled under lot option and similar contracts, and total land/lots controlled."
            break

    if ticker == "PHM":
        match = re.search(
            r"At December 31, [0-9]{4}, we controlled approximately ([0-9,]+) lots, of which ([0-9,]+) were owned and ([0-9,]+) were under option agreements",
            visible_text,
            re.IGNORECASE,
        )
        if match is None:
            raise RuntimeError(f"Could not find Pulte early prose disclosure for {fiscal_year}.")

        total_lots = float(match.group(1).replace(",", ""))
        owned_lots = float(match.group(2).replace(",", ""))
        nonowned_controlled_lots = float(match.group(3).replace(",", ""))
        optioned_lots = nonowned_controlled_lots
        approximate_flag = True
        precision = "rounded_prose"
        extraction_method = "pulte_owned_optioned_controlled_prose"
        source_excerpt = visible_text[max(0, match.start() - 700):min(len(visible_text), match.end() + 900)]
        source_note = "Pulte early prose reports approximate controlled, owned, and under-option lot counts; rounded components reconcile."

    if ticker == "KBH":
        for table_index, table in enumerate(table_parser.tables):
            rows = []
            for html_row in table["rows"]:
                cells = [clean_text(cell.get("text", "")) for cell in html_row]
                cells = [cell for cell in cells if cell]
                if cells:
                    rows.append(cells)

            table_text = clean_text(" || ".join(" | ".join(cells) for cells in rows))
            if "Total Lots" not in table_text:
                continue
            if "Homes/Lots in" not in table_text or "Lots Under" not in table_text:
                continue

            for cells in rows:
                if len(cells) >= 8 and cells[0] == "Total":
                    homes_lots_in_production = float(cells[1].replace(",", ""))
                    land_under_development = float(cells[3].replace(",", ""))
                    optioned_lots = float(cells[5].replace(",", ""))
                    total_lots = float(cells[7].replace(",", ""))
                    owned_lots = homes_lots_in_production + land_under_development
                    nonowned_controlled_lots = optioned_lots
                    break

            if total_lots is not None:
                source_table_index = str(table_index)
                source_excerpt = table_text[:1400]
                extraction_method = "kbh_total_lots_owned_or_under_option_table"
                source_note = "KBH owned lots are homes/lots in production plus land under development; nonowned controlled lots are lots under option."
                break

    if ticker == "LEN":
        unit_type = "homesites"
        for table_index, table in enumerate(table_parser.tables):
            rows = []
            for html_row in table["rows"]:
                cells = [clean_text(cell.get("text", "")) for cell in html_row]
                cells = [cell for cell in cells if cell]
                if cells:
                    rows.append(cells)

            table_text = clean_text(" || ".join(" | ".join(cells) for cells in rows))
            if "Controlled" not in table_text or "Optioned" not in table_text or "JVs" not in table_text:
                continue

            current_year_block = False
            for cells in rows:
                if cells == [f"November 30, {fiscal_year}", "Owned", "Optioned", "JVs", "Total"]:
                    current_year_block = True
                    continue
                if len(cells) == 5 and cells[0] == "Total" and current_year_block:
                    owned_lots = float(cells[1].replace(",", ""))
                    optioned_lots = float(cells[2].replace(",", ""))
                    jv_lots = float(cells[3].replace(",", ""))
                    nonowned_controlled_lots = optioned_lots + jv_lots
                    total_lots = float(cells[4].replace(",", ""))
                    break

            if total_lots is not None:
                source_table_index = str(table_index)
                source_excerpt = table_text[:1600]
                extraction_method = (
                    "lennar_2005_comparative_controlled_homesites_table"
                    if fiscal_year == 2004
                    else "lennar_controlled_homesites_table"
                )
                source_note = "Lennar controlled homesites equal optioned plus JV homesites in this table."
                if fiscal_year == 2004:
                    manual_review_flag = True
                    manual_review_reason = "uses_2005_comparative_row_for_2004_optioned_jv_split"
                    source_note = source_note + " Fiscal 2004 uses the exact 2005 comparative row; it reconciles to the 2004 filing's controlled-homesites total."
                break

    if ticker == "HOV":
        unit_type = "homesites"
        for table_index, table in enumerate(table_parser.tables):
            rows = []
            for html_row in table["rows"]:
                cells = [clean_text(cell.get("text", "")) for cell in html_row]
                cells = [cell for cell in cells if cell]
                if cells:
                    rows.append(cells)

            table_text = clean_text(" || ".join(" | ".join(cells) for cells in rows))
            if "Total Home Sites" not in table_text:
                continue
            if "Construction to permanent financing lots" not in table_text:
                continue

            current_year_block = False
            consolidated_total = None
            for cells in rows:
                if cells == [f"October 31, {fiscal_year}:"]:
                    current_year_block = True
                    continue
                if len(cells) == 1 and cells[0].startswith("October 31, ") and cells[0] != f"October 31, {fiscal_year}:":
                    current_year_block = False
                if not current_year_block or len(cells) < 2:
                    continue

                if cells[0] == "Consolidated Total":
                    consolidated_total = float(cells[1].replace(",", ""))
                if cells[0] == "Owned":
                    owned_lots = float(cells[1].replace(",", ""))
                if cells[0] == "Optioned":
                    optioned_lots = float(cells[1].replace(",", ""))
                    nonowned_controlled_lots = optioned_lots
                if cells[0] == "Construction to permanent financing lots":
                    construction_to_perm_lots = float(cells[1].replace(",", ""))
                if cells[0] == "Lots controlled by unconsolidated joint ventures":
                    jv_lots = float(cells[1].replace(",", ""))

            if consolidated_total is not None:
                total_lots = consolidated_total
                source_table_index = str(table_index)
                source_excerpt = table_text[:2200]
                extraction_method = (
                    "hov_2005_comparative_total_home_sites_table"
                    if fiscal_year == 2004
                    else "hov_total_home_sites_table"
                )
                source_note = "HOV denominator is consolidated total home sites. The selected series uses optioned home sites as the numerator to match the later HOV optioned-share convention; construction-to-permanent lots are included in the consolidated denominator and retained separately, while unconsolidated JV lots are retained outside the denominator."
                if fiscal_year == 2004:
                    manual_review_flag = True
                    manual_review_reason = "uses_2005_comparative_row_for_2004_consolidated_total_definition"
                break

    if total_lots is None or owned_lots is None or nonowned_controlled_lots is None:
        raise RuntimeError(f"Failed to extract a complete early row for {ticker} {fiscal_year}.")

    component_identity_gap = owned_lots + nonowned_controlled_lots + (construction_to_perm_lots or 0) - total_lots
    if ticker == "LEN":
        component_identity_gap = owned_lots + optioned_lots + jv_lots - total_lots

    panel_rows.append({
        "ticker": ticker,
        "cik10": filing["cik10"],
        "sec_company_name": filing["sec_company_name"],
        "fiscal_year": fiscal_year,
        "report_date": filing_by_key[(ticker, fiscal_year)]["report_date"],
        "filing_date": filing["filing_date"],
        "accession_number": filing_by_key[(ticker, fiscal_year)]["accession_number"],
        "source_accession_number": filing["accession_number"],
        "primary_document": filing["primary_document"],
        "source_local_path": filing["primary_document_local_path"],
        "source_url": filing["filing_url"],
        "unit_type": unit_type,
        "owned_lots": owned_lots,
        "nonowned_controlled_lots": nonowned_controlled_lots,
        "optioned_lots": optioned_lots,
        "jv_lots": jv_lots,
        "construction_to_perm_lots": construction_to_perm_lots,
        "total_lots": total_lots,
        "nonowned_controlled_share": nonowned_controlled_lots / total_lots,
        "optioned_share": optioned_lots / total_lots if optioned_lots is not None else None,
        "owned_share": owned_lots / total_lots,
        "component_identity_gap": component_identity_gap,
        "component_identity_pass": abs(component_identity_gap) <= 1,
        "approximate_flag": approximate_flag,
        "extraction_method": extraction_method,
        "precision": precision,
        "source_fiscal_year": source_fiscal_year,
        "source_table_index": source_table_index,
        "source_row_label": "Total",
        "uses_later_comparative_prior_year_row": source_fiscal_year != fiscal_year,
        "panel_use_flag": True,
        "manual_review_flag": manual_review_flag,
        "manual_review_reason": manual_review_reason,
        "source_note": source_note,
    })

    source_notes.append({
        "ticker": ticker,
        "fiscal_year": fiscal_year,
        "source_fiscal_year": source_fiscal_year,
        "extraction_method": extraction_method,
        "source_excerpt": source_excerpt,
    })

audit_rows = [
    {
        "audit_check": "firm_year_rows",
        "status": "ok" if len(panel_rows) == 11 else "fail",
        "value": len(panel_rows),
        "detail": "Expected BZH 2004 plus DHI/HOV/KBH/LEN/PHM 2004-2005.",
    },
    {
        "audit_check": "component_identity",
        "status": "ok" if all(row["component_identity_pass"] for row in panel_rows) else "fail",
        "value": sum(row["component_identity_pass"] for row in panel_rows),
        "detail": "Owned plus nonowned components must reconcile to the chosen denominator.",
    },
    {
        "audit_check": "share_in_range",
        "status": "ok" if all(0 <= row["nonowned_controlled_share"] <= 1 for row in panel_rows) else "fail",
        "value": sum(0 <= row["nonowned_controlled_share"] <= 1 for row in panel_rows),
        "detail": "All extracted nonowned controlled shares should be between zero and one.",
    },
    {
        "audit_check": "later_comparative_rows",
        "status": "ok" if sum(row["uses_later_comparative_prior_year_row"] for row in panel_rows) == 2 else "fail",
        "value": sum(row["uses_later_comparative_prior_year_row"] for row in panel_rows),
        "detail": "Expected later comparative rows for LEN 2004 and HOV 2004 only.",
    },
    {
        "audit_check": "rounded_prose_rows",
        "status": "ok" if sum(row["approximate_flag"] for row in panel_rows) == 2 else "fail",
        "value": sum(row["approximate_flag"] for row in panel_rows),
        "detail": "Expected rounded prose rows for PHM 2004 and PHM 2005.",
    },
]

write_csv(
    "../output/tier1_early_2004_2005_land_panel.csv",
    panel_rows,
    [
        "ticker", "cik10", "sec_company_name", "fiscal_year", "report_date", "filing_date",
        "accession_number", "source_accession_number", "primary_document", "source_local_path",
        "source_url", "unit_type", "owned_lots", "nonowned_controlled_lots",
        "optioned_lots", "jv_lots", "construction_to_perm_lots", "total_lots",
        "nonowned_controlled_share", "optioned_share", "owned_share",
        "component_identity_gap", "component_identity_pass", "approximate_flag",
        "extraction_method", "precision", "source_fiscal_year", "source_table_index",
        "source_row_label", "uses_later_comparative_prior_year_row", "panel_use_flag",
        "manual_review_flag", "manual_review_reason", "source_note",
    ],
)

write_csv(
    "../output/tier1_early_2004_2005_extraction_audit.csv",
    audit_rows,
    ["audit_check", "status", "value", "detail"],
)

write_csv(
    "../output/tier1_early_2004_2005_source_notes.csv",
    source_notes,
    ["ticker", "fiscal_year", "source_fiscal_year", "extraction_method", "source_excerpt"],
)
