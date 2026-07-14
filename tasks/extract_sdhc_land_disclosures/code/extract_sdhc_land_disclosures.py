#!/usr/bin/env python3

import csv
import re
import sys
from pathlib import Path

sys.path.append(str(Path(__file__).resolve().parents[2] / "_lib"))
from sec_fetch_utils import write_csv

sys.path.append(str(Path(__file__).resolve().parents[1].parent / "extract_10k_land_candidates" / "code"))
from extract_10k_land_candidates import SecTableParser, clean_text


with open("../input/land_light_firm_year_measures.csv", newline="") as f:
    filing_rows = [
        row for row in csv.DictReader(f)
        if row.get("ticker") == "SDHC"
        and row.get("form") == "10-K"
        and 2023 <= int(float(row.get("fiscal_year"))) <= 2025
    ]

if len(filing_rows) == 0:
    raise RuntimeError("No Smith Douglas filing rows found in land_light_firm_year_measures.csv.")

filing_by_year = {}
for filing in filing_rows:
    fiscal_year = int(float(filing["fiscal_year"]))
    if fiscal_year in filing_by_year:
        raise RuntimeError("Smith Douglas filing rows must be unique by fiscal year.")
    filing_by_year[fiscal_year] = filing

panel_rows = []
segment_rows = []
source_notes = []

