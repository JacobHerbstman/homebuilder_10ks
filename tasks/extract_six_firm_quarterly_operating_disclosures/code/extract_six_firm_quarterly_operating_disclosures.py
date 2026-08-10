#!/usr/bin/env python3

import csv
import html
import re
import sys
from html.parser import HTMLParser
from pathlib import Path

sys.path.append(str(Path(__file__).resolve().parents[2] / "_lib"))
from sec_fetch_utils import write_csv


class VisibleTextParser(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.skip_depth = 0
        self.parts = []

    def handle_starttag(self, tag, attrs):
        tag = tag.lower()
        if tag in {"script", "style", "noscript", "head", "title"}:
            self.skip_depth += 1
        if tag in {"br", "p", "div", "tr", "td", "th", "li", "h1", "h2", "h3", "h4", "table"}:
            self.parts.append(" ")

    def handle_endtag(self, tag):
        tag = tag.lower()
        if tag in {"script", "style", "noscript", "head", "title"} and self.skip_depth:
            self.skip_depth -= 1
        if tag in {"p", "div", "tr", "li", "h1", "h2", "h3", "h4", "table"}:
            self.parts.append(" ")

    def handle_data(self, data):
        if not self.skip_depth:
            self.parts.append(data)

    def text(self):
        return re.sub(r"\s+", " ", html.unescape(" ".join(self.parts))).strip()


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
    cleaned = str(x).replace("$", "").replace(",", "").replace("%", "").strip()
    cleaned = cleaned.replace("(", "-").replace(")", "")
    cleaned = cleaned.replace("—", "").replace("-", "") if cleaned.strip() in {"—", "-"} else cleaned
    if cleaned == "":
        return None
    return float(cleaned)


def parse_money_to_thousands(amount, scale_label=None):
    value = parse_number(amount)
    if value is None:
        return None
    scale = clean_text(scale_label).lower()
    if "billion" in scale:
        return value * 1_000_000
    if "million" in scale:
        return value * 1_000
    return value


def parse_abs_number(x):
    value = parse_number(x)
    return abs(value) if value is not None else None


def format_number(x):
    if x is None:
        return ""
    if abs(x - round(x)) < 1e-9:
        return str(int(round(x)))
    return f"{x:.12g}"


def snippet(text, match, before=450, after=950):
    if match is None:
        return ""
    return clean_text(text[max(0, match.start() - before):min(len(text), match.end() + after)])


def find_number(text, pattern):
    match = re.search(pattern, text, re.IGNORECASE)
    return (parse_number(match.group(1)), match) if match else (None, None)


def find_money(text, pattern):
    match = re.search(pattern, text, re.IGNORECASE)
    return (parse_money_to_thousands(match.group(1), match.group(2) if match.lastindex and match.lastindex >= 2 else None), match) if match else (None, None)


def numbers_in(text):
    return [parse_number(match.group(0)) for match in re.finditer(r"\(?[0-9][0-9,]*(?:\.[0-9]+)?\)?", text)]


def window_after(text, pattern, length=9000):
    match = re.search(pattern, text, re.IGNORECASE)
    if not match:
        return "", None
    return text[match.start():min(len(text), match.start() + length)], match


def window_around(text, pattern, before=800, after=3500):
    match = re.search(pattern, text, re.IGNORECASE)
    if not match:
        return "", None
    return text[max(0, match.start() - before):min(len(text), match.end() + after)], match


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
        "filing_url": row["source_url"],
        "source_local_path": row["source_local_path"],
        "source_checksum_sha256": row["source_checksum_sha256"],
        "orders_units": "",
        "orders_value_thousands": "",
        "orders_period_basis": "current_quarter",
        "deliveries_units": "",
        "deliveries_value_thousands": "",
        "deliveries_period_basis": "current_quarter",
        "backlog_units": "",
        "backlog_value_thousands": "",
        "cancellation_rate_pct": "",
        "active_communities": "",
        "deposit_writeoffs_thousands": "",
        "deposit_writeoffs_ytd_thousands": "",
        "deposit_writeoffs_extraction_method": "",
        "deposit_writeoffs_context_snippet": "",
        "operating_extraction_method": "",
        "operating_context_snippet": "",
    }


