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
        if row.get("cik10") == "0001095996"
        and row.get("form") == "10-K"
        and 2004 <= int(float(row.get("fiscal_year"))) <= 2018
    ]

if len(filing_rows) == 0:
    raise RuntimeError("No William Lyon Homes filing rows found in land_light_firm_year_measures.csv.")

filing_by_year = {}
for filing in filing_rows:
    fiscal_year = int(float(filing["fiscal_year"]))
    if fiscal_year in filing_by_year:
        raise RuntimeError("William Lyon Homes filing rows must be unique by fiscal_year.")
    filing_by_year[fiscal_year] = filing

source_fiscal_year_by_year = {
    2004: 2004,
    2005: 2005,
    2006: 2008,
    2007: 2008,
    2008: 2008,
    2009: 2009,
    2010: 2010,
    2011: 2012,
    2012: 2012,
    2013: 2013,
    2014: 2014,
    2015: 2015,
    2016: 2016,
    2017: 2017,
    2018: 2018,
}

expected_values = {
    2004: (8858, 9754, 18612),
    2005: (11518, 15071, 26589),
    2006: (13288, 7377, 20665),
    2007: (13624, 837, 14461),
    2008: (11605, 727, 12332),
    2009: (9124, 1206, 10330),
    2010: (10165, 417, 10582),
    2011: (10350, 114, 10464),
    2012: (10593, 1249, 11842),
    2013: (10901, 2846, 13747),
    2014: (14103, 3439, 17542),
    2015: (13479, 3935, 17414),
    2016: (13626, 4232, 17858),
    2017: (13256, 4180, 17436),
    2018: (17649, 11892, 29541),
}

panel_rows = []
source_notes = []

for fiscal_year in range(2004, 2019):
    source_fiscal_year = source_fiscal_year_by_year[fiscal_year]
    filing = filing_by_year[source_fiscal_year]
    source_path = Path("../../build_land_light_measures/code") / filing["primary_document_local_path"]
    source_path = source_path.resolve()

    if not source_path.exists():
        raise RuntimeError(f"Missing William Lyon Homes source file: {source_path}")

    raw_text = source_path.read_text(encoding="utf-8", errors="ignore")
    table_parser = SecTableParser()
    table_parser.feed(raw_text)

    owned_lots = ""
    controlled_lots = ""
    total_lots = ""
    nonowned_controlled_share = ""
    owned_share = ""
    component_identity_gap = ""
    component_identity_pass = ""
    source_table_index = ""
    source_table_text = ""
    source_row_label = "missing owned/controlled lot-count table"
    extraction_method = "william_lyon_audited_missing_owned_controlled_split"
    main_panel_eligible = False
    manual_review_flag = True
    manual_review_reason = ""

    if fiscal_year <= 2005:
        source_text = clean_text(visible_text(source_path))
        lot_match = re.search(
            r"Lots controlled at end of year\s+Owned lots.*?"
            r"Total\s+([\d,]+)\s+([\d,]+)\s+([\d,]+)\s+"
            r"Optioned lots.*?Total\s+([\d,]+)\s+"
            r"Total lots controlled.*?Total\s+([\d,]+)",
            source_text,
            re.I,
        )
        if lot_match is None:
            raise RuntimeError(f"Could not find William Lyon Homes owned/optioned lot table for fiscal {fiscal_year}.")

        owned_lots = int(lot_match.group(3).replace(",", ""))
        controlled_lots = int(lot_match.group(4).replace(",", ""))
        total_lots = int(lot_match.group(5).replace(",", ""))
        nonowned_controlled_share = controlled_lots / total_lots
        owned_share = owned_lots / total_lots
        component_identity_gap = owned_lots + controlled_lots - total_lots
        component_identity_pass = abs(component_identity_gap) <= 1
        source_table_text = source_text[lot_match.start():lot_match.end()]
        source_row_label = "Owned lots total / Optioned lots total / Total lots controlled"
        extraction_method = "william_lyon_owned_optioned_lot_table"
        main_panel_eligible = True
        manual_review_flag = False

    if fiscal_year >= 2006:
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

            table_years = []
            for year_match in re.findall(r"\b(20\d{2})\b", table_text[:240]):
                if year_match not in table_years:
                    table_years.append(year_match)

            if str(fiscal_year) not in table_years[:2]:
                continue

            year_column = table_years[:2].index(str(fiscal_year))
            table_owned_lots = ""
            table_controlled_lots = ""
            table_total_lots = ""
            active_section = ""

            for cells in parsed_rows:
                label = cells[0].lower().strip()
                label = re.sub(r"\s+", " ", label)
                row_numbers = []
                for value in cells[1:]:
                    value = value.replace(",", "").replace("$", "").strip()
                    value = value.replace("(", "").replace(")", "").replace("%", "")
                    if value in {"", "-", "—", "N/M"}:
                        continue
                    if re.fullmatch(r"\d+(?:\.\d+)?", value):
                        row_numbers.append(float(value))

                if label.startswith("lots owned") and "controlled" not in label:
                    active_section = "owned"
                    continue
                if label.startswith("lots controlled"):
                    active_section = "controlled"
                    continue
                if label == "total" and len(row_numbers) >= 2 and active_section == "owned":
                    table_owned_lots = int(row_numbers[year_column])
                if label == "total" and len(row_numbers) >= 2 and active_section == "controlled":
                    table_controlled_lots = int(row_numbers[year_column])
                if label.startswith("total lots owned and controlled") and len(row_numbers) >= 2:
                    table_total_lots = int(row_numbers[year_column])

            if table_owned_lots != "" and table_controlled_lots != "" and table_total_lots != "":
                owned_lots = table_owned_lots
                controlled_lots = table_controlled_lots
                total_lots = table_total_lots
                source_table_index = str(table_index)
                source_table_text = table_text
                break

        if source_table_index == "":
            raise RuntimeError(f"Could not find William Lyon Homes owned/controlled lot table for fiscal {fiscal_year}.")

        nonowned_controlled_share = controlled_lots / total_lots
        owned_share = owned_lots / total_lots
        component_identity_gap = owned_lots + controlled_lots - total_lots
        component_identity_pass = abs(component_identity_gap) <= 1
        source_row_label = "Lots Owned total / Lots Controlled total / Total Lots Owned and Controlled"
        extraction_method = "william_lyon_owned_controlled_lot_table"
        main_panel_eligible = True
        manual_review_flag = fiscal_year in {2006, 2007, 2011}
        manual_review_reason = ""
        if fiscal_year in {2006, 2007}:
            manual_review_reason = "Uses exact comparative year column from the 2008 10-K because the recurring owned/controlled table was not found in the current-year filing."
        if fiscal_year == 2011:
            manual_review_reason = "Uses exact 2011 predecessor comparative row from the 2012 10-K successor/predecessor table."

    source_notes.append({
        "ticker": "WLH",
        "fiscal_year": fiscal_year,
        "source_fiscal_year": source_fiscal_year,
        "source_table_index": source_table_index,
        "source_row_label": source_row_label,
        "source_excerpt": source_table_text[:2600] if source_table_text != "" else "No owned/controlled lot-count table found; active-project owned lot tables are not used as omega inputs.",
    })

    panel_rows.append({
        "ticker": "WLH",
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
        "nonowned_controlled_lots": controlled_lots,
        "optioned_lots": controlled_lots if fiscal_year <= 2005 else "",
        "total_lots": total_lots,
        "nonowned_controlled_share": nonowned_controlled_share,
        "optioned_share": nonowned_controlled_share if fiscal_year <= 2005 else "",
        "owned_share": owned_share,
        "component_identity_gap": component_identity_gap,
        "component_identity_pass": component_identity_pass,
        "source_fiscal_year": source_fiscal_year,
        "uses_later_comparative_prior_year_row": fiscal_year in {2006, 2007, 2011},
        "successor_predecessor_table_source": fiscal_year == 2011,
        "controlled_measure_not_pure_options": fiscal_year >= 2006,
        "controlled_includes_land_banking_or_jv_language_where_disclosed": fiscal_year >= 2006,
        "audited_missing_no_controlled_lot_count": False,
        "extraction_method": extraction_method,
        "source_table_index": source_table_index,
        "source_row_label": source_row_label,
        "panel_use_flag": True,
        "main_panel_eligible": main_panel_eligible,
        "manual_review_flag": manual_review_flag,
        "manual_review_reason": manual_review_reason,
        "source_note": (
            "William Lyon reports owned and optioned lots directly for 2004-2005. "
            "From 2006 onward, Lots Controlled is coded as nonowned controlled lots, not pure optioned lots, "
            "because later filings note land banking and joint-venture purchase structures."
        ),
    })

