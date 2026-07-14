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
        if row.get("ticker") == "TMHC"
        and row.get("form") == "10-K"
        and 2013 <= int(float(row.get("fiscal_year"))) <= 2025
    ]

if len(filing_rows) == 0:
    raise RuntimeError("No Taylor Morrison filing rows found in land_light_firm_year_measures.csv.")

filings_by_year = {
    int(float(row["fiscal_year"])): row
    for row in filing_rows
}

panel_rows = []
segment_rows = []
source_notes = []

for filing in sorted(filing_rows, key=lambda row: int(float(row["fiscal_year"]))):
    fiscal_year = int(float(filing["fiscal_year"]))
    source_path = Path(filing["primary_document_local_path"])

    if not source_path.exists():
        raise RuntimeError(f"Missing Taylor Morrison source file: {source_path}")

    raw_text = source_path.read_text(encoding="utf-8", errors="ignore")
    table_parser = SecTableParser()
    table_parser.feed(raw_text)

    owned_lots = None
    controlled_lots = None
    total_lots = None
    land_option_purchase_contract_lots = None
    land_banking_lots = None
    other_controlled_lots = None
    homes_in_inventory = None
    us_owned_lots = None
    us_controlled_lots = None
    us_total_lots = None
    canada_owned_lots = None
    canada_controlled_lots = None
    canada_total_lots = None
    unconsolidated_jv_owned_lots = None
    unconsolidated_jv_controlled_lots = None
    unconsolidated_jv_total_lots = None
    original_2022_owned_lots = None
    original_2022_controlled_lots = None
    original_2022_total_lots = None
    definition_version = ""
    definition_recast_source_year = ""
    main_series_uses_recast = False
    extraction_method = ""
    source_table_index = ""
    source_row_label = ""
    source_excerpt = ""
    source_accession_number = filing["accession_number"]
    source_url = filing["filing_url"]
    source_local_path = filing["primary_document_local_path"]

    if fiscal_year <= 2021:
        for table_index, table in enumerate(table_parser.tables):
            parsed_rows = []
            for html_row in table["rows"]:
                cells = [clean_text(cell.get("text", "")) for cell in html_row]
                cells = [cell for cell in cells if cell]
                if cells:
                    parsed_rows.append(cells)

            table_text = clean_text(" || ".join(" | ".join(cells) for cells in parsed_rows))
            table_text_lower = table_text.lower()

            if "owned lots" not in table_text_lower or "controlled lots" not in table_text_lower:
                continue
            if (
                "owned and controlled lots" not in table_text_lower
                and "owned & controlled lots" not in table_text_lower
                and "total owned and controlled" not in table_text_lower
            ):
                continue

            for cells in parsed_rows:
                row_label = cells[0].lower()
                numeric_values = []
                for cell in cells[1:]:
                    if re.fullmatch(r"\d+(?:,\d{3})*", cell):
                        numeric_values.append(float(cell.replace(",", "")))
                    elif cell in ("—", "-", "--"):
                        numeric_values.append(0.0)

                if row_label == "subtotal u.s." and len(numeric_values) >= 10:
                    us_owned_lots = numeric_values[4]
                    us_controlled_lots = numeric_values[8]
                    us_total_lots = numeric_values[9]

                if row_label == "canada" and len(numeric_values) >= 10:
                    canada_owned_lots = numeric_values[4]
                    canada_controlled_lots = numeric_values[8]
                    canada_total_lots = numeric_values[9]

                if row_label.startswith("unconsolidated joint ventures") and len(numeric_values) >= 10:
                    unconsolidated_jv_owned_lots = numeric_values[4]
                    unconsolidated_jv_controlled_lots = numeric_values[8]
                    unconsolidated_jv_total_lots = numeric_values[9]

                if row_label == "total" and len(numeric_values) >= 10:
                    owned_lots = numeric_values[4]
                    controlled_lots = numeric_values[8]
                    total_lots = numeric_values[9]
                    extraction_method = "detailed_land_portfolio_total_row"
                    definition_version = "issuer_companywide_detailed_land_portfolio"
                    source_table_index = str(table_index)
                    source_row_label = cells[0]
                    source_excerpt = table_text[:1400]

                elif row_label == "total" and len(numeric_values) >= 6:
                    owned_lots = numeric_values[-3]
                    controlled_lots = numeric_values[-2]
                    total_lots = numeric_values[-1]
                    extraction_method = "compact_land_portfolio_total_row"
                    definition_version = "issuer_companywide_compact_land_portfolio"
                    source_table_index = str(table_index)
                    source_row_label = cells[0]
                    source_excerpt = table_text[:1400]

                if len(numeric_values) >= 10 and row_label not in ("total",):
                    segment_rows.append({
                        "ticker": "TMHC",
                        "cik10": filing["cik10"],
                        "fiscal_year": fiscal_year,
                        "accession_number": source_accession_number,
                        "source_table_index": table_index,
                        "segment_label": cells[0],
                        "row_type": "region_or_scope",
                        "owned_lots": numeric_values[4],
                        "controlled_lots": numeric_values[8],
                        "total_lots": numeric_values[9],
                        "component_identity_gap": numeric_values[4] + numeric_values[8] - numeric_values[9],
                    })

                elif len(numeric_values) >= 6 and row_label not in ("total",):
                    segment_rows.append({
                        "ticker": "TMHC",
                        "cik10": filing["cik10"],
                        "fiscal_year": fiscal_year,
                        "accession_number": source_accession_number,
                        "source_table_index": table_index,
                        "segment_label": cells[0],
                        "row_type": "region_or_scope",
                        "owned_lots": numeric_values[-3],
                        "controlled_lots": numeric_values[-2],
                        "total_lots": numeric_values[-1],
                        "component_identity_gap": numeric_values[-3] + numeric_values[-2] - numeric_values[-1],
                    })

            if extraction_method != "":
                break

    if fiscal_year == 2022:
        for table_index, table in enumerate(table_parser.tables):
            parsed_rows = []
            for html_row in table["rows"]:
                cells = [clean_text(cell.get("text", "")) for cell in html_row]
                cells = [cell for cell in cells if cell]
                if cells:
                    parsed_rows.append(cells)

            table_text = clean_text(" || ".join(" | ".join(cells) for cells in parsed_rows))
            table_text_lower = table_text.lower()

            if "total owned lots" in table_text_lower and "book value of land and development" in table_text_lower:
                for cells in parsed_rows:
                    numeric_values = []
                    for cell in cells[1:]:
                        if re.fullmatch(r"\d+(?:,\d{3})*", cell):
                            numeric_values.append(float(cell.replace(",", "")))

                    if cells[0].lower() == "total owned lots" and numeric_values:
                        original_2022_owned_lots = numeric_values[0]

            if "total controlled lots" in table_text_lower and "land option purchase contracts" in table_text_lower:
                for cells in parsed_rows:
                    numeric_values = []
                    for cell in cells[1:]:
                        if re.fullmatch(r"\d+(?:,\d{3})*", cell):
                            numeric_values.append(float(cell.replace(",", "")))

                    if cells[0].lower() == "total controlled lots" and numeric_values:
                        original_2022_controlled_lots = numeric_values[0]

        if original_2022_owned_lots is not None and original_2022_controlled_lots is not None:
            original_2022_total_lots = original_2022_owned_lots + original_2022_controlled_lots

        restatement_filing = filings_by_year.get(2023)
        if restatement_filing is None:
            raise RuntimeError("Taylor Morrison 2023 filing is required for the restated 2022 land table.")

        restatement_path = Path(restatement_filing["primary_document_local_path"])
        if not restatement_path.exists():
            raise RuntimeError(f"Missing Taylor Morrison 2023 source file: {restatement_path}")

        restatement_parser = SecTableParser()
        restatement_parser.feed(restatement_path.read_text(encoding="utf-8", errors="ignore"))

        for table_index, table in enumerate(restatement_parser.tables):
            parsed_rows = []
            for html_row in table["rows"]:
                cells = [clean_text(cell.get("text", "")) for cell in html_row]
                cells = [cell for cell in cells if cell]
                if cells:
                    parsed_rows.append(cells)

            table_text = clean_text(" || ".join(" | ".join(cells) for cells in parsed_rows))
            table_text_lower = table_text.lower()

            if "total owned and controlled lots" not in table_text_lower:
                continue
            if "homes in inventory" not in table_text_lower or "land option purchase contracts" not in table_text_lower:
                continue

            for cells in parsed_rows:
                row_label = cells[0].lower()
                numeric_values = []
                for cell in cells[1:]:
                    if re.fullmatch(r"\d+(?:,\d{3})*", cell):
                        numeric_values.append(float(cell.replace(",", "")))

                if len(numeric_values) < 2:
                    continue

                if row_label == "total owned lots":
                    owned_lots = numeric_values[1]
                if row_label == "land option purchase contracts":
                    land_option_purchase_contract_lots = numeric_values[1]
                if row_label == "land banking arrangements":
                    land_banking_lots = numeric_values[1]
                if row_label.startswith("other controlled lots"):
                    other_controlled_lots = numeric_values[1]
                if row_label == "total controlled lots":
                    controlled_lots = numeric_values[1]
                if row_label == "total owned and controlled lots":
                    total_lots = numeric_values[1]
                if row_label == "homes in inventory":
                    homes_in_inventory = numeric_values[1]

            if owned_lots is not None and controlled_lots is not None and total_lots is not None:
                extraction_method = "restated_prior_year_from_2023_owned_controlled_note"
                definition_version = "recast_2023_owned_controlled_homes_inventory_excluded"
                definition_recast_source_year = "2023"
                main_series_uses_recast = True
                source_table_index = "2023:" + str(table_index)
                source_row_label = "prior-year column"
                source_excerpt = table_text[:1400]
                source_accession_number = restatement_filing["accession_number"]
                source_url = restatement_filing["filing_url"]
                source_local_path = restatement_filing["primary_document_local_path"]
                break

    if fiscal_year >= 2023:
        for table_index, table in enumerate(table_parser.tables):
            parsed_rows = []
            for html_row in table["rows"]:
                cells = [clean_text(cell.get("text", "")) for cell in html_row]
                cells = [cell for cell in cells if cell]
                if cells:
                    parsed_rows.append(cells)

            table_text = clean_text(" || ".join(" | ".join(cells) for cells in parsed_rows))
            table_text_lower = table_text.lower()

            if "total owned and controlled lots" not in table_text_lower:
                continue
            if "homes in inventory" not in table_text_lower or "land option purchase contracts" not in table_text_lower:
                continue

            for cells in parsed_rows:
                row_label = cells[0].lower()
                numeric_values = []
                for cell in cells[1:]:
                    if re.fullmatch(r"\d+(?:,\d{3})*", cell):
                        numeric_values.append(float(cell.replace(",", "")))

                if len(numeric_values) == 0:
                    continue

                if row_label == "total owned lots":
                    owned_lots = numeric_values[0]
                if row_label == "land option purchase contracts":
                    land_option_purchase_contract_lots = numeric_values[0]
                if row_label == "land banking arrangements":
                    land_banking_lots = numeric_values[0]
                if row_label.startswith("other controlled lots"):
                    other_controlled_lots = numeric_values[0]
                if row_label == "total controlled lots":
                    controlled_lots = numeric_values[0]
                if row_label == "total owned and controlled lots":
                    total_lots = numeric_values[0]
                if row_label == "homes in inventory":
                    homes_in_inventory = numeric_values[0]

                if row_label in (
                    "land option purchase contracts",
                    "land banking arrangements",
                    "total controlled lots",
                    "total owned lots",
                    "total owned and controlled lots",
                    "homes in inventory",
                ) or row_label.startswith("other controlled lots"):
                    segment_rows.append({
                        "ticker": "TMHC",
                        "cik10": filing["cik10"],
                        "fiscal_year": fiscal_year,
                        "accession_number": source_accession_number,
                        "source_table_index": table_index,
                        "segment_label": cells[0],
                        "row_type": "owned_controlled_component",
                        "owned_lots": numeric_values[0] if row_label == "total owned lots" else None,
                        "controlled_lots": numeric_values[0] if row_label not in ("total owned lots", "total owned and controlled lots", "homes in inventory") else None,
                        "total_lots": numeric_values[0] if row_label == "total owned and controlled lots" else None,
                        "component_identity_gap": None,
                    })

            if owned_lots is not None and controlled_lots is not None and total_lots is not None:
                extraction_method = "owned_controlled_note_current_year"
                definition_version = "current_owned_controlled_homes_inventory_excluded"
                source_table_index = str(table_index)
                source_row_label = "current-year column"
                source_excerpt = table_text[:1400]
                break

    component_gap = ""
    if owned_lots is not None and controlled_lots is not None and total_lots is not None:
        component_gap = owned_lots + controlled_lots - total_lots

    controlled_component_gap = ""
    if (
        land_option_purchase_contract_lots is not None
        and land_banking_lots is not None
        and other_controlled_lots is not None
        and controlled_lots is not None
    ):
        controlled_component_gap = (
            land_option_purchase_contract_lots
            + land_banking_lots
            + other_controlled_lots
            - controlled_lots
        )

    scope_identity_gap = ""
    if (
        us_owned_lots is not None
        and canada_owned_lots is not None
        and unconsolidated_jv_owned_lots is not None
        and owned_lots is not None
        and us_controlled_lots is not None
        and canada_controlled_lots is not None
        and unconsolidated_jv_controlled_lots is not None
        and controlled_lots is not None
        and us_total_lots is not None
        and canada_total_lots is not None
        and unconsolidated_jv_total_lots is not None
        and total_lots is not None
    ):
        scope_identity_gap = (
            us_owned_lots + canada_owned_lots + unconsolidated_jv_owned_lots - owned_lots
            + us_controlled_lots + canada_controlled_lots + unconsolidated_jv_controlled_lots - controlled_lots
            + us_total_lots + canada_total_lots + unconsolidated_jv_total_lots - total_lots
        )

    panel_rows.append({
        "ticker": "TMHC",
        "cik10": filing["cik10"],
        "sec_company_name": filing["sec_company_name"],
        "fiscal_year": fiscal_year,
        "report_date": filing["report_date"],
        "filing_date": filing["filing_date"],
        "accession_number": filing["accession_number"],
        "primary_document": filing["primary_document"],
        "source_accession_number": source_accession_number,
        "source_local_path": source_local_path,
        "source_url": source_url,
        "unit_type": "lots",
        "owned_lots": owned_lots,
        "controlled_lots": controlled_lots,
        "nonowned_controlled_lots": controlled_lots,
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
        "land_option_purchase_contract_lots": land_option_purchase_contract_lots,
        "land_banking_lots": land_banking_lots,
        "other_controlled_lots": other_controlled_lots,
        "homes_in_inventory": homes_in_inventory,
        "us_owned_lots": us_owned_lots,
        "us_controlled_lots": us_controlled_lots,
        "us_total_lots": us_total_lots,
        "canada_owned_lots": canada_owned_lots,
        "canada_controlled_lots": canada_controlled_lots,
        "canada_total_lots": canada_total_lots,
        "unconsolidated_jv_owned_lots": unconsolidated_jv_owned_lots,
        "unconsolidated_jv_controlled_lots": unconsolidated_jv_controlled_lots,
        "unconsolidated_jv_total_lots": unconsolidated_jv_total_lots,
        "includes_canada_lots": canada_total_lots is not None,
        "includes_unconsolidated_jv_lots": unconsolidated_jv_total_lots is not None,
        "original_2022_owned_lots": original_2022_owned_lots,
        "original_2022_controlled_lots": original_2022_controlled_lots,
        "original_2022_total_lots": original_2022_total_lots,
        "definition_version": definition_version,
        "definition_recast_source_year": definition_recast_source_year,
        "main_series_uses_recast": main_series_uses_recast,
        "component_identity_gap": component_gap,
        "component_identity_pass": (
            abs(component_gap) <= 1
            if isinstance(component_gap, float)
            else False
        ),
        "controlled_component_identity_gap": controlled_component_gap,
        "controlled_component_identity_pass": (
            abs(controlled_component_gap) <= 1
            if isinstance(controlled_component_gap, float)
            else ""
        ),
        "scope_identity_gap": scope_identity_gap,
        "scope_identity_pass": (
            abs(scope_identity_gap) <= 1
            if isinstance(scope_identity_gap, float)
            else ""
        ),
        "extraction_method": extraction_method if extraction_method != "" else "not_found",
        "precision": "reported_table" if extraction_method != "" else "",
        "source_table_index": source_table_index,
        "source_row_label": source_row_label,
        "panel_use_flag": extraction_method != "",
        "manual_review_flag": extraction_method == "",
        "manual_review_reason": "missing_taylor_morrison_land_control_table" if extraction_method == "" else "",
        "source_note": "Taylor Morrison main series uses issuer-level owned and controlled lots. 2013 includes Canada and proportionate JV lots; U.S. subtotal is retained separately. 2022 uses the restated 2022 comparative column from the 2023 table for consistency with 2023-2025; originally filed 2022 values are retained separately.",
    })

    source_notes.append({
        "ticker": "TMHC",
        "fiscal_year": fiscal_year,
        "extraction_method": extraction_method if extraction_method != "" else "not_found",
        "source_excerpt": source_excerpt,
    })

