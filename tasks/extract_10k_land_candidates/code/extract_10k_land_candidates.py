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
        self.skip_tags = set()
        self.parts = []

    def handle_starttag(self, tag, attrs):
        tag = tag.lower()
        if tag in {"script", "style", "noscript", "head", "title"}:
            self.skip_tags.add(tag)
        if tag in {"br", "p", "div", "tr", "td", "th", "li", "h1", "h2", "h3", "h4"}:
            self.parts.append(" ")

    def handle_endtag(self, tag):
        tag = tag.lower()
        if tag in self.skip_tags:
            self.skip_tags.discard(tag)
        if tag in {"p", "div", "tr", "li", "h1", "h2", "h3", "h4"}:
            self.parts.append(" ")

    def handle_data(self, data):
        if not self.skip_tags:
            self.parts.append(data)

    def text(self):
        return re.sub(r"\s+", " ", html.unescape(" ".join(self.parts))).strip()


VARIABLE_PATTERNS = [
    ("owned_lots", "lots", [r"\bowned land/lots?\b", r"\bland/lots? owned\b", r"\bowned lots?\b", r"\blots? owned\b"]),
    ("controlled_lots", "lots", [r"\bcontrolled lots?\b", r"\blots? controlled\b", r"\blots? controlled through land and lot purchase contracts?\b"]),
    ("total_lots", "lots", [r"\btotal land/lots? owned and controlled\b", r"\btotal lots? owned and controlled\b", r"\bowned and controlled lots?\b"]),
    ("owned_homesites", "homesites", [r"\bowned homesites?\b", r"\bhomesites? owned\b"]),
    ("controlled_homesites", "homesites", [r"\bcontrolled homesites?\b", r"\bhomesites? controlled\b"]),
    ("total_homesites", "homesites", [r"\btotal homesites?\b", r"\bowned and controlled homesites?\b"]),
    ("controlled_share", "percent", [r"\bcontrolled share\b", r"\bcontrolled percentage\b", r"\bpercentage of.*controlled\b", r"\bapproximately \d{1,3}\s*%.*controlled\b"]),
    ("land_and_lot_purchase_contracts", "lots", [r"\bland and lot purchase contracts?\b", r"\bland or lot purchase contracts?\b"]),
    ("lot_purchase_agreements", "lots", [r"\blot purchase agreements?\b", r"\bLPAs?\b"]),
    ("option_contracts", "homesites", [r"\boption contracts?\b", r"\boptions? to purchase\b", r"\bland options?\b"]),
    ("raw_land_under_contract", "unknown", [r"\braw land under contract\b", r"\bland under contract\b"]),
    ("finished_lots_owned_or_controlled", "lots", [r"\bfinished lots? owned or controlled\b", r"\bfinished lots? owned and controlled\b"]),
    ("option_deposits", "dollars", [r"\boption deposits?\b", r"\bland option deposits?\b"]),
    ("earnest_money_deposits", "dollars", [r"\bearnest money deposits?\b"]),
    ("deposits_and_preacquisition_costs", "dollars", [r"\bdeposits and pre-acquisition costs?\b", r"\bdeposits and preacquisition costs?\b"]),
    ("remaining_purchase_price", "dollars", [r"\bremaining purchase price\b", r"\bremaining purchase prices\b"]),
    ("land_purchase_contract_obligations", "dollars", [r"\bland purchase contract obligations?\b", r"\bpurchase obligations? under land purchase contracts?\b"]),
    ("purchase_commitments_to_land_banks", "dollars", [r"\bpurchase commitments? to land banks?\b", r"\bland bank purchase commitments?\b"]),
    ("specific_performance_purchase_obligations", "dollars", [r"\bspecific performance purchase obligations?\b", r"\bspecific performance\b"]),
    ("deposit_write_offs", "dollars", [r"\bdeposit write-?offs?\b", r"\bwrite-?offs? of deposits?\b"]),
    ("land_inventory_impairments", "dollars", [r"\bland inventory impairments?\b", r"\binventory impairments?\b"]),
    ("owned_land_inventory", "dollars", [r"\bowned land inventory\b", r"\bland inventory\b"]),
    ("homes_in_inventory", "homes", [r"\bhomes in inventory\b"]),
    ("active_communities", "communities", [r"\bactive communities\b", r"\baverage active communities\b"]),
    ("closings_deliveries", "homes", [r"\bclosings\b", r"\bhomes closed\b", r"\bdeliveries\b", r"\bhomes delivered\b"]),
    ("backlog", "homes", [r"\bbacklog\b"]),
]

