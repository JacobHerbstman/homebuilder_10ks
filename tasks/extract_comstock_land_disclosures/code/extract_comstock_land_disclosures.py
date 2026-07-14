#!/usr/bin/env python3

import csv
import re
import sys
from pathlib import Path

from bs4 import BeautifulSoup

sys.path.append(str(Path(__file__).resolve().parents[2] / "_lib"))
from sec_fetch_utils import write_csv

sys.path.append(str(Path(__file__).resolve().parents[1].parent / "extract_10k_land_candidates" / "code"))
from extract_10k_land_candidates import visible_text


def count_value(value):
    value = str(value).replace(",", "").replace("$", "").strip()
    if value in {"", "—", "―", "-", "N/A", "n/a"}:
        return 0
    return int(value)


with open("../input/land_light_firm_year_measures.csv", newline="") as f:
    filing_rows = [
        row for row in csv.DictReader(f)
        if row.get("cik10") == "0001299969"
        and row.get("form") == "10-K"
        and 2006 <= int(float(row.get("fiscal_year"))) <= 2016
    ]

if len(filing_rows) == 0:
    raise RuntimeError("No Comstock filing rows found in land_light_firm_year_measures.csv.")

filing_by_year = {}
for filing in filing_rows:
    fiscal_year = int(float(filing["fiscal_year"]))
    if fiscal_year in filing_by_year:
        raise RuntimeError("Comstock filing rows must be unique by fiscal_year.")
    filing_by_year[fiscal_year] = filing

expected_values = {
    2006: {"estimated": 6764, "settled": 1417, "backlog": 317, "owned": 2881, "nonowned": 2154, "foreclosed": 0, "table_total": 5352, "main": True},
    2007: {"estimated": 4188, "settled": 1528, "backlog": 70, "owned": 2102, "nonowned": 488, "foreclosed": 0, "table_total": 2660, "main": True},
    2008: {"estimated": 3200, "settled": 1352, "backlog": 11, "owned": 1349, "nonowned": 488, "foreclosed": 0, "table_total": 1848, "main": True},
    2009: {"estimated": 2749, "settled": 1423, "backlog": 4, "owned": 940, "nonowned": 0, "foreclosed": 382, "table_total": 944, "main": True},
    2010: {"estimated": 1226, "settled": 855, "backlog": 1, "owned": 117, "nonowned": None, "foreclosed": 0, "table_total": None, "main": False},
    2011: {"estimated": 1500, "settled": 901, "backlog": 3, "owned": 6, "nonowned": None, "foreclosed": 0, "table_total": None, "main": False},
    2012: {"estimated": 1622, "settled": 946, "backlog": 9, "owned": 6, "nonowned": None, "foreclosed": 0, "table_total": None, "main": False},
    2013: {"estimated": 657, "settled": 164, "backlog": 28, "owned": 465, "nonowned": 0, "foreclosed": 0, "table_total": 493, "main": True},
    2014: {"estimated": 1146, "settled": 200, "backlog": 24, "owned": 371, "nonowned": 551, "foreclosed": 0, "table_total": 946, "main": True},
    2015: {"estimated": 849, "settled": 323, "backlog": 25, "owned": 256, "nonowned": 245, "foreclosed": 0, "table_total": 526, "main": True},
    2016: {"estimated": 928, "settled": 417, "backlog": 35, "owned": 262, "nonowned": 214, "foreclosed": 0, "table_total": 511, "main": True},
}

panel_rows = []
source_notes = []

