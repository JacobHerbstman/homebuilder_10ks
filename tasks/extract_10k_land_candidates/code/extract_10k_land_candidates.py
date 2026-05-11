#!/usr/bin/env python3

import csv
import html
import re
import sys
from html.parser import HTMLParser
from pathlib import Path

sys.path.append(str(Path(__file__).resolve().parents[2] / "_lib"))
from sec_fetch_utils import utc_now, write_csv


WHITESPACE_PATTERN = re.compile(r"\s+")


def clean_text(x):
    x = "" if x is None else str(x)
    x = html.unescape(x).replace("\xa0", " ")
    x = WHITESPACE_PATTERN.sub(" ", x)
    return x.strip()


def clean_key(x):
    x = clean_text(x).lower()
    x = re.sub(r"[^a-z0-9%$]+", " ", x)
    return WHITESPACE_PATTERN.sub(" ", x).strip()


def parse_int_attr(value, default=1):
    try:
        out = int(value)
        return out if out > 0 else default
    except (TypeError, ValueError):
        return default


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


class SecTableParser(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.tables = []
        self.skip_depth = 0
        self.table_depth = 0
        self.current_table = None
        self.current_row = None
        self.current_cell = None
        self.outside_parts = []

    def recent_outside_text(self):
        return clean_text(" ".join(self.outside_parts[-250:]))

    def handle_starttag(self, tag, attrs):
        tag = tag.lower()
        attrs = dict(attrs)

        if tag in {"script", "style", "noscript", "head", "title"}:
            self.skip_depth += 1
            return
        if self.skip_depth:
            return

        if tag == "table":
            if self.table_depth == 0:
                self.current_table = {"rows": [], "context": self.recent_outside_text()}
            self.table_depth += 1
            return

        if self.table_depth > 0:
            if tag == "tr":
                self.current_row = []
            elif tag in {"td", "th"}:
                self.current_cell = {
                    "parts": [],
                    "rowspan": parse_int_attr(attrs.get("rowspan"), 1),
                    "colspan": parse_int_attr(attrs.get("colspan"), 1),
                    "is_header": tag == "th",
                }
            elif tag in {"br", "p", "div", "li"} and self.current_cell is not None:
                self.current_cell["parts"].append(" ")
            return

        if tag in {"br", "p", "div", "tr", "li", "h1", "h2", "h3", "h4"}:
            self.outside_parts.append(" ")

    def handle_endtag(self, tag):
        tag = tag.lower()
        if tag in {"script", "style", "noscript", "head", "title"} and self.skip_depth:
            self.skip_depth -= 1
            return
        if self.skip_depth:
            return

        if self.table_depth > 0:
            if tag in {"td", "th"} and self.current_cell is not None:
                self.current_cell["text"] = clean_text(" ".join(self.current_cell["parts"]))
                if self.current_row is not None:
                    self.current_row.append(self.current_cell)
                self.current_cell = None
            elif tag == "tr" and self.current_row is not None:
                if self.current_table is not None:
                    self.current_table["rows"].append(self.current_row)
                self.current_row = None
            elif tag == "table":
                self.table_depth -= 1
                if self.table_depth == 0 and self.current_table is not None:
                    if self.current_table["rows"]:
                        self.tables.append(self.current_table)
                    self.current_table = None
            return

        if tag in {"p", "div", "tr", "li", "h1", "h2", "h3", "h4"}:
            self.outside_parts.append(" ")

    def handle_data(self, data):
        if self.skip_depth:
            return
        if self.table_depth > 0:
            if self.current_cell is not None:
                self.current_cell["parts"].append(data)
            return
        text = clean_text(data)
        if text:
            self.outside_parts.append(text)


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
    ("optioned_lots_approved_for_purchase", "lots", [r"\bapproved for purchase\b", r"\bapproved lots?\b"]),
    ("optioned_lots_pending_approval", "lots", [r"\bpending approval\b", r"\bpending lots?\b"]),
    ("raw_land_under_contract", "unknown", [r"\braw land under contract\b", r"\bland under contract\b"]),
    ("finished_lots_owned_or_controlled", "lots", [r"\bfinished lots? owned or controlled\b", r"\bfinished lots? owned and controlled\b"]),
    ("option_deposits", "dollars", [r"\boption deposits?\b", r"\bland option deposits?\b"]),
    ("earnest_money_deposits", "dollars", [r"\bearnest money deposits?\b"]),
    ("deposits_preacquisition_costs", "dollars", [r"\bdeposits and pre-acquisition costs?\b", r"\bdeposits and preacquisition costs?\b"]),
    ("refundable_deposits", "dollars", [r"\brefundable deposits?\b", r"\brefundable portion\b"]),
    ("nonrefundable_deposits_preacquisition_costs", "dollars", [r"\bnon-?refundable deposits?\b", r"\bnon-?refundable deposits? and pre-acquisition costs?\b"]),
    ("option_deposit_collateral_total", "dollars", [r"\bcash deposits? and/\s*or letters? of credit\b", r"\btotal deposits?\b.{0,120}\bcash deposits?\b.{0,120}\bletters? of credit\b"]),
    ("remaining_purchase_price", "dollars", [r"\bremaining purchase price\b", r"\bremaining purchase prices\b"]),
    ("land_not_owned_under_option_agreements", "dollars", [r"\bland,? not owned,? under option agreements?\b", r"\bliabilities for land,? not owned,? under option agreements?\b"]),
    ("land_purchase_contract_obligations", "dollars", [r"\bland purchase contract obligations?\b", r"\bpurchase obligations? under land purchase contracts?\b"]),
    ("lpa_cash_deposits", "dollars", [r"\bLPAs?.{0,120}\bcash\b.{0,80}\bdeposits?\b", r"\bcash deposits?\b"]),
    ("purchase_commitments_to_land_banks", "dollars", [r"\bpurchase commitments? to land banks?\b", r"\bland bank purchase commitments?\b"]),
    ("specific_performance_purchase_obligations", "dollars", [r"\bspecific performance purchase obligations?\b", r"\bspecific performance\b"]),
    ("writeoff_deposits_preacquisition_costs", "dollars", [r"\bdeposit write-?offs?\b", r"\bwrite-?offs? of deposits?\b"]),
    ("land_inventory_impairments", "dollars", [r"\bland inventory impairments?\b", r"\binventory impairments?\b"]),
    ("owned_land_inventory", "dollars", [r"\bowned land inventory\b", r"\bland inventory\b"]),
    ("land_held_for_sale", "dollars", [r"\bland held for sale\b"]),
    ("land_under_development", "dollars", [r"\bland under development\b"]),
    ("land_held_for_future_development", "dollars", [r"\bland held for future development\b"]),
    ("homes_under_construction_inventory", "dollars", [r"\bhomes under construction\b"]),
    ("total_inventory", "dollars", [r"\btotal inventory\b"]),
    ("total_assets", "dollars", [r"\btotal assets\b"]),
    ("land_sale_revenue", "dollars", [r"\bland sale revenues?\b"]),
    ("land_sale_cost", "dollars", [r"\bland sale cost of revenues?\b"]),
    ("homes_in_inventory", "homes", [r"\bhomes in inventory\b"]),
    ("active_communities", "communities", [r"\bactive communities\b", r"\baverage active communities\b"]),
    ("closings_deliveries", "homes", [r"\bclosings\b", r"\bhomes closed\b", r"\bdeliveries\b", r"\bhomes delivered\b"]),
    ("backlog", "homes", [r"\bbacklog\b"]),
]

VARIABLE_MASTER_LOOKUP = {}
VARIABLE_MASTER_PARTS = []
for pattern_index, (variable_name, expected_unit, patterns) in enumerate(VARIABLE_PATTERNS):
    for subpattern_index, pattern in enumerate(patterns):
        group_name = f"V{pattern_index}_{subpattern_index}"
        VARIABLE_MASTER_LOOKUP[group_name] = (variable_name, expected_unit)
        VARIABLE_MASTER_PARTS.append(f"(?P<{group_name}>{pattern})")
VARIABLE_MASTER_PATTERN = re.compile("|".join(VARIABLE_MASTER_PARTS), re.IGNORECASE)

CORE_PHYSICAL_SNIPPET_METRICS = {
    "owned_lots",
    "optioned_lots",
    "controlled_lots",
    "total_lots",
    "owned_homesites",
    "controlled_homesites",
    "total_homesites",
    "land_and_lot_purchase_contracts",
    "lot_purchase_agreements",
    "option_contracts",
}

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
    ("cancellable_option_mention", r"\bcancell?able\b.{0,80}\boptions?\b|\bcancel\b.{0,80}\bland option\b"),
    ("predetermined_price_mention", r"\bpredetermined prices?\b|\bfixed prices?\b"),
    ("letter_of_credit_mention", r"\bletters? of credit\b"),
    ("surety_bond_mention", r"\bsurety bonds?\b"),
]

