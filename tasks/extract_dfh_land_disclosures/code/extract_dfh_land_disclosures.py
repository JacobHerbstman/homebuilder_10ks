#!/usr/bin/env python3

import csv
import re
import sys
from pathlib import Path

sys.path.append(str(Path(__file__).resolve().parents[2] / "_lib"))
from sec_fetch_utils import write_csv

sys.path.append(str(Path(__file__).resolve().parents[1].parent / "extract_10k_land_candidates" / "code"))
from extract_10k_land_candidates import VisibleTextParser, clean_text


with open("../input/land_light_firm_year_measures.csv", newline="") as f:
    filing_rows = [
        row for row in csv.DictReader(f)
        if row.get("ticker") == "DFH"
        and row.get("form") == "10-K"
        and 2020 <= int(float(row.get("fiscal_year"))) <= 2025
    ]

if len(filing_rows) == 0:
    raise RuntimeError("No Dream Finders filing rows found in land_light_firm_year_measures.csv.")

filing_by_year = {}
for filing in filing_rows:
    fiscal_year = int(float(filing["fiscal_year"]))
    if fiscal_year in filing_by_year:
        raise RuntimeError("Dream Finders filing rows must be unique by fiscal year.")
    filing_by_year[fiscal_year] = filing

panel_rows = []
source_notes = []

