#!/bin/sh
# Read or replace the pinned SQLite amalgamation.
#
#   check   Read the download page and compare its sqlite-amalgamation row
#           with sqlite-pin. Exit 0 when that row is not newer. Exit non-zero
#           when a newer amalgamation is listed, or when the page cannot be
#           fetched or parsed. Does not edit the tree, and a failure does not
#           claim the pin is current.
#   update  Download the amalgamation zip the page names, and replace
#           src/sqlite3.c, src/sqlite3.h and sqlite-pin only after the
#           published SHA3-256 matches. A mismatch leaves the tree unchanged.
#           Does not commit.
#   verify  Offline. Exit non-zero when src/sqlite3.c or src/sqlite3.h does
#           not match the hash in sqlite-pin. make test runs this. It does
#           not use the network.
#
# --page is a URL or a local file (the default is the live download page).
# --base is the prefix for a relative zip URL (the default is https://sqlite.org/).
# --root is the library directory (the default is this script's parent).
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
cd "$ROOT"
exec python3 - "$@" << 'PY'
import argparse
import hashlib
import os
import sys
import urllib.error
import urllib.request
import zipfile
from pathlib import Path

HEADER = "PRODUCT,VERSION,RELATIVE-URL,SIZE-IN-BYTES,SHA3-HASH"
PIN_KEYS = (
    "version",
    "version_number",
    "relative_url",
    "zip_sha3_256",
    "sqlite3.c",
    "sqlite3.h",
)


def die(message):
    print("sqlite-pin: " + message, file=sys.stderr)
    sys.exit(1)


def encode_version(text):
    parts = text.split(".")
    if len(parts) != 3:
        return None
    try:
        major, minor, patch = (int(part) for part in parts)
    except ValueError:
        return None
    if major < 0 or minor < 0 or patch < 0 or minor > 99 or patch > 99:
        return None
    return major * 1000000 + minor * 10000 + patch * 100


def sha3(data):
    return hashlib.sha3_256(data).hexdigest()


def load_pin(root):
    path = root / "sqlite-pin"
    if not path.is_file():
        die("no sqlite-pin under " + str(root))
    data = {}
    for line in path.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        if "=" not in line:
            die("sqlite-pin has a line that is not key=value")
        key, value = line.split("=", 1)
        data[key] = value
    for key in PIN_KEYS:
        if key not in data or data[key] == "":
            die("sqlite-pin is missing " + key)
    try:
        recorded = int(data["version_number"])
    except ValueError:
        die("sqlite-pin version_number is not an integer")
    encoded = encode_version(data["version"])
    if encoded is None or encoded != recorded:
        die("sqlite-pin version does not encode to version_number")
    return data


def save_pin(root, data):
    text = "".join(key + "=" + data[key] + "\n" for key in PIN_KEYS)
    path = root / "sqlite-pin"
    tmp = Path(str(path) + ".tmp")
    tmp.write_text(text)
    os.replace(tmp, path)


def fetch_bytes(source, timeout):
    if "://" not in source:
        path = Path(source)
        if not path.is_file():
            die("could not read " + source)
        return path.read_bytes()
    try:
        with urllib.request.urlopen(source, timeout=timeout) as response:
            return response.read()
    except (urllib.error.URLError, TimeoutError, OSError) as exc:
        die("could not fetch " + source + ": " + str(exc))


def page_text(source, timeout):
    path = Path(source)
    if path.is_file():
        return path.read_text(errors="replace")
    return fetch_bytes(source, timeout).decode("utf-8", errors="replace")


def amalgamation_row(html):
    start = 0
    while True:
        comment_at = html.find("<!--", start)
        if comment_at < 0:
            return None
        end = html.find("-->", comment_at)
        if end < 0:
            return None
        body = html[comment_at + 4:end]
        start = end + 3
        if HEADER not in body:
            continue
        rows = []
        seen_header = False
        for line in body.splitlines():
            line = line.strip()
            if not seen_header:
                if line == HEADER:
                    seen_header = True
                continue
            parts = line.split(",")
            if len(parts) != 5:
                continue
            relative = parts[2].strip()
            name = relative.rsplit("/", 1)[-1]
            if "snapshot" in relative or not name.startswith("sqlite-amalgamation-"):
                continue
            version = parts[1].strip()
            encoded = encode_version(version)
            digest = parts[4].strip().lower()
            if encoded is None or len(digest) != 64:
                continue
            rows.append({
                "version": version,
                "version_number": str(encoded),
                "relative_url": relative,
                "zip_sha3_256": digest,
            })
        if not rows:
            return None
        rows.sort(key=lambda row: int(row["version_number"]))
        return rows[-1]


