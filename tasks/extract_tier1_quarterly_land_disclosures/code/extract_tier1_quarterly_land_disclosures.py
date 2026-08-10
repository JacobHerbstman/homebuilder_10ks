#!/usr/bin/env python3

import csv
import re
import sys
from pathlib import Path

sys.path.append(str(Path(__file__).resolve().parents[2] / "_lib"))
from sec_fetch_utils import write_csv

sys.path.append(str(Path(__file__).resolve().parents[2] / "extract_10k_land_candidates" / "code"))
from extract_10k_land_candidates import SecTableParser, VisibleTextParser, clean_text

def read_html(path):
    raw = Path(path).read_bytes()
    for encoding in ("utf-8", "latin-1"):
        try:
            return raw.decode(encoding)
        except UnicodeDecodeError:
            continue
    return raw.decode("latin-1", errors="ignore")


def visible_text(raw_html):
    parser = VisibleTextParser()
    parser.feed(raw_html)
    parser.close()
    return clean_text(parser.text())


def parsed_tables(raw_html):
    parser = SecTableParser()
    parser.feed(raw_html)
    tables = []
    for table_index, table in enumerate(parser.tables):
        rows = []
        for html_row in table["rows"]:
            cells = [clean_text(cell.get("text", "")) for cell in html_row]
            cells = [cell for cell in cells if cell]
            if cells:
                rows.append(cells)
        if rows:
            tables.append((table_index, rows, clean_text(" || ".join(" | ".join(cells) for cells in rows))))
    return tables


def parse_number(x):
    if x is None:
        return None
    cleaned = str(x).replace("$", "").replace(",", "").replace("(", "").replace(")", "").strip()
    if cleaned in {"-", "—", ""}:
        return 0.0 if cleaned in {"-", "—"} else None
    return float(cleaned)


def numeric_values(cells):
    values = []
    for cell in cells[1:]:
        if re.fullmatch(r"\(?\s*\$?\s*[0-9][0-9,]*(?:\.[0-9]+)?\s*%?\s*\)?", cell):
            values.append(parse_number(cell.replace("%", "")))
    return values


def snippet(text, match, before=450, after=850):
    return clean_text(text[max(0, match.start() - before):min(len(text), match.end() + after)])


def format_number(x):
    if x is None:
        return ""
    if abs(x - round(x)) < 1e-9:
        return str(int(round(x)))
    return str(x)


def format_share(x):
    if x is None:
        return ""
    return f"{x:.12g}"


def base_disclosure(row):
    return {
        "ticker": row["ticker"],
        "company": row["company"],
        "cik10": row["cik10"],
        "calendar_year": row["calendar_year"],
        "calendar_quarter": row["calendar_quarter"],
        "calendar_quarter_label": row["calendar_quarter_label"],
        "fiscal_year": row["fiscal_year"],
        "fiscal_quarter": row["fiscal_quarter"],
        "form": row["source_form"],
        "filing_date": row["source_filing_date"],
        "report_date": row["source_report_date"],
        "accession_number": row["source_accession_number"],
        "source_url": row["source_url"],
        "source_local_path": row["source_local_path"],
        "source_checksum_sha256": row["source_checksum_sha256"],
        "owned_lots_or_homesites": "",
        "nonowned_controlled_lots_or_homesites": "",
        "total_lots_or_homesites": "",
        "omega_nonowned_controlled_share": "",
        "reported_pipeline_lots_or_homesites": "",
        "unit_type": "",
        "measure_definition": "",
        "extraction_method": "",
        "extraction_confidence": "",
        "source_quality": "",
        "omega_component_counts_available": "",
        "component_identity_expected": "",
        "manual_review_flag": "",
        "manual_review_reason": "",
        "context_snippet": "",
    }


def disclosure_from_values(
    row, owned, nonowned, total, unit_type, measure_definition, method, confidence, quality, context,
    component_identity_expected=True,
):
    out = base_disclosure(row)
    out["owned_lots_or_homesites"] = format_number(owned)
    out["nonowned_controlled_lots_or_homesites"] = format_number(nonowned)
    out["total_lots_or_homesites"] = format_number(total)
    out["omega_nonowned_controlled_share"] = format_share(nonowned / total if total not in (None, 0) and nonowned is not None else None)
    out["unit_type"] = unit_type
    out["measure_definition"] = measure_definition
    out["extraction_method"] = method
    out["extraction_confidence"] = confidence
    out["source_quality"] = quality
    out["omega_component_counts_available"] = str(nonowned is not None and total is not None).upper()
    out["component_identity_expected"] = str(component_identity_expected).upper()
    out["manual_review_flag"] = "FALSE"
    out["manual_review_reason"] = ""
    out["context_snippet"] = context
    return out