for fiscal_year in range(2006, 2017):
    filing = filing_by_year[fiscal_year]
    source_path = Path("../../build_land_light_measures/code") / filing["primary_document_local_path"]
    source_path = source_path.resolve()

    if not source_path.exists():
        raise RuntimeError(f"Missing Comstock source file: {source_path}")

    source_text = re.sub(r"\s+", " ", visible_text(source_path))
    source_excerpt = ""
    foreclosed_lots = 0
    nonowned_controlled_lots = None
    table_total_including_backlog = None

    if fiscal_year in {2006, 2007, 2008}:
        total_match = re.search(
            r"Total Active [&amp; ]+Development\s+([\d,]+)\s+([\d,]+)\s+([\d,]+)\s+([\d,]+)\s+([\d,]+)",
            source_text,
            re.I,
        )
        if total_match is None:
            raise RuntimeError(f"Could not extract Comstock total active and development row for fiscal {fiscal_year}.")
        estimated_units = count_value(total_match.group(1))
        settled_units = count_value(total_match.group(2))
        backlog_units = count_value(total_match.group(3))
        owned_lots = count_value(total_match.group(4))
        nonowned_controlled_lots = count_value(total_match.group(5))
        table_total_including_backlog = backlog_units + owned_lots + nonowned_controlled_lots
        source_excerpt = source_text[total_match.start():total_match.start() + 1800]

    if fiscal_year == 2009:
        total_match = re.search(
            r"Total Active [&amp; ]+Development\s+([\d,]+)\s+([\d,]+)\s+([\d,]+)\s+([\d,]+)\s+([\d,]+)\s+(—|―|-|[\d,]+)",
            source_text,
            re.I,
        )
        if total_match is None:
            raise RuntimeError("Could not extract Comstock 2009 foreclosure total row.")
        estimated_units = count_value(total_match.group(1))
        settled_units = count_value(total_match.group(2))
        backlog_units = count_value(total_match.group(3))
        foreclosed_lots = count_value(total_match.group(4))
        owned_lots = count_value(total_match.group(5))
        nonowned_controlled_lots = count_value(total_match.group(6))
        table_total_including_backlog = backlog_units + owned_lots + nonowned_controlled_lots
        source_excerpt = source_text[total_match.start():total_match.start() + 1800]

    if fiscal_year in {2010, 2011, 2012}:
        soup = BeautifulSoup(source_path.read_text(errors="ignore"), "html.parser")
        table = None
        table_index = ""
        for index, candidate in enumerate(soup.find_all("table")):
            table_text = " ".join(candidate.get_text(" ", strip=True).split())
            if "Lots Owned Unsold" in table_text:
                table = candidate
                table_index = str(index)
                break
        if table is None:
            raise RuntimeError(f"Could not find Comstock owned-unsold table for fiscal {fiscal_year}.")

        estimated_units = 0
        settled_units = 0
        backlog_units = 0
        owned_lots = 0
        for tr in table.find_all("tr"):
            cells = [" ".join(td.get_text(" ", strip=True).split()) for td in tr.find_all(["td", "th"])]
            cells = [cell for cell in cells if cell != ""]
            if len(cells) < 7 or cells[0] in {"Project", "Total"} or cells[0].startswith("As of"):
                continue
            estimated_units += count_value(cells[3])
            settled_units += count_value(cells[4])
            backlog_units += count_value(cells[5])
            owned_lots += count_value(cells[6])
        source_excerpt = " ".join(table.get_text(" ", strip=True).split())[:1800]

    if fiscal_year == 2013:
        total_match = re.search(
            r"Total\s+([\d,]+)\s+([\d,]+)\s+([\d,]+)\s+([\d,]+)\s+(—|―|-|[\d,]+)\s+[\d,]+",
            source_text,
            re.I,
        )
        if total_match is None:
            raise RuntimeError("Could not extract Comstock 2013 total row.")
        estimated_units = count_value(total_match.group(1))
        settled_units = count_value(total_match.group(2))
        backlog_units = count_value(total_match.group(3))
        owned_lots = count_value(total_match.group(4))
        nonowned_controlled_lots = count_value(total_match.group(5))
        table_total_including_backlog = backlog_units + owned_lots + nonowned_controlled_lots
        source_excerpt = source_text[total_match.start():total_match.start() + 1800]

    if fiscal_year in {2014, 2015, 2016}:
        anchor = source_text.find(f"Pipeline Report as of December 31, {fiscal_year}")
        if anchor < 0:
            raise RuntimeError(f"Could not find Comstock pipeline report anchor for fiscal {fiscal_year}.")
        total_match = re.search(
            r"Total\s+([\d,]+)\s+([\d,]+)\s+([\d,]+)\s+([\d,]+)\s+([\d,]+)\s+([\d,]+)",
            source_text[anchor:anchor + 6000],
            re.I,
        )
        if total_match is None:
            raise RuntimeError(f"Could not extract Comstock pipeline report total row for fiscal {fiscal_year}.")
        estimated_units = count_value(total_match.group(1))
        settled_units = count_value(total_match.group(2))
        backlog_units = count_value(total_match.group(3))
        owned_lots = count_value(total_match.group(4))
        nonowned_controlled_lots = count_value(total_match.group(5))
        table_total_including_backlog = count_value(total_match.group(6))
        source_excerpt = source_text[anchor + total_match.start():anchor + total_match.start() + 1800]

    main_panel_eligible = expected_values[fiscal_year]["main"]
    total_lots = None
    nonowned_controlled_share = None
    owned_share = None
    backlog_inclusive_nonowned_controlled_share = None
    component_identity_gap = None
    component_identity_pass = None

    if nonowned_controlled_lots is not None:
        total_lots = owned_lots + nonowned_controlled_lots
        nonowned_controlled_share = nonowned_controlled_lots / total_lots if total_lots > 0 else None
        owned_share = owned_lots / total_lots if total_lots > 0 else None
        backlog_inclusive_nonowned_controlled_share = (
            nonowned_controlled_lots / table_total_including_backlog
            if table_total_including_backlog is not None and table_total_including_backlog > 0
            else None
        )
        component_identity_gap = backlog_units + owned_lots + nonowned_controlled_lots - table_total_including_backlog
        component_identity_pass = abs(component_identity_gap) <= 1

    manual_review_reason = ""
    if fiscal_year == 2009:
        manual_review_reason = "Foreclosed and bankruptcy-transfer lots are disclosed in a separate table column and excluded from omega; the reported owned-unsold and optioned-unsold columns imply an exact zero option share."
    if fiscal_year in {2010, 2011, 2012}:
        manual_review_reason = "Filing discloses lots owned unsold and identifies some communities as under control, but does not disclose a nonowned control count; omega is missing."

    panel_rows.append({
        "ticker": "CHCI",
        "cik10": filing["cik10"],
        "sec_company_name": filing["sec_company_name"],
        "fiscal_year": fiscal_year,
        "report_date": f"{fiscal_year}-12-31",
        "filing_date": filing["filing_date"],
        "accession_number": filing["accession_number"],
        "primary_document": filing["primary_document"],
        "source_local_path": filing["primary_document_local_path"],
        "source_url": filing["filing_url"],
        "unit_type": "lots_or_units",
        "estimated_units_at_completion": estimated_units,
        "settled_units": settled_units,
        "backlog_units": backlog_units,
        "owned_lots": owned_lots,
        "nonowned_controlled_lots": nonowned_controlled_lots,
        "optioned_lots": nonowned_controlled_lots,
        "total_lots": total_lots,
        "table_total_including_backlog": table_total_including_backlog,
        "nonowned_controlled_share": nonowned_controlled_share,
        "optioned_share": nonowned_controlled_share,
        "owned_share": owned_share,
        "backlog_inclusive_nonowned_controlled_share": backlog_inclusive_nonowned_controlled_share,
        "component_identity_gap": component_identity_gap,
        "component_identity_pass": component_identity_pass,
        "foreclosed_lots": foreclosed_lots,
        "foreclosed_lots_excluded_from_main": foreclosed_lots > 0,
        "backlog_excluded_from_main": True,
        "unit_label_changes_lots_to_units": fiscal_year >= 2014,
        "distressed_denominator_conflict": fiscal_year == 2009,
        "nonowned_count_not_disclosed": fiscal_year in {2010, 2011, 2012},
        "table_total_includes_backlog": table_total_including_backlog is not None,
        "nonowned_label_raw": "lots_under_option_agreement_unsold" if fiscal_year <= 2013 else "units_under_control_land_option_purchase_contract_not_owned",
        "extraction_method": "comstock_pipeline_table_total_row",
        "source_table_index": table_index if fiscal_year in {2010, 2011, 2012} else "",
        "source_row_label": "Total Active & Development" if fiscal_year <= 2009 else "Total",
        "panel_use_flag": True,
        "main_panel_eligible": main_panel_eligible,
        "manual_review_flag": fiscal_year in {2009, 2010, 2011, 2012},
        "manual_review_reason": manual_review_reason,
        "source_note": "Main omega excludes backlog and uses owned unsold plus nonowned option/control lots or units. Backlog-inclusive table totals are retained separately where disclosed.",
    })

    source_notes.append({
        "ticker": "CHCI",
        "fiscal_year": fiscal_year,
        "source_table_index": table_index if fiscal_year in {2010, 2011, 2012} else "",
        "source_row_label": "Total Active & Development" if fiscal_year <= 2009 else "Total",
        "source_excerpt": source_excerpt,
    })