VARIABLE_FAMILIES = {
    "owned_lots": "land_control",
    "optioned_lots": "land_control",
    "controlled_lots": "land_control",
    "total_lots": "land_control",
    "owned_homesites": "land_control",
    "controlled_homesites": "land_control",
    "total_homesites": "land_control",
    "homes_in_inventory": "land_control",
    "developed_share": "land_control",
    "developed_share_owned": "land_control",
    "developed_share_optioned": "land_control",
    "developed_share_controlled": "land_control",
    "optioned_lots_approved_for_purchase": "land_control",
    "optioned_lots_pending_approval": "land_control",
    "land_and_lot_purchase_contracts": "land_control",
    "lot_purchase_agreements": "land_control",
    "deposits_preacquisition_costs": "option_economics",
    "refundable_deposits": "option_economics",
    "nonrefundable_deposits_preacquisition_costs": "option_economics",
    "remaining_purchase_price": "option_economics",
    "land_not_owned_under_option_agreements": "option_economics",
    "land_purchase_contract_obligations": "option_economics",
    "option_deposit_collateral_total": "option_economics",
    "lpa_cash_deposits": "option_economics",
    "earnest_money_deposits": "option_economics",
    "option_deposits": "option_economics",
    "closings": "operating_scale",
    "closings_deliveries": "operating_scale",
    "net_new_orders_units": "operating_scale",
    "net_new_orders_dollars": "operating_scale",
    "cancellation_rate": "operating_scale",
    "active_communities": "operating_scale",
    "backlog_units": "operating_scale",
    "backlog_dollars": "operating_scale",
    "average_selling_price": "operating_scale",
    "home_sale_revenue": "operating_scale",
    "land_sale_revenue": "operating_scale",
    "land_sale_cost": "operating_scale",
    "home_sale_gross_margin": "operating_scale",
    "land_held_for_sale": "inventory_accounting",
    "land_held_for_sale_gross": "inventory_accounting",
    "land_held_for_sale_nrv_reserve": "inventory_accounting",
    "land_under_development": "inventory_accounting",
    "land_held_for_future_development": "inventory_accounting",
    "homes_under_construction_inventory": "inventory_accounting",
    "total_inventory": "inventory_accounting",
    "total_assets": "inventory_accounting",
    "land_inventory_impairments": "risk_accounting",
    "land_related_charges_total": "risk_accounting",
    "land_community_valuation_adjustments": "risk_accounting",
    "nrv_adjustments_land_held_for_sale": "risk_accounting",
    "writeoff_deposits_preacquisition_costs": "risk_accounting",
    "jv_impairments": "risk_accounting",
    "letters_of_credit": "off_balance_sheet",
    "surety_bonds": "off_balance_sheet",
    "guarantees": "off_balance_sheet",
}

VARIABLE_UNITS = {
    "owned_lots": "lots",
    "optioned_lots": "lots",
    "controlled_lots": "lots",
    "total_lots": "lots",
    "owned_homesites": "homesites",
    "controlled_homesites": "homesites",
    "total_homesites": "homesites",
    "homes_in_inventory": "homes",
    "developed_share": "percent",
    "developed_share_owned": "percent",
    "developed_share_optioned": "percent",
    "developed_share_controlled": "percent",
    "optioned_lots_approved_for_purchase": "lots",
    "optioned_lots_pending_approval": "lots",
    "land_and_lot_purchase_contracts": "lots",
    "lot_purchase_agreements": "lots",
    "deposits_preacquisition_costs": "dollars",
    "deposits_and_preacquisition_costs": "dollars",
    "refundable_deposits": "dollars",
    "nonrefundable_deposits_preacquisition_costs": "dollars",
    "remaining_purchase_price": "dollars",
    "land_not_owned_under_option_agreements": "dollars",
    "land_purchase_contract_obligations": "dollars",
    "option_deposit_collateral_total": "dollars",
    "lpa_cash_deposits": "dollars",
    "earnest_money_deposits": "dollars",
    "option_deposits": "dollars",
    "closings": "homes",
    "closings_deliveries": "homes",
    "net_new_orders_units": "homes",
    "net_new_orders_dollars": "dollars",
    "cancellation_rate": "percent",
    "active_communities": "communities",
    "backlog_units": "homes",
    "backlog_dollars": "dollars",
    "average_selling_price": "dollars",
    "home_sale_revenue": "dollars",
    "land_sale_revenue": "dollars",
    "land_sale_cost": "dollars",
    "home_sale_gross_margin": "percent",
    "land_held_for_sale": "dollars",
    "land_held_for_sale_gross": "dollars",
    "land_held_for_sale_nrv_reserve": "dollars",
    "land_under_development": "dollars",
    "land_held_for_future_development": "dollars",
    "homes_under_construction_inventory": "dollars",
    "total_inventory": "dollars",
    "total_assets": "dollars",
    "land_inventory_impairments": "dollars",
    "land_related_charges_total": "dollars",
    "land_community_valuation_adjustments": "dollars",
    "nrv_adjustments_land_held_for_sale": "dollars",
    "writeoff_deposits_preacquisition_costs": "dollars",
    "jv_impairments": "dollars",
    "letters_of_credit": "dollars",
    "surety_bonds": "dollars",
    "guarantees": "dollars",
}

VALUE_PATTERN = re.compile(
    r"(?P<currency>\$)?\s*"
    r"(?P<number>\(?\d{1,3}(?:,\d{3})+(?:\.\d+)?\)?|\(?\d+(?:\.\d+)?\)?)"
    r"\s*(?P<percent>%|percent)?"
    r"\s*(?P<scale>billion|millions?|thousands?)?",
    re.IGNORECASE,
)

TABLE_RELEVANCE_PATTERN = re.compile(
    r"owned|optioned|controlled|homesites?|lots?|deposits?|remaining purchase|"
    r"land related|valuation|write off|write offs|backlog|closings|new orders|"
    r"active communities|average selling price|cancellation rate|homes under construction|"
    r"land under development|land held for future development|land held for sale|"
    r"total inventory|total assets|land sale|letters? of credit|surety|guarantees?|"
    r"refundable|non refundable|nonrefundable",
    re.IGNORECASE,
)

NON_OPERATING_TARGET_TABLE_PATTERN = re.compile(
    r"compensation|incentive|performance share|performance based|long term incentive|"
    r"long-term incentive|equity award|threshold|target|maximum|payout|executive",
    re.IGNORECASE,
)

NON_DATA_TABLE_PATTERN = re.compile(
    r"exhibit number|exhibit no\.?|exhibits?, continued|incorporated by reference|"
    r"proxy statement|filed herewith|registration statement|form 8-?k|form 8 k|form 10-?q|form 10 q|"
    r"indenture dated|supplemental indenture|guarantee agreement,? dated|"
    r"credit agreement,? dated|annual report on form 10-k and is incorporated",
    re.IGNORECASE,
)


def read_inventory():
    with Path("../input/sec_10k_download_inventory.csv").open(newline="") as f:
        return list(csv.DictReader(f))


def decode_html(path):
    raw = Path(path).read_bytes()
    for encoding in ("utf-8", "latin-1"):
        try:
            return raw.decode(encoding)
        except UnicodeDecodeError:
            continue
    return raw.decode("latin-1", errors="ignore")


def visible_text(path):
    text = decode_html(path)
    parser = VisibleTextParser()
    parser.feed(text)
    parser.close()
    parsed = parser.text()
    if parsed:
        return parsed
    return re.sub(r"\s+", " ", html.unescape(re.sub(r"<[^>]+>", " ", text))).strip()


def parse_html_tables(path):
    parser = SecTableParser()
    parser.feed(decode_html(path))
    parser.close()
    return parser.tables


def expand_table(raw_rows):
    matrix = []
    rowspans = {}

    for raw_row in raw_rows:
        row = []
        col = 0

        def fill_spans():
            nonlocal col
            while col in rowspans:
                span_text, remaining = rowspans[col]
                row.append(span_text)
                if remaining <= 1:
                    del rowspans[col]
                else:
                    rowspans[col] = (span_text, remaining - 1)
                col += 1

        fill_spans()
        for cell in raw_row:
            fill_spans()
            text = cell.get("text", "")
            colspan = cell.get("colspan", 1)
            rowspan = cell.get("rowspan", 1)
            for offset in range(colspan):
                row.append(text)
                if rowspan > 1:
                    rowspans[col + offset] = (text, rowspan - 1)
            col += colspan
        fill_spans()
        matrix.append(row)

    max_cols = max((len(row) for row in matrix), default=0)
    return [row + [""] * (max_cols - len(row)) for row in matrix]