def disclosure_from_share(
    row, share, unit_type, measure_definition, method, confidence, quality, context, review_reason, total=None,
):
    out = base_disclosure(row)
    out["total_lots_or_homesites"] = format_number(total)
    out["omega_nonowned_controlled_share"] = format_share(share)
    out["unit_type"] = unit_type
    out["measure_definition"] = measure_definition
    out["extraction_method"] = method
    out["extraction_confidence"] = confidence
    out["source_quality"] = quality
    out["omega_component_counts_available"] = "FALSE"
    out["component_identity_expected"] = "FALSE"
    out["manual_review_flag"] = "FALSE" if review_reason == "" else "TRUE"
    out["manual_review_reason"] = review_reason
    out["context_snippet"] = context
    return out


def incomplete_disclosure(
    row, nonowned, pipeline, unit_type, measure_definition, method, reason, context, owned=None,
):
    out = base_disclosure(row)
    out["owned_lots_or_homesites"] = format_number(owned)
    out["nonowned_controlled_lots_or_homesites"] = format_number(nonowned)
    out["reported_pipeline_lots_or_homesites"] = format_number(pipeline)
    out["unit_type"] = unit_type
    out["measure_definition"] = measure_definition
    out["extraction_method"] = method
    out["extraction_confidence"] = "high"
    out["source_quality"] = "reported_component_without_omega_denominator"
    out["omega_component_counts_available"] = "FALSE"
    out["component_identity_expected"] = "FALSE"
    out["manual_review_flag"] = "TRUE"
    out["manual_review_reason"] = reason
    out["context_snippet"] = context
    return out


def missing_disclosure(row, reason, context=""):
    out = base_disclosure(row)
    out["extraction_method"] = "not_disclosed"
    out["extraction_confidence"] = "none"
    out["source_quality"] = "missing"
    out["omega_component_counts_available"] = "FALSE"
    out["component_identity_expected"] = "FALSE"
    out["manual_review_flag"] = "TRUE"
    out["manual_review_reason"] = reason
    out["context_snippet"] = context
    return out


def extract_dhi(row, text):
    pattern = (
        r"Owned lots totaled\s+([0-9,]+).{0,320}?"
        r"Lots controlled through (?:land and lot |option )?purchase contracts\s+"
        r"(?:totaled|increased to|decreased to)\s+([0-9,]+)"
    )
    match = re.search(pattern, text, re.IGNORECASE)
    if not match:
        return missing_disclosure(row, "DHI current-quarter owned/controlled lot prose was not found.")
    owned = parse_number(match.group(1))
    nonowned = parse_number(match.group(2))
    return disclosure_from_values(
        row,
        owned,
        nonowned,
        owned + nonowned,
        "lots",
        "lots_controlled_through_purchase_contracts / total_owned_and_controlled_lots",
        "dhi_owned_lots_and_purchase_contract_prose",
        "high",
        "exact_quarterly_components",
        snippet(text, match),
    )


def extract_len(row, text):
    old_split = (
        r"Optioned\s+JVs\s+Total\s+Owned Homesites\s+Total Homesites"
        r".{0,1100}?Total homesites(?:\s*\([^)]*\))?\s+"
        r"([0-9,]+)\s+([0-9,]+)\s+([0-9,]+)\s+([0-9,]+)\s+([0-9,]+)"
    )
    match = re.search(old_split, text, re.IGNORECASE)
    if match:
        controlled = parse_number(match.group(3))
        owned = parse_number(match.group(4))
        total = parse_number(match.group(5))
        return disclosure_from_values(
            row,
            owned,
            controlled,
            total,
            "homesites",
            "controlled_homesites_optioned_plus_jv / total_homesites",
            "len_optioned_jv_owned_homesite_table",
            "high",
            "exact_quarterly_components",
            snippet(text, match),
        )

    combined = (
        r"Controlled Homesites\s+Owned Homesites\s+Total Homesites\s+Supply Owned"
        r".{0,1100}?Total homesites\s+([0-9,]+)\s+([0-9,]+)\s+([0-9,]+)"
        r"\s+[0-9.]+\s*%\s+of total homesites\s+([0-9]+)\s*%\s+([0-9]+)\s*%"
    )
    match = re.search(combined, text, re.IGNORECASE)
    if not match:
        return missing_disclosure(row, "Lennar controlled/owned/total homesite table was not found.")
    controlled = parse_number(match.group(1))
    owned = parse_number(match.group(2))
    total = parse_number(match.group(3))
    return disclosure_from_values(
        row,
        owned,
        controlled,
        total,
        "homesites",
        "controlled_homesites / total_homesites",
        "len_controlled_owned_homesite_table",
        "high",
        "exact_quarterly_components",
        snippet(text, match),
    )