audit_rows = []
for row in panel_rows:
    expected = expected_values[row["fiscal_year"]]
    observed = (
        row["estimated_units_at_completion"],
        row["settled_units"],
        row["backlog_units"],
        row["owned_lots"],
        row["nonowned_controlled_lots"],
        row["foreclosed_lots"],
        row["table_total_including_backlog"],
        row["main_panel_eligible"],
    )
    target = (
        expected["estimated"],
        expected["settled"],
        expected["backlog"],
        expected["owned"],
        expected["nonowned"],
        expected["foreclosed"],
        expected["table_total"],
        expected["main"],
    )
    audit_rows.append({
        "audit_check": "expected_values",
        "fiscal_year": row["fiscal_year"],
        "status": "ok" if observed == target else "fail",
        "value": "|".join("" if value is None else str(value) for value in observed),
        "detail": "Expected " + "|".join("" if value is None else str(value) for value in target) + ".",
    })

audit_rows.append({
    "audit_check": "firm_year_rows",
    "fiscal_year": "",
    "status": "ok" if len(panel_rows) == 11 else "fail",
    "value": len(panel_rows),
    "detail": "Expected Comstock fiscal 2006-2016 audited rows.",
})

audit_rows.append({
    "audit_check": "main_eligible_years",
    "fiscal_year": "",
    "status": "ok" if sum(row["main_panel_eligible"] is True for row in panel_rows) == 8 else "fail",
    "value": sum(row["main_panel_eligible"] is True for row in panel_rows),
    "detail": "Expected 8 main-eligible years: 2006-2009 and 2013-2016. The 2009 restructuring year remains review-flagged but has an exact reported owned/optioned split.",
})