def disclosure_from_values(row, values, method, context):
    out = base_disclosure(row)
    for key, value in values.items():
        out[key] = format_number(value)
    out["operating_extraction_method"] = method
    out["operating_context_snippet"] = clean_text(context)
    return out


def add_deposit_writeoffs(row, text, out):
    value = None
    ytd_value = None
    match = None
    method = ""

    if row["ticker"] == "DHI":
        match = re.search(
            r"earnest money and pre-acquisition cost write-offs related to land purchase contracts.*?"
            r"were\s+\$\s*([0-9.]+)\s+(million|billion)",
            text,
            re.IGNORECASE,
        )
        if match:
            value = parse_money_to_thousands(match.group(1), match.group(2))
            method = "dhi_earnest_money_preacquisition_writeoff_prose"

    if row["ticker"] == "PHM":
        match = re.search(
            r"Write-offs of deposits and pre-acquisition costs\s+\$?\s*\(?\s*([0-9,]+)\s*\)?",
            text,
            re.IGNORECASE,
        )
        if match:
            value = parse_abs_number(match.group(1))
            method = "phm_other_expense_writeoff_table"

    if row["ticker"] == "KBH":
        match = re.search(
            r"land option contract abandonment charges:\s+.*?Total\s+\$?\s*([0-9,]+)",
            text,
            re.IGNORECASE,
        )
        if match:
            value = parse_abs_number(match.group(1))
            method = "kbh_segment_abandonment_charges_table"
        else:
            match = re.search(
                r"recognized land option contract abandonment charges of\s+\$\s*([0-9.]+)\s*(million)?\s+for the three",
                text,
                re.IGNORECASE,
            )
            if match:
                value = parse_money_to_thousands(match.group(1), "million" if match.group(2) else "")
                method = "kbh_abandonment_charges_prose"

    if row["ticker"] == "HOV":
        match = re.search(
            r"Inventory impairments?(?: loss)? and land option write-offs\s+\(?\s*([0-9,]+)\s*\)?",
            text,
            re.IGNORECASE,
        )
        if not match:
            match = re.search(
                r"Inventory impairment loss and land option write-offs\s+\(?\s*([0-9,]+)\s*\)?",
                text,
                re.IGNORECASE,
            )
        if match:
            value = parse_abs_number(match.group(1))
            method = "hov_income_statement_inventory_impairment_land_option_writeoff_row"

    if row["ticker"] == "LEN":
        match = re.search(
            r"Valuation adjustments and write-offs of option deposits(?:,\s*pre-acquisition costs and other assets| and pre-acquisition costs)?\s+\(?\s*([0-9,]+)\s*\)?",
            text,
            re.IGNORECASE,
        )
        if match:
            ytd_value = parse_abs_number(match.group(1))
            method = "len_cash_flow_ytd_valuation_adjustments_writeoffs"

    if value is not None:
        out["deposit_writeoffs_thousands"] = format_number(value)
    if ytd_value is not None:
        out["deposit_writeoffs_ytd_thousands"] = format_number(ytd_value)
    if value is not None or ytd_value is not None:
        out["deposit_writeoffs_extraction_method"] = method
        out["deposit_writeoffs_context_snippet"] = snippet(text, match, 300, 850)
    return out


def missing_disclosure(row, context=""):
    out = base_disclosure(row)
    out["operating_extraction_method"] = "no_quarterly_operating_match"
    out["operating_context_snippet"] = clean_text(context)
    return out


def extract_dhi(row, text):
    section, section_match = window_after(text, r"Key financial results", 4500)
    if section == "":
        section = text
    deliveries, deliveries_match = find_number(
        section, r"Homes closed\s+(?:increased|decreased|were|totaled).{0,120}?\s+to\s+([0-9,]+)\s+homes"
    )
    orders, orders_match = find_number(
        section, r"Net sales orders\s+(?:increased|decreased|were|totaled).{0,120}?\s+to\s+([0-9,]+)\s+homes"
    )
    orders_value, orders_value_match = find_money(
        section, r"value of net sales orders\s+(?:increased|decreased|was|were).{0,120}?\s+to\s+\$([0-9.]+)\s+(billion|million)"
    )
    backlog, backlog_match = find_number(
        section, r"Sales order backlog\s+(?:increased|decreased|was|were).{0,120}?\s+to\s+([0-9,]+)\s+homes"
    )
    backlog_value, backlog_value_match = find_money(
        section, r"value of sales order backlog\s+(?:increased|decreased|was|were).{0,120}?\s+to\s+\$([0-9.]+)\s+(billion|million)"
    )
    if orders is None or deliveries is None:
        return missing_disclosure(row)
    return disclosure_from_values(
        row,
        {
            "orders_units": orders,
            "orders_value_thousands": orders_value,
            "deliveries_units": deliveries,
            "backlog_units": backlog,
            "backlog_value_thousands": backlog_value,
        },
        "dhi_key_financial_results_prose",
        " ".join([
            snippet(section, deliveries_match, 250, 500),
            snippet(section, orders_match, 250, 500),
            snippet(section, orders_value_match, 250, 500),
            snippet(section, backlog_match, 250, 500),
            snippet(section, backlog_value_match, 250, 500),
        ]),
    )