def extract_phm(row, text):
    pattern = r"Controlled lots.{0,1400}?\bTotal\s+([0-9,]+)\s+([0-9,]+)\s+([0-9,]+)"
    match = re.search(pattern, text, re.IGNORECASE)
    if not match:
        return missing_disclosure(row, "Pulte owned/optioned/controlled lot table was not found.")
    owned = parse_number(match.group(1))
    nonowned = parse_number(match.group(2))
    total = parse_number(match.group(3))
    return disclosure_from_values(
        row,
        owned,
        nonowned,
        total,
        "lots",
        "optioned_lots / controlled_lots",
        "phm_owned_optioned_controlled_lot_table",
        "high",
        "exact_quarterly_components",
        snippet(text, match),
    )


def extract_kbh(row, text):
    pattern = (
        r"(?:number of lots we controlled under land option contracts and other similar contracts|"
        r"lots\s+(?:[0-9]+\s+)?controlled under land option contracts and other similar contracts|"
        r"land under contract)"
        r".{0,160}?as a percentage of total lots was\s+([0-9.]+)\s*%"
    )
    match = re.search(pattern, text, re.IGNORECASE)
    if not match:
        return missing_disclosure(row, "KBH direct land-option share disclosure was not found.")
    return disclosure_from_share(
        row,
        parse_number(match.group(1)) / 100,
        "lots",
        "direct_disclosed_land_option_or_under_contract_share_of_total_lots",
        "kbh_direct_percentage_prose",
        "high",
        "direct_quarterly_share_no_counts",
        snippet(text, match),
        "",
    )


def extract_hov(row, text):
    old_table = (
        r"Owned\s+([0-9,]+)\s+([0-9,]+)\s+([0-9,]+)\s+"
        r"Optioned\s+([0-9,]+)\s+([0-9,]+)\s+([0-9,]+)\s+"
        r"Controlled lots\s+([0-9,]+)\s+([0-9,]+)\s+([0-9,]+)\s+"
        r"Construction to permanent financing lots\s+([0-9,\-]+)\s+([0-9,\-]+)\s+([0-9,\-]+)\s+"
        r"Consolidated total\s+([0-9,]+)\s+([0-9,]+)\s+([0-9,]+)"
    )
    match = re.search(old_table, text, re.IGNORECASE)
    if match:
        owned = parse_number(match.group(3))
        nonowned = parse_number(match.group(6))
        total = parse_number(match.group(15))
        return disclosure_from_values(
            row,
            owned,
            nonowned,
            total,
            "homesites",
            "optioned_home_sites / consolidated_total_home_sites",
            "hov_owned_optioned_controlled_lot_table",
            "high",
            "exact_quarterly_components",
            snippet(text, match),
            False,
        )

    new_table = (
        r"Owned\s+([0-9,]+)\s+([0-9,]+)\s+([0-9,]+)\s+"
        r"Optioned\s+([0-9,]+)\s+([0-9,]+)\s+([0-9,]+)\s+"
        r"Construction to permanent financing lots\s+([0-9,\-]+)\s+([0-9,\-]+)\s+([0-9,\-]+)\s+"
        r"Consolidated total\s+([0-9,]+)\s+([0-9,]+)\s+([0-9,]+)"
    )
    match = re.search(new_table, text, re.IGNORECASE)
    if not match:
        return missing_disclosure(row, "Hovnanian owned/optioned/consolidated home-site table was not found.")
    owned = parse_number(match.group(3))
    nonowned = parse_number(match.group(6))
    total = parse_number(match.group(12))
    return disclosure_from_values(
        row,
        owned,
        nonowned,
        total,
        "homesites",
        "optioned_home_sites / consolidated_total_home_sites",
        "hov_owned_optioned_home_site_table",
        "high",
        "exact_quarterly_components",
        snippet(text, match),
        False,
    )


def extract_nvr(row, text):
    total_match = re.search(r"Total lots controlled:\s+.*?\bTotal\s+([0-9,]+)\s+([0-9,]+)", text, re.IGNORECASE)
    lpa_match = re.search(
        r"controlled approximately\s+([0-9,]+)\s+lots?\s+under\s+(?:LPAs|Lot Purchase Agreements|purchase agreements)",
        text,
        re.IGNORECASE,
    )
    jv_match = re.search(
        r"Of the lots to be produced by the JVs,\s+approximately\s+([0-9,]+)\s+lots?\s+were\s+controlled\s+by\s+us",
        text,
        re.IGNORECASE,
    )
    if not jv_match:
        jv_match = re.search(r"approximately\s+([0-9,]+)\s+lots?\s+were\s+controlled\s+by\s+us", text, re.IGNORECASE)
    if total_match and lpa_match:
        total = parse_number(total_match.group(1))
        nonowned = parse_number(lpa_match.group(1)) + (parse_number(jv_match.group(1)) if jv_match else 0)
        return disclosure_from_values(
            row,
            None,
            nonowned,
            total,
            "lots",
            "lpa_plus_jv_controlled_lots / total_controlled_lots",
            "nvr_total_lots_table_plus_lpa_jv_prose",
            "high" if jv_match else "medium",
            "component_count_no_owned_lots",
            clean_text(f"{snippet(text, total_match, 350, 550)} {snippet(text, lpa_match, 350, 550)} {snippet(text, jv_match, 350, 550) if jv_match else ''}"),
        )
    if total_match:
        total = parse_number(total_match.group(1))
        return disclosure_from_share(
            row,
            1.0,
            "lots",
            "total_controlled_lots_as_nonowned_proxy",
            "nvr_total_controlled_lots_proxy",
            "low",
            "proxy_total_controlled_lots_only",
            snippet(text, total_match),
            "NVR total controlled lots were found, but LPA/JV components were not found in this filing.",
        )
    return missing_disclosure(row, "NVR total controlled lots table was not found.")


