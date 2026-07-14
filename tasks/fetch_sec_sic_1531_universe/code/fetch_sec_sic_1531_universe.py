#!/usr/bin/env python3

import csv
import html
import json
import sys
import time
import urllib.parse
from html.parser import HTMLParser
from pathlib import Path

sys.path.append(str(Path(__file__).resolve().parents[2] / "_lib"))
from sec_fetch_utils import (
    fetch_to_path,
    pull_date,
    read_json,
    require_sec_user_agent,
    sec_request_delay,
    sha256,
    write_csv,
)


ANNUAL_FORMS = {"10-K", "10-K/A", "10-K405", "10-K405/A", "10-KSB", "10-KSB/A", "10-KT", "10-KT/A"}


def clean_text(value):
    return " ".join(html.unescape(str(value or "")).replace("\xa0", " ").split())


def cik10(value):
    raw_value = "".join(ch for ch in str(value or "") if ch.isdigit())
    return raw_value.zfill(10) if raw_value else ""


class SecTableParser(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.in_results_table = False
        self.table_depth = 0
        self.in_cell = False
        self.current_cell = []
        self.current_row = []
        self.rows = []

    def handle_starttag(self, tag, attrs):
        tag = tag.lower()
        attrs = dict(attrs)
        if tag == "table" and "tableFile2" in attrs.get("class", ""):
            self.in_results_table = True
            self.table_depth = 1
            return
        if self.in_results_table and tag == "table":
            self.table_depth += 1
            return
        if self.in_results_table and tag == "tr":
            self.current_row = []
            return
        if self.in_results_table and tag in {"td", "th"}:
            self.in_cell = True
            self.current_cell = []
            return
        if self.in_cell and tag == "br":
            self.current_cell.append(" ")

    def handle_endtag(self, tag):
        tag = tag.lower()
        if self.in_results_table and tag in {"td", "th"} and self.in_cell:
            self.current_row.append(clean_text(" ".join(self.current_cell)))
            self.current_cell = []
            self.in_cell = False
            return
        if self.in_results_table and tag == "tr":
            if self.current_row:
                self.rows.append(self.current_row)
            self.current_row = []
            return
        if self.in_results_table and tag == "table":
            self.table_depth -= 1
            if self.table_depth <= 0:
                self.in_results_table = False

    def handle_data(self, data):
        if self.in_cell:
            self.current_cell.append(data)


def parse_sic_browse_companies(path):
    parser = SecTableParser()
    parser.feed(Path(path).read_text(encoding="utf-8", errors="replace"))
    rows = []
    for row in parser.rows:
        if len(row) < 3 or not row[0].isdigit():
            continue
        rows.append({
            "cik10": cik10(row[0]),
            "cik": str(int(row[0])),
            "sic_1531_company_name": row[1],
            "sic_1531_state_country": row[2],
        })
    return rows


def filing_rows_from_json(submission_json):
    filings = submission_json.get("filings", {}).get("recent")
    if not filings and "accessionNumber" in submission_json:
        filings = submission_json
    if not filings:
        return []

    accessions = filings.get("accessionNumber", [])
    rows = []
    for i in range(len(accessions)):
        rows.append({
            "accession_number": str(accessions[i]),
            "form": str(filings.get("form", [""] * len(accessions))[i]),
            "filing_date": str(filings.get("filingDate", [""] * len(accessions))[i]),
            "report_date": str(filings.get("reportDate", [""] * len(accessions))[i]),
        })
    return rows


def sic_browse_url(start):
    return "https://www.sec.gov/cgi-bin/browse-edgar?" + urllib.parse.urlencode({
        "action": "getcompany",
        "SIC": "1531",
        "type": "10-K",
        "dateb": "",
        "owner": "include",
        "count": "100",
        "start": str(start),
    })


def main():
    user_agent = require_sec_user_agent()
    delay_seconds = sec_request_delay()
    browse_pages = []
    submission_files = []
    company_candidates = {}

    for start in range(0, 5000, 100):
        source_url = sic_browse_url(start)
        source_local_path = Path("..") / "output" / "raw" / "sec_sic_1531_browse" / pull_date() / f"start_{start}.html"
        result = fetch_to_path(source_url, source_local_path, user_agent)
        companies = parse_sic_browse_companies(source_local_path) if source_local_path.exists() else []
        browse_pages.append({
            "source_id": "sec_sic_1531_browse",
            "pull_date": pull_date(),
            "start": start,
            "source_url": source_url,
            "source_local_path": str(source_local_path),
            "status": result["status"],
            "http_status": result["http_status"],
            "downloaded_at_utc": result["downloaded_at_utc"],
            "bytes": result["bytes"],
            "company_rows": len(companies),
            "checksum_sha256": sha256(source_local_path),
            "error": result["error"],
        })
        for company in companies:
            company_candidates[company["cik10"]] = company
        time.sleep(delay_seconds)
        if result["status"] not in {"downloaded", "already_present"} or not companies:
            break

    company_rows = []
    for company in sorted(company_candidates.values(), key=lambda row: (row["sic_1531_company_name"].lower(), row["cik10"])):
        source_local_dir = Path("..") / "output" / "raw" / "sec_sic_1531_submissions" / company["cik10"]
        main_name = f"CIK{company['cik10']}.json"
        main_url = f"https://data.sec.gov/submissions/{main_name}"
        main_path = source_local_dir / main_name
        result = fetch_to_path(main_url, main_path, user_agent)
        submission_files.append({
            "cik": company["cik"],
            "cik10": company["cik10"],
            "sic_1531_company_name": company["sic_1531_company_name"],
            "file_role": "main_submissions_json",
            "source_url": main_url,
            "source_local_path": str(main_path),
            "status": result["status"],
            "http_status": result["http_status"],
            "downloaded_at_utc": result["downloaded_at_utc"],
            "bytes": result["bytes"],
            "checksum_sha256": sha256(main_path),
            "error": result["error"],
        })
        time.sleep(delay_seconds)

        sec_name = ""
        sec_sic = ""
        sec_sic_description = ""
        tickers = []
        exchanges = []
        annual_filings = []
        older_files = []

        if result["status"] in {"downloaded", "already_present"} and main_path.exists():
            try:
                main_json = read_json(main_path)
                sec_name = clean_text(main_json.get("name", ""))
                sec_sic = clean_text(main_json.get("sic", ""))
                sec_sic_description = clean_text(main_json.get("sicDescription", ""))
                tickers = [clean_text(value) for value in (main_json.get("tickers", []) or []) if clean_text(value)]
                exchanges = [clean_text(value) for value in (main_json.get("exchanges", []) or []) if clean_text(value)]
                annual_filings.extend(row for row in filing_rows_from_json(main_json) if row["form"] in ANNUAL_FORMS)
                older_files = main_json.get("filings", {}).get("files", []) or []
            except json.JSONDecodeError as e:
                submission_files[-1]["error"] = str(e)

        for older_file in older_files:
            name = older_file.get("name", "")
            if not name:
                continue
            older_url = f"https://data.sec.gov/submissions/{name}"
            older_path = source_local_dir / name
            older_result = fetch_to_path(older_url, older_path, user_agent)
            submission_files.append({
                "cik": company["cik"],
                "cik10": company["cik10"],
                "sic_1531_company_name": company["sic_1531_company_name"],
                "file_role": "older_submissions_json",
                "source_url": older_url,
                "source_local_path": str(older_path),
                "status": older_result["status"],
                "http_status": older_result["http_status"],
                "downloaded_at_utc": older_result["downloaded_at_utc"],
                "bytes": older_result["bytes"],
                "checksum_sha256": sha256(older_path),
                "error": older_result["error"],
            })
            if older_result["status"] in {"downloaded", "already_present"} and older_path.exists():
                try:
                    older_json = read_json(older_path)
                    annual_filings.extend(row for row in filing_rows_from_json(older_json) if row["form"] in ANNUAL_FORMS)
                except json.JSONDecodeError as e:
                    submission_files[-1]["error"] = str(e)
            time.sleep(delay_seconds)

        annual_filing_dates = sorted(row["filing_date"] for row in annual_filings if row["filing_date"])
        annual_report_dates = sorted(row["report_date"] for row in annual_filings if row["report_date"])
        forms_observed = sorted(set(row["form"] for row in annual_filings if row["form"]))
        company_rows.append({
            "cik": company["cik"],
            "cik10": company["cik10"],
            "sic_1531_company_name": company["sic_1531_company_name"],
            "sic_1531_state_country": company["sic_1531_state_country"],
            "sec_company_name": sec_name,
            "sec_sic": sec_sic,
            "sec_sic_description": sec_sic_description,
            "tickers": "|".join(tickers),
            "exchanges": "|".join(exchanges),
            "annual_10k_filing_count": len(annual_filings),
            "annual_forms_observed": "|".join(forms_observed),
            "first_annual_10k_filing_date": annual_filing_dates[0] if annual_filing_dates else "",
            "last_annual_10k_filing_date": annual_filing_dates[-1] if annual_filing_dates else "",
            "first_annual_10k_report_date": annual_report_dates[0] if annual_report_dates else "",
            "last_annual_10k_report_date": annual_report_dates[-1] if annual_report_dates else "",
            "main_submissions_local_path": str(main_path),
            "sec_company_url": f"https://www.sec.gov/cgi-bin/browse-edgar?action=getcompany&CIK={company['cik10']}&owner=include&count=100&hidefilings=0",
        })

    qc_rows = [
        {"check": "sic_1531_browse_pages", "status": "ok" if browse_pages else "fail", "value": len(browse_pages), "detail": ""},
        {"check": "sic_1531_companies", "status": "ok" if company_rows else "fail", "value": len(company_rows), "detail": ""},
        {"check": "sic_1531_companies_with_annual_10k", "status": "ok" if any(int(row["annual_10k_filing_count"]) > 0 for row in company_rows) else "warn", "value": sum(int(row["annual_10k_filing_count"]) > 0 for row in company_rows), "detail": ""},
        {"check": "submission_file_failures", "status": "ok" if not any(row["status"] not in {"downloaded", "already_present"} for row in submission_files) else "warn", "value": sum(row["status"] not in {"downloaded", "already_present"} for row in submission_files), "detail": ""},
    ]

    write_csv(
        Path("..") / "output" / "sec_sic_1531_companies.csv",
        company_rows,
        [
            "cik", "cik10", "sic_1531_company_name", "sic_1531_state_country",
            "sec_company_name", "sec_sic", "sec_sic_description", "tickers",
            "exchanges", "annual_10k_filing_count", "annual_forms_observed",
            "first_annual_10k_filing_date", "last_annual_10k_filing_date",
            "first_annual_10k_report_date", "last_annual_10k_report_date",
            "main_submissions_local_path", "sec_company_url",
        ],
    )
    write_csv(
        Path("..") / "output" / "sec_sic_1531_browse_pages.csv",
        browse_pages,
        [
            "source_id", "pull_date", "start", "source_url", "source_local_path",
            "status", "http_status", "downloaded_at_utc", "bytes",
            "company_rows", "checksum_sha256", "error",
        ],
    )
    write_csv(
        Path("..") / "output" / "sec_sic_1531_submission_files.csv",
        submission_files,
        [
            "cik", "cik10", "sic_1531_company_name", "file_role", "source_url",
            "source_local_path", "status", "http_status", "downloaded_at_utc",
            "bytes", "checksum_sha256", "error",
        ],
    )
    write_csv(Path("..") / "output" / "sec_sic_1531_qc.csv", qc_rows, ["check", "status", "value", "detail"])
    print("Wrote SEC SIC-1531 universe outputs to ../output")


if __name__ == "__main__":
    main()