for fiscal_year in range(2022, 2026):
    source_fiscal_year = 2023 if fiscal_year == 2022 else fiscal_year
    use_prior_column_group = fiscal_year == 2022
    filing = filing_by_year[source_fiscal_year]
    source_path = Path(filing["primary_document_local_path"])

    if not source_path.exists():
        raise RuntimeError(f"Missing Smith Douglas source file: {source_path}")

    table_parser = SecTableParser()
    table_parser.feed(source_path.read_text(encoding="utf-8", errors="ignore"))

    owned_lots = None
    optioned_lots = None
    total_controlled_lots = None
    land_source_table_index = ""
    land_source_excerpt = ""

    for table_index, table in enumerate(table_parser.tables):
        parsed_rows = []
        for html_row in table["rows"]:
            cells = [clean_text(cell.get("text", "")) for cell in html_row]
            cells = [cell for cell in cells if cell and cell != "\u200b"]
            if cells:
                parsed_rows.append(cells)

        table_text = clean_text(" || ".join(" | ".join(cells) for cells in parsed_rows))
        table_text_lower = table_text.lower()

        if "owned" not in table_text_lower or "optioned" not in table_text_lower:
            continue
        if "total controlled" not in table_text_lower:
            continue
        if str(fiscal_year) not in table_text:
            continue
        if "year over year change" in table_text_lower:
            continue

        for cells in parsed_rows:
            row_label = cells[0]
            numeric_values = []
            for cell in cells[1:]:
                if re.fullmatch(r"\d+(?:,\d{3})*", cell):
                    numeric_values.append(float(cell.replace(",", "")))
                elif cell in ("—", "-", "--"):
                    numeric_values.append(0.0)

            if len(numeric_values) < 3:
                continue

            lot_values = numeric_values[3:6] if use_prior_column_group else numeric_values[0:3]
            if len(lot_values) != 3:
                continue

            segment_rows.append({
                "ticker": "SDHC",
                "cik10": filing["cik10"],
                "fiscal_year": fiscal_year,
                "source_fiscal_year": source_fiscal_year,
                "accession_number": filing["accession_number"],
                "source_table_index": table_index,
                "segment_label": row_label,
                "row_type": "total" if row_label.lower() == "total" else "market",
                "owned_lots": lot_values[0],
                "optioned_lots": lot_values[1],
                "total_controlled_lots": lot_values[2],
                "component_identity_gap": lot_values[0] + lot_values[1] - lot_values[2],
            })

            if row_label.lower() == "total":
                owned_lots = lot_values[0]
                optioned_lots = lot_values[1]
                total_controlled_lots = lot_values[2]
                land_source_table_index = str(table_index)
                land_source_excerpt = table_text[:1400]

        if total_controlled_lots is not None:
            break

    if total_controlled_lots is None:
        raise RuntimeError(f"Could not find Smith Douglas owned/optioned/controlled total row for {fiscal_year}.")

    option_deposits = None
    remaining_purchase_price = None
    option_economics_table_index = ""
    option_economics_excerpt = ""

    for table_index, table in enumerate(table_parser.tables):
        parsed_rows = []
        for html_row in table["rows"]:
            cells = [clean_text(cell.get("text", "")) for cell in html_row]
            cells = [cell for cell in cells if cell and cell not in ("$", "\u200b")]
            if cells:
                parsed_rows.append(cells)

        table_text = clean_text(" || ".join(" | ".join(cells) for cells in parsed_rows))
        table_text_lower = table_text.lower()

        if "deposits or investments" not in table_text_lower:
            continue
        if "remaining purchase price" not in table_text_lower:
            continue
        if str(fiscal_year) not in table_text:
            continue

        for cells in parsed_rows:
            if cells[0].lower() != "total option contracts":
                continue

            numeric_values = []
            for cell in cells[1:]:
                if re.fullmatch(r"\d+(?:,\d{3})*", cell):
                    numeric_values.append(float(cell.replace(",", "")))
                elif cell in ("—", "-", "--"):
                    numeric_values.append(0.0)

            if len(numeric_values) >= 2:
                option_deposits = numeric_values[0] * 1000
                remaining_purchase_price = numeric_values[1] * 1000
                option_economics_table_index = str(table_index)
                option_economics_excerpt = table_text[:1000]
                break

        if option_deposits is not None:
            break

    if option_deposits is None:
        raise RuntimeError(f"Could not find Smith Douglas option economics total row for {fiscal_year}.")

    component_gap = owned_lots + optioned_lots - total_controlled_lots
    source_note = (
        "Uses Smith Douglas Owned / Optioned / Total Controlled total row. "
        "Optioned is coded as non-owned optioned lots because the table explicitly labels that bucket."
    )

    if fiscal_year == 2022:
        source_note = (
            "Uses exact December 31, 2022 comparative row from the 2023 Smith Douglas 10-K. "
            "This is a pre-IPO operating-builder observation reported in a later filing."
        )
    elif fiscal_year == 2023:
        source_note = (
            "Uses fiscal 2023 total row from the 2023 Smith Douglas 10-K. "
            "The fiscal year predates the 2024 IPO but is reported in the post-IPO filing."
        )

    panel_rows.append({
        "ticker": "SDHC",
        "cik10": filing["cik10"],
        "sec_company_name": filing["sec_company_name"],
        "fiscal_year": fiscal_year,
        "report_date": f"{fiscal_year}-12-31",
        "filing_date": filing["filing_date"],
        "accession_number": filing["accession_number"],
        "source_accession_number": filing["accession_number"],
        "primary_document": filing["primary_document"],
        "source_local_path": filing["primary_document_local_path"],
        "source_url": filing["filing_url"],
        "unit_type": "lots",
        "owned_lots": owned_lots,
        "nonowned_controlled_lots": optioned_lots,
        "optioned_lots": optioned_lots,
        "total_lots": total_controlled_lots,
        "total_controlled_lots": total_controlled_lots,
        "nonowned_controlled_share": optioned_lots / total_controlled_lots,
        "optioned_share": optioned_lots / total_controlled_lots,
        "owned_share": owned_lots / total_controlled_lots,
        "option_deposits": option_deposits,
        "remaining_purchase_price": remaining_purchase_price,
        "deposit_rate": option_deposits / remaining_purchase_price,
        "component_identity_gap": component_gap,
        "component_identity_pass": abs(component_gap) <= 1,
        "extraction_method": (
            "prior_year_column_from_2023_owned_optioned_table"
            if fiscal_year == 2022
            else "current_year_column_from_owned_optioned_table"
        ),
        "precision": "reported_table",
        "source_fiscal_year": source_fiscal_year,
        "land_source_table_index": land_source_table_index,
        "option_economics_table_index": option_economics_table_index,
        "source_row_label": "Total",
        "source_total_row_used": True,
        "source_table": "land_control_by_market",
        "optioned_definition_raw": "Optioned",
        "total_definition_raw": "Total Controlled",
        "owned_plus_optioned_equals_total_controlled": abs(component_gap) <= 1,
        "total_controlled_means_owned_plus_optioned_for_this_firm": True,
        "optioned_treated_as_nonowned_controlled": True,
        "optioned_treated_as_pure_optioned_lots": True,
        "option_economics_available": True,
        "option_dollar_values_used_for_omega": False,
        "segment_rows_retained": True,
        "uses_later_comparative_prior_year_row": fiscal_year == 2022,
        "pre_ipo_operating_builder_observation": fiscal_year < 2024,
        "post_ipo_public_company_row": fiscal_year >= 2024,
        "panel_use_flag": True,
        "main_panel_eligible": fiscal_year >= 2024,
        "manual_review_flag": False,
        "manual_review_reason": "",
        "source_note": source_note,
    })

    source_notes.append({
        "ticker": "SDHC",
        "fiscal_year": fiscal_year,
        "source_fiscal_year": source_fiscal_year,
        "land_source_table_index": land_source_table_index,
        "option_economics_table_index": option_economics_table_index,
        "land_source_excerpt": land_source_excerpt,
        "option_economics_excerpt": option_economics_excerpt,
    })