def extract_bzh(row, text):
    patterns = [
        (
            r"Of the (?:total\s+)?activ\s*e?\s+([0-9,]+)\s+lots,\s+we owned\s+[0-9.]+\s*%\s*,?\s*or\s+([0-9,]+)\s+of these lots,\s+"
            r"and\s+the remaining\s+([0-9,]+)\s+of these lots.*?were under option contracts",
            "bzh_active_owned_optioned_prose",
        ),
        (
            r"Of the\s+([0-9,]+)\s+active lots,\s+we controlled\s+([0-9,]+)\s+of these lots.*?through option agreements",
            "bzh_active_optioned_prose",
        ),
        (
            r"we controlled\s+([0-9,]+)\s+lots.*?we owned\s+[0-9.]+\s*%\s*,?\s*or\s+([0-9,]+)\s+of these lots,\s+"
            r"and\s+(?:the remaining\s+)?([0-9,]+)\s+of these lots.*?were under option contracts",
            "bzh_total_owned_optioned_prose",
        ),
    ]
    for pattern, method in patterns:
        match = re.search(pattern, text, re.IGNORECASE)
        if not match:
            continue
        if method == "bzh_total_owned_optioned_prose":
            total, owned, nonowned = [parse_number(match.group(i)) for i in range(1, 4)]
        elif method == "bzh_active_owned_optioned_prose":
            total, owned, nonowned = [parse_number(match.group(i)) for i in range(1, 4)]
        else:
            total = parse_number(match.group(1))
            nonowned = parse_number(match.group(2))
            owned = total - nonowned
        return disclosure_from_values(
            row, owned, nonowned, total, "lots",
            "lots_under_option_agreements / total_active_lots",
            method, "high", "exact_quarterly_components", snippet(text, match),
        )

    active_match = re.search(r"controlled\s+([0-9,]+)\s+active lots", text, re.IGNORECASE)
    option_match = re.search(
        r"(?:had|controlled)\s+([0-9,]+)\s+lots,\s+or\s+[0-9.]+\s*%\s+of our total active lots.*?(?:under|through) option",
        text, re.IGNORECASE,
    )
    if active_match and option_match:
        total = parse_number(active_match.group(1))
        nonowned = parse_number(option_match.group(1))
        return disclosure_from_values(
            row, total - nonowned, nonowned, total, "lots",
            "lots_under_option_agreements / total_active_lots",
            "bzh_active_total_and_optioned_prose", "high", "exact_quarterly_components",
            clean_text(f"{snippet(text, active_match)} {snippet(text, option_match)}"),
        )
    return missing_disclosure(row, "Beazer total active lots and optioned-lot count were not jointly disclosed.")


def extract_ccs(row, text, tables):
    for _, rows, table_text in tables:
        lower = table_text.lower()
        if "lots owned" not in lower or "controlled" not in lower or "owned" not in lower:
            continue
        for cells in rows:
            if cells[0].lower() != "total":
                continue
            values = numeric_values(cells)
            if len(values) >= 3 and values[0] + values[1] == values[2]:
                return disclosure_from_values(
                    row, values[0], values[1], values[2], "lots",
                    "controlled_lots / total_owned_and_controlled_lots",
                    "ccs_owned_controlled_total_row", "high",
                    "exact_quarterly_components_prose_total_differs_by_10"
                    if row["source_report_date"] == "2022-09-30" else "exact_quarterly_components",
                    table_text[:2200],
                )
    match = re.search(
        r"(?:Homebuilding\s+)?Lots owned and controlled\s+(?:March|June|September)\s+[0-9]{1,2},?\s+[0-9]{4}"
        r".{0,2200}?\bTotal\s+([0-9,]+)\s+([0-9,]+)\s+([0-9,]+)",
        text, re.IGNORECASE,
    )
    if match:
        owned, nonowned, total = [parse_number(match.group(i)) for i in range(1, 4)]
        if owned + nonowned == total:
            return disclosure_from_values(
                row, owned, nonowned, total, "lots",
                "controlled_lots / total_owned_and_controlled_lots",
                "ccs_owned_controlled_total_text", "high",
                "exact_quarterly_components_prose_total_differs_by_10"
                if row["source_report_date"] == "2022-09-30" else "exact_quarterly_components",
                snippet(text, match),
            )
    return missing_disclosure(row, "Century Communities owned/controlled/total lot row was not found.")


