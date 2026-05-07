#!/usr/bin/env python3

import csv
import datetime as dt
import gzip
import hashlib
import os
import ssl
import time
import urllib.error
import urllib.request
import zlib
from pathlib import Path


def utc_now():
    return dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def sha256(path):
    if not path.exists():
        return ""

    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def decode_response(raw_bytes, encoding):
    if encoding == "gzip":
        return gzip.decompress(raw_bytes)
    if encoding == "deflate":
        try:
            return zlib.decompress(raw_bytes)
        except zlib.error:
            return zlib.decompress(raw_bytes, -zlib.MAX_WBITS)
    return raw_bytes


def verified_ssl_context():
    try:
        import certifi

        return ssl.create_default_context(cafile=certifi.where())
    except Exception:
        return ssl.create_default_context()


def fetch_url_once(url, user_agent):
    request = urllib.request.Request(
        url,
        headers={
            "User-Agent": user_agent,
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            "Accept-Encoding": "gzip, deflate",
            "Accept-Language": "en-US,en;q=0.9",
            "Connection": "close",
        },
    )

    try:
        with urllib.request.urlopen(request, timeout=45, context=verified_ssl_context()) as response:
            raw_bytes = response.read()
            encoding = response.headers.get("Content-Encoding", "").lower()
            body = decode_response(raw_bytes, encoding)
            return response.status, body, ""
    except urllib.error.HTTPError as e:
        body = e.read()
        encoding = e.headers.get("Content-Encoding", "").lower()
        try:
            body = decode_response(body, encoding)
        except Exception:
            pass
        return e.code, body, str(e)
    except Exception as e:
        return "", b"", str(e)


def fetch_url(url, user_agent):
    last_status = ""
    last_body = b""
    last_error = ""

    for attempt in range(3):
        last_status, last_body, last_error = fetch_url_once(url, user_agent)

        if last_status in {401, 403, 404}:
            return last_status, last_body, last_error
        if isinstance(last_status, int) and 200 <= last_status < 500:
            return last_status, last_body, last_error
        if attempt < 2:
            time.sleep(1.0 + attempt)

    return last_status, last_body, last_error


def write_csv(path, rows, fieldnames):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        for row in rows:
            writer.writerow(row)


def main():
    start_year = int(os.environ.get("BUILDER_START_YEAR", "2004"))
    end_year = int(os.environ.get("BUILDER_END_YEAR", str(max(2026, dt.date.today().year))))
    force = os.environ.get("BUILDER_FORCE", "0") == "1"
    pull_date = os.environ.get("BUILDER_PULL_DATE", dt.date.today().strftime("%Y%m%d"))
    user_agent = os.environ.get(
        "BUILDER_USER_AGENT",
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 "
        "(KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36",
    )

    rows = []
    checksum_rows = []
    qc_counts = {}

    for year in range(start_year, end_year + 1):
        for list_type, url in (
            ("top_100", f"https://www.builderonline.com/builder-100/builder-100-list/{year}/"),
            ("next_100", f"https://www.builderonline.com/builder-100/builder-100-list/{year}?next=true"),
        ):
            raw_path = Path("..") / ".." / ".." / "data_raw" / "builder_magazine_builder_100_lists" / pull_date / f"builder_100_{year}_{list_type}.html"
            raw_path.parent.mkdir(parents=True, exist_ok=True)
            downloaded_at_utc = utc_now()
            http_status = ""
            error = ""

            if raw_path.exists() and not force:
                status = "already_present"
                bytes_written = raw_path.stat().st_size
            else:
                http_status, body, error = fetch_url(url, user_agent)
                body_text_start = body[:2000].decode("utf-8", errors="ignore").lower()

                if http_status == 200 and "sorry, you have been blocked" not in body_text_start and "builder 100" in body_text_start:
                    temp_path = raw_path.with_suffix(raw_path.suffix + ".tmp")
                    temp_path.write_bytes(body)
                    temp_path.replace(raw_path)
                    status = "downloaded"
                    bytes_written = raw_path.stat().st_size
                elif http_status == 404:
                    status = "not_available"
                    bytes_written = 0
                    if raw_path.exists():
                        raw_path.unlink()
                elif http_status in {401, 403} or "sorry, you have been blocked" in body_text_start:
                    status = "blocked"
                    bytes_written = 0
                    if raw_path.exists():
                        raw_path.unlink()
                else:
                    status = "download_failed"
                    bytes_written = 0
                    if raw_path.exists():
                        raw_path.unlink()

                time.sleep(0.35)

            row = {
                "source_id": "builder_magazine_builder_100_lists",
                "pull_date": pull_date,
                "list_year": year,
                "list_type": list_type,
                "source_url": url,
                "raw_path": str(raw_path),
                "status": status,
                "http_status": http_status,
                "downloaded_at_utc": downloaded_at_utc,
                "bytes": bytes_written,
                "error": error,
            }
            rows.append(row)
            checksum_rows.append({
                "source_id": row["source_id"],
                "pull_date": pull_date,
                "list_year": year,
                "list_type": list_type,
                "raw_path": str(raw_path),
                "checksum_sha256": sha256(raw_path),
            })
            qc_counts[status] = qc_counts.get(status, 0) + 1

    qc_rows = [
        {
            "check": "requested_pages",
            "status": "ok",
            "value": len(rows),
            "detail": f"{start_year}-{end_year}, top_100 and next_100",
        },
        {
            "check": "downloaded_or_present_pages",
            "status": "ok" if sum(r["status"] in {"downloaded", "already_present"} for r in rows) > 0 else "fail",
            "value": sum(r["status"] in {"downloaded", "already_present"} for r in rows),
            "detail": "Pages available for downstream parsing",
        },
    ]

    for status_value in sorted(qc_counts):
        qc_rows.append({
            "check": f"fetch_status_{status_value}",
            "status": "ok" if status_value in {"downloaded", "already_present", "not_available"} else "warn",
            "value": qc_counts[status_value],
            "detail": "",
        })

    write_csv(
        Path("..") / "output" / "builder_magazine_html_files.csv",
        rows,
        ["source_id", "pull_date", "list_year", "list_type", "source_url", "raw_path", "status", "http_status", "downloaded_at_utc", "bytes", "error"],
    )
    write_csv(
        Path("..") / "output" / "builder_magazine_html_checksums.csv",
        checksum_rows,
        ["source_id", "pull_date", "list_year", "list_type", "raw_path", "checksum_sha256"],
    )
    write_csv(
        Path("..") / "output" / "builder_magazine_fetch_qc.csv",
        qc_rows,
        ["check", "status", "value", "detail"],
    )
    print("Wrote Builder Magazine fetch outputs to ../output")


if __name__ == "__main__":
    main()