audit_rows = []
for row in panel_rows:
    if row["fiscal_year"] in expected_values:
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
    "status": "ok" if len(panel_rows) == 15 else "fail",
    "value": len(panel_rows),
    "detail": "Expected William Lyon Homes fiscal 2004-2018 audited rows.",
})

audit_rows.append({
    "audit_check": "component_identity",
    "fiscal_year": "",
    "status": "ok" if all(row["component_identity_pass"] in {"", True} for row in panel_rows) else "fail",
    "value": sum(row["component_identity_pass"] is True for row in panel_rows),
    "detail": "Owned plus controlled lots must equal total lots owned and controlled when coded.",
})

write_csv(
    "../output/wlh_2004_2018_land_panel.csv",
    panel_rows,
    [
        "ticker", "cik10", "sec_company_name", "fiscal_year", "report_date",
        "filing_date", "accession_number", "primary_document", "source_local_path",
        "source_url", "unit_type", "owned_lots", "nonowned_controlled_lots",
        "optioned_lots", "total_lots", "nonowned_controlled_share",
        "optioned_share", "owned_share", "component_identity_gap",
        "component_identity_pass", "source_fiscal_year",
        "uses_later_comparative_prior_year_row", "successor_predecessor_table_source",
        "controlled_measure_not_pure_options",
        "controlled_includes_land_banking_or_jv_language_where_disclosed",
        "audited_missing_no_controlled_lot_count", "extraction_method",
        "source_table_index", "source_row_label", "panel_use_flag",
        "main_panel_eligible", "manual_review_flag", "manual_review_reason",
        "source_note",
    ],
)

write_csv(
    "../output/wlh_2004_2018_extraction_audit.csv",
    audit_rows,
    ["audit_check", "fiscal_year", "status", "value", "detail"],
)

write_csv(
    "../output/wlh_2004_2018_source_notes.csv",
    source_notes,
    ["ticker", "fiscal_year", "source_fiscal_year", "source_table_index", "source_row_label", "source_excerpt"],
)