def extract_dfh(row, text):
    match = re.search(
        r"Owned and Controlled Lots.{0,7000}?Grand Total(?:\s*\([0-9]+\))?\s+([0-9,]+)\s+([0-9,]+)\s+([0-9,]+)",
        text, re.IGNORECASE,
    )
    if match:
        owned, nonowned, total = [parse_number(match.group(i)) for i in range(1, 4)]
        if owned + nonowned == total:
            return disclosure_from_values(
                row, owned, nonowned, total, "lots",
                "controlled_lots / total_owned_and_controlled_lots",
                "dfh_owned_controlled_grand_total_row", "high", "exact_quarterly_components", snippet(text, match),
            )

    total_match = re.search(
        r"Total owned and controlled lots.*?to\s+([0-9,]+)\s+lots at",
        text, re.IGNORECASE,
    )
    controlled_match = re.search(
        r"controlled\s+([0-9,]+)\s+lots under (?:finished )?lot option and land bank option contracts",
        text, re.IGNORECASE,
    )
    if total_match and controlled_match:
        total = parse_number(total_match.group(1))
        nonowned = parse_number(controlled_match.group(1))
        return disclosure_from_values(
            row, total - nonowned, nonowned, total, "lots",
            "controlled_lots / total_owned_and_controlled_lots",
            "dfh_total_prose_and_controlled_prose", "high", "exact_quarterly_components",
            clean_text(f"{snippet(text, total_match)} {snippet(text, controlled_match)}"),
        )

    pipeline_match = re.search(
        r"Controlled Lots? Pipeline.*?Total\s*\([0-9]+\)\s+([0-9,]+)\s+([0-9,]+)",
        text, re.IGNORECASE,
    )
    if pipeline_match:
        nonowned = parse_number(pipeline_match.group(1))
        return incomplete_disclosure(
            row, nonowned, None, "lots", "controlled_lot_pipeline_without_owned_lot_denominator",
            "dfh_controlled_lot_pipeline_only",
            "Dream Finders stopped disclosing the owned-lot denominator; quarterly omega is not computable.",
            snippet(text, pipeline_match),
        )
    return missing_disclosure(row, "Dream Finders owned/controlled lot table or controlled-lot pipeline was not found.")


def extract_grbk(row, tables):
    for _, rows, table_text in tables:
        lower = table_text.lower()
        if "total lots owned" not in lower or not any(term in lower for term in ("total lots controlled", "total lots under contract")):
            continue
        owned = None
        nonowned = None
        total = None
        for cells in rows:
            label = cells[0].lower()
            values = numeric_values(cells)
            if not values:
                continue
            current = values[2] if len(values) >= 3 and values[0] + values[1] == values[2] else values[0]
            if label.startswith("total lots owned and controlled") or label.startswith("total lots owned and under contract"):
                total = current
            elif label.startswith("total lots owned"):
                owned = current
            elif label.startswith("total lots controlled") or label.startswith("total lots under contract"):
                nonowned = current
        if owned is not None and nonowned is not None:
            total = total if total is not None else owned + nonowned
            return disclosure_from_values(
                row, owned, nonowned, total, "lots",
                "controlled_or_under_contract_lots / total_owned_and_controlled_lots",
                "grbk_companywide_total_rows", "high", "exact_quarterly_components", table_text[:2200],
            )
    return missing_disclosure(row, "Green Brick company-wide owned/controlled lot totals were not found.")


def extract_lgih(row, text):
    match = re.search(
        r"Home Closings\s+Owned(?:\s*\([0-9]+\))?\s+Controlled(?:\s*\([0-9]+\))?\s+Total.*?"
        r"\bTotal\s+([0-9,]+)\s+([0-9,]+)\s+([0-9,]+)\s+([0-9,]+)",
        text, re.IGNORECASE,
    )
    if not match:
        return missing_disclosure(row, "LGI company-wide closings/owned/controlled/total lot row was not found.")
    owned = parse_number(match.group(2))
    nonowned = parse_number(match.group(3))
    total = parse_number(match.group(4))
    return disclosure_from_values(
        row, owned, nonowned, total, "lots",
        "controlled_lots / total_owned_and_controlled_lots",
        "lgih_operating_lot_total_row", "high", "exact_quarterly_components", snippet(text, match),
    )


def extract_lsea(row, tables):
    for _, rows, table_text in tables:
        lower = table_text.lower()
        if "lots owned" not in lower or "lots controlled" not in lower:
            continue
        for cells in rows:
            if cells[0].lower() != "total":
                continue
            values = numeric_values(cells)
            if len(values) >= 3 and values[0] + values[1] == values[2]:
                return disclosure_from_values(
                    row, values[0], values[1], values[2], "lots",
                    "controlled_lots / total_owned_and_controlled_lots",
                    "lsea_owned_controlled_total_row", "high", "exact_quarterly_components", table_text[:2200],
                )
    return missing_disclosure(row, "Landsea company-wide owned/controlled lot total row was not found.")