def document_scale_factor(text):
    head = clean_key(text[:60000])
    if re.search(r"dollars? in thousands|amounts? in thousands|in thousands except|\$000|000 s omitted|000s omitted", head):
        return 1000
    return 1


def snippet_scale_factor(text):
    key = clean_key(text)
    if re.search(
        r"dollars? in thousands|amounts? in thousands|in thousands except|\$000|"
        r"\bin thousands\b|000 s omitted|000s omitted|thousands of dollars",
        key,
    ):
        return 1000
    if re.search(r"dollars? in millions|amounts? in millions|in millions except|millions of dollars", key):
        return 1_000_000
    if re.search(r"dollars? in billions|amounts? in billions|in billions except|billions of dollars", key):
        return 1_000_000_000
    return 1


def clean_snippet(text, start, end):
    return text[max(0, start):min(len(text), end)].strip()


def numeric_value(raw_number, unit, scale_word, percent_marker, fallback_scale_factor=1, has_currency=False):
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
    if unit == "dollars" and scale_factor == 1 and has_currency and fallback_scale_factor > 1:
        if abs(value) >= 10_000_000:
            return value, 1
        return value * fallback_scale_factor, fallback_scale_factor
    return value * scale_factor, scale_factor


def candidate_values(snippet, term_start_in_snippet, expected_unit, fallback_scale_factor=1):
    values = []
    for match in VALUE_PATTERN.finditer(snippet):
        raw_value = match.group(0).strip()
        if not raw_value:
            continue
        percent_marker = match.group("percent") == "%" or (match.group("percent") or "").lower() == "percent"
        has_currency = bool(match.group("currency"))
        has_scale_word = bool(match.group("scale"))
        if expected_unit == "percent" and not percent_marker:
            continue
        if percent_marker and expected_unit != "percent":
            continue
        if expected_unit in {"homes", "lots", "homesites", "communities"} and (has_currency or has_scale_word):
            continue
        if expected_unit in {"homes", "lots", "homesites", "communities"}:
            local_value_context = clean_key(snippet[max(0, match.start() - 45):min(len(snippet), match.end() + 65)])
            physical_unit_pattern = {
                "homes": r"\bhomes?\b|\bclosings?\b|\bdeliver(?:y|ies|ed)\b|\bclosed\b",
                "lots": r"\blots?\b",
                "homesites": r"\bhomesites?\b",
                "communities": r"\bcommunities\b|\bcommunity\b",
            }.get(expected_unit, "")
            if physical_unit_pattern and not re.search(physical_unit_pattern, local_value_context):
                continue
        unit = "percent" if percent_marker or expected_unit == "percent" else expected_unit
        value, scale_factor = numeric_value(
            match.group("number"),
            unit,
            match.group("scale"),
            percent_marker,
            fallback_scale_factor,
            has_currency,
        )
        if expected_unit == "dollars" and not has_currency and not has_scale_word:
            continue
        if expected_unit == "dollars" and re.fullmatch(r"\$?\s*0+", raw_value.replace(",", "")):
            continue
        distance = abs(match.start() - term_start_in_snippet)
        if unit != "percent" and value != "" and 1900 <= value <= 2100 and not match.group("currency") and not match.group("scale"):
            continue
        if expected_unit in {"homes", "lots", "homesites", "communities"} and value != "" and value > 1_000_000:
            continue
        if expected_unit in {"homes", "lots", "homesites"} and value != "" and abs(value - round(value)) > 1e-6:
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


def score_for_confidence(confidence, distance=250):
    base = {"high": 65, "medium": 45, "low": 25}.get(confidence, 15)
    return max(1, round(base - min(distance, 400) / 20, 2))


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


def empty_provenance():
    return {
        "metric_raw_name": "",
        "metric_family": "",
        "source_scope": "",
        "segment_label": "",
        "period_label": "",
        "source_table_index": "",
        "source_row_label": "",
        "source_column_label": "",
        "source_section": "",
        "table_scale_label": "",
        "statement_scale_factor": "",
        "candidate_score": "",
    }


def candidate_rows_for_filing(base, text, source_path, fallback_scale_factor=1):
    rows = []
    seen = set()
    for match in VARIABLE_MASTER_PATTERN.finditer(text):
        variable_name, expected_unit = VARIABLE_MASTER_LOOKUP[match.lastgroup]
        snippet_start = max(0, match.start() - 450)
        snippet_end = min(len(text), match.end() + 650)
        snippet = clean_snippet(text, snippet_start, snippet_end)
        snippet_key = clean_key(snippet)
        if variable_name == "nonrefundable_deposits_preacquisition_costs" and re.search(
            r"walked away|charges? to income|writes? off|wrote off|write offs?|"
            r"abandonment charges?|land option approval and engineering costs|"
            r"effectively compelled|financing arrangements?|contractual obligations table|"
            r"payments due by period|long term debt principal payments|"
            r"long term debt interest payments|operating leases",
            snippet_key,
        ):
            continue
        if variable_name == "option_deposits" and re.search(
            r"summary of our interests in land option agreements|"
            r"option earnest money deposits cash|"
            r"option earnest money deposits number of lots|"
            r"book cost primarily represents|no money at risk|"
            r"refundable earnest money deposits|"
            r"total purchase price of approximately .* with .* cash deposits|"
            r"consolidated the fair value of certain vies|consolidation of these vies",
            snippet_key,
        ):
            continue
        if variable_name == "earnest_money_deposits" and re.search(
            r"performance bonds?|bonds and letters? of credit|"
            r"support of .*earnest money deposits|"
            r"earnest money deposits, among other things|"
            r"consolidated the fair value|added .* inventories and other liabilities|"
            r"variable interest|fasb interpretation no\.? 46|"
            r"wrote off|write off|write-off|write offs?|land option contract abandonments?",
            snippet_key,
        ):
            continue
        if variable_name == "lpa_cash_deposits" and re.search(
            r"cash deposits? and\s+or letters? of credit|"
            r"total deposits? .*comprised .*cash deposits? .*letters? of credit",
            snippet_key,
        ):
            continue
        term_start_in_snippet = match.start() - snippet_start
        values = candidate_values(snippet, term_start_in_snippet, expected_unit, snippet_scale_factor(snippet))

        if not values:
            key = (variable_name, match.start(), "")
            if key in seen:
                continue
            seen.add(key)
            row = {
                **base,
                **empty_provenance(),
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
            }
            row["metric_raw_name"] = match.group(0)
            row["metric_family"] = VARIABLE_FAMILIES.get(variable_name, "")
            row["source_scope"] = "filing_snippet"
            row["source_section"] = snippet[:250]
            rows.append(row)
            continue

        for value in values:
            if (
                variable_name in CORE_PHYSICAL_SNIPPET_METRICS
                and value["numeric_value"] != ""
                and value["numeric_value"] < 100
            ):
                continue
            key = (variable_name, match.start(), value["raw_value"])
            if key in seen:
                continue
            seen.add(key)
            has_currency = "$" in value["raw_value"]
            confidence = confidence_for(value["distance"], has_currency, expected_unit)
            row = {
                **base,
                **empty_provenance(),
                "variable_name": variable_name,
                "raw_value": value["raw_value"],
                "numeric_value": value["numeric_value"],
                "unit": value["unit"],
                "scale_factor_applied": value["scale_factor_applied"],
                "context_snippet": snippet,
                "table_row_or_table_text": "",
                "extraction_method": "keyword_snippet_nearby_numeric",
                "confidence": confidence,
                "source_path": source_path,
                "source_url": base.get("filing_url", ""),
                "notes": f"Matched phrase: {match.group(0)}",
            }
            row["metric_raw_name"] = match.group(0)
            row["metric_family"] = VARIABLE_FAMILIES.get(variable_name, "")
            row["source_scope"] = "filing_snippet"
            row["source_section"] = snippet[:250]
            row["statement_scale_factor"] = value["scale_factor_applied"]
            row["candidate_score"] = score_for_confidence(confidence, value["distance"])
            rows.append(row)
    return rows