for fiscal_year in range(2020, 2026):
    filing = filing_by_year[fiscal_year]
    source_path = Path(filing["primary_document_local_path"])

    if not source_path.exists():
        raise RuntimeError(f"Missing Dream Finders source file: {source_path}")

    raw_text = source_path.read_text(encoding="utf-8", errors="ignore")
    visible_parser = VisibleTextParser()
    visible_parser.feed(raw_text)
    visible_text = clean_text(visible_parser.text())

    owned_lots = None
    controlled_lots = None
    total_lots = None
    comparative_controlled_lots = None
    extraction_method = ""
    source_excerpt = ""

    if fiscal_year <= 2023:
        table_match = re.search(
            r"Owned and Controlled Lots.*?Grand Total\s+([0-9,]+)\s+([0-9,]+)\s+([0-9,]+)",
            visible_text,
            re.IGNORECASE,
        )

        if table_match is None:
            raise RuntimeError(f"Could not find Dream Finders owned/controlled/total row for {fiscal_year}.")

        owned_lots = float(table_match.group(1).replace(",", ""))
        controlled_lots = float(table_match.group(2).replace(",", ""))
        total_lots = float(table_match.group(3).replace(",", ""))
        extraction_method = "owned_controlled_total_grand_total_row"
        source_excerpt = visible_text[
            max(0, table_match.start() - 500):min(len(visible_text), table_match.end() + 800)
        ]

    if fiscal_year >= 2024:
        pipeline_match = re.search(
            r"Controlled Lots? Pipeline.*?Total \(2\)\s+([0-9,]+)\s+([0-9,]+)",
            visible_text,
            re.IGNORECASE,
        )

        if pipeline_match is None:
            raise RuntimeError(f"Could not find Dream Finders controlled-lot pipeline row for {fiscal_year}.")

        controlled_lots = float(pipeline_match.group(1).replace(",", ""))
        comparative_controlled_lots = float(pipeline_match.group(2).replace(",", ""))
        extraction_method = "controlled_lot_pipeline_only"
        source_excerpt = visible_text[
            max(0, pipeline_match.start() - 500):min(len(visible_text), pipeline_match.end() + 800)
        ]

    next_year_comparative_controlled_lots = None
    confirmed_by_next_year_comparative = False

    if fiscal_year == 2024 and 2025 in filing_by_year:
        next_source_path = Path(filing_by_year[2025]["primary_document_local_path"])
        next_raw_text = next_source_path.read_text(encoding="utf-8", errors="ignore")
        next_visible_parser = VisibleTextParser()
        next_visible_parser.feed(next_raw_text)
        next_visible_text = clean_text(next_visible_parser.text())
        next_pipeline_match = re.search(
            r"Controlled Lots? Pipeline.*?Total \(2\)\s+([0-9,]+)\s+([0-9,]+)",
            next_visible_text,
            re.IGNORECASE,
        )

        if next_pipeline_match is not None:
            next_year_comparative_controlled_lots = float(next_pipeline_match.group(2).replace(",", ""))
            confirmed_by_next_year_comparative = next_year_comparative_controlled_lots == controlled_lots

    component_gap = ""
    if owned_lots is not None and controlled_lots is not None and total_lots is not None:
        component_gap = owned_lots + controlled_lots - total_lots

    source_note = "Dream Finders Owned and Controlled Lots Grand Total row; Controlled is coded as current nonowned controlled lots."
    if fiscal_year == 2020:
        source_note = (
            source_note
            + " The filing also reports that 99% of owned and controlled lots were controlled through finished-lot option and land-bank option contracts; "
            + "that contract-sourced share is retained separately and not used as current physical omega."
        )
    if fiscal_year in {2021, 2022, 2023}:
        source_note = source_note + " Owned lots are described as finished lots purchased just-in-time for production."
    if fiscal_year >= 2024:
        source_note = "Dream Finders Controlled Lot Pipeline table only; controlled lots are retained, but owned lots and owned-plus-controlled denominator are not disclosed as lot counts."
    if fiscal_year == 2024 and confirmed_by_next_year_comparative:
        source_note = source_note + " The 2025 filing's comparative 2024 controlled-lot value matches the 2024 current filing."

    panel_rows.append({
        "ticker": "DFH",
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
        "controlled_lots": controlled_lots,
        "total_lots": total_lots,
        "nonowned_controlled_share": (
            controlled_lots / total_lots
            if controlled_lots is not None and total_lots not in (None, 0)
            else None
        ),
        "owned_share": (
            owned_lots / total_lots
            if owned_lots is not None and total_lots not in (None, 0)
            else None
        ),
        "component_identity_gap": component_gap,
        "component_identity_pass": (
            abs(component_gap) <= 1
            if isinstance(component_gap, float)
            else False
        ),
        "main_panel_eligible": fiscal_year <= 2023,
        "owned_controlled_split_disclosed": fiscal_year <= 2023,
        "owned_plus_controlled_equals_total": (
            abs(component_gap) <= 1
            if isinstance(component_gap, float)
            else False
        ),
        "firm_reported_asset_light_contract_sourced_share": 0.99 if fiscal_year == 2020 else "",
        "asset_light_contract_sourced_percent_disclosed": fiscal_year == 2020,
        "asset_light_percent_not_used_for_omega": fiscal_year == 2020,
        "owned_lots_may_include_jit_takedowns_from_option_contracts": fiscal_year in {2021, 2022, 2023},
        "owned_lots_include_cip_finished_model_or_spec_inventory": fiscal_year in {2022, 2023},
        "remaining_owned_lots_ready_for_construction_or_jit_purchase": fiscal_year in {2022, 2023},
        "extraction_method": extraction_method,
        "precision": "reported_table",
        "source_row_label": "Grand Total" if fiscal_year <= 2023 else "Total",
        "controlled_lots_only": fiscal_year >= 2024,
        "denominator_not_disclosed_after_table_schema_change": fiscal_year >= 2024,
        "schema_break_year": fiscal_year == 2024,
        "owned_lots_missing": fiscal_year >= 2024,
        "denominator_missing": fiscal_year >= 2024,
        "omega_missing_due_to_schema_change": fiscal_year >= 2024,
        "do_not_impute_owned_lots": fiscal_year >= 2024,
        "do_not_splice_pipeline_into_denominator": fiscal_year >= 2024,
        "comparative_controlled_lots": comparative_controlled_lots,
        "next_year_comparative_controlled_lots": next_year_comparative_controlled_lots,
        "confirmed_by_next_year_comparative": confirmed_by_next_year_comparative,
        "panel_use_flag": True,
        "manual_review_flag": fiscal_year >= 2024,
        "manual_review_reason": (
            "controlled_lot_pipeline_only_owned_lot_denominator_not_disclosed"
            if fiscal_year >= 2024
            else ""
        ),
        "source_note": source_note,
    })

    source_notes.append({
        "ticker": "DFH",
        "fiscal_year": fiscal_year,
        "extraction_method": extraction_method,
        "source_excerpt": source_excerpt,
    })