def extract_mdc(row, tables):
    for _, rows, table_text in tables:
        lower = table_text.lower()
        if "lots owned" not in lower or not any(term in lower for term in ("lots optioned", "lots under option")):
            continue
        for cells in rows:
            if cells[0].lower() != "total":
                continue
            values = numeric_values(cells)
            if len(values) >= 3 and values[0] + values[1] == values[2]:
                return disclosure_from_values(
                    row, values[0], values[1], values[2], "lots",
                    "optioned_lots / total_owned_and_optioned_lots",
                    "mdc_owned_optioned_total_row", "high", "exact_quarterly_components", table_text[:2200],
                )
    return missing_disclosure(row, "MDC company-wide owned/optioned lot total row was not found.")


def extract_mho(row, text):
    match = re.search(r"had a total of\s+([0-9,]+)\s+lots under contract", text, re.IGNORECASE)
    if not match:
        return missing_disclosure(row, "M/I Homes quarterly lots-under-contract disclosure was not found.")
    return incomplete_disclosure(
        row, parse_number(match.group(1)), None, "lots", "lots_under_contract_without_owned_lot_denominator",
        "mho_lots_under_contract_prose",
        "M/I Homes reports quarterly lots under contract but discloses owned-lot counts only annually.",
        snippet(text, match),
    )


def extract_mth(row, text, tables):
    for _, rows, table_text in tables:
        lower = table_text.lower()
        if "projected number of lots" not in lower or "total committed" not in lower:
            continue
        for cells in rows:
            if not cells[0].lower().startswith("total committed"):
                continue
            values = numeric_values(cells)
            if values:
                return incomplete_disclosure(
                    row, values[0], None, "lots",
                    "committed_purchase_and_option_contract_lots_without_owned_lot_denominator",
                    "mth_total_committed_contract_lots_row",
                    "Meritage reports quarterly committed contract lots but discloses owned-lot counts only annually.",
                    table_text[:2200],
                )
    match = re.search(r"Total committed\s+([0-9,]+)\s+[0-9,]+\s+[0-9,]+", text, re.IGNORECASE)
    if match:
        return incomplete_disclosure(
            row, parse_number(match.group(1)), None, "lots",
            "committed_purchase_and_option_contract_lots_without_owned_lot_denominator",
            "mth_total_committed_contract_lots_text",
            "Meritage reports quarterly committed contract lots but discloses owned-lot counts only annually.",
            snippet(text, match),
        )
    return missing_disclosure(row, "Meritage committed purchase/option contract lot row was not found.")


def extract_sdhc(row, text):
    match = re.search(
        r"Controlled lots \(period end\):.*?Homes under construction\s+([0-9,]+)\s+[0-9,]+.*?"
        r"Owned lots\s+([0-9,]+)\s+[0-9,]+.*?Optioned lots\s+([0-9,]+)\s+[0-9,]+.*?"
        r"Total controlled lots\s+([0-9,]+)\s+[0-9,]+",
        text, re.IGNORECASE,
    )
    if not match:
        return missing_disclosure(row, "Smith Douglas owned/optioned/total controlled lot block was not found.")
    homes_under_construction, owned_lots, nonowned, total = [parse_number(match.group(i)) for i in range(1, 5)]
    owned = homes_under_construction + owned_lots
    return disclosure_from_values(
        row, owned, nonowned, total, "lots",
        "optioned_lots / total_controlled_lots_including_homes_under_construction",
        "sdhc_controlled_lots_operating_block", "high", "exact_quarterly_components", snippet(text, match),
    )


