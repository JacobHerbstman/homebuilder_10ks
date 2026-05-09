#!/usr/bin/env python3

import csv
import json
import sys
import time
from pathlib import Path

sys.path.append(str(Path(__file__).resolve().parents[2] / "_lib"))
from sec_fetch_utils import fetch_to_path, require_sec_user_agent, sec_request_delay, sha256, write_csv


def read_filing_index():
    with Path("../input/sec_10k_filing_index.csv").open(newline="") as f:
        return list(csv.DictReader(f))


def accession_text_document(index_path, accession_number):
    if not Path(index_path).exists() or not accession_number:
        return ""

    try:
        index_json = json.loads(Path(index_path).read_text())
    except Exception:
        return ""

    items = index_json.get("directory", {}).get("item", [])
    names = [item.get("name", "") for item in items]
    accession_text_name = f"{accession_number}.txt"
    if accession_text_name in names:
        return accession_text_name

    text_names = [name for name in names if name.lower().endswith(".txt")]
    accession_prefix_matches = [
        name for name in text_names
        if name.startswith(accession_number) or name.startswith(accession_number.replace("-", ""))
    ]
    if accession_prefix_matches:
        return accession_prefix_matches[0]

    return ""


def main():
    user_agent = require_sec_user_agent()
    delay_seconds = sec_request_delay()
    rows = []

    for filing in read_filing_index():
        cik10 = filing.get("cik10", "")
        accession_no_dashes = filing.get("accession_number_no_dashes", "")
        cik_no_leading_zeros = filing.get("cik_no_leading_zeros", "")
        primary_document = filing.get("primary_document", "")

        if not cik10 or not accession_no_dashes or not cik_no_leading_zeros or not primary_document:
            continue

        source_local_dir = Path("..") / ".." / "fetch_sec_10k_filings" / "output" / "raw" / "sec_10k_filings" / cik10 / accession_no_dashes
        index_url = f"https://www.sec.gov/Archives/edgar/data/{cik_no_leading_zeros}/{accession_no_dashes}/index.json"
        filing_url = f"https://www.sec.gov/Archives/edgar/data/{cik_no_leading_zeros}/{accession_no_dashes}/{primary_document}"
        index_path = source_local_dir / "index.json"
        document_path = source_local_dir / primary_document

        index_result = fetch_to_path(index_url, index_path, user_agent)
        time.sleep(delay_seconds)
        document_result = fetch_to_path(filing_url, document_path, user_agent)
        time.sleep(delay_seconds)

        requested_primary_document = primary_document
        fallback_primary_document = ""
        if document_result["status"] not in {"downloaded", "already_present"}:
            fallback_primary_document = accession_text_document(index_path, filing.get("accession_number", ""))
            if fallback_primary_document and fallback_primary_document != primary_document:
                fallback_url = f"https://www.sec.gov/Archives/edgar/data/{cik_no_leading_zeros}/{accession_no_dashes}/{fallback_primary_document}"
                fallback_path = source_local_dir / fallback_primary_document
                fallback_result = fetch_to_path(fallback_url, fallback_path, user_agent)
                time.sleep(delay_seconds)
                if fallback_result["status"] in {"downloaded", "already_present"}:
                    primary_document = fallback_primary_document
                    filing_url = fallback_url
                    document_path = fallback_path
                    document_result = fallback_result

        rows.append({
            "builder_name_key": filing.get("builder_name_key", ""),
            "builder_name_clean": filing.get("builder_name_clean", ""),
            "ticker": filing.get("ticker", ""),
            "cik": filing.get("cik", ""),
            "cik10": cik10,
            "sec_company_name": filing.get("sec_company_name", ""),
            "accession_number": filing.get("accession_number", ""),
            "accession_number_no_dashes": accession_no_dashes,
            "form": filing.get("form", ""),
            "filing_date": filing.get("filing_date", ""),
            "report_date": filing.get("report_date", ""),
            "fiscal_year": filing.get("fiscal_year", ""),
            "requested_primary_document": requested_primary_document,
            "primary_document": primary_document,
            "fallback_primary_document": fallback_primary_document,
            "filing_url": filing_url,
            "directory_index_url": index_url,
            "directory_index_local_path": str(index_path),
            "primary_document_local_path": str(document_path),
            "directory_index_status": index_result["status"],
            "primary_document_status": document_result["status"],
            "directory_index_http_status": index_result["http_status"],
            "primary_document_http_status": document_result["http_status"],
            "download_timestamp_utc": document_result["downloaded_at_utc"],
            "directory_index_bytes": index_result["bytes"],
            "primary_document_bytes": document_result["bytes"],
            "directory_index_checksum_sha256": sha256(index_path),
            "primary_document_checksum_sha256": sha256(document_path),
            "directory_index_error": index_result["error"],
            "primary_document_error": document_result["error"],
        })

    failures = [
        row for row in rows
        if row["directory_index_status"] not in {"downloaded", "already_present"}
        or row["primary_document_status"] not in {"downloaded", "already_present"}
    ]
    if not failures:
        failures = [{
            "builder_name_key": "",
            "builder_name_clean": "",
            "ticker": "",
            "cik": "",
            "cik10": "",
            "sec_company_name": "",
            "accession_number": "",
            "accession_number_no_dashes": "",
            "form": "",
            "filing_date": "",
            "report_date": "",
            "fiscal_year": "",
            "requested_primary_document": "",
            "primary_document": "",
            "fallback_primary_document": "",
            "filing_url": "",
            "directory_index_url": "",
            "directory_index_local_path": "",
            "primary_document_local_path": "",
            "directory_index_status": "no_failures",
            "primary_document_status": "no_failures",
            "directory_index_http_status": "",
            "primary_document_http_status": "",
            "download_timestamp_utc": "",
            "directory_index_bytes": "",
            "primary_document_bytes": "",
            "directory_index_checksum_sha256": "",
            "primary_document_checksum_sha256": "",
            "directory_index_error": "",
            "primary_document_error": "",
        }]

    qc_rows = [
        {"check": "filings_requested", "status": "ok", "value": len(rows), "detail": ""},
        {"check": "primary_documents_downloaded_or_present", "status": "ok" if any(row["primary_document_status"] in {"downloaded", "already_present"} for row in rows) else "fail", "value": sum(row["primary_document_status"] in {"downloaded", "already_present"} for row in rows), "detail": ""},
        {"check": "filing_download_failures", "status": "ok" if len([r for r in failures if r["primary_document_status"] != "no_failures"]) == 0 else "warn", "value": len([r for r in failures if r["primary_document_status"] != "no_failures"]), "detail": ""},
    ]

    fieldnames = [
        "builder_name_key", "builder_name_clean", "ticker", "cik", "cik10", "sec_company_name",
        "accession_number", "accession_number_no_dashes", "form", "filing_date", "report_date",
        "fiscal_year", "requested_primary_document", "primary_document",
        "fallback_primary_document", "filing_url", "directory_index_url",
        "directory_index_local_path", "primary_document_local_path", "directory_index_status",
        "primary_document_status", "directory_index_http_status", "primary_document_http_status",
        "download_timestamp_utc", "directory_index_bytes", "primary_document_bytes",
        "directory_index_checksum_sha256", "primary_document_checksum_sha256",
        "directory_index_error", "primary_document_error"
    ]
    write_csv(Path("..") / "output" / "sec_10k_download_inventory.csv", rows, fieldnames)
    write_csv(Path("..") / "output" / "sec_10k_download_failures.csv", failures, fieldnames)
    write_csv(Path("..") / "output" / "sec_10k_download_qc.csv", qc_rows, ["check", "status", "value", "detail"])
    print("Wrote SEC 10-K download outputs to ../output")


if __name__ == "__main__":
    main()