def special_value_candidate(base, source_path, variable_name, raw_value, unit, snippet, method, period_label, fallback_scale_factor):
    if variable_name == "lpa_cash_deposits":
        fallback_scale_factor = max(fallback_scale_factor, 1000)
    match = VALUE_PATTERN.search(raw_value)
    if not match:
        return None
    percent_marker = match.group("percent") == "%" or (match.group("percent") or "").lower() == "percent"
    numeric, scale_factor = numeric_value(
        match.group("number"),
        unit,
        match.group("scale"),
        percent_marker,
        fallback_scale_factor,
        bool(match.group("currency")),
    )
    return {
        **base,
        **empty_provenance(),
        "variable_name": variable_name,
        "raw_value": raw_value,
        "numeric_value": numeric,
        "unit": unit,
        "scale_factor_applied": scale_factor,
        "context_snippet": snippet,
        "table_row_or_table_text": "",
        "extraction_method": method,
        "confidence": "high",
        "source_path": source_path,
        "source_url": base.get("filing_url", ""),
        "notes": "Structured prose pattern.",
        "metric_raw_name": variable_name,
        "metric_family": VARIABLE_FAMILIES.get(variable_name, ""),
        "source_scope": "filing_snippet",
        "period_label": period_label,
        "source_section": snippet[:250],
        "statement_scale_factor": scale_factor,
        "candidate_score": 95,
    }


def special_prose_candidates_for_filing(base, text, source_path, fallback_scale_factor=1):
    rows = []
    patterns = [
        (
            "optioned_lots_approved_for_purchase",
            "lots",
            r"(?P<current>\d{1,3}(?:,\d{3})*)\s+and\s+(?P<prior>\d{1,3}(?:,\d{3})*)\s+were under option agreements approved for purchase at [A-Za-z]+ \d{1,2},\s*(?P<year>(?:19|20)\d{2})",
        ),
        (
            "optioned_lots_pending_approval",
            "lots",
            r"there were\s+(?P<current>\d{1,3}(?:,\d{3})*)\s+and\s+(?P<prior>\d{1,3}(?:,\d{3})*)\s+lots under option agreements pending approval at [A-Za-z]+ \d{1,2},\s*(?P<year>(?:19|20)\d{2})",
        ),
        (
            "controlled_lots",
            "lots",
            r"As of [A-Za-z]+ \d{1,2},\s*(?P<year>(?:19|20)\d{2}),\s+we controlled approximately\s+(?P<current>\d{1,3}(?:,\d{3})*)\s+lots",
        ),
        (
            "lot_purchase_agreements",
            "lots",
            r"We controlled approximately\s+(?P<current>\d{1,3}(?:,\d{3})*)\s+lots under LPAs",
        ),
        (
            "lpa_cash_deposits",
            "dollars",
            r"deposits in cash and letters of credit totaling approximately\s+(?P<current>\$\s*\d{1,3}(?:,\d{3})*)\s+and\s+\$\s*\d{1,3}(?:,\d{3})*",
        ),
        (
            "lpa_cash_deposits",
            "dollars",
            r"cash deposits related to these land option contracts totaled\s+(?P<current>\$ ?\d+(?:\.\d+)?\s*(?:billion|million))",
        ),
        (
            "lpa_cash_deposits",
            "dollars",
            r"total deposits of\s+\$ ?\d+(?:\.\d+)?\s*(?:billion|million)\s*,?\s+comprised of cash deposits of\s+(?P<current>\$ ?\d+(?:\.\d+)?\s*(?:billion|million))\s*,?\s+and letters of credit",
        ),
        (
            "lpa_cash_deposits",
            "dollars",
            r"total deposits of\s+\$ ?\d+(?:\.\d+)?\s*(?:billion|million)\s*,?\s+comprised of\s+(?P<current>\$ ?\d+(?:\.\d+)?\s*(?:billion|million))\s+of cash deposits\s+and\s+\$ ?\d+(?:\.\d+)?\s*(?:billion|million)\s+of letters of credit",
        ),
        (
            "letters_of_credit",
            "dollars",
            r"total deposits of\s+\$ ?\d+(?:\.\d+)?\s*(?:billion|million)\s*,?\s+comprised of cash deposits of\s+\$ ?\d+(?:\.\d+)?\s*(?:billion|million)\s*,?\s+and letters of credit of\s+(?P<current>\$ ?\d+(?:\.\d+)?\s*(?:billion|million))",
        ),
        (
            "letters_of_credit",
            "dollars",
            r"total deposits of\s+\$ ?\d+(?:\.\d+)?\s*(?:billion|million)\s*,?\s+comprised of\s+\$ ?\d+(?:\.\d+)?\s*(?:billion|million)\s+of cash deposits\s+and\s+(?P<current>\$ ?\d+(?:\.\d+)?\s*(?:billion|million))\s+of letters of credit",
        ),
        (
            "option_deposit_collateral_total",
            "dollars",
            r"cash deposits and/\s*or letters of credit totaling\s+(?P<current>\$ ?\d+(?:\.\d+)?\s*(?:billion|million))",
        ),
        (
            "option_deposit_collateral_total",
            "dollars",
            r"cash deposits and/\s*or letters of credit related to these land option contracts totaled\s+(?P<current>\$ ?\d+(?:\.\d+)?\s*(?:billion|million))",
        ),
        (
            "option_deposit_collateral_total",
            "dollars",
            r"total deposits of\s+(?P<current>\$ ?\d+(?:\.\d+)?\s*(?:billion|million))\s*,?\s+comprised of (?:cash deposits of\s+\$ ?\d+(?:\.\d+)?\s*(?:billion|million)\s*,?\s+and letters of credit|(?:\$ ?\d+(?:\.\d+)?\s*(?:billion|million)\s+of cash deposits\s+and\s+\$ ?\d+(?:\.\d+)?\s*(?:billion|million)\s+of letters of credit))",
        ),
        (
            "lpa_cash_deposits",
            "dollars",
            r"had\s+deposits on real estate under option or contract of\s+(?P<current>\$ ?\d+(?:\.\d+)?\s*(?:billion|million))",
        ),
        (
            "earnest_money_deposits",
            "dollars",
            r"had total deposits of\s+(?P<current>\$\s*\d+(?:\.\d+)?\s*(?:billion|million))\s*,?\s+consisting of cash deposits.*?related to contracts to purchase land and lots",
        ),
        (
            "nonrefundable_deposits_preacquisition_costs",
            "dollars",
            r"had\s+(?P<current>\$ ?\d+(?:\.\d+)?\s*(?:billion|million))\s+of\s+non-?refundable cash deposits?\s+pertaining to land option contracts? and purchase contracts?",
        ),
        (
            "writeoff_deposits_preacquisition_costs",
            "dollars",
            r"resulting in charges to income before taxes of\s+(?P<current>\$ ?\d+(?:\.\d+)?\s*(?:billion|million))",
        ),
        (
            "writeoff_deposits_preacquisition_costs",
            "dollars",
            r"wrote off residential land option, approval and engineering costs totaling\s+(?P<current>\$ ?\d+(?:\.\d+)?\s*(?:billion|million))",
        ),
        (
            "writeoff_deposits_preacquisition_costs",
            "dollars",
            r"recognized\s+(?:land option contract\s+)?abandonment charges(?:\s+associated with land option contracts)?\s+of\s+(?P<current>\$ ?\d+(?:\.\d+)?\s*(?:billion|million))\s+in\s+(?P<year>(?:19|20)\d{2})",
        ),
        (
            "writeoff_deposits_preacquisition_costs",
            "dollars",
            r"During\s+(?P<year>(?:19|20)\d{2})\s*,\s*(?:19|20)\d{2}\s+and\s+(?:19|20)\d{2}\s*,\s+we wrote off\s+(?P<current>\$ ?\d+(?:\.\d+)?\s*(?:billion|million))\s*,\s+\$ ?\d+(?:\.\d+)?\s*(?:billion|million)\s+and\s+\$ ?\d+(?:\.\d+)?\s*(?:billion|million)\s*,\s+respectively,\s+as a result of land option contract abandonments",
        ),
    ]

    for variable_name, unit, pattern in patterns:
        for match in re.finditer(pattern, text, flags=re.IGNORECASE):
            snippet = clean_snippet(text, match.start() - 450, match.end() + 650)
            period_label = match.groupdict().get("year") or base.get("fiscal_year", "")
            row = special_value_candidate(
                base,
                source_path,
                variable_name,
                match.group("current"),
                unit,
                snippet,
                "structured_prose_current_year",
                period_label,
                fallback_scale_factor,
            )
            if row is not None:
                rows.append(row)
    return rows


