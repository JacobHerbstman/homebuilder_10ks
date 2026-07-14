#!/usr/bin/env python3

import csv
import json
import sys
import time
from pathlib import Path

sys.path.append(str(Path(__file__).resolve().parents[2] / "_lib"))
from sec_fetch_utils import fetch_to_path, read_json, require_sec_user_agent, sec_request_delay, sha256, write_csv


def read_crosswalk():
    with Path("../input/builder_sec_crosswalk.csv").open(newline="") as f:
        rows = list(csv.DictReader(f))

    out = []
    seen = set()
    for row in rows:
        cik10 = row.get("cik10", "")
        if row.get("sec_reporting_indicator") == "TRUE" and cik10 and row.get("public_parent_no_comparable_us_10k") != "TRUE":
            if cik10 not in seen:
                out.append(row)
                seen.add(cik10)
    return out


def main():
    user_agent = require_sec_user_agent()
    delay_seconds = sec_request_delay()
    rows = []
    crosswalk_rows = read_crosswalk()

    for firm in crosswalk_rows:
        cik10 = firm["cik10"]
        source_local_dir = Path("..") / ".." / "fetch_sec_submissions" / "output" / "raw" / "sec_submissions" / cik10
        main_name = f"CIK{cik10}.json"
        main_url = f"https://data.sec.gov/submissions/{main_name}"
        main_path = source_local_dir / main_name
        result = fetch_to_path(main_url, main_path, user_agent)
        rows.append({
            "builder_name_key": firm["builder_name_key"],
            "builder_name_clean": firm["builder_name_clean"],
            "ticker": firm["ticker"],
            "cik10": cik10,
            "sec_company_name": firm["sec_company_name"],
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
        if result["status"] != "already_present":
            time.sleep(delay_seconds)

        if result["status"] not in {"downloaded", "already_present"} or not main_path.exists():
            continue

        try:
            main_json = read_json(main_path)
        except json.JSONDecodeError as e:
            rows[-1]["error"] = str(e)
            continue

        for older_file in main_json.get("filings", {}).get("files", []):
            name = older_file.get("name", "")
            if not name:
                continue
            older_url = f"https://data.sec.gov/submissions/{name}"
            older_path = source_local_dir / name
            older_result = fetch_to_path(older_url, older_path, user_agent)
            rows.append({
                "builder_name_key": firm["builder_name_key"],
                "builder_name_clean": firm["builder_name_clean"],
                "ticker": firm["ticker"],
                "cik10": cik10,
                "sec_company_name": firm["sec_company_name"],
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
            if older_result["status"] != "already_present":
                time.sleep(delay_seconds)

    failures = [row for row in rows if row["status"] not in {"downloaded", "already_present"}]
    if not failures:
        failures = [{
            "builder_name_key": "",
            "builder_name_clean": "",
            "ticker": "",
            "cik10": "",
            "sec_company_name": "",
            "file_role": "",
            "source_url": "",
            "source_local_path": "",
            "status": "no_failures",
            "http_status": "",
            "downloaded_at_utc": "",
            "bytes": "",
            "checksum_sha256": "",
            "error": "",
        }]

    qc_rows = [
        {"check": "sec_reporting_ciks_requested", "status": "ok", "value": len(crosswalk_rows), "detail": ""},
        {"check": "submission_files_downloaded_or_present", "status": "ok" if any(row["status"] in {"downloaded", "already_present"} for row in rows) else "fail", "value": sum(row["status"] in {"downloaded", "already_present"} for row in rows), "detail": ""},
        {"check": "submission_file_failures", "status": "ok" if len([r for r in failures if r["status"] != "no_failures"]) == 0 else "warn", "value": len([r for r in failures if r["status"] != "no_failures"]), "detail": ""},
    ]

    fieldnames = ["builder_name_key", "builder_name_clean", "ticker", "cik10", "sec_company_name", "file_role", "source_url", "source_local_path", "status", "http_status", "downloaded_at_utc", "bytes", "checksum_sha256", "error"]
    write_csv(Path("..") / "output" / "sec_submissions_files.csv", rows, fieldnames)
    write_csv(Path("..") / "output" / "sec_submissions_failures.csv", failures, fieldnames)
    write_csv(Path("..") / "output" / "sec_submissions_qc.csv", qc_rows, ["check", "status", "value", "detail"])
    print("Wrote SEC submissions fetch outputs to ../output")


if __name__ == "__main__":
    main()