def extract_len(row, text):
    deliveries_section, _ = window_around(text, r"Of the total homes delivered", 3500, 1400)
    orders_section, _ = window_after(text, r"New Orders\s*(?:\([^)]*\))?:", 7000)
    backlog_section, _ = window_after(text, r"Backlog\s*(?:\([^)]*\))?:", 4500)
    active_communities = None
    deliveries_match = re.search(
        r"Total\s+([0-9,]+)\s+([0-9,]+)\s+\$?\s*([0-9,]+)\s+([0-9,]+).*?Of the total homes delivered",
        deliveries_section,
        re.IGNORECASE,
    )
    if not deliveries_match:
        deliveries_section, _ = window_around(
            text,
            r"New home deliveries\s+(?:(?:increased|decreased)\s+to|were)\s+[0-9,]+\s+homes",
            700,
            900,
        )
        deliveries_match = re.search(
            r"New home deliveries\s+(?:(?:increased|decreased)\s+to|were)\s+([0-9,]+)\s+homes",
            deliveries_section,
            re.IGNORECASE,
        )
    orders_match = re.search(
        r"New Orders\s*(?:\([^)]*\))?:.*?Active Communities\s+Homes\s+Dollar Value.*?"
        r"Total\s+([0-9,]+)\s+([0-9,]+)\s+([0-9,]+)\s+([0-9,]+)\s+\$?\s*([0-9,]+)\s+([0-9,]+)",
        orders_section,
        re.IGNORECASE,
    )
    if orders_match:
        active_communities = parse_number(orders_match.group(1))
        orders_units = parse_number(orders_match.group(3))
        orders_value = parse_number(orders_match.group(5))
    else:
        orders_match = re.search(
            r"New Orders\s*(?:\([^)]*\))?:.*?Homes\s+Dollar Value.*?"
            r"Total\s+([0-9,]+)\s+([0-9,]+)\s+\$?\s*([0-9,]+)\s+([0-9,]+)",
            orders_section,
            re.IGNORECASE,
        )
        orders_units = parse_number(orders_match.group(1)) if orders_match else None
        orders_value = parse_number(orders_match.group(3)) if orders_match else None
    backlog_match = re.search(
        r"Backlog\s*(?:\([^)]*\))?:.*?Homes\s+Dollar Value.*?Total\s+([0-9,]+)\s+([0-9,]+)\s+\$?\s*([0-9,]+)\s+([0-9,]+)",
        backlog_section,
        re.IGNORECASE,
    )
    if not deliveries_match or not orders_match:
        return missing_disclosure(row)
    deliveries_units = parse_number(deliveries_match.group(1))
    deliveries_value = parse_number(deliveries_match.group(3)) if deliveries_match.lastindex and deliveries_match.lastindex >= 3 else None
    return disclosure_from_values(
        row,
        {
            "orders_units": orders_units,
            "orders_value_thousands": orders_value,
            "deliveries_units": deliveries_units,
            "deliveries_value_thousands": deliveries_value,
            "backlog_units": parse_number(backlog_match.group(1)) if backlog_match else None,
            "backlog_value_thousands": parse_number(backlog_match.group(3)) if backlog_match else None,
            "active_communities": active_communities,
        },
        "len_home_deliveries_new_orders_backlog_total_rows",
        " ".join([snippet(deliveries_section, deliveries_match), snippet(orders_section, orders_match), snippet(backlog_section, backlog_match)]),
    )