def zip_url(base, relative):
    if "://" in relative:
        return relative
    return base.rstrip("/") + "/" + relative.lstrip("/")


def members(blob):
    try:
        archive = zipfile.ZipFile(__import__("io").BytesIO(blob))
    except zipfile.BadZipFile:
        die("downloaded bytes are not a zip")
    found = {}
    for info in archive.infolist():
        base = info.filename.rsplit("/", 1)[-1]
        if base in ("sqlite3.c", "sqlite3.h") and base not in found:
            found[base] = archive.read(info)
    if "sqlite3.c" not in found or "sqlite3.h" not in found:
        die("zip does not contain sqlite3.c and sqlite3.h")
    return found


def replace_tree(root, files, pin):
    paths = {
        "sqlite3.c": root / "src" / "sqlite3.c",
        "sqlite3.h": root / "src" / "sqlite3.h",
    }
    written = []
    for name, data in files.items():
        path = paths[name]
        tmp = Path(str(path) + ".tmp")
        tmp.write_bytes(data)
        written.append((tmp, path))
    pin_path = root / "sqlite-pin"
    pin_tmp = Path(str(pin_path) + ".tmp")
    pin_tmp.write_text("".join(key + "=" + pin[key] + "\n" for key in PIN_KEYS))
    written.append((pin_tmp, pin_path))
    for tmp, path in written:
        os.replace(tmp, path)


def verify(root):
    pin = load_pin(root)
    for name in ("sqlite3.c", "sqlite3.h"):
        path = root / "src" / name
        if not path.is_file():
            die("missing " + str(path))
        digest = sha3(path.read_bytes())
        if digest != pin[name].lower():
            die("hash mismatch for " + name)
    print("sqlite-pin: sqlite3.c and sqlite3.h match the pin")


def main():
    parser = argparse.ArgumentParser(add_help=True)
    parser.add_argument("command", choices=("check", "update", "verify"))
    parser.add_argument("--root", default=os.getcwd())
    parser.add_argument(
        "--page", default="https://www.sqlite.org/download.html")
    parser.add_argument("--base", default="https://sqlite.org/")
    parser.add_argument("--timeout", type=float, default=60)
    args = parser.parse_args()
    root = Path(args.root)
    if args.command == "verify":
        verify(root)
        return

    pin = load_pin(root)
    try:
        html = page_text(args.page, args.timeout)
    except SystemExit:
        raise
    row = amalgamation_row(html)
    if row is None:
        die("the download page has no sqlite-amalgamation row")
    published = int(row["version_number"])
    recorded = int(pin["version_number"])
    if published <= recorded:
        print(
            "sqlite-pin: amalgamation "
            + row["version"]
            + " matches the pin")
        return
    if args.command == "check":
        print("sqlite-pin: newer amalgamation " + row["version"])
        sys.exit(1)

    url = zip_url(args.base, row["relative_url"])
    blob = fetch_bytes(url, args.timeout)
    digest = sha3(blob)
    if digest != row["zip_sha3_256"]:
        die("SHA3-256 mismatch for " + url)
    files = members(blob)
    new_pin = {
        "version": row["version"],
        "version_number": row["version_number"],
        "relative_url": row["relative_url"],
        "zip_sha3_256": row["zip_sha3_256"],
        "sqlite3.c": sha3(files["sqlite3.c"]),
        "sqlite3.h": sha3(files["sqlite3.h"]),
    }
    replace_tree(root, files, new_pin)
    print("sqlite-pin: updated amalgamation to " + row["version"])


if __name__ == "__main__":
    main()
PY