def detect_table_scale(matrix, context):
    table_head = clean_key(" ".join(" ".join(row[:12]) for row in matrix[:8]))
    table_labels = clean_key(" ".join(first_text_label(row) for row in matrix[:12] if first_text_label(row)))
    nearby_context = clean_key(context[-500:])
    scale_text = clean_key(f"{table_head} {table_labels} {nearby_context}")

    if re.search(
        r"\$000|000 s omitted|000s omitted|\$ 000|\bin thousands\b|dollars? in thousands|"
        r"dollar amounts? in thousands|amounts? in thousands|in thousands except|"
        r"thousands of dollars",
        scale_text,
    ):
        return "$000s omitted", 1000
    if re.search(
        r"\bin millions\b|dollars? in millions|dollar amounts? in millions|amounts? in millions|"
        r"in millions except|millions of dollars|\$ in millions",
        scale_text,
    ):
        return "millions", 1_000_000
    if re.search(
        r"\bin billions\b|dollars? in billions|dollar amounts? in billions|amounts? in billions|"
        r"in billions except|billions of dollars|\$ in billions",
        scale_text,
    ):
        return "billions", 1_000_000_000
    return "", 1


def applied_table_scale(unit, variable_name, value, has_currency, table_scale_factor):
    if unit != "dollars":
        return 1
    if variable_name == "average_selling_price":
        return 1000 if value < 10000 else 1
    if table_scale_factor == 1:
        return 1
    if has_currency and abs(value) >= 100_000_000:
        return 1
    if has_currency and table_scale_factor > 1000 and abs(value) >= 1_000_000:
        return 1
    return table_scale_factor


def row_has_number(row):
    return any(re.search(r"\d", clean_text(cell)) for cell in row)


def header_candidate_row(row):
    row_text = clean_text(" ".join(row))
    if not row_text:
        return True
    numbers = re.findall(r"\b\d{1,4}(?:,\d{3})*(?:\.\d+)?\b", row_text)
    if not numbers:
        return True
    if all(re.fullmatch(r"(19|20)\d{2}", number) for number in numbers):
        return True
    if re.search(r"january|february|march|april|may|june|july|august|september|october|november|december", row_text, flags=re.IGNORECASE):
        return all(
            re.fullmatch(r"(19|20)\d{2}", number) or (number.isdigit() and 1 <= int(number) <= 31)
            for number in numbers
        )
    numeric_data_cells = sum(
        bool(re.fullmatch(r"\$?\s*\(?\d{1,3}(?:,\d{3})*(?:\.\d+)?\)?\s*%?", clean_text(cell)))
        for cell in row
    )
    if first_text_label(row) and numeric_data_cells >= 2:
        return False
    if re.search(r"[A-Za-z]", row_text) and not re.search(r"\d{1,3},\d{3}|\d+\.\d+", row_text):
        return True
    return False


def first_text_label(row):
    for cell in row:
        text = clean_text(cell)
        if not text:
            continue
        key = clean_key(text)
        if key in {"$", "%", "nan"}:
            continue
        if not re.search(r"\d", key) or re.search(r"[a-z]", key):
            return text
    return ""


def table_search_key(matrix, context):
    header_cells = []
    for row in matrix[:8]:
        header_cells.extend(row[:12])

    label_cells = []
    for row in matrix:
        label = first_text_label(row)
        if label:
            label_cells.append(label)

    return clean_key(" ".join(header_cells + label_cells + [context]))


def table_content_key(matrix):
    header_cells = []
    for row in matrix[:8]:
        header_cells.extend(row[:12])
    label_cells = [first_text_label(row) for row in matrix if first_text_label(row)]
    return clean_key(" ".join(header_cells + label_cells))


def likely_note_or_reference_row(row_text):
    text = clean_text(row_text)
    key = clean_key(text)
    if not text:
        return False
    if NON_DATA_TABLE_PATTERN.search(text):
        return True
    first_cell = clean_text(text.split("|", 1)[0])
    rest = clean_text(text.split("|", 1)[1] if "|" in text else "")
    if re.fullmatch(r"\(?[A-Za-z0-9]{1,3}\)?", first_cell) and len(rest) > 25 and re.search(r"[A-Za-z]", rest):
        return True
    if re.match(r"^\(?\s*\d{1,2}\s*\)?\s*\|", text) and re.search(
        r"excludes|includes|does not include|amount represents|numbers presented|"
        r"for a more detailed|refer to|see note|incorporated|agreement|indenture|"
        r"dated|guaranteed by|purchase obligations relate|consists of|consist of|"
        r"acquired|closed on|open for sales|not designed|designed to",
        key,
    ):
        return True
    return False


def row_labels(matrix, row_index):
    row = matrix[row_index]
    raw_label = first_text_label(row)
    label = raw_label
    if not label and row_has_number(row):
        label = "Total"

    group_label = ""
    for prior_index in range(row_index - 1, max(-1, row_index - 12), -1):
        prior = matrix[prior_index]
        prior_label = first_text_label(prior)
        prior_key = clean_key(prior_label)
        if not prior_label:
            continue
        if prior_label.endswith(":") or not row_has_number(prior):
            group_label = prior_label.rstrip(":")
            break

    combined = label
    label_key = clean_key(label)
    group_key = clean_key(group_label)
    if group_label and (
        label_key in {"units", "dollars", "total"}
        or re.search(r"valuation adjustments|net realizable value|write off|impairments of investments|net new orders|backlog", group_key)
        or (label_key == "total" and re.search(r"lots? owned|lots? controlled|homesites? owned|homesites? controlled", group_key))
        or (label_key == "total" and re.search(r"\binventor(y|ies)\b", group_key))
    ):
        combined = clean_text(f"{group_label} {label}")
    return label, combined, group_label


def column_labels(matrix, row_index, col_index):
    headers = []
    years = []
    for r in range(row_index):
        if not header_candidate_row(matrix[r]):
            continue
        if col_index >= len(matrix[r]):
            continue
        text = clean_text(matrix[r][col_index])
        key = clean_key(text)
        if not text or key in {"$", "%", "nan"}:
            continue
        year_match = re.search(r"(19|20)\d{2}", text)
        if year_match:
            years.append(year_match.group(0))
        if year_match and not re.search(r"[A-Za-z].*(owned|option|controlled|deposit|remaining|purchase|homesite|lot|dollar|unit|community|revenue|margin)", text, flags=re.IGNORECASE):
            continue
        if re.search(r"years ended|december|fiscal year|\bFY\b", text, flags=re.IGNORECASE):
            continue
        headers.append(text)

    deduped = []
    for header in headers:
        if header not in deduped:
            deduped.append(header)
    period_label = years[-1] if years else ""
    column_label = " | ".join(deduped[-3:])
    return column_label, period_label


def table_period_label(matrix):
    header_text = clean_text(" ".join(" ".join(row) for row in matrix[:4]))
    date_years = re.findall(
        r"(?:january|february|march|april|may|june|july|august|september|"
        r"october|november|december)\s+\d{1,2},\s*((?:19|20)\d{2})",
        header_text,
        flags=re.IGNORECASE,
    )
    unique_years = sorted(set(date_years))
    if len(unique_years) == 1:
        return unique_years[0]
    return ""


def parse_table_number(matrix, row_index, col_index):
    text = clean_text(matrix[row_index][col_index])
    if not text or not re.search(r"\d", text):
        return None
    if re.fullmatch(r"(19|20)\d{2}", text):
        return None
    if re.fullmatch(r"(19|20)\d{2}\s*[-–—]\s*(\d{2}|(19|20)\d{2})", text):
        return None

    previous_text = clean_text(matrix[row_index][col_index - 1]) if col_index > 0 else ""
    next_text = clean_text(matrix[row_index][col_index + 1]) if col_index + 1 < len(matrix[row_index]) else ""
    has_currency = "$" in text or previous_text == "$"
    has_percent = "%" in text or next_text == "%"
    if re.match(r"^\(?\s*\d{1,3}\s*\)?\s+[A-Za-z]", text):
        return None
    if re.search(r"[A-Za-z]", text) and not has_currency and not has_percent:
        return None
    is_negative = text.strip().startswith("(") or previous_text == "(" or next_text == ")"

    match = re.search(r"\(?\d{1,3}(?:,\d{3})*(?:\.\d+)?\)?|\(?\d+(?:\.\d+)?\)?", text)
    if not match:
        return None
    number = match.group(0)
    cleaned = number.replace(",", "").replace("(", "").replace(")", "")
    try:
        value = float(cleaned)
    except ValueError:
        return None
    if is_negative:
        value = -value

    raw_value = clean_text((" $ " if has_currency and "$" not in text else "") + text + (" %" if has_percent and "%" not in text else ""))
    return raw_value, value, has_currency, has_percent