audit_rows.append({
    "audit_check": "missing_nonowned_control_years",
    "fiscal_year": "",
    "status": "ok" if [row["fiscal_year"] for row in panel_rows if row["nonowned_controlled_lots"] is None] == [2010, 2011, 2012] else "fail",
    "value": "|".join(str(row["fiscal_year"]) for row in panel_rows if row["nonowned_controlled_lots"] is None),
    "detail": "Expected 2010-2012 to have no disclosed nonowned/control count.",
})

write_csv(
    "../output/chci_2006_2016_land_panel.csv",
    panel_rows,
    [
        "ticker", "cik10", "sec_company_name", "fiscal_year", "report_date",
        "filing_date", "accession_number", "primary_document", "source_local_path",
        "source_url", "unit_type", "estimated_units_at_completion", "settled_units",
        "backlog_units", "owned_lots", "nonowned_controlled_lots", "optioned_lots",
        "total_lots", "table_total_including_backlog",
        "nonowned_controlled_share", "optioned_share", "owned_share",
        "backlog_inclusive_nonowned_controlled_share", "component_identity_gap",
        "component_identity_pass", "foreclosed_lots",
        "foreclosed_lots_excluded_from_main", "backlog_excluded_from_main",
        "unit_label_changes_lots_to_units", "distressed_denominator_conflict",
        "nonowned_count_not_disclosed", "table_total_includes_backlog",
        "nonowned_label_raw", "extraction_method",
        "source_table_index", "source_row_label", "panel_use_flag",
        "main_panel_eligible", "manual_review_flag", "manual_review_reason",
        "source_note",
    ],
)

write_csv(
    "../output/chci_2006_2016_extraction_audit.csv",
    audit_rows,
    ["audit_check", "fiscal_year", "status", "value", "detail"],
)

write_csv(
    "../output/chci_2006_2016_source_notes.csv",
    source_notes,
    ["ticker", "fiscal_year", "source_table_index", "source_row_label", "source_excerpt"],
)