def extract_phm(row, text):
    section, _ = window_after(text, r"Supplemental data", 6500)
    match = re.search(
        r"Closings\s+\(units\)\s+([0-9,]+).*?"
        r"Net new orders.*?Units\s+([0-9,]+).*?"
        r"Dollars(?:\s+\([a-z]\))?\s+\$?\s*([0-9,]+).*?"
        r"Cancellation rate\s+([0-9.]+)\s*%.*?"
        r"(?:Average active communities|Active communities(?:\s+at\s+[A-Za-z]+\s+[0-9]+)?)\s+([0-9,]+).*?"
        r"Backlog at .*?Units\s+([0-9,]+).*?"
        r"Dollars\s+\$?\s*([0-9,]+)",
        section,
        re.IGNORECASE,
    )
    if not match:
        return missing_disclosure(row)
    return disclosure_from_values(
        row,
        {
            "orders_units": parse_number(match.group(2)),
            "orders_value_thousands": parse_number(match.group(3)),
            "deliveries_units": parse_number(match.group(1)),
            "backlog_units": parse_number(match.group(6)),
            "backlog_value_thousands": parse_number(match.group(7)),
            "cancellation_rate_pct": parse_number(match.group(4)),
            "active_communities": parse_number(match.group(5)),
        },
        "phm_supplemental_operating_data_table",
        snippet(section, match),
    )


def extract_kbh(row, text):
    deliveries_section, _ = window_around(text, r"Homes delivered\s+[0-9,]+", 3500, 2200)
    orders_section, _ = window_after(text, r"The following table presents information concerning our net orders", 4200)
    if orders_section == "":
        orders_section, _ = window_after(text, r"Net Orders, Cancellation Rates, Backlog and Community Count", 4200)
    if orders_section == "":
        orders_section, _ = window_around(text, r"Net orders\s+[0-9,]+", 1200, 2200)
    deliveries_value, deliveries_value_match = find_number(deliveries_section, r"Housing\s+\$?\s*([0-9,]+)")
    deliveries_units, deliveries_match = find_number(deliveries_section, r"Homes delivered\s+([0-9,]+)")
    orders_units, orders_match = find_number(orders_section, r"Net orders\s+([0-9,]+)")
    orders_value, orders_value_match = find_number(orders_section, r"Net order value.*?\$?\s*([0-9,]+)")
    cancellation_rate, cancellation_match = find_number(orders_section, r"Cancellation rates?.*?([0-9.]+)\s*%")
    backlog_units, backlog_match = find_number(orders_section, r"Ending backlog\s+[—-]\s+homes\s+([0-9,]+)")
    backlog_value, backlog_value_match = find_number(orders_section, r"Ending backlog\s+[—-]\s+value\s+\$?\s*([0-9,]+)")
    active_communities, active_match = find_number(orders_section, r"Average community count\s+([0-9,]+)")
    if deliveries_units is None or orders_units is None:
        return missing_disclosure(row)
    return disclosure_from_values(
        row,
        {
            "orders_units": orders_units,
            "orders_value_thousands": orders_value,
            "deliveries_units": deliveries_units,
            "deliveries_value_thousands": deliveries_value,
            "backlog_units": backlog_units,
            "backlog_value_thousands": backlog_value,
            "cancellation_rate_pct": cancellation_rate,
            "active_communities": active_communities,
        },
        "kbh_financial_results_and_net_orders_table",
        " ".join([
            snippet(deliveries_section, deliveries_match),
            snippet(deliveries_section, deliveries_value_match),
            snippet(orders_section, orders_match),
            snippet(orders_section, orders_value_match),
            snippet(orders_section, cancellation_match),
            snippet(orders_section, backlog_match),
            snippet(orders_section, backlog_value_match),
            snippet(orders_section, active_match),
        ]),
    )