audit_rows = [
    {
        "audit_check": "firm_year_rows",
        "status": "ok" if len(panel_rows) == 6 else "fail",
        "value": len(panel_rows),
        "detail": "Expected Dream Finders fiscal years 2020 through 2025.",
    },
    {
        "audit_check": "owned_controlled_total_rows",
        "status": "ok" if sum(row["extraction_method"] == "owned_controlled_total_grand_total_row" for row in panel_rows) == 4 else "fail",
        "value": sum(row["extraction_method"] == "owned_controlled_total_grand_total_row" for row in panel_rows),
        "detail": "Expected 2020-2023 owned/controlled/total lot rows.",
    },
    {
        "audit_check": "controlled_pipeline_only_rows",
        "status": "ok" if sum(row["controlled_lots_only"] for row in panel_rows) == 2 else "fail",
        "value": sum(row["controlled_lots_only"] for row in panel_rows),
        "detail": "Expected 2024-2025 controlled-lot-pipeline-only rows.",
    },
    {
        "audit_check": "component_identity",
        "status": "ok" if all(
            row["controlled_lots_only"] or row["component_identity_pass"]
            for row in panel_rows
        ) else "fail",
        "value": sum(
            row["controlled_lots_only"] or row["component_identity_pass"]
            for row in panel_rows
        ),
        "detail": "Owned plus controlled must equal total whenever the denominator is disclosed.",
    },
    {
        "audit_check": "share_missing_for_controlled_only_rows",
        "status": "ok" if all(
            not row["controlled_lots_only"] or row["nonowned_controlled_share"] is None
            for row in panel_rows
        ) else "fail",
        "value": sum(
            row["controlled_lots_only"] and row["nonowned_controlled_share"] is None
            for row in panel_rows
        ),
        "detail": "Controlled-lot-only rows should not receive omega.",
    },
    {
        "audit_check": "current_2024_confirmed_by_2025_comparative",
        "status": "ok" if any(
            row["fiscal_year"] == 2024 and row["confirmed_by_next_year_comparative"]
            for row in panel_rows
        ) else "fail",
        "value": next(
            row["next_year_comparative_controlled_lots"]
            for row in panel_rows
            if row["fiscal_year"] == 2024
        ),
        "detail": "The 2025 filing's comparative 2024 controlled-lot value should match the 2024 current filing.",
    },
]

write_csv(
    "../output/dfh_2020_2025_land_panel.csv",
    panel_rows,
    [
        "ticker", "cik10", "sec_company_name", "fiscal_year", "report_date", "filing_date",
        "accession_number", "primary_document", "source_local_path", "source_url", "unit_type",
        "owned_lots", "nonowned_controlled_lots", "controlled_lots", "total_lots",
        "nonowned_controlled_share", "owned_share", "component_identity_gap",
        "component_identity_pass", "main_panel_eligible",
        "owned_controlled_split_disclosed", "owned_plus_controlled_equals_total",
        "firm_reported_asset_light_contract_sourced_share",
        "asset_light_contract_sourced_percent_disclosed",
        "asset_light_percent_not_used_for_omega",
        "owned_lots_may_include_jit_takedowns_from_option_contracts",
        "owned_lots_include_cip_finished_model_or_spec_inventory",
        "remaining_owned_lots_ready_for_construction_or_jit_purchase",
        "extraction_method", "precision", "source_row_label",
        "controlled_lots_only", "denominator_not_disclosed_after_table_schema_change",
        "schema_break_year", "owned_lots_missing", "denominator_missing",
        "omega_missing_due_to_schema_change", "do_not_impute_owned_lots",
        "do_not_splice_pipeline_into_denominator", "comparative_controlled_lots",
        "next_year_comparative_controlled_lots", "confirmed_by_next_year_comparative",
        "panel_use_flag", "manual_review_flag", "manual_review_reason", "source_note",
    ],
)

write_csv(
    "../output/dfh_2020_2025_extraction_audit.csv",
    audit_rows,
    ["audit_check", "status", "value", "detail"],
)

write_csv(
    "../output/dfh_2020_2025_source_notes.csv",
    source_notes,
    ["ticker", "fiscal_year", "extraction_method", "source_excerpt"],
)