def segment_label_from_context(text):
    key = clean_key(text)
    segment_terms = (
        "northeast", "mid atlantic", "midwest", "southeast", "southwest",
        "central", "east", "west", "texas",
    )
    explicit_matches = [
        (match.start(), match.group(1))
        for match in re.finditer(
            r"our (" + "|".join(segment_terms) + r") homebuilding reporting segment",
            key,
        )
    ]
    explicit_matches.extend(
        (match.start(), match.group(1))
        for match in re.finditer(r"(financial services|land development) reporting segment", key)
    )
    if explicit_matches:
        return clean_text(sorted(explicit_matches)[-1][1])
    matched = []
    for label in (
        "northeast", "mid atlantic", "midwest", "southeast", "southwest",
        "central", "east", "west", "texas", "homebuilding",
        "financial services", "land development", "unconsolidated joint ventures",
    ):
        if label in key:
            matched.append((key.rfind(label), label))
    if matched:
        return sorted(matched)[-1][1]
    return ""


def source_scope_for(row_label, combined_label, variable_name, column_label="", table_key=""):
    key = clean_key(row_label)
    combined_key = clean_key(combined_label)
    source_key = clean_key(f"{table_key} {column_label}")
    segment_label = segment_label_from_context(source_key)
    if re.search(r"unconsolidated.*joint ventures?|joint ventures?.*equity method", source_key):
        if VARIABLE_FAMILIES.get(variable_name) in {"inventory_accounting", "operating_scale"}:
            return "segment_year", segment_label or "unconsolidated joint ventures"
    if variable_name.startswith("developed_share") and "developed" in combined_key:
        return "firm_year", ""
    if re.search(r"total homesites?|total lots?|total land lots?", key):
        return "firm_year", ""
    if VARIABLE_FAMILIES.get(variable_name) == "inventory_accounting" and re.search(
        r"homes under construction|construction in progress|land under development|"
        r"residential land.*developed.*under development|land held for future development|"
        r"land held for sale|total inventory|inventor(y|ies) total|total assets|^inventor(y|ies)$",
        key,
    ):
        return "firm_year", ""
    if key in {"", "total"} or combined_key.endswith(" total") or combined_key == "total land related charges":
        return "firm_year", ""
    if re.search(
        r"reporting segment|homebuilding segment|financial services reporting segment|"
        r"operating data by segment|"
        r"financial information related to our .* segment",
        source_key,
    ):
        if VARIABLE_FAMILIES.get(variable_name) in {"operating_scale", "inventory_accounting"}:
            return "segment_year", segment_label
    if re.search(r"consolidated vie|unconsolidated vie|other land option agreements?", key):
        return "contract_structure", row_label
    if VARIABLE_FAMILIES.get(variable_name) == "risk_accounting":
        return "firm_year", ""
    if VARIABLE_FAMILIES.get(variable_name) in {"land_control", "risk_accounting", "inventory_accounting"}:
        return "segment_year", row_label
    return "firm_year", ""


