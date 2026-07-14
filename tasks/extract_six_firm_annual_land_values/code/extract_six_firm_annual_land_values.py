#!/usr/bin/env python3

import csv
import html
import re
import sys
from html.parser import HTMLParser
from pathlib import Path

sys.path.append(str(Path(__file__).resolve().parents[2] / "_lib"))
from sec_fetch_utils import utc_now, write_csv


class VisibleTextParser(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.skip_depth = 0
        self.parts = []

    def handle_starttag(self, tag, attrs):
        tag = tag.lower()
        if tag in {"script", "style", "noscript", "head", "title", "ix:header", "ix:hidden", "ix:references", "ix:resources"}:
            self.skip_depth += 1
        if self.skip_depth == 0 and tag in {"br", "p", "div", "tr", "td", "th", "li", "h1", "h2", "h3", "h4", "table"}:
            self.parts.append(" ")

    def handle_endtag(self, tag):
        tag = tag.lower()
        if tag in {"script", "style", "noscript", "head", "title", "ix:header", "ix:hidden", "ix:references", "ix:resources"} and self.skip_depth:
            self.skip_depth -= 1
        if self.skip_depth == 0 and tag in {"p", "div", "tr", "li", "h1", "h2", "h3", "h4", "table"}:
            self.parts.append(" ")

    def handle_data(self, data):
        if self.skip_depth == 0:
            self.parts.append(data)

    def text(self):
        return clean_text(" ".join(self.parts))


def clean_text(x):
    return re.sub(r"\s+", " ", html.unescape(str(x or "")).replace("\xa0", " ")).strip()


def decode_html(path):
    raw = Path(path).read_bytes()
    for encoding in ("utf-8", "latin-1"):
        try:
            return raw.decode(encoding)
        except UnicodeDecodeError:
            continue
    return raw.decode("latin-1", errors="ignore")


def visible_text(path):
    parser = VisibleTextParser()
    parser.feed(decode_html(path))
    parser.close()
    parsed = parser.text()
    if parsed:
        return parsed
    return clean_text(re.sub(r"<[^>]+>", " ", decode_html(path)))


def parse_number(x):
    if x is None:
        return None
    cleaned = str(x).replace("$", "").replace(",", "").replace("(", "").replace(")", "").strip()
    if cleaned in {"", "-", "—"}:
        return None
    return float(cleaned)


def format_number(x):
    if x is None:
        return ""
    if abs(x - round(x)) < 1e-9:
        return str(int(round(x)))
    return f"{x:.12g}"


def snippet(text, match, before=700, after=1200):
    if match is None:
        return ""
    return clean_text(text[max(0, match.start() - before):min(len(text), match.end() + after)])


def base_row(row):
    return {
        "ticker": row["ticker"],
        "pilot_builder_name": row["pilot_builder_name"],
        "fiscal_year": row["fiscal_year"],
        "cik10": row.get("cik10", ""),
        "sec_company_name": row.get("sec_company_name", ""),
        "report_date": row.get("downloaded_report_date", ""),
        "filing_date": row.get("downloaded_filing_date", ""),
        "accession_number": row.get("downloaded_accession_number", ""),
        "primary_document": row.get("primary_document", ""),
        "source_url": row.get("filing_url", ""),
        "source_local_path": row.get("primary_document_local_path", ""),
        "source_file_exists": "FALSE",
        "unit_type": "",
        "measure_definition": "",
        "owned_physical_count": "",
        "nonowned_controlled_physical_count": "",
        "optioned_physical_count": "",
        "jv_physical_count": "",
        "construction_to_perm_physical_count": "",
        "total_physical_count": "",
        "nonowned_controlled_share": "",
        "extraction_template_id": "",
        "extraction_method": "",
        "extraction_status": "",
        "extraction_confidence": "",
        "manual_review_flag": "",
        "manual_review_reason": "",
        "context_snippet": "",
        "parse_timestamp_utc": utc_now(),
    }


def candidate(
    row, unit_type, measure_definition, owned, nonowned, total, template_id, method,
    confidence, context, optioned=None, jv=None, construction_to_perm=None,
    default_optioned_to_nonowned=True
):
    out = base_row(row)
    out["source_file_exists"] = "TRUE"
    out["unit_type"] = unit_type
    out["measure_definition"] = measure_definition
    out["owned_physical_count"] = format_number(owned)
    out["nonowned_controlled_physical_count"] = format_number(nonowned)
    optioned_value = optioned if optioned is not None else None
    if optioned_value is None and default_optioned_to_nonowned:
        optioned_value = nonowned
    out["optioned_physical_count"] = format_number(optioned_value)
    out["jv_physical_count"] = format_number(jv)
    out["construction_to_perm_physical_count"] = format_number(construction_to_perm)
    out["total_physical_count"] = format_number(total)
    out["nonowned_controlled_share"] = format_number(nonowned / total if nonowned is not None and total not in (None, 0) else None)
    out["extraction_template_id"] = template_id
    out["extraction_method"] = method
    out["extraction_status"] = "value_extracted"
    out["extraction_confidence"] = confidence
    out["manual_review_flag"] = "FALSE" if confidence == "high" else "TRUE"
    out["manual_review_reason"] = "" if confidence == "high" else "Medium-confidence extraction requires source review before replacing hand-coded data."
    out["context_snippet"] = context
    return out


def missing(row, reason, source_file_exists=False, context=""):
    out = base_row(row)
    out["source_file_exists"] = "TRUE" if source_file_exists else "FALSE"
    out["extraction_status"] = "not_extracted"
    out["extraction_confidence"] = "none"
    out["manual_review_flag"] = "TRUE"
    out["manual_review_reason"] = reason
    out["context_snippet"] = context
    return out


def find_first(patterns, text):
    for template_id, method, pattern in patterns:
        match = re.search(pattern, text, re.IGNORECASE)
        if match:
            return template_id, method, match
    return "", "", None


def extract_dhi(row, text):
    dhi_number = r"[0-9]{1,3}(?:,[0-9]{3})+"
    pair_year_pattern = (
        rf"({dhi_number})\s+({dhi_number})\s+({dhi_number})\s+({dhi_number})\s+"
        rf"({dhi_number})\s+({dhi_number})\s+({dhi_number})\s+({dhi_number})\s+"
        r"[0-9]{1,3}\s*%\s+[0-9]{1,3}\s*%\s+100\s*%"
    )
    for table_match in re.finditer(pair_year_pattern, text, re.IGNORECASE):
        values = [parse_number(table_match.group(i)) for i in range(1, 9)]
        if (
            values[0] is not None and values[1] is not None and values[2] is not None and
            values[4] is not None and values[5] is not None and values[6] is not None and
            abs((values[0] + values[1]) - values[2]) <= 1 and
            abs((values[4] + values[5]) - values[6]) <= 1 and
            values[2] > 50000 and values[6] > 50000
        ):
            if values[2] < 0.5 * values[6]:
                owned, nonowned, total = values[4], values[5], values[6]
            else:
                owned, nonowned, total = values[0], values[1], values[2]
            return candidate(
                row, "lots", "lots_controlled_under_land_lot_contracts / total_land_lots_owned_and_controlled",
                owned, nonowned, total, "DHI_annual_land_position_table_total_row",
                "dhi_land_position_table_total_row", "high", snippet(text, table_match),
                optioned=nonowned
            )

    single_year_pattern = (
        rf"({dhi_number})\s+({dhi_number})\s+({dhi_number})\s+({dhi_number})\s+"
        r"[0-9]{1,3}\s*%\s+[0-9]{1,3}\s*%\s+100\s*%"
    )
    for table_match in re.finditer(single_year_pattern, text, re.IGNORECASE):
        owned = parse_number(table_match.group(1))
        nonowned = parse_number(table_match.group(2))
        total = parse_number(table_match.group(3))
        if owned is not None and nonowned is not None and total is not None and abs((owned + nonowned) - total) <= 1 and total > 50000:
            return candidate(
                row, "lots", "lots_controlled_under_land_lot_contracts / total_land_lots_owned_and_controlled",
                owned, nonowned, total, "DHI_annual_land_position_table_total_row",
                "dhi_land_position_table_total_row", "high", snippet(text, table_match),
                optioned=nonowned
            )

    bullet_match = re.search(
        r"Owned lots totaled\s+([0-9,]+)\s+compared to\s+[0-9,]+,\s+and lots controlled through purchase contracts totaled\s+([0-9,]+)",
        text,
        re.IGNORECASE,
    )
    if bullet_match:
        owned = parse_number(bullet_match.group(1))
        nonowned = parse_number(bullet_match.group(2))
        total = owned + nonowned if owned is not None and nonowned is not None else None
        return candidate(
            row, "lots", "lots_controlled_under_purchase_contracts / owned_plus_controlled_lots",
            owned, nonowned, total, "DHI_annual_modern_owned_controlled_bullet",
            "dhi_owned_controlled_lots_bullet", "high", snippet(text, bullet_match),
            optioned=nonowned
        )

    patterns = [
        (
            "DHI_annual_modern_owned_controlled_total",
            "dhi_modern_owned_controlled_total_table_text",
            r"Owned land/lots\s+([0-9,]+).{0,900}?Lots controlled through land and lot purchase contracts\s+([0-9,]+).{0,900}?Total land/lots owned and controlled\s+([0-9,]+)",
        ),
        (
            "DHI_annual_legacy_total_controlled_prose",
            "dhi_legacy_total_and_controlled_lots_prose",
            r"At September\s+30,\s+[0-9]{4},\s+we owned or controlled approximately\s+([0-9,]+)\s+lots.{0,2200}?At September\s+30,\s+[0-9]{4},\s+we controlled approximately\s+([0-9,]+)\s+lots",
        ),
    ]
    template_id, method, match = find_first(patterns, text)
    if not match:
        return missing(row, "DHI owned/controlled/total lot disclosure was not found.", True)
    if template_id.startswith("DHI_annual_modern"):
        owned = parse_number(match.group(1))
        nonowned = parse_number(match.group(2))
        total = parse_number(match.group(3))
    else:
        total = parse_number(match.group(1))
        nonowned = parse_number(match.group(2))
        owned = total - nonowned if total is not None and nonowned is not None else None
    return candidate(
        row, "lots", "lots_controlled_under_land_lot_contracts / total_land_lots_owned_and_controlled",
        owned, nonowned, total, template_id, method, "high", snippet(text, match)
    )


def extract_len(row, text):
    patterns = [
        (
            "LEN_annual_legacy_owned_access_split_prose",
            "len_legacy_owned_access_optioned_jv_homesite_prose",
            r"At November\s+30,\s+[0-9]{4},\s+we owned\s+([0-9,]+)\s+homesites and had access(?:\s+through option contracts)?\s+to an additional\s+([0-9,]+)\s+homesites,\s+of which\s+([0-9,]+)\s+were through option contracts with third parties and\s+([0-9,]+)\s+were through option contracts with unconsolidated entities",
        ),
        (
            "LEN_annual_controlled_optioned_jv_owned_total_table",
            "len_controlled_optioned_jv_owned_homesite_table_text",
            r"Controlled Homesites\s+Owned Homesites\s+Total Homesites\s+Optioned\s+JVs\s+Total.{0,1400}?Total homesites(?:\s*\([^)]*\))?\s+([0-9,]+)\s+([0-9,]+)\s+([0-9,]+)\s+([0-9,]+)\s+([0-9,]+)",
        ),
        (
            "LEN_annual_optioned_jv_owned_total_table",
            "len_optioned_jv_owned_homesite_table_text",
            r"Optioned\s+JVs\s+Total\s+Owned Homesites\s+Total Homesites.{0,1400}?Total homesites(?:\s*\([^)]*\))?\s+([0-9,]+)\s+([0-9,]+)\s+([0-9,]+)\s+([0-9,]+)\s+([0-9,]+)",
        ),
        (
            "LEN_annual_controlled_owned_total_table",
            "len_controlled_owned_total_homesite_table_text",
            r"Controlled Homesites\s+Owned Homesites\s+Total Homesites.{0,1400}?Total homesites\s+([0-9,]+)\s+([0-9,]+)\s+([0-9,]+)",
        ),
        (
            "LEN_annual_legacy_owned_access_prose",
            "len_legacy_owned_and_access_homesite_prose",
            r"At November\s+30,\s+[0-9]{4},\s+we owned\s+([0-9,]+)\s+homesites and had access(?:\s+through option contracts)?\s+to an additional\s+([0-9,]+)\s+homesites",
        ),
    ]
    template_id, method, match = find_first(patterns, text)
    if not match:
        return missing(row, "Lennar homesite disclosure was not found.", True)
    if template_id == "LEN_annual_legacy_owned_access_split_prose":
        owned = parse_number(match.group(1))
        nonowned = parse_number(match.group(2))
        optioned = parse_number(match.group(3))
        jv = parse_number(match.group(4))
        total = owned + nonowned if owned is not None and nonowned is not None else None
        default_optioned_to_nonowned = False
    elif template_id in {"LEN_annual_optioned_jv_owned_total_table", "LEN_annual_controlled_optioned_jv_owned_total_table"}:
        optioned = parse_number(match.group(1))
        jv = parse_number(match.group(2))
        nonowned = parse_number(match.group(3))
        owned = parse_number(match.group(4))
        total = parse_number(match.group(5))
        default_optioned_to_nonowned = True
    elif template_id == "LEN_annual_controlled_owned_total_table":
        nonowned = parse_number(match.group(1))
        owned = parse_number(match.group(2))
        total = parse_number(match.group(3))
        optioned = None
        jv = None
        default_optioned_to_nonowned = False
    else:
        owned = parse_number(match.group(1))
        nonowned = parse_number(match.group(2))
        total = owned + nonowned if owned is not None and nonowned is not None else None
        optioned = None
        jv = None
        default_optioned_to_nonowned = False
    return candidate(
        row, "homesites", "controlled_homesites / total_homesites",
        owned, nonowned, total, template_id, method, "high", snippet(text, match),
        optioned=optioned, jv=jv, default_optioned_to_nonowned=default_optioned_to_nonowned
    )


def extract_phm(row, text):
    year = int(row["fiscal_year"])
    prose = re.search(
        r"At December\s+31,\s+%s,\s+we controlled(?:\s+approximately)?\s+([0-9,]+)\s+lots,\s+of which\s+([0-9,]+)\s+were\s+owned\s+and\s+([0-9,]+)\s+were\s+under option agreements"
        % year,
        text,
        re.IGNORECASE,
    )
    if prose:
        total = parse_number(prose.group(1))
        owned = parse_number(prose.group(2))
        optioned = parse_number(prose.group(3))
        return candidate(
            row, "lots", "optioned_lots / controlled_lots",
            owned, optioned, total, "PHM_annual_controlled_owned_optioned_prose",
            "phm_controlled_owned_optioned_lots_prose", "high", snippet(text, prose),
            optioned=optioned
        )

    pattern = r"Controlled lots.{0,2400}?Total\s+([0-9,]+)\s+([0-9,]+)\s+([0-9,]+)"
    match = re.search(pattern, text, re.IGNORECASE)
    if not match:
        return missing(row, "Pulte owned/optioned/controlled lot table was not found.", True)
    owned = parse_number(match.group(1))
    optioned = parse_number(match.group(2))
    total = parse_number(match.group(3))
    return candidate(
        row, "lots", "optioned_lots / controlled_lots",
        owned, optioned, total, "PHM_annual_owned_optioned_controlled_table",
        "phm_owned_optioned_controlled_lot_table_text", "high", snippet(text, match), optioned=optioned
    )


def extract_kbh(row, text):
    generic_total_row = re.search(
        r"Total\s+([0-9,]+)\s+[0-9,]+\s+([0-9,]+)\s+[0-9,]+\s+([0-9,]+)\s+[0-9,]+\s+([0-9,]+)\s+[0-9,]+"
        r".{0,900}?(?:The following charts present the percentage|Reflecting our geographic diversity|Home Construction and Deliveries)",
        text,
        re.IGNORECASE,
    )
    if generic_total_row:
        homes_lots_in_production = parse_number(generic_total_row.group(1))
        land_future = parse_number(generic_total_row.group(2))
        optioned = parse_number(generic_total_row.group(3))
        total = parse_number(generic_total_row.group(4))
        owned = homes_lots_in_production + land_future if homes_lots_in_production is not None and land_future is not None else None
        if owned is not None and optioned is not None and total is not None and abs((owned + optioned) - total) <= 1:
            return candidate(
                row, "lots", "land_under_option / total_land_owned_or_under_option",
                owned, optioned, total, "KBH_annual_total_row_owned_components_land_under_option",
                "kbh_total_row_owned_components_plus_land_under_option", "high",
                snippet(text, generic_total_row), optioned=optioned
            )

    pattern = (
        r"Homes Under Construction and Land Under Development\s+Land Held for Future Development\s+"
        r"Land Under Option\s+Total Land Owned or Under Option.{0,1800}?"
        r"Total\s+([0-9,]+)\s+[0-9,]+\s+([0-9,]+)\s+[0-9,]+\s+([0-9,]+)\s+[0-9,]+\s+([0-9,]+)\s+[0-9,]+"
    )
    match = re.search(pattern, text, re.IGNORECASE)
    if not match:
        return missing(row, "KBH lot table with owned components and land under option was not found.", True)
    homes_lots_in_production = parse_number(match.group(1))
    land_future = parse_number(match.group(2))
    optioned = parse_number(match.group(3))
    total = parse_number(match.group(4))
    owned = homes_lots_in_production + land_future if homes_lots_in_production is not None and land_future is not None else None
    return candidate(
        row, "lots", "land_under_option / total_land_owned_or_under_option",
        owned, optioned, total, "KBH_annual_owned_components_land_under_option_table",
        "kbh_owned_components_plus_land_under_option_table_text", "high", snippet(text, match), optioned=optioned
    )


def extract_hov(row, text):
    three_column_table = (
        r"Owned\s+([0-9,]+)\s+([0-9,]+)\s+([0-9,]+)\s+"
        r"Optioned\s+([0-9,]+)\s+([0-9,]+)\s+([0-9,]+)\s+"
        r"Construction to permanent financing lots\s+([0-9,]+)\s+([0-9,]+)(?:\s+[0-9,\-—]+)?\s+"
        r"Consolidated total\s+([0-9,]+)\s+([0-9,]+)\s+([0-9,]+)"
    )
    match = re.search(three_column_table, text, re.IGNORECASE)
    if match:
        owned = parse_number(match.group(1))
        optioned = parse_number(match.group(4))
        construction_to_perm = parse_number(match.group(7))
        total = parse_number(match.group(9))
        return candidate(
            row, "homesites", "optioned_home_sites / consolidated_total_home_sites",
            owned, optioned, total, "HOV_annual_owned_optioned_ctp_total_three_column_table",
            "hov_owned_optioned_ctp_total_three_column_table_text", "high", snippet(text, match),
            optioned=optioned, construction_to_perm=construction_to_perm
        )

    old_table = (
        r"Owned\s+([0-9,]+)\s+([0-9,]+)\s+([0-9,]+)\s+"
        r"Optioned\s+([0-9,]+)\s+([0-9,]+)\s+([0-9,]+)\s+"
        r"Controlled lots\s+([0-9,]+)\s+([0-9,]+)\s+([0-9,]+)\s+"
        r"Construction to permanent financing lots\s+([0-9,\-—]+)\s+([0-9,\-—]+)\s+([0-9,\-—]+)\s+"
        r"Consolidated total\s+([0-9,]+)\s+([0-9,]+)\s+([0-9,]+)"
    )
    match = re.search(old_table, text, re.IGNORECASE)
    if match:
        owned = parse_number(match.group(1))
        optioned = parse_number(match.group(4))
        construction_to_perm = parse_number(match.group(10))
        total = parse_number(match.group(13))
        return candidate(
            row, "homesites", "optioned_home_sites / consolidated_total_home_sites",
            owned, optioned, total, "HOV_annual_owned_optioned_controlled_ctp_total_table",
            "hov_owned_optioned_controlled_ctp_total_table_text", "high", snippet(text, match),
            optioned=optioned, construction_to_perm=construction_to_perm
        )

    new_table = (
        r"Owned\s+([0-9,]+)\s+([0-9,]+)\s+([0-9,]+)\s+"
        r"Optioned\s+([0-9,]+)\s+([0-9,]+)\s+([0-9,]+)\s+"
        r"Construction to permanent financing lots\s+([0-9,\-—]+)\s+([0-9,\-—]+)\s+([0-9,\-—]+)\s+"
        r"Consolidated total\s+([0-9,]+)\s+([0-9,]+)\s+([0-9,]+)"
    )
    match = re.search(new_table, text, re.IGNORECASE)
    if not match:
        return missing(row, "Hovnanian owned/optioned/consolidated home-site table was not found.", True)
    owned = parse_number(match.group(1))
    optioned = parse_number(match.group(4))
    construction_to_perm = parse_number(match.group(7))
    total = parse_number(match.group(10))
    return candidate(
        row, "homesites", "optioned_home_sites / consolidated_total_home_sites",
        owned, optioned, total, "HOV_annual_owned_optioned_ctp_total_table",
        "hov_owned_optioned_ctp_total_table_text", "high", snippet(text, match),
        optioned=optioned, construction_to_perm=construction_to_perm
    )


def extract_nvr(row, text):
    early_match = re.search(
        r"As of December\s+31,\s+[0-9]{4},\s+(?:the Company\s+)?(?:we\s+)?controlled approximately\s+([0-9,]+)\s+lots with deposits",
        text,
        re.IGNORECASE,
    )
    if early_match and int(row["fiscal_year"]) <= 2009:
        total = parse_number(early_match.group(1))
        early_jv_match = re.search(
            r"joint venture limited liability.{0,900}?controlled approximately\s+([0-9,]+)\s+lots",
            text,
            re.IGNORECASE,
        )
        jv = parse_number(early_jv_match.group(1)) if early_jv_match else None
        return candidate(
            row, "lots", "pre_2010_lpa_lots / total_controlled_lots",
            None, None, total, "NVR_annual_pre_2010_controlled_lots_prose",
            "nvr_pre_2010_controlled_lots_prose", "high",
            clean_text(f"{snippet(text, early_match)} {snippet(text, early_jv_match)}"),
            optioned=total, jv=jv
        )

    total_match = re.search(r"Total lots controlled:?\s+.*?\bTotal\s+([0-9,]+)\s+([0-9,]+)", text, re.IGNORECASE)
    lpa_match = re.search(
        r"controlled approximately\s+([0-9,]+)\s+lots?\s+under\s+(?:LPAs|Lot Purchase Agreements|purchase agreements)",
        text,
        re.IGNORECASE,
    )
    jv_expected_match = re.search(
        r"expected to produce approximately\s+([0-9,]+)\s+(?:finished\s+)?lots.{0,260}?approximately\s+([0-9,]+)\s+were not under contract(?:\s+with\s+(?:us|NVR))?",
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
    jv_direct_match = re.search(
        r"In addition,\s+we controlled approximately\s+([0-9,]+)\s+lots?\s+through\s+(?:joint ventures|joint venture limited liability corporations|[0-9]+\s+JVs)",
        text,
        re.IGNORECASE,
    )
    if not total_match:
        return missing(row, "NVR total controlled-lots disclosure was not found.", True)
    total = parse_number(total_match.group(1))
    lpa = parse_number(lpa_match.group(1)) if lpa_match else None
    if jv_expected_match:
        jv_expected = parse_number(jv_expected_match.group(1))
        jv_not_under_contract = parse_number(jv_expected_match.group(2))
        jv = jv_expected - jv_not_under_contract if jv_expected is not None and jv_not_under_contract is not None else None
    elif jv_match:
        jv = parse_number(jv_match.group(1))
    elif jv_direct_match:
        jv = parse_number(jv_direct_match.group(1))
    else:
        jv = None
    nonowned = lpa + (jv or 0) if lpa is not None else total
    confidence = "high" if lpa_match and jv is not None else "medium"
    return candidate(
        row, "lots", "lpa_plus_jv_controlled_lots / total_controlled_lots",
        None, nonowned, total, "NVR_annual_total_lpa_jv_disclosures",
        "nvr_total_lots_lpa_jv_prose_and_table_text", confidence,
        clean_text(f"{snippet(text, total_match, 500, 800)} {snippet(text, lpa_match, 500, 800)} {snippet(text, jv_match, 500, 800)}"),
        optioned=lpa, jv=jv
    )


def extract_row(row):
    path = row.get("primary_document_local_path", "")
    if not path or not Path(path).exists():
        return missing(row, "SEC source file is missing.", False)
    text = visible_text(path)
    if row["ticker"] == "DHI":
        return extract_dhi(row, text)
    if row["ticker"] == "LEN":
        return extract_len(row, text)
    if row["ticker"] == "PHM":
        return extract_phm(row, text)
    if row["ticker"] == "KBH":
        return extract_kbh(row, text)
    if row["ticker"] == "HOV":
        return extract_hov(row, text)
    if row["ticker"] == "NVR":
        return extract_nvr(row, text)
    return missing(row, "Ticker is outside the six-firm pilot.", True)


with Path("../input/six_firm_2006_2025_skeleton.csv").open(newline="") as f:
    rows = list(csv.DictReader(f))

machine_values = [extract_row(row) for row in rows]

audit_rows = []
for ticker in ["DHI", "LEN", "PHM", "KBH", "HOV", "NVR"]:
    ticker_rows = [row for row in machine_values if row["ticker"] == ticker]
    extracted = [row for row in ticker_rows if row["extraction_status"] == "value_extracted"]
    audit_rows.append({
        "audit_scope": "ticker",
        "ticker": ticker,
        "check": "firm_year_rows",
        "status": "ok" if len(ticker_rows) == 20 else "warn",
        "value": len(ticker_rows),
        "detail": "Expected 20 firm-years for 2006-2025.",
    })
    audit_rows.append({
        "audit_scope": "ticker",
        "ticker": ticker,
        "check": "firm_years_extracted",
        "status": "ok" if len(extracted) == 20 else "review",
        "value": len(extracted),
        "detail": "Rows where the firm-template extractor recovered a physical-count disclosure.",
    })

audit_rows.append({
    "audit_scope": "all",
    "ticker": "",
    "check": "total_rows",
    "status": "ok" if len(machine_values) == 120 else "warn",
    "value": len(machine_values),
    "detail": "Expected six firms times 20 fiscal years.",
})
audit_rows.append({
    "audit_scope": "all",
    "ticker": "",
    "check": "rows_extracted",
    "status": "ok" if sum(row["extraction_status"] == "value_extracted" for row in machine_values) == 120 else "review",
    "value": sum(row["extraction_status"] == "value_extracted" for row in machine_values),
    "detail": "Rows with programmatically recovered physical-count values.",
})
audit_rows.append({
    "audit_scope": "all",
    "ticker": "",
    "check": "rows_needing_manual_review",
    "status": "review" if sum(row["manual_review_flag"] == "TRUE" for row in machine_values) > 0 else "ok",
    "value": sum(row["manual_review_flag"] == "TRUE" for row in machine_values),
    "detail": "Rows not ready to replace the gold hand-coded panel.",
})

value_fields = [
    "ticker", "pilot_builder_name", "fiscal_year", "cik10", "sec_company_name",
    "report_date", "filing_date", "accession_number", "primary_document",
    "source_url", "source_local_path", "source_file_exists", "unit_type",
    "measure_definition", "owned_physical_count", "nonowned_controlled_physical_count",
    "optioned_physical_count", "jv_physical_count", "construction_to_perm_physical_count",
    "total_physical_count", "nonowned_controlled_share", "extraction_template_id",
    "extraction_method", "extraction_status", "extraction_confidence",
    "manual_review_flag", "manual_review_reason", "context_snippet", "parse_timestamp_utc",
]

write_csv("../output/six_firm_2006_2025_annual_land_machine_values.csv", machine_values, value_fields)
write_csv(
    "../output/six_firm_2006_2025_annual_land_extraction_audit.csv",
    audit_rows,
    ["audit_scope", "ticker", "check", "status", "value", "detail"],
)

print("Wrote six-firm annual land machine values to ../output")