def extract_tmhc(row, text, tables):
    for _, rows, table_text in tables:
        lower = table_text.lower()
        if "total owned lots" not in lower or "total controlled lots" not in lower:
            continue
        owned = None
        nonowned = None
        total = None
        for cells in rows:
            values = numeric_values(cells)
            if not values:
                continue
            label = cells[0].lower()
            if label == "total owned lots":
                owned = values[0]
            elif label == "total controlled lots":
                nonowned = values[0]
            elif label == "total owned and controlled lots":
                total = values[0]
        if owned is not None and nonowned is not None:
            total = total if total is not None else owned + nonowned
            return disclosure_from_values(
                row, owned, nonowned, total, "lots",
                "controlled_lots / total_owned_and_controlled_lots",
                "tmhc_owned_controlled_total_rows", "high", "exact_quarterly_components", table_text[:2200],
            )

    owned_match = re.search(r"Total homebuilding owned lots\s+([0-9,]+)", text, re.IGNORECASE)
    controlled_match = re.search(r"Total controlled lots\s+([0-9,]+)", text, re.IGNORECASE)
    if owned_match and controlled_match:
        owned = parse_number(owned_match.group(1))
        nonowned = parse_number(controlled_match.group(1))
        return disclosure_from_values(
            row, owned, nonowned, owned + nonowned, "lots",
            "controlled_lots / total_homebuilding_owned_and_controlled_lots",
            "tmhc_separate_owned_and_controlled_tables", "high", "exact_quarterly_components",
            clean_text(f"{snippet(text, owned_match)} {snippet(text, controlled_match)}"),
        )

    share_match = re.search(
        r"Controlled lots as a percentage of total (?:lot )?supply.*?to\s+([0-9.]+)\s+percent",
        text, re.IGNORECASE,
    )
    total_match = re.search(
        r"approximately\s+([0-9,]+)\s+(?:total lots owned and controlled|owned and controlled homesites|"
        r"homebuilding lots owned and controlled)",
        text, re.IGNORECASE,
    )
    if not total_match:
        total_match = re.search(
            r"Homebuilding lot supply.*?approximately\s+([0-9,]+)\s+(?:total lots owned and controlled|"
            r"owned and controlled homesites)",
            text, re.IGNORECASE,
        )
    if share_match:
        return disclosure_from_share(
            row, parse_number(share_match.group(1)) / 100, "lots",
            "direct_disclosed_controlled_share_of_total_lot_supply",
            "tmhc_direct_controlled_share", "high", "direct_quarterly_share_rounded_total",
            clean_text(f"{snippet(text, share_match)} {snippet(text, total_match) if total_match else ''}"),
            "", parse_number(total_match.group(1)) if total_match else None,
        )

    owned_match = re.search(r"(?:Total owned lots|Total)\s+([0-9,]+)\s+\$?\s*[0-9,]+", text, re.IGNORECASE)
    option_match = re.search(
        r"had the right to purchase\s+([0-9,]+).*?lots under land option purchase contracts",
        text, re.IGNORECASE,
    )
    bank_match = re.search(
        r"had the right to purchase\s+([0-9,]+)\s+lots under such land agreements",
        text, re.IGNORECASE,
    )
    if owned_match and option_match:
        known_nonowned = parse_number(option_match.group(1)) + (parse_number(bank_match.group(1)) if bank_match else 0)
        return incomplete_disclosure(
            row, known_nonowned, None, "lots",
            "disclosed_option_and_land_bank_lots_without_other_controlled_lots",
            "tmhc_partial_controlled_components",
            "Taylor Morrison did not disclose all controlled-lot categories in this quarterly filing; omega is not computable.",
            clean_text(f"{snippet(text, owned_match)} {snippet(text, option_match)} "
                       f"{snippet(text, bank_match) if bank_match else ''}"),
            parse_number(owned_match.group(1)),
        )
    return missing_disclosure(row, "Taylor Morrison quarterly owned and controlled lot disclosures were not found.")


def extract_tol(row, text):
    match = re.search(
        r"owned or controlled through options approximately\s+([0-9,]+)\s+home sites.*?"
        r"Of the approximately\s+[0-9,]+\s+total home sites.*?we owned approximately\s+([0-9,]+)\s+"
        r"and controlled approximately\s+([0-9,]+)\s+through options",
        text, re.IGNORECASE,
    )
    if not match:
        return missing_disclosure(row, "Toll company-wide owned/controlled homesite prose was not found.")
    total, owned, nonowned = [parse_number(match.group(i)) for i in range(1, 4)]
    return disclosure_from_values(
        row, owned, nonowned, total, "homesites",
        "controlled_through_options_homesites / total_owned_or_controlled_homesites",
        "tol_companywide_prose", "high", "rounded_quarterly_components", snippet(text, match),
    )


def extract_tph(row, tables):
    for _, rows, table_text in tables:
        lower = table_text.lower()
        if "lots owned" not in lower or "lots controlled" not in lower or "total lots owned or controlled" not in lower:
            continue
        section = ""
        owned = None
        nonowned = None
        total = None
        for cells in rows:
            label = cells[0].lower()
            values = numeric_values(cells)
            if label.startswith("lots owned"):
                section = "owned"
                continue
            if label.startswith("lots controlled"):
                section = "controlled"
                continue
            if label.startswith("total lots owned or controlled") and values:
                total = values[0]
            elif label == "total" and values and section == "owned":
                owned = values[0]
            elif label == "total" and values and section == "controlled":
                nonowned = values[0]
        if owned is not None and nonowned is not None:
            total = total if total is not None else owned + nonowned
            return disclosure_from_values(
                row, owned, nonowned, total, "lots",
                "controlled_lots / total_lots_owned_or_controlled",
                "tph_owned_controlled_total_rows", "high", "exact_quarterly_components", table_text[:2200],
            )
    return missing_disclosure(row, "Tri Pointe company-wide owned/controlled lot totals were not found.")