MENTION_FLAGS = [
    ("land_option_mention", r"\bland options?\b"),
    ("option_contract_mention", r"\boption contracts?\b"),
    ("lot_purchase_agreement_mention", r"\blot purchase agreements?\b"),
    ("lpa_mention", r"\bLPAs?\b"),
    ("land_bank_mention", r"\bland banks?\b"),
    ("unconsolidated_joint_venture_mention", r"\bunconsolidated joint ventures?\b"),
    ("vie_mention", r"\bvariable interest entities?\b|\bVIEs?\b"),
    ("specific_performance_mention", r"\bspecific performance\b"),
    ("forfeitable_deposit_mention", r"\bforfeitable deposits?\b"),
    ("walk_away_right_mention", r"\bwalk-away rights?\b|\bwalk away rights?\b"),
    ("right_of_first_offer_mention", r"\bright of first offer\b"),
    ("entitlement_mention", r"\bentitlements?\b"),
    ("forestar_mention", r"\bForestar\b"),
    ("millrose_mention", r"\bMillrose\b"),
    ("third_party_option_contract_mention", r"\bthird-party option contracts?\b|\bthird party option contracts?\b"),
    ("investor_group_land_bank_mention", r"\binvestor-group land banks?\b|\binvestor group land banks?\b"),
]

VALUE_PATTERN = re.compile(
    r"(?P<currency>\$)?\s*"
    r"(?P<number>\(?\d{1,3}(?:,\d{3})+(?:\.\d+)?\)?|\(?\d+(?:\.\d+)?\)?)"
    r"\s*(?P<percent>%|percent)?"
    r"\s*(?P<scale>billion|millions?|thousands?)?",
    re.IGNORECASE,
)


def read_inventory():
    with Path("../input/sec_10k_download_inventory.csv").open(newline="") as f:
        return list(csv.DictReader(f))


def visible_text(path):
    raw = Path(path).read_bytes()
    for encoding in ("utf-8", "latin-1"):
        try:
            text = raw.decode(encoding)
            break
        except UnicodeDecodeError:
            text = raw.decode("latin-1", errors="ignore")
    parser = VisibleTextParser()
    parser.feed(text)
    parser.close()
    parsed = parser.text()
    if parsed:
        return parsed
    return re.sub(r"\s+", " ", html.unescape(re.sub(r"<[^>]+>", " ", text))).strip()


def clean_snippet(text, start, end):
    return text[max(0, start):min(len(text), end)].strip()


def numeric_value(raw_number, unit, scale_word, percent_marker):
    cleaned = raw_number.replace(",", "").replace("(", "").replace(")", "")
    try:
        value = float(cleaned)
    except ValueError:
        return "", ""

    scale_factor = 1
    scale_word = (scale_word or "").lower()
    if scale_word.startswith("billion"):
        scale_factor = 1_000_000_000
    elif scale_word.startswith("million"):
        scale_factor = 1_000_000
    elif scale_word.startswith("thousand"):
        scale_factor = 1_000

    if percent_marker:
        return value, 1
    if unit == "dollars" and scale_factor == 1 and value < 1000 and scale_word:
        return value * scale_factor, scale_factor
    return value * scale_factor, scale_factor