audit_rows = [
    {
        "audit_check": "firm_year_rows",
        "status": "ok" if len(panel_rows) == 13 else "fail",
        "value": len(panel_rows),
        "detail": "Expected Taylor Morrison fiscal years 2013 through 2025 from current filing inventory.",
    },
    {
        "audit_check": "missing_extractions",
        "status": "ok" if sum(row["extraction_method"] == "not_found" for row in panel_rows) == 0 else "fail",
        "value": sum(row["extraction_method"] == "not_found" for row in panel_rows),
        "detail": "Firm-years without a Taylor Morrison land-control extraction.",
    },
    {
        "audit_check": "share_in_range",
        "status": "ok" if all(
            row["nonowned_controlled_share"] is not None and 0 <= row["nonowned_controlled_share"] <= 1
            for row in panel_rows
        ) else "fail",
        "value": sum(
            row["nonowned_controlled_share"] is not None and 0 <= row["nonowned_controlled_share"] <= 1
            for row in panel_rows
        ),
        "detail": "Extracted controlled-lot share is between zero and one.",
    },
    {
        "audit_check": "component_identity",
        "status": "ok" if all(row["component_identity_pass"] for row in panel_rows) else "fail",
        "value": sum(row["component_identity_pass"] for row in panel_rows),
        "detail": "Owned lots plus controlled lots equals total owned and controlled lots.",
    },
    {
        "audit_check": "controlled_component_identity",
        "status": "ok" if all(
            row["controlled_component_identity_pass"] in ("", True)
            for row in panel_rows
        ) else "fail",
        "value": sum(row["controlled_component_identity_pass"] is True for row in panel_rows),
        "detail": "For 2022 onward, controlled subcomponents sum to total controlled lots.",
    },
    {
        "audit_check": "retained_original_2022",
        "status": "ok" if any(row["original_2022_total_lots"] is not None for row in panel_rows) else "fail",
        "value": sum(row["original_2022_total_lots"] is not None for row in panel_rows),
        "detail": "Original 2022 filing classification is retained while the main series uses the 2023 restated 2022 column.",
    },
    {
        "audit_check": "scope_identity_2013",
        "status": "ok" if any(row["scope_identity_pass"] is True for row in panel_rows) else "fail",
        "value": sum(row["scope_identity_pass"] is True for row in panel_rows),
        "detail": "For 2013, U.S. subtotal plus Canada plus unconsolidated JV lots reconciles to issuer-level Total.",
    },
]

