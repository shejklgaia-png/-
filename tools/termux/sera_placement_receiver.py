#!/data/data/com.termux/files/usr/bin/python
"""Loopback-only inbox for developer placement JSON; no Git or shell actions."""
import json
import math
import os
from pathlib import Path
import re
import tempfile
from http.server import BaseHTTPRequestHandler, HTTPServer

INBOX = Path.home() / ".sera_apk_placement.json"
MAX_BYTES = 512 * 1024
KEY = re.compile(r"^(?:base/facility/[A-Z_]+|nexus/(?:model|camera)/[A-Z_]+|labo/camera/[A-Z_]+|labo/model/[A-Z_]+/[A-Za-z0-9_/-]+)$")

def validate(data):
    if not isinstance(data, dict) or data.get("schema") != 1 or not isinstance(data.get("records"), dict):
        raise ValueError("schema")
    for key, record in data["records"].items():
        if not KEY.fullmatch(key) or not isinstance(record, dict):
            raise ValueError("record")
        stamp = record.get("updated_at")
        if type(stamp) not in (int, float) or not math.isfinite(stamp) or stamp <= 0:
            raise ValueError("timestamp")
    return data["records"]

def merge(*records):
    result = {}
    for source in records:
        for key, value in source.items():
            if key not in result or value["updated_at"] > result[key]["updated_at"]:
                result[key] = value
    return result

def read(path):
    if not path.exists():
        return {}
    return validate(json.loads(path.read_text(encoding="utf-8")))

def write(records):
    with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", dir=INBOX.parent, delete=False) as f:
        tmp = Path(f.name)
        try:
            json.dump({"schema": 1, "records": records}, f, allow_nan=False, sort_keys=True)
            f.flush()
            os.fsync(f.fileno())
        except Exception:
            tmp.unlink(missing_ok=True)
            raise
    try:
        tmp.replace(INBOX)
    finally:
        tmp.unlink(missing_ok=True)

class Handler(BaseHTTPRequestHandler):
    def setup(self):
        super().setup()
        self.connection.settimeout(8)

    def do_POST(self):
        if self.path != "/sera-placement/v1" or self.headers.get_content_type() != "application/json":
            self.send_error(404)
            return
        try:
            size = int(self.headers.get("Content-Length", "0"))
            if not 0 < size <= MAX_BYTES:
                raise ValueError("size")
            raw = self.rfile.read(size)
            if len(raw) != size:
                raise ValueError("incomplete")
            new = validate(json.loads(raw))
            if not new:
                raise ValueError("empty")
            existing = read(INBOX)
            combined = merge(existing, new)
            if combined != existing:
                write(combined)
        except (ValueError, TypeError, UnicodeError, OverflowError):
            self.send_error(400)
            return
        except OSError:
            self.send_error(503)
            return
        self.send_response(200)
        self.end_headers()
        self.wfile.write(b"stored")

if __name__ == "__main__":
    print("Placement receiver listening on 127.0.0.1:18743", flush=True)
    HTTPServer(("127.0.0.1", 18743), Handler).serve_forever()