audit_rows = [
    {
        "audit_check": "firm_year_rows",
        "status": "ok" if len(panel_rows) == 4 else "fail",
        "value": len(panel_rows),
        "detail": "Expected Smith Douglas fiscal years 2022 through 2025.",
    },
    {
        "audit_check": "component_identity",
        "status": "ok" if all(row["component_identity_pass"] for row in panel_rows) else "fail",
        "value": sum(row["component_identity_pass"] for row in panel_rows),
        "detail": "Owned plus optioned must equal total controlled in each selected total row.",
    },
    {
        "audit_check": "option_economics_rows",
        "status": "ok" if all(row["option_deposits"] is not None and row["remaining_purchase_price"] is not None for row in panel_rows) else "fail",
        "value": sum(row["option_deposits"] is not None and row["remaining_purchase_price"] is not None for row in panel_rows),
        "detail": "Each selected year should have a Total option contracts deposits and remaining purchase price row.",
    },
    {
        "audit_check": "pre_ipo_flags",
        "status": "ok" if sum(row["pre_ipo_operating_builder_observation"] for row in panel_rows) == 2 else "fail",
        "value": sum(row["pre_ipo_operating_builder_observation"] for row in panel_rows),
        "detail": "Expected fiscal 2022 and 2023 to be flagged as pre-IPO operating-builder observations.",
    },
    {
        "audit_check": "main_panel_flags",
        "status": "ok" if sum(row["main_panel_eligible"] for row in panel_rows) == 2 else "fail",
        "value": sum(row["main_panel_eligible"] for row in panel_rows),
        "detail": "Expected fiscal 2024 and 2025 to be main public-company rows.",
    },
]

write_csv(
    "../output/sdhc_2022_2025_land_panel.csv",
    panel_rows,
    [
        "ticker", "cik10", "sec_company_name", "fiscal_year", "report_date", "filing_date",
        "accession_number", "source_accession_number", "primary_document", "source_local_path",
        "source_url", "unit_type", "owned_lots", "nonowned_controlled_lots", "optioned_lots",
        "total_lots", "total_controlled_lots", "nonowned_controlled_share", "optioned_share",
        "owned_share", "option_deposits", "remaining_purchase_price", "deposit_rate",
        "component_identity_gap", "component_identity_pass", "extraction_method", "precision",
        "source_fiscal_year", "land_source_table_index", "option_economics_table_index",
        "source_row_label", "source_total_row_used", "source_table", "optioned_definition_raw",
        "total_definition_raw", "owned_plus_optioned_equals_total_controlled",
        "total_controlled_means_owned_plus_optioned_for_this_firm",
        "optioned_treated_as_nonowned_controlled", "optioned_treated_as_pure_optioned_lots",
        "option_economics_available", "option_dollar_values_used_for_omega",
        "segment_rows_retained", "uses_later_comparative_prior_year_row",
        "pre_ipo_operating_builder_observation", "post_ipo_public_company_row",
        "panel_use_flag", "main_panel_eligible", "manual_review_flag",
        "manual_review_reason", "source_note",
    ],
)

write_csv(
    "../output/sdhc_2022_2025_segment_land_rows.csv",
    segment_rows,
    [
        "ticker", "cik10", "fiscal_year", "source_fiscal_year", "accession_number",
        "source_table_index", "segment_label", "row_type", "owned_lots", "optioned_lots",
        "total_controlled_lots", "component_identity_gap",
    ],
)

write_csv(
    "../output/sdhc_2022_2025_extraction_audit.csv",
    audit_rows,
    ["audit_check", "status", "value", "detail"],
)

write_csv(
    "../output/sdhc_2022_2025_source_notes.csv",
    source_notes,
    [
        "ticker", "fiscal_year", "source_fiscal_year", "land_source_table_index",
        "option_economics_table_index", "land_source_excerpt", "option_economics_excerpt",
    ],
)