def classify_table_metric(row_label, combined_label, column_label, table_key):
    row_key = clean_key(combined_label)
    raw_row_key = clean_key(row_label)
    col_key = clean_key(column_label)
    combo_key = clean_key(f"{row_key} {col_key}")
    value_column_key = re.search(r"carrying value|net carrying value|fair value|book value", col_key)
    cash_flow_change_key = re.search(r"^(increase|decrease|change) in|cash flows?|restricted cash", row_key)
    land_lot_table = re.search(
        r"lots? owned|owned lots?|lots? controlled|controlled lots?|lots? optioned|optioned lots?|"
        r"lots? under contract|total land controlled|owned controlled lots?|owned and controlled lots?|"
        r"total homebuilding lots?|homesites? owned|owned homesites?|homesites? controlled|controlled homesites?",
        table_key,
    )
    non_land_lot_row = re.search(
        r"new homes delivered|home sales?|revenues?|costs?|gross margin|income|expense|"
        r"inventory impairment|selling general and administrative|financial services|"
        r"other segment items?|closings?|orders?|backlog|average selling price|assets?|"
        r"purchase contract|obligations?|debt|lease|interest|notes?|liabilities",
        row_key,
    )
    option_deposit_column = re.search(r"option\s*/?\s*earnest money deposits?\s*cash|earnest money deposits?\s*cash", col_key)
    deposit_amount_column = re.search(r"\bdeposits?\b|\bcash\b", col_key) and not re.search(
        r"projected number|number of lots|lots under|purchase price|aggregate purchase price|commitments?",
        col_key,
    )
    purchase_price_column = re.search(r"purchase price|aggregate purchase price|remaining purchase price", col_key)
    land_option_table = re.search(
        r"land option agreements?|land option contracts?|land purchase contracts?|"
        r"lots under option|lots under contract or option|land deposits|"
        r"pre acquisition costs and deposits|non refundable option deposits|"
        r"option earnest money deposits",
        table_key,
    )
    cash_flow_table_context = re.search(
        r"statements? of cash flows?|net cash provided by operating activities|"
        r"adjustments to reconcile net income|cash used in investing|cash used in financing",
        clean_key(f"{table_key} {col_key}"),
    )
    cash_flow_row_context = re.search(
        r"statements? of cash flows?|net cash provided by operating activities|"
        r"adjustments to reconcile net income|cash used in investing|cash used in financing",
        clean_key(f"{row_key} {col_key}"),
    )
    if cash_flow_row_context or (cash_flow_table_context and not land_option_table):
        return ""

    if land_option_table and re.search(r"letters? of credit", col_key):
        return "letters_of_credit"
    if option_deposit_column:
        if re.search(r"non refundable|nonrefundable", row_key):
            return "nonrefundable_deposits_preacquisition_costs"
        if re.search(r"refundable", row_key):
            return "refundable_deposits"
        return "earnest_money_deposits"
    if purchase_price_column and land_option_table and re.search(
        r"total|unconsolidated|other land option|option contracts?|purchase contracts?|"
        r"land purchase contracts?|lots under contract|lots under option|commitments?",
        row_key,
    ):
        return "remaining_purchase_price"
    if deposit_amount_column and land_option_table:
        if re.search(r"non refundable|nonrefundable", row_key):
            return "nonrefundable_deposits_preacquisition_costs"
        if re.search(r"refundable", row_key):
            return "refundable_deposits"
        return "lpa_cash_deposits"
    if re.search(r"land deposits? and option payments?", row_key):
        return "lpa_cash_deposits"
    if re.search(r"commitments? under the land purchase contracts?", row_key):
        return "remaining_purchase_price"

    if "developed" in row_key and re.search(r"\bowned\b", col_key):
        return "developed_share_owned"
    if "developed" in row_key and re.search(r"\boptioned\b", col_key):
        return "developed_share_optioned"
    if "developed" in row_key and re.search(r"\bcontrolled\b", col_key):
        return "developed_share_controlled"
    if re.search(r"controlled homesites?", col_key):
        return "controlled_homesites"
    if re.search(r"owned homesites?", col_key):
        return "owned_homesites"
    if re.search(r"total homesites?", col_key):
        return "total_homesites"
    if re.search(r"total homesites? owned and controlled|total owned controlled homesites?", row_key):
        return "total_homesites"
    if re.search(r"homesites? owned total|total homesites? owned|total owned homesites?", row_key):
        return "owned_homesites"
    if re.search(r"homesites? controlled total|total homesites? controlled|total controlled homesites?", row_key):
        return "controlled_homesites"
    if (
        re.search(r"total lots? owned and controlled|total owned controlled lots?|total homebuilding lots?", row_key)
        or re.search(r"total lots? owned and controlled|total owned controlled lots?|total homebuilding lots?", col_key)
    ) and not value_column_key:
        return "total_lots"
    if (
        re.search(r"total lots? owned or under option|lots? owned or under option|owned or under option", row_key)
        or re.search(r"total lots? owned or under option|lots? owned or under option|owned or under option", col_key)
    ) and not value_column_key:
        return "total_lots"
    if (
        re.search(r"lots? owned total|total lots? owned|total owned lots?", row_key)
        or re.search(r"lots? owned total|total lots? owned|total owned lots?", col_key)
    ) and not value_column_key:
        return "owned_lots"
    if (
        re.search(r"lots? controlled total|total lots? controlled|total controlled lots?|total land controlled", row_key)
        or re.search(r"lots? controlled total|total lots? controlled|total controlled lots?|total land controlled", col_key)
    ) and not value_column_key:
        return "controlled_lots"
    if (
        re.search(r"lots? optioned total|total lots? optioned|total optioned lots?|total lots? under contract", row_key)
        or re.search(r"lots? optioned total|total lots? optioned|total optioned lots?|total lots? under contract", col_key)
    ) and not value_column_key:
        return "optioned_lots"
    if land_lot_table and re.fullmatch(r"total", col_key) and not value_column_key and not non_land_lot_row:
        return "total_lots"
    if re.search(r"total land lots?|total lots?|owned and controlled|owned controlled", col_key) and not value_column_key:
        return "total_lots"
    if "years of supply" in col_key:
        return ""
    if (
        re.search(r"land lots? owned|lots? owned", col_key) or
        (land_lot_table and re.search(r"\bowned\b", col_key) and not non_land_lot_row)
    ) and "not owned" not in col_key and not value_column_key:
        return "owned_lots"
    if (
        re.search(r"option lots?|optioned lots?", col_key) or
        (land_lot_table and re.search(r"\boptioned\b", col_key) and not non_land_lot_row)
    ) and not value_column_key:
        return "optioned_lots"
    if re.search(r"\bjvs?\b|joint ventures?", col_key) and land_lot_table:
        return ""
    if (
        re.search(r"lots? controlled|controlled lots?", col_key) or
        (land_lot_table and re.search(r"\bcontrolled\b", col_key) and not non_land_lot_row)
    ) and "not owned" not in col_key and not value_column_key:
        return "controlled_lots"
    if re.search(r"homes in inventory", col_key):
        return "homes_in_inventory"

    if re.search(r"land sale revenues?", row_key):
        return "land_sale_revenue"
    if re.search(r"land sale cost of revenues?", row_key):
        return "land_sale_cost"
    inventory_column_table = re.search(
        r"operating data by segment|homes under construction.*land under development.*total inventory",
        table_key,
    )
    if inventory_column_table and re.search(r"total inventory", col_key):
        return "total_inventory"
    if inventory_column_table and re.search(r"total assets", col_key):
        return "total_assets"
    if inventory_column_table and re.search(r"land held for future development", col_key):
        return "land_held_for_future_development"
    if inventory_column_table and re.search(r"land under development", col_key):
        return "land_under_development"
    if inventory_column_table and re.search(r"homes under construction", col_key):
        return "homes_under_construction_inventory"
    if cash_flow_change_key and re.search(
        r"inventory|inventories|construction in progress|residential land|land held|homes under construction",
        row_key,
    ):
        return ""
    if re.search(r"construction in progress and finished homes", row_key):
        return "homes_under_construction_inventory"
    if re.search(r"residential land( and lots?| lots?) .*developed.*under development", row_key):
        return "land_under_development"
    if re.search(r"inventory impairments?|inventory and land option charges", row_key):
        return "land_inventory_impairments"
    if re.search(r"total inventory", row_key):
        return "total_inventory"
    if re.search(r"inventor(y|ies) total", row_key):
        return "total_inventory"
    if row_key in {"inventory", "inventories"}:
        return "total_inventory"
    if re.search(r"total assets", row_key):
        return "total_assets"
    if re.search(r"land held for future development", row_key):
        return "land_held_for_future_development"
    if re.search(r"land under development", row_key):
        return "land_under_development"
    if re.search(r"homes under construction", row_key):
        return "homes_under_construction_inventory"
    if re.search(r"land held for sale gross", combo_key):
        return "land_held_for_sale_gross"
    if re.search(r"net realizable value reserves?", combo_key):
        return "land_held_for_sale_nrv_reserve"
    if re.search(r"land held for sale net", combo_key) or row_key == "land held for sale":
        return "land_held_for_sale"

    if re.search(r"total land related charges|land related charges$", row_key):
        return "land_related_charges_total"
    if re.search(r"land and community valuation adjustments?", row_key):
        return "land_community_valuation_adjustments"
    if re.search(r"write offs? of deposits? and pre acquisition costs?", row_key):
        if raw_row_key == "total" and "land related charges" not in table_key:
            return ""
        return "writeoff_deposits_preacquisition_costs"
    if re.search(r"land inventory impairments?|inventory impairments?|land impairments?", row_key):
        return "land_inventory_impairments"
    if re.search(r"net realizable value|nrv adjustments?", row_key):
        return "nrv_adjustments_land_held_for_sale"
    if re.search(r"write down of land and deposits? and pre acquisition costs?", row_key):
        return "land_related_charges_total"
    if re.search(r"impairments? of investments? in unconsolidated joint ventures?", row_key):
        return "jv_impairments"

    if re.search(r"remaining purchase price", col_key) or re.search(r"remaining purchase price", row_key):
        return "remaining_purchase_price"
    if (
        re.search(r"land not owned under option agreements?", combo_key)
        or re.search(r"liabilities for land not owned", combo_key)
    ) and not cash_flow_change_key:
        return "land_not_owned_under_option_agreements"
    if (
        re.search(r"non refundable deposits? and pre acquisition costs?|nonrefundable deposits? and pre acquisition costs?|non refundable deposits?|nonrefundable deposits?", combo_key)
        and not re.search(r"projected number|number of lots|purchase price|aggregate purchase price|commitments?", col_key)
    ):
        return "nonrefundable_deposits_preacquisition_costs"
    if (
        re.search(r"deposits? and pre acquisition costs?", col_key)
        or re.search(r"deposits? and pre acquisition costs?", row_key)
    ) and not re.search(r"write offs?|write down|land related", row_key) and not cash_flow_change_key:
        return "deposits_preacquisition_costs"
    if (
        re.search(r"refundable deposits?|refundable portion", combo_key)
        and not re.search(r"projected number|number of lots|purchase price|aggregate purchase price|commitments?", col_key)
    ):
        return "refundable_deposits"
    if re.search(r"land purchase contract obligations?", combo_key):
        return "land_purchase_contract_obligations"
    if re.search(r"letters? of credit", combo_key):
        if re.search(r"^(increase|decrease|change) in|restricted cash|collateral for|cash flows?", row_key):
            return ""
        return "letters_of_credit"
    if re.search(r"surety bonds?", combo_key):
        return "surety_bonds"
    if re.search(r"guarantees?|guaranteed", combo_key):
        return "guarantees"

    if "net new orders" in row_key and raw_row_key == "units":
        return "net_new_orders_units"
    if "net new orders" in row_key and raw_row_key == "dollars":
        return "net_new_orders_dollars"
    if "backlog" in row_key and raw_row_key == "units":
        return "backlog_units"
    if "backlog" in row_key and raw_row_key == "dollars":
        return "backlog_dollars"
    if re.search(r"costs? of (home )?closings|total cost of closings|cost of closings", row_key):
        return ""
    if re.search(r"percentage of home closings|percentage of closings|% of home closings|% of closings", combo_key):
        return ""
    if re.search(r"closings", row_key) and re.search(r"costs?|revenues?|revenue|margin|income|sales value|profit|deferr", row_key):
        return ""
    if re.search(r"closings", row_key):
        return "closings"
    if re.search(r"cancellation rate", row_key):
        return "cancellation_rate"
    if re.search(r"active communities", row_key):
        return "active_communities"
    if re.search(r"average selling price", row_key):
        return "average_selling_price"
    if re.search(r"home sale revenues?", row_key):
        if NON_OPERATING_TARGET_TABLE_PATTERN.search(clean_text(f"{table_key} {col_key}")):
            return ""
        return "home_sale_revenue"
    if re.search(r"gross margin from home sales", row_key):
        return "home_sale_gross_margin"

    return ""


def confidence_from_score(score):
    if score >= 85:
        return "high"
    if score >= 60:
        return "medium"
    return "low"


def table_candidate_score(variable_name, source_scope, period_label, fiscal_year, row_label, column_label):
    score = 60
    if period_label and str(period_label) == str(fiscal_year):
        score += 25
    elif period_label:
        score -= 25
    if source_scope == "firm_year":
        score += 20
    elif source_scope == "segment_year":
        score += 5
    if clean_key(row_label) == "total":
        score += 10
    if variable_name in {
        "remaining_purchase_price", "earnest_money_deposits", "lpa_cash_deposits",
        "nonrefundable_deposits_preacquisition_costs", "refundable_deposits",
    }:
        row_key = clean_key(row_label)
        if re.search(r"total lots under contract or option|total purchase and option contracts", row_key):
            score += 25
        elif re.search(r"total committed", row_key):
            score += 10
    if column_label:
        score += 5
    if variable_name in {
        "owned_lots", "optioned_lots", "controlled_lots", "total_lots",
        "owned_homesites", "controlled_homesites", "total_homesites",
        "remaining_purchase_price", "deposits_preacquisition_costs",
    }:
        score += 5
    if variable_name == "land_purchase_contract_obligations":
        if re.search(r"payments? due|less than|more than|thereafter|years?", clean_key(column_label)):
            score -= 25
        else:
            score += 20
    return max(1, min(score, 100))