write_csv("../output/tmhc_2013_2025_land_panel.csv", panel_rows, [
    "ticker", "cik10", "sec_company_name", "fiscal_year", "report_date",
    "filing_date", "accession_number", "primary_document",
    "source_accession_number", "source_local_path", "source_url", "unit_type",
    "owned_lots", "controlled_lots", "nonowned_controlled_lots", "total_lots",
    "nonowned_controlled_share", "owned_share",
    "land_option_purchase_contract_lots", "land_banking_lots",
    "other_controlled_lots", "homes_in_inventory",
    "us_owned_lots", "us_controlled_lots", "us_total_lots",
    "canada_owned_lots", "canada_controlled_lots", "canada_total_lots",
    "unconsolidated_jv_owned_lots", "unconsolidated_jv_controlled_lots",
    "unconsolidated_jv_total_lots", "includes_canada_lots",
    "includes_unconsolidated_jv_lots",
    "original_2022_owned_lots", "original_2022_controlled_lots",
    "original_2022_total_lots", "definition_version",
    "definition_recast_source_year", "main_series_uses_recast",
    "component_identity_gap",
    "component_identity_pass", "controlled_component_identity_gap",
    "controlled_component_identity_pass", "scope_identity_gap",
    "scope_identity_pass", "extraction_method", "precision",
    "source_table_index", "source_row_label", "panel_use_flag",
    "manual_review_flag", "manual_review_reason", "source_note",
])
write_csv("../output/tmhc_2013_2025_segment_land_rows.csv", segment_rows, [
    "ticker", "cik10", "fiscal_year", "accession_number", "source_table_index",
    "segment_label", "row_type", "owned_lots", "controlled_lots", "total_lots",
    "component_identity_gap",
])
write_csv("../output/tmhc_2013_2025_extraction_audit.csv", audit_rows, [
    "audit_check", "status", "value", "detail",
])
write_csv("../output/tmhc_2013_2025_source_notes.csv", source_notes, [
    "ticker", "fiscal_year", "extraction_method", "source_excerpt",
])