def extract_uhg(row, text):
    patterns = [
        r"pipeline (?:as of .*?|currently) consists of approximately\s+([0-9,]+)\s+lots",
        r"pipeline as of .*? consists of\s+([0-9,]+)\s+lots",
        r"pipeline of approximately\s+([0-9,]+)\s+lots",
    ]
    match = None
    for pattern in patterns:
        match = re.search(pattern, text, re.IGNORECASE)
        if match:
            break
    if not match:
        return missing_disclosure(row, "UHG approximate mixed land-pipeline disclosure was not found.")
    return incomplete_disclosure(
        row, None, parse_number(match.group(1)), "lots", "mixed_owned_optioned_related_party_pipeline_without_split",
        "uhg_approximate_mixed_pipeline_prose",
        "UHG reports a mixed approximate pipeline without an owned/nonowned split; quarterly omega is not computable.",
        snippet(text, match),
    )


def extract_disclosure(row):
    path = row.get("source_local_path", "")
    if not path or not Path(path).exists():
        return missing_disclosure(row, "Quarterly filing source file is missing.")
    raw_html = read_html(path)
    text = visible_text(raw_html)
    tables = parsed_tables(raw_html)
    if row["ticker"] == "BZH":
        return extract_bzh(row, text)
    if row["ticker"] == "CCS":
        return extract_ccs(row, text, tables)
    if row["ticker"] == "DFH":
        return extract_dfh(row, text)
    if row["ticker"] == "DHI":
        return extract_dhi(row, text)
    if row["ticker"] == "GRBK":
        return extract_grbk(row, tables)
    if row["ticker"] == "LEN":
        return extract_len(row, text)
    if row["ticker"] == "LGIH":
        return extract_lgih(row, text)
    if row["ticker"] == "LSEA":
        return extract_lsea(row, tables)
    if row["ticker"] == "MDC":
        return extract_mdc(row, tables)
    if row["ticker"] == "MHO":
        return extract_mho(row, text)
    if row["ticker"] == "MTH":
        return extract_mth(row, text, tables)
    if row["ticker"] == "PHM":
        return extract_phm(row, text)
    if row["ticker"] == "KBH":
        return extract_kbh(row, text)
    if row["ticker"] == "HOV":
        return extract_hov(row, text)
    if row["ticker"] == "NVR":
        return extract_nvr(row, text)
    if row["ticker"] == "SDHC":
        return extract_sdhc(row, text)
    if row["ticker"] == "TMHC":
        return extract_tmhc(row, text, tables)
    if row["ticker"] == "TOL":
        return extract_tol(row, text)
    if row["ticker"] == "TPH":
        return extract_tph(row, tables)
    if row["ticker"] == "UHG":
        return extract_uhg(row, text)
    return missing_disclosure(row, "Ticker is outside the Tier-1 roster.")


with Path("../input/tier1_2018_2025_quarterly_skeleton.csv").open(newline="") as f:
    filing_rows = [row for row in csv.DictReader(f) if row["source_kind"] == "interim_10q"]

if len(filing_rows) != 424 or len({(row["ticker"], row["calendar_year"], row["calendar_quarter"]) for row in filing_rows}) != 424:
    raise SystemExit("Expected 424 unique Tier-1 interim 10-Q firm-quarter rows.")

disclosures = [extract_disclosure(row) for row in filing_rows]

for row in disclosures:
    omega = parse_number(row["omega_nonowned_controlled_share"])
    if omega is not None and not 0 <= omega <= 1:
        raise SystemExit(f"Quarterly omega is outside [0, 1] for {row['ticker']} {row['report_date']}.")
    owned = parse_number(row["owned_lots_or_homesites"])
    nonowned = parse_number(row["nonowned_controlled_lots_or_homesites"])
    total = parse_number(row["total_lots_or_homesites"])
    if (row["component_identity_expected"] == "TRUE" and owned is not None and nonowned is not None
            and total is not None and abs(owned + nonowned - total) > 1):
        raise SystemExit(f"Quarterly land components do not add up for {row['ticker']} {row['report_date']}.")

disclosure_fields = [
    "ticker", "company", "cik10", "calendar_year", "calendar_quarter", "calendar_quarter_label",
    "fiscal_year", "fiscal_quarter", "form", "filing_date", "report_date", "accession_number",
    "owned_lots_or_homesites", "nonowned_controlled_lots_or_homesites", "total_lots_or_homesites",
    "omega_nonowned_controlled_share", "reported_pipeline_lots_or_homesites", "unit_type",
    "measure_definition", "extraction_method", "extraction_confidence", "source_quality",
    "omega_component_counts_available", "component_identity_expected", "manual_review_flag", "manual_review_reason",
    "context_snippet", "source_url", "source_local_path", "source_checksum_sha256",
]

write_csv(
    "../output/tier1_2018_2025_quarterly_land_disclosures.csv",
    disclosures,
    disclosure_fields,
)

print("Wrote Tier-1 quarterly land disclosures to ../output")