def extract_hov(row, text):
    deliveries_section, _ = window_after(text, r"Information on (?:homes delivered|the sale of homes)", 4500)
    deliveries_match = re.search(
        r"Consolidated total:\s+(?:Dollars|Housing revenues)\s+\$?\s*([0-9,]+).*?"
        r"(?:Homes delivered|Homes)\s+([0-9,]+)",
        deliveries_section,
        re.IGNORECASE,
    )
    if not deliveries_match:
        deliveries_match = re.search(
            r"Consolidated total\s*:\s+(?:Dollars|Housing revenues)\s+\$?\s*([0-9,]+).*?"
            r"(?:Homes delivered|Homes)\s+([0-9,]+)",
            text,
            re.IGNORECASE,
        )
        deliveries_section = text
    contracts_section = ""
    contracts_match = None
    for match in re.finditer(r"Net Contracts", text, re.IGNORECASE):
        possible_section = text[match.start():match.start() + 12000]
        if re.search(r"Contract Backlog as of", possible_section, re.IGNORECASE) and re.search(r"Dollars in thousands", possible_section, re.IGNORECASE):
            possible_match = re.search(
                r"(?:Consolidated total|Total)(?:\s*\(\s*[0-9]+\s*\))?\s*:\s*(?:\(\s*[0-9]+\s*\)\s*)?Dollars\s+(.*?)\s+"
                r"(?:Homes|Number of homes)\s+(.*)",
                possible_section,
                re.IGNORECASE,
            )
            if possible_match:
                contracts_section = possible_section
                contracts_match = possible_match
                break
    cancellation_rate = None
    quarter_label = {"1": "First", "2": "Second", "3": "Third", "4": "Fourth"}.get(row.get("fiscal_quarter", ""))
    cancellation_match = None
    if quarter_label:
        cancellation_match = re.search(rf"{quarter_label}\s+([0-9.]+)\s*%", text, re.IGNORECASE)
        if cancellation_match:
            cancellation_rate = parse_number(cancellation_match.group(1))
    if not deliveries_match or not contracts_match:
        return missing_disclosure(row)
    contract_dollars = numbers_in(contracts_match.group(1))
    contract_homes = numbers_in(contracts_match.group(2))[:len(contract_dollars)]
    if len(contract_dollars) not in {4, 6} or len(contract_homes) != len(contract_dollars):
        return missing_disclosure(row, snippet(text, contracts_match))
    backlog_index = len(contract_homes) - 2
    return disclosure_from_values(
        row,
        {
            "orders_units": contract_homes[0],
            "orders_value_thousands": contract_dollars[0],
            "deliveries_units": parse_number(deliveries_match.group(2)),
            "deliveries_value_thousands": parse_number(deliveries_match.group(1)),
            "backlog_units": contract_homes[backlog_index],
            "backlog_value_thousands": contract_dollars[backlog_index],
            "cancellation_rate_pct": cancellation_rate,
        },
        "hov_delivery_and_contract_backlog_total_rows",
        " ".join([snippet(deliveries_section, deliveries_match), snippet(text, contracts_match), snippet(text, cancellation_match, 250, 450)]),
    )


def extract_nvr(row, text):
    section, _ = window_after(text, r"Operating Data:\s+New orders", 5200)
    orders_units, orders_match = find_number(section, r"New orders\s+\(units\)\s+([0-9,]+)")
    avg_order_price_thousands, avg_order_match = find_number(section, r"Average new order price\s+\$?\s*([0-9.]+)")
    deliveries_units, deliveries_match = find_number(section, r"Settlements\s+\(units\)\s+([0-9,]+)")
    avg_delivery_price_thousands, avg_delivery_match = find_number(section, r"Average settlement price\s+\$?\s*([0-9.]+)")
    backlog_units, backlog_match = find_number(section, r"Backlog\s+\(units\)\s+([0-9,]+)")
    avg_backlog_price_thousands, avg_backlog_match = find_number(section, r"Average backlog price\s+\$?\s*([0-9.]+)")
    cancellation_rate, cancellation_match = find_number(section, r"New order cancellation rate\s+([0-9.]+)\s*%")
    active_communities, active_match = find_number(section, r"Average active communities:?\s+([0-9,]+)")
    if active_communities is None:
        active_section, _ = window_after(text, r"Average active communities", 1800)
        active_communities, active_match = find_number(active_section, r"Total\s+([0-9,]+)")
    if orders_units is None or deliveries_units is None:
        return missing_disclosure(row)
    return disclosure_from_values(
        row,
        {
            "orders_units": orders_units,
            "orders_value_thousands": orders_units * avg_order_price_thousands if orders_units is not None and avg_order_price_thousands is not None else None,
            "deliveries_units": deliveries_units,
            "deliveries_value_thousands": deliveries_units * avg_delivery_price_thousands if deliveries_units is not None and avg_delivery_price_thousands is not None else None,
            "backlog_units": backlog_units,
            "backlog_value_thousands": backlog_units * avg_backlog_price_thousands if backlog_units is not None and avg_backlog_price_thousands is not None else None,
            "cancellation_rate_pct": cancellation_rate,
            "active_communities": active_communities,
        },
        "nvr_homebuilding_operations_operating_data_table",
        " ".join([
            snippet(section, orders_match),
            snippet(section, avg_order_match),
            snippet(section, deliveries_match),
            snippet(section, avg_delivery_match),
            snippet(section, backlog_match),
            snippet(section, avg_backlog_match),
            snippet(section, cancellation_match),
            snippet(section, active_match),
        ]),
    )