def candidate_values(snippet, term_start_in_snippet, expected_unit):
    values = []
    for match in VALUE_PATTERN.finditer(snippet):
        raw_value = match.group(0).strip()
        if not raw_value:
            continue
        percent_marker = match.group("percent") == "%" or (match.group("percent") or "").lower() == "percent"
        unit = "percent" if percent_marker or expected_unit == "percent" else expected_unit
        value, scale_factor = numeric_value(match.group("number"), unit, match.group("scale"), percent_marker)
        distance = abs(match.start() - term_start_in_snippet)
        if unit != "percent" and value != "" and 1900 <= value <= 2100 and not match.group("currency") and not match.group("scale"):
            continue
        values.append({
            "raw_value": raw_value,
            "numeric_value": value,
            "unit": unit,
            "scale_factor_applied": scale_factor,
            "distance": distance,
        })
    values.sort(key=lambda row: row["distance"])
    return values[:3]


def confidence_for(distance, has_currency, expected_unit):
    if distance <= 120 and (expected_unit != "dollars" or has_currency):
        return "high"
    if distance <= 220:
        return "medium"
    return "low"


def mention_row(base, text):
    row = dict(base)
    land_term_count = 0
    for flag_name, pattern in MENTION_FLAGS:
        count = len(re.findall(pattern, text, flags=re.IGNORECASE))
        row[flag_name] = int(count > 0)
        land_term_count += count
    row["land_term_hit_count"] = land_term_count
    row["parse_timestamp_utc"] = utc_now()
    return row


def candidate_rows_for_filing(base, text, source_path):
    rows = []
    seen = set()
    for variable_name, expected_unit, patterns in VARIABLE_PATTERNS:
        for pattern in patterns:
            for match in re.finditer(pattern, text, flags=re.IGNORECASE):
                snippet_start = max(0, match.start() - 450)
                snippet_end = min(len(text), match.end() + 650)
                snippet = clean_snippet(text, snippet_start, snippet_end)
                term_start_in_snippet = match.start() - snippet_start
                values = candidate_values(snippet, term_start_in_snippet, expected_unit)

                if not values:
                    key = (variable_name, match.start(), "")
                    if key in seen:
                        continue
                    seen.add(key)
                    rows.append({
                        **base,
                        "variable_name": variable_name,
                        "raw_value": "",
                        "numeric_value": "",
                        "unit": "unknown",
                        "scale_factor_applied": "",
                        "context_snippet": snippet,
                        "table_row_or_table_text": "",
                        "extraction_method": "keyword_snippet_no_numeric",
                        "confidence": "low",
                        "source_path": source_path,
                        "source_url": base.get("filing_url", ""),
                        "notes": f"Matched phrase: {match.group(0)}",
                    })
                    continue

                for value in values:
                    key = (variable_name, match.start(), value["raw_value"])
                    if key in seen:
                        continue
                    seen.add(key)
                    has_currency = "$" in value["raw_value"]
                    rows.append({
                        **base,
                        "variable_name": variable_name,
                        "raw_value": value["raw_value"],
                        "numeric_value": value["numeric_value"],
                        "unit": value["unit"],
                        "scale_factor_applied": value["scale_factor_applied"],
                        "context_snippet": snippet,
                        "table_row_or_table_text": "",
                        "extraction_method": "keyword_snippet_nearby_numeric",
                        "confidence": confidence_for(value["distance"], has_currency, expected_unit),
                        "source_path": source_path,
                        "source_url": base.get("filing_url", ""),
                        "notes": f"Matched phrase: {match.group(0)}",
                    })
    return rows


