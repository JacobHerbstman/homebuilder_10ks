import datetime as dt
import gzip
import hashlib
import json
import os
import ssl
import time
import urllib.error
import urllib.request
import zlib
from pathlib import Path


def utc_now():
    return dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def require_sec_user_agent():
    user_agent = os.environ.get("SEC_USER_AGENT", "").strip()
    if not user_agent:
        raise SystemExit("SEC_USER_AGENT must be set before running SEC fetch tasks.")
    return user_agent


def sec_request_delay():
    raw_value = os.environ.get("SEC_REQUESTS_PER_SECOND", "4")
    try:
        requests_per_second = float(raw_value)
    except ValueError:
        requests_per_second = 4.0
    requests_per_second = max(0.1, min(requests_per_second, 9.5))
    return 1.0 / requests_per_second


def force_download():
    return os.environ.get("SEC_FORCE", "0") == "1"


def pull_date():
    return os.environ.get("SEC_PULL_DATE", dt.date.today().strftime("%Y%m%d"))


def sha256(path):
    path = Path(path)
    if not path.exists():
        return ""

    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def verified_ssl_context():
    try:
        import certifi

        return ssl.create_default_context(cafile=certifi.where())
    except Exception:
        return ssl.create_default_context()


def decode_response(raw_bytes, encoding):
    if encoding == "gzip":
        return gzip.decompress(raw_bytes)
    if encoding == "deflate":
        try:
            return zlib.decompress(raw_bytes)
        except zlib.error:
            return zlib.decompress(raw_bytes, -zlib.MAX_WBITS)
    return raw_bytes


def fetch_url_once(url, user_agent):
    request = urllib.request.Request(
        url,
        headers={
            "User-Agent": user_agent,
            "Accept-Encoding": "gzip, deflate",
            "Accept": "application/json,text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            "Host": urllib.request.urlparse(url).netloc,
        },
    )

    try:
        with urllib.request.urlopen(request, timeout=60, context=verified_ssl_context()) as response:
            raw_bytes = response.read()
            encoding = response.headers.get("Content-Encoding", "").lower()
            return response.status, decode_response(raw_bytes, encoding), ""
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


def fetch_url(url, user_agent, delay_seconds=None):
    delay_seconds = sec_request_delay() if delay_seconds is None else delay_seconds
    last_status = ""
    last_body = b""
    last_error = ""

    for attempt in range(3):
        last_status, last_body, last_error = fetch_url_once(url, user_agent)
        if last_status in {401, 403, 404}:
            return last_status, last_body, last_error
        if isinstance(last_status, int) and 200 <= last_status < 500:
            return last_status, last_body, last_error
        time.sleep(delay_seconds * (attempt + 1))

    return last_status, last_body, last_error


def fetch_to_path(url, dest_path, user_agent):
    dest_path = Path(dest_path)
    dest_path.parent.mkdir(parents=True, exist_ok=True)

    if dest_path.exists() and not force_download():
        return {
            "status": "already_present",
            "http_status": "",
            "bytes": dest_path.stat().st_size,
            "error": "",
            "downloaded_at_utc": dt.datetime.fromtimestamp(
                dest_path.stat().st_mtime,
                dt.timezone.utc,
            ).strftime("%Y-%m-%dT%H:%M:%SZ"),
        }

    http_status, body, error = fetch_url(url, user_agent)
    if http_status == 200 and body:
        temp_path = dest_path.with_suffix(dest_path.suffix + ".tmp")
        temp_path.write_bytes(body)
        temp_path.replace(dest_path)
        return {
            "status": "downloaded",
            "http_status": http_status,
            "bytes": dest_path.stat().st_size,
            "error": "",
            "downloaded_at_utc": utc_now(),
        }

    return {
        "status": "not_available" if http_status == 404 else "download_failed",
        "http_status": http_status,
        "bytes": dest_path.stat().st_size if dest_path.exists() else 0,
        "error": error,
        "downloaded_at_utc": utc_now(),
    }


def write_csv(path, rows, fieldnames):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    import csv

    temp_path = path.with_suffix(path.suffix + ".tmp")
    with temp_path.open("w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        for row in rows:
            writer.writerow(row)

    if path.exists() and path.read_bytes() == temp_path.read_bytes():
        temp_path.unlink()
        path.touch()
    else:
        temp_path.replace(path)


def read_json(path):
    with Path(path).open("r", encoding="utf-8") as f:
        return json.load(f)