def extract_disclosure(row):
    path = row.get("source_local_path", "")
    if not path or not Path(path).exists():
        return missing_disclosure(row)
    text = visible_text(path)
    if row["ticker"] == "DHI":
        return add_deposit_writeoffs(row, text, extract_dhi(row, text))
    if row["ticker"] == "LEN":
        return add_deposit_writeoffs(row, text, extract_len(row, text))
    if row["ticker"] == "PHM":
        return add_deposit_writeoffs(row, text, extract_phm(row, text))
    if row["ticker"] == "KBH":
        return add_deposit_writeoffs(row, text, extract_kbh(row, text))
    if row["ticker"] == "HOV":
        return add_deposit_writeoffs(row, text, extract_hov(row, text))
    if row["ticker"] == "NVR":
        return add_deposit_writeoffs(row, text, extract_nvr(row, text))
    return missing_disclosure(row)


with Path("../input/tier1_2018_2025_quarterly_skeleton.csv").open(newline="") as f:
    filing_rows = [
        row for row in csv.DictReader(f)
        if row["ticker"] in {"DHI", "LEN", "PHM", "KBH", "HOV", "NVR"}
        and row["source_kind"] == "interim_10q"
    ]

with Path("../input/tier1_2018_2025_sec_10q_download_inventory.csv").open(newline="") as f:
    for row in csv.DictReader(f):
        if row["ticker"] == "DHI" and row["fiscal_q4_derivation_lookback_flag"] == "TRUE":
            filing_rows.append({
                "ticker": row["ticker"],
                "company": row["company"],
                "cik10": row["cik10"],
                "calendar_year": row["calendar_year"],
                "calendar_quarter": row["calendar_quarter"],
                "calendar_quarter_label": row["calendar_quarter_label"],
                "fiscal_year": str(int(row["calendar_year"]) + 1),
                "fiscal_quarter": "1",
                "source_form": row["form"],
                "source_filing_date": row["filing_date"],
                "source_report_date": row["report_date"],
                "source_accession_number": row["accession_number"],
                "source_url": row["filing_url"],
                "source_local_path": row["source_local_path"],
                "source_checksum_sha256": row["source_checksum_sha256"],
            })

disclosures = [extract_disclosure(row) for row in filing_rows]

if len(disclosures) != 145 or len({(row["ticker"], row["report_date"]) for row in disclosures}) != 145:
    raise SystemExit("Expected 145 unique six-firm 10-Q disclosure rows, including the DHI fiscal-2018 lookback quarter.")

if any(not row["orders_units"] or not row["deliveries_units"] or not row["backlog_units"] for row in disclosures):
    raise SystemExit("At least one six-firm 10-Q disclosure is missing orders, deliveries, or backlog.")

disclosure_fields = [
    "ticker", "company", "cik10", "calendar_year", "calendar_quarter", "calendar_quarter_label",
    "fiscal_year", "fiscal_quarter", "form", "filing_date", "report_date", "accession_number",
    "orders_units", "orders_value_thousands", "orders_period_basis",
    "deliveries_units", "deliveries_value_thousands", "deliveries_period_basis",
    "backlog_units", "backlog_value_thousands", "cancellation_rate_pct", "active_communities",
    "deposit_writeoffs_thousands", "deposit_writeoffs_ytd_thousands",
    "deposit_writeoffs_extraction_method", "deposit_writeoffs_context_snippet",
    "operating_extraction_method", "operating_context_snippet", "filing_url",
    "source_local_path", "source_checksum_sha256",
]

write_csv("../output/six_firm_2018_2025_quarterly_operating_disclosures.csv", disclosures, disclosure_fields)

print("Wrote six-firm quarterly operating disclosures to ../output")
