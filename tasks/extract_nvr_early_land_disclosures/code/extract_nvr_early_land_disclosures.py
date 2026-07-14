#!/usr/bin/env python3

import csv
import html
import re
import sys
from pathlib import Path

sys.path.append(str(Path(__file__).resolve().parents[2] / "_lib"))
from sec_fetch_utils import write_csv


with open("../input/land_light_firm_year_measures.csv", newline="") as f:
    filing_rows = [
        row for row in csv.DictReader(f)
        if row.get("ticker") == "NVR"
        and row.get("form") == "10-K"
        and 2004 <= int(float(row.get("fiscal_year"))) <= 2009
    ]

if len(filing_rows) == 0:
    raise RuntimeError("No early NVR filing rows found in land_light_firm_year_measures.csv.")

panel_rows = []
source_notes = []

for filing in sorted(filing_rows, key=lambda row: int(float(row["fiscal_year"]))):
    fiscal_year = int(float(filing["fiscal_year"]))
    source_path = Path(filing["primary_document_local_path"])

    if not source_path.exists():
        raise RuntimeError(f"Missing NVR source file: {source_path}")

    raw_text = source_path.read_text(encoding="utf-8", errors="ignore")
    clean_filing_text = html.unescape(re.sub(r"<[^>]+>", " ", raw_text))
    clean_filing_text = re.sub(r"\s+", " ", clean_filing_text)

    lpa_match = re.search(
        r"controlled approximately ([0-9,]+) lots with deposits",
        clean_filing_text,
        re.IGNORECASE,
    )
    if lpa_match is None:
        lpa_match = re.search(
            r"controlled approximately ([0-9,]+) lots with an aggregate purchase price",
            clean_filing_text,
            re.IGNORECASE,
        )

    if lpa_match is None:
        raise RuntimeError(f"Could not find NVR purchase-agreement controlled lots for {fiscal_year}.")

    lpa_lots = float(lpa_match.group(1).replace(",", ""))

    jv_lots = None
    for pattern in [
        r"also controlled approximately ([0-9,]+) lots through investments in joint venture",
        r"which controlled approximately ([0-9,]+) lots",
        r"controlled approximately ([0-9,]+) lots through these LLCs",
    ]:
        jv_match = re.search(pattern, clean_filing_text, re.IGNORECASE)
        if jv_match is not None:
            jv_lots = float(jv_match.group(1).replace(",", ""))
            break

    impaired_lots = None
    impaired_match = re.search(
        r"Included in the number of controlled lots are approximately ([0-9,]+) lots",
        clean_filing_text,
        re.IGNORECASE,
    )
    if impaired_match is not None:
        impaired_lots = float(impaired_match.group(1).replace(",", ""))

    specific_performance_lots = None
    specific_performance_match = re.search(
        r"specific performance[^.]*?([0-9,]+) (?:finished )?lots",
        clean_filing_text,
        re.IGNORECASE,
    )
    if specific_performance_match is not None:
        specific_performance_lots = float(specific_performance_match.group(1).replace(",", ""))

    original_as_filed_total_lots = lpa_lots + (jv_lots if jv_lots is not None else 0)
    total_lots = original_as_filed_total_lots
    restated_prior_year_value_used = False
    jv_lots_added_to_main_total = jv_lots is not None

    if fiscal_year == 2009:
        original_as_filed_total_lots = lpa_lots
        total_lots = 46337.0
        restated_prior_year_value_used = True
        jv_lots_added_to_main_total = False

    source_excerpt = clean_filing_text[
        max(0, lpa_match.start() - 500):min(len(clean_filing_text), lpa_match.end() + 900)
    ]

    source_note = "NVR early prose-era row. Reported controlled lots are treated as an all-controlled NVR land pipeline, not as a decomposed owned-versus-controlled table."
    if jv_lots_added_to_main_total:
        source_note = source_note + " Separately disclosed JV-controlled lots are added because the filing uses additional/also language."
    if fiscal_year == 2009:
        source_note = source_note + " Main 2009 value uses 2010 filing's restated 46,337 prior-year total; originally filed rounded 46,300 deposit-controlled lots and 760 LLC lots are retained separately."

    panel_rows.append({
        "ticker": "NVR",
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
        "owned_lots": 0.0,
        "nonowned_controlled_lots": total_lots,
        "lpa_or_deposit_controlled_lots": lpa_lots,
        "jv_controlled_lots": jv_lots,
        "total_lots": total_lots,
        "nonowned_controlled_share": 1.0,
        "owned_share": 0.0,
        "component_identity_gap": 0.0,
        "component_identity_pass": True,
        "source_type": "prose_disclosure",
        "early_prose_series": True,
        "owned_lots_not_separately_disclosed": True,
        "omega_set_to_one_by_reported_control_universe": True,
        "jv_lots_added_to_main_total": jv_lots_added_to_main_total,
        "jv_nonoverlap_assumption_flag": jv_lots_added_to_main_total,
        "specific_performance_lots": specific_performance_lots,
        "specific_performance_lots_added_to_total": False,
        "impaired_lots_within_controlled_pipeline": impaired_lots,
        "impaired_lots_excluded_from_numerator": False,
        "restated_prior_year_value_used": restated_prior_year_value_used,
        "original_as_filed_total_lots": original_as_filed_total_lots,
        "extraction_method": "early_prose_regex_controlled_lots",
        "precision": "rounded_prose",
        "panel_use_flag": True,
        "manual_review_flag": True,
        "manual_review_reason": "early_nvr_prose_series_not_fully_decomposed_owned_controlled_table",
        "source_note": source_note,
    })

    source_notes.append({
        "ticker": "NVR",
        "fiscal_year": fiscal_year,
        "accession_number": filing["accession_number"],
        "primary_document": filing["primary_document"],
        "source_local_path": filing["primary_document_local_path"],
        "source_note": source_note,
        "source_excerpt": source_excerpt,
    })