def table_candidates_for_filing(base, source_path):
    rows = []
    seen = set()
    fiscal_year = base.get("fiscal_year", "")

    for table_index, table in enumerate(parse_html_tables(source_path), start=1):
        matrix = expand_table(table["rows"])
        if not matrix:
            continue

        max_cols = max((len(row) for row in matrix), default=0)
        if len(matrix) > 400 or max_cols > 80:
            continue

        table_key = table_search_key(matrix, table.get("context", ""))
        if not TABLE_RELEVANCE_PATTERN.search(table_key):
            continue
        table_key_for_classification = table_key
        if NON_DATA_TABLE_PATTERN.search(table_content_key(matrix)):
            continue

        table_scale_label, table_scale_factor = detect_table_scale(matrix, table.get("context", ""))
        fallback_period_label = table_period_label(matrix)
        source_section = table.get("context", "")[-500:]

        for row_index, row in enumerate(matrix):
            row_label, combined_label, group_label = row_labels(matrix, row_index)
            if not combined_label and not row_has_number(row):
                continue
            group_key = clean_key(group_label)
            if clean_key(row_label) in {"inventory", "inventories"} and re.search(
                r"operating activities|cash flows?|changes? in operating assets|changes? in assets|"
                r"decrease increase|increase decrease|reconcile.*net income|"
                r"consolidation|deconsolidation|spin off|spin-off|noncash|non cash",
                group_key,
            ):
                continue
            row_text = clean_text(" | ".join(cell for cell in row if clean_text(cell)))
            if likely_note_or_reference_row(row_text):
                continue
            row_is_percent = "%" in row_text and re.search(
                r"%|percent|percentage|rate|developed",
                clean_key(row_label),
            )

            for col_index in range(len(row)):
                parsed_number = parse_table_number(matrix, row_index, col_index)
                if parsed_number is None:
                    continue

                column_label, period_label = column_labels(matrix, row_index, col_index)
                if not period_label and fallback_period_label:
                    period_label = fallback_period_label
                if fiscal_year and period_label and str(period_label) != str(fiscal_year):
                    continue

                variable_name = classify_table_metric(row_label, combined_label, column_label, table_key_for_classification)
                if not variable_name:
                    continue
                if variable_name in {"home_sale_gross_margin", "cancellation_rate"} and re.search(
                    r"increase|decrease|change|amount|variance",
                    clean_key(column_label),
                ):
                    continue

                raw_value, value, _has_currency, _has_percent = parsed_number
                unit = VARIABLE_UNITS.get(variable_name, "unknown")
                if (_has_percent or row_is_percent) and unit != "percent":
                    continue
                if unit == "percent" and not (_has_percent or row_is_percent):
                    continue
                if unit == "dollars" and re.search(r"percentages?|gross margin %|%", clean_key(column_label)) and not _has_currency:
                    continue
                if unit == "dollars" and not _has_currency and table_scale_factor == 1:
                    continue
                if _has_currency and unit != "dollars":
                    continue
                cell_text = clean_text(matrix[row_index][col_index])
                if (
                    unit != "percent"
                    and not _has_currency
                    and cell_text.startswith("(")
                    and re.fullmatch(r"\(?\d{1,3}\)?", cell_text.replace(" ", ""))
                ):
                    continue
                if unit in {"homes", "lots", "homesites", "communities"} and value > 1_000_000:
                    continue
                if unit in {"homes", "lots", "homesites"} and abs(value - round(value)) > 1e-6:
                    continue
                applied_scale = 1
                if unit == "dollars":
                    applied_scale = applied_table_scale(
                        unit, variable_name, value, _has_currency, table_scale_factor
                    )
                    value *= applied_scale

                source_scope, segment_label = source_scope_for(
                    row_label,
                    combined_label,
                    variable_name,
                    column_label,
                    table.get("context", ""),
                )
                if (
                    variable_name == "total_inventory"
                    and clean_key(row_label) == "total"
                    and re.search(r"\binventor(y|ies)\b", group_key)
                ):
                    prior_labels = clean_key(
                        " ".join(
                            first_text_label(matrix[i])
                            for i in range(max(0, row_index - 6), row_index)
                        )
                    )
                    if re.search(
                        r"deferred income taxes|property and equipment|other assets|goodwill|"
                        r"financial services|total assets",
                        prior_labels,
                    ):
                        continue
                score = table_candidate_score(variable_name, source_scope, period_label, fiscal_year, row_label, column_label)
                if variable_name == "total_assets" and clean_key(row_label) == "total":
                    prior_labels = clean_key(" ".join(first_text_label(matrix[i]) for i in range(max(0, row_index - 3), row_index)))
                    if "financial services" in prior_labels:
                        score += 5
                key = (
                    table_index, variable_name, source_scope, segment_label,
                    period_label, raw_value, value, row_text[:120], column_label
                )
                if key in seen:
                    continue
                seen.add(key)

                candidate_row = {
                    **base,
                    "variable_name": variable_name,
                    "raw_value": raw_value,
                    "numeric_value": value,
                    "unit": unit,
                    "scale_factor_applied": applied_scale,
                    "context_snippet": source_section,
                    "table_row_or_table_text": row_text,
                    "extraction_method": "table_cell_structured",
                    "confidence": confidence_from_score(score),
                    "source_path": source_path,
                    "source_url": base.get("filing_url", ""),
                    "notes": f"Table group: {group_label}",
                    "metric_raw_name": clean_text(f"{combined_label} {column_label}"),
                    "metric_family": VARIABLE_FAMILIES.get(variable_name, ""),
                    "source_scope": source_scope,
                    "segment_label": segment_label,
                    "period_label": period_label,
                    "source_table_index": table_index,
                    "source_row_label": row_label,
                    "source_column_label": column_label,
                    "source_section": source_section,
                    "table_scale_label": table_scale_label,
                    "statement_scale_factor": applied_scale,
                    "candidate_score": score,
                }
                rows.append(candidate_row)
                if (
                    variable_name == "lpa_cash_deposits"
                    and source_scope == "firm_year"
                    and re.search(r"non refundable|nonrefundable", table_key_for_classification)
                    and not re.search(r"letters? of credit", clean_key(column_label))
                    and re.search(r"\bdeposits?\b|land deposits? and option payments?", clean_key(f"{row_label} {column_label}"))
                ):
                    alias_row = dict(candidate_row)
                    alias_row["variable_name"] = "nonrefundable_deposits_preacquisition_costs"
                    alias_row["metric_raw_name"] = clean_text(
                        f"{candidate_row['metric_raw_name']} non-refundable deposit alias"
                    )
                    alias_row["metric_family"] = VARIABLE_FAMILIES.get(alias_row["variable_name"], "")
                    alias_row["notes"] = f"{candidate_row['notes']}; table context describes these deposits as non-refundable."
                    alias_row["candidate_score"] = min(100, score + 5)
                    alias_row["confidence"] = confidence_from_score(alias_row["candidate_score"])
                    rows.append(alias_row)
    return rows


def main():
    inventory = read_inventory()
    eligible_filings = [
        filing for filing in inventory
        if filing.get("primary_document_status", "") in {"downloaded", "already_present"}
    ]
    candidate_rows = []
    mention_rows = []
    parsed_count = 0
    missing_files = 0

    for filing in eligible_filings:
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
        candidate_rows.extend(candidate_rows_for_filing(base, text, source_path, document_scale_factor(text)))
        candidate_rows.extend(special_prose_candidates_for_filing(base, text, source_path, document_scale_factor(text)))
        candidate_rows.extend(table_candidates_for_filing(base, source_path))
        if parsed_count == 1 or parsed_count % 25 == 0 or parsed_count == len(eligible_filings):
            print(
                f"Parsed {parsed_count}/{len(eligible_filings)} filings; "
                f"candidate rows so far: {len(candidate_rows)}",
                flush=True,
            )

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
        {"check": "table_candidate_rows", "status": "ok" if any(row.get("extraction_method") == "table_cell_structured" for row in candidate_rows) else "warn", "value": sum(row.get("extraction_method") == "table_cell_structured" for row in candidate_rows), "detail": ""},
    ]

    candidate_fields = [
        "builder_name_key", "builder_name_clean", "ticker", "cik", "cik10", "sec_company_name",
        "accession_number", "accession_number_no_dashes", "form", "filing_date", "report_date",
        "fiscal_year", "primary_document", "filing_url", "variable_name", "raw_value",
        "numeric_value", "unit", "scale_factor_applied", "context_snippet",
        "table_row_or_table_text", "extraction_method", "confidence", "source_path",
        "source_url", "notes", "metric_raw_name", "metric_family", "source_scope",
        "segment_label", "period_label", "source_table_index", "source_row_label",
        "source_column_label", "source_section", "table_scale_label",
        "statement_scale_factor", "candidate_score"
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