def main():
    inventory = read_inventory()
    candidate_rows = []
    mention_rows = []
    parsed_count = 0
    missing_files = 0

    for filing in inventory:
        status = filing.get("primary_document_status", "")
        source_path = filing.get("primary_document_local_path", "")
        if status not in {"downloaded", "already_present"}:
            continue
        if not source_path or not Path(source_path).exists():
            missing_files += 1
            continue

        base = {
            "builder_name_key": filing.get("builder_name_key", ""),
            "builder_name_clean": filing.get("builder_name_clean", ""),
            "ticker": filing.get("ticker", ""),
            "cik": filing.get("cik", ""),
            "cik10": filing.get("cik10", ""),
            "sec_company_name": filing.get("sec_company_name", ""),
            "accession_number": filing.get("accession_number", ""),
            "accession_number_no_dashes": filing.get("accession_number_no_dashes", ""),
            "form": filing.get("form", ""),
            "filing_date": filing.get("filing_date", ""),
            "report_date": filing.get("report_date", ""),
            "fiscal_year": filing.get("fiscal_year", ""),
            "primary_document": filing.get("primary_document", ""),
            "filing_url": filing.get("filing_url", ""),
        }
        text = visible_text(source_path)
        parsed_count += 1
        mention_rows.append(mention_row(base, text))
        candidate_rows.extend(candidate_rows_for_filing(base, text, source_path))

    if not mention_rows:
        mention_rows = [{
            "builder_name_key": "", "builder_name_clean": "", "ticker": "", "cik": "",
            "cik10": "", "sec_company_name": "", "accession_number": "",
            "accession_number_no_dashes": "", "form": "", "filing_date": "",
            "report_date": "", "fiscal_year": "", "primary_document": "", "filing_url": "",
            **{flag_name: 0 for flag_name, _ in MENTION_FLAGS},
            "land_term_hit_count": 0,
            "parse_timestamp_utc": "",
        }]

    qc_rows = [
        {"check": "download_inventory_rows", "status": "ok", "value": len(inventory), "detail": ""},
        {"check": "filings_parsed", "status": "ok" if parsed_count > 0 else "warn", "value": parsed_count, "detail": ""},
        {"check": "document_paths_missing", "status": "ok" if missing_files == 0 else "warn", "value": missing_files, "detail": ""},
        {"check": "filings_with_land_term_hits", "status": "ok" if any(int(row.get("land_term_hit_count", 0)) > 0 for row in mention_rows) else "warn", "value": sum(int(row.get("land_term_hit_count", 0)) > 0 for row in mention_rows), "detail": ""},
        {"check": "candidate_rows", "status": "ok" if len(candidate_rows) > 0 else "warn", "value": len(candidate_rows), "detail": ""},
        {"check": "candidate_rows_with_numeric_value", "status": "ok" if any(str(row.get("numeric_value", "")) != "" for row in candidate_rows) else "warn", "value": sum(str(row.get("numeric_value", "")) != "" for row in candidate_rows), "detail": ""},
    ]

    candidate_fields = [
        "builder_name_key", "builder_name_clean", "ticker", "cik", "cik10", "sec_company_name",
        "accession_number", "accession_number_no_dashes", "form", "filing_date", "report_date",
        "fiscal_year", "primary_document", "filing_url", "variable_name", "raw_value",
        "numeric_value", "unit", "scale_factor_applied", "context_snippet",
        "table_row_or_table_text", "extraction_method", "confidence", "source_path",
        "source_url", "notes"
    ]
    mention_fields = [
        "builder_name_key", "builder_name_clean", "ticker", "cik", "cik10", "sec_company_name",
        "accession_number", "accession_number_no_dashes", "form", "filing_date", "report_date",
        "fiscal_year", "primary_document", "filing_url",
        *[flag_name for flag_name, _ in MENTION_FLAGS],
        "land_term_hit_count", "parse_timestamp_utc"
    ]
    write_csv(Path("../output/tenk_land_candidates.csv"), candidate_rows, candidate_fields)
    write_csv(Path("../output/tenk_land_mention_flags.csv"), mention_rows, mention_fields)
    write_csv(Path("../output/tenk_land_extraction_qc.csv"), qc_rows, ["check", "status", "value", "detail"])
    print("Wrote 10-K land candidate outputs to ../output")


if __name__ == "__main__":
    main()
