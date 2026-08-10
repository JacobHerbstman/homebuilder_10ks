#!/usr/bin/env python3

import csv
import json
import sys
import time
from pathlib import Path

sys.path.append(str(Path(__file__).resolve().parents[2] / "_lib"))
from sec_fetch_utils import fetch_to_path, require_sec_user_agent, sec_request_delay, sha256, write_csv


user_agent = require_sec_user_agent()
delay_seconds = sec_request_delay()

with Path("../input/tier1_2018_2025_sec_10q_filing_index.csv").open(newline="") as f:
    filing_index = list(csv.DictReader(f))

if not filing_index:
    raise SystemExit("Tier-1 SEC 10-Q filing index is empty.")

rows = []

for filing in filing_index:
    cik10 = filing["cik10"]
    cik_no_leading_zeros = filing["cik_no_leading_zeros"]
    accession_number = filing["accession_number"]
    accession_number_no_dashes = filing["accession_number_no_dashes"]
    primary_document = filing["primary_document"]
    source_local_dir = Path("../../fetch_tier1_sec_10q_filings/output/sec_10q_filings") / cik10 / accession_number_no_dashes
    directory_index_url = f"https://www.sec.gov/Archives/edgar/data/{cik_no_leading_zeros}/{accession_number_no_dashes}/index.json"
    filing_url = f"https://www.sec.gov/Archives/edgar/data/{cik_no_leading_zeros}/{accession_number_no_dashes}/{primary_document}"
    directory_index_local_path = source_local_dir / "index.json"
    source_local_path = source_local_dir / primary_document

    directory_index_result = fetch_to_path(directory_index_url, directory_index_local_path, user_agent)
    if directory_index_result["status"] != "already_present":
        time.sleep(delay_seconds)
    primary_document_result = fetch_to_path(filing_url, source_local_path, user_agent)
    if primary_document_result["status"] != "already_present":
        time.sleep(delay_seconds)

    requested_primary_document = primary_document
    fallback_primary_document = ""

    if primary_document_result["status"] not in {"downloaded", "already_present"} and directory_index_local_path.exists():
        try:
            directory_items = json.loads(directory_index_local_path.read_text()).get("directory", {}).get("item", [])
        except (json.JSONDecodeError, OSError):
            directory_items = []

        text_names = [item.get("name", "") for item in directory_items if item.get("name", "").lower().endswith(".txt")]
        fallback_candidates = [
            name for name in text_names
            if name == f"{accession_number}.txt"
            or name.startswith(accession_number)
            or name.startswith(accession_number_no_dashes)
        ]

        if fallback_candidates:
            fallback_primary_document = fallback_candidates[0]
            primary_document = fallback_primary_document
            filing_url = f"https://www.sec.gov/Archives/edgar/data/{cik_no_leading_zeros}/{accession_number_no_dashes}/{primary_document}"
            source_local_path = source_local_dir / primary_document
            primary_document_result = fetch_to_path(filing_url, source_local_path, user_agent)
            if primary_document_result["status"] != "already_present":
                time.sleep(delay_seconds)

    rows.append({
        **filing,
        "requested_primary_document": requested_primary_document,
        "downloaded_primary_document": primary_document,
        "fallback_primary_document": fallback_primary_document,
        "filing_url": filing_url,
        "directory_index_url": directory_index_url,
        "directory_index_local_path": str(directory_index_local_path),
        "source_local_path": str(source_local_path),
        "directory_index_status": directory_index_result["status"],
        "primary_document_status": primary_document_result["status"],
        "directory_index_http_status": directory_index_result["http_status"],
        "primary_document_http_status": primary_document_result["http_status"],
        "download_timestamp_utc": primary_document_result["downloaded_at_utc"],
        "directory_index_bytes": directory_index_result["bytes"],
        "primary_document_bytes": primary_document_result["bytes"],
        "directory_index_checksum_sha256": sha256(directory_index_local_path),
        "source_checksum_sha256": sha256(source_local_path),
        "directory_index_error": directory_index_result["error"],
        "primary_document_error": primary_document_result["error"],
    })

write_csv(
    Path("../output/tier1_2018_2025_sec_10q_download_inventory.csv"),
    rows,
    list(rows[0].keys()),
)

print("Wrote Tier-1 SEC 10-Q download inventory to ../output")
