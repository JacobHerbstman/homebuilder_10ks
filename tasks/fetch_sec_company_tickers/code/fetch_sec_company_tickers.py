#!/usr/bin/env python3

import sys
from pathlib import Path

sys.path.append(str(Path(__file__).resolve().parents[2] / "_lib"))
from sec_fetch_utils import fetch_to_path, pull_date, require_sec_user_agent, sha256, write_csv


def main():
    user_agent = require_sec_user_agent()
    source_local_path = Path("..") / ".." / "fetch_sec_company_tickers" / "output" / "raw" / "sec_company_tickers" / pull_date() / "company_tickers.json"
    source_url = "https://www.sec.gov/files/company_tickers.json"
    result = fetch_to_path(source_url, source_local_path, user_agent)

    file_rows = [{
        "source_id": "sec_company_tickers",
        "pull_date": pull_date(),
        "source_url": source_url,
        "source_local_path": str(source_local_path),
        "status": result["status"],
        "http_status": result["http_status"],
        "downloaded_at_utc": result["downloaded_at_utc"],
        "bytes": result["bytes"],
        "error": result["error"],
    }]

    checksum_rows = [{
        "source_id": "sec_company_tickers",
        "pull_date": pull_date(),
        "source_local_path": str(source_local_path),
        "checksum_sha256": sha256(source_local_path),
    }]

    qc_rows = [{
        "check": "company_tickers_downloaded_or_present",
        "status": "ok" if result["status"] in {"downloaded", "already_present"} else "fail",
        "value": int(result["status"] in {"downloaded", "already_present"}),
        "detail": result["error"],
    }]

    write_csv(
        Path("..") / "output" / "sec_company_tickers_files.csv",
        file_rows,
        ["source_id", "pull_date", "source_url", "source_local_path", "status", "http_status", "downloaded_at_utc", "bytes", "error"],
    )
    write_csv(
        Path("..") / "output" / "sec_company_tickers_checksums.csv",
        checksum_rows,
        ["source_id", "pull_date", "source_local_path", "checksum_sha256"],
    )
    write_csv(
        Path("..") / "output" / "sec_company_tickers_qc.csv",
        qc_rows,
        ["check", "status", "value", "detail"],
    )
    print("Wrote SEC company ticker fetch outputs to ../output")


if __name__ == "__main__":
    main()