audit_rows = [
    {
        "audit_check": "firm_year_rows",
        "status": "ok" if len(panel_rows) == 6 else "fail",
        "value": len(panel_rows),
        "detail": "Expected NVR early fiscal years 2004 through 2009.",
    },
    {
        "audit_check": "missing_extractions",
        "status": "ok" if sum(row["total_lots"] is None for row in panel_rows) == 0 else "fail",
        "value": sum(row["total_lots"] is None for row in panel_rows),
        "detail": "Every early NVR filing should have a prose controlled-lot count.",
    },
    {
        "audit_check": "share_equals_one",
        "status": "ok" if all(row["nonowned_controlled_share"] == 1.0 for row in panel_rows) else "fail",
        "value": sum(row["nonowned_controlled_share"] == 1.0 for row in panel_rows),
        "detail": "Early NVR rows are all-controlled-pipeline observations by construction.",
    },
    {
        "audit_check": "jv_fields_present",
        "status": "ok" if sum(row["jv_controlled_lots"] is not None for row in panel_rows) == 6 else "fail",
        "value": sum(row["jv_controlled_lots"] is not None for row in panel_rows),
        "detail": "Every early NVR filing should disclose JV/LLC-controlled lots separately.",
    },
    {
        "audit_check": "restated_2009_used_once",
        "status": "ok" if sum(row["restated_prior_year_value_used"] for row in panel_rows) == 1 else "fail",
        "value": sum(row["restated_prior_year_value_used"] for row in panel_rows),
        "detail": "Only 2009 should use the 2010 restated prior-year total controlled-lot value.",
    },
]

write_csv(
    "../output/nvr_2004_2009_early_land_panel.csv",
    panel_rows,
    [
        "ticker", "cik10", "sec_company_name", "fiscal_year", "report_date", "filing_date",
        "accession_number", "primary_document", "source_local_path", "source_url", "unit_type",
        "owned_lots", "nonowned_controlled_lots", "lpa_or_deposit_controlled_lots",
        "jv_controlled_lots", "total_lots", "nonowned_controlled_share", "owned_share",
        "component_identity_gap", "component_identity_pass", "source_type", "early_prose_series",
        "owned_lots_not_separately_disclosed", "omega_set_to_one_by_reported_control_universe",
        "jv_lots_added_to_main_total", "jv_nonoverlap_assumption_flag",
        "specific_performance_lots", "specific_performance_lots_added_to_total",
        "impaired_lots_within_controlled_pipeline", "impaired_lots_excluded_from_numerator",
        "restated_prior_year_value_used", "original_as_filed_total_lots", "extraction_method",
        "precision", "panel_use_flag", "manual_review_flag", "manual_review_reason", "source_note",
    ],
)

write_csv(
    "../output/nvr_2004_2009_early_land_audit.csv",
    audit_rows,
    ["audit_check", "status", "value", "detail"],
)

write_csv(
    "../output/nvr_2004_2009_early_source_notes.csv",
    source_notes,
    [
        "ticker", "fiscal_year", "accession_number", "primary_document",
        "source_local_path", "source_note", "source_excerpt",
    ],
)
