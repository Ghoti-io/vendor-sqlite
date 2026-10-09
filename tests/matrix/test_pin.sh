#!/bin/sh
# Matrix rows for the pin script: a newer amalgamation is reported and the
# tree is left alone; a hash mismatch leaves the tree alone; a matching
# hash replaces the files and the pin; a fetch or parse failure exits
# non-zero and does not claim the pin is current; a snapshot row is ignored.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
PIN=$ROOT/tools/sqlite-pin.sh

fail() {
  echo "test_pin: $1" >&2
  exit 1
}

assert_fail_silent() {
  # $1 is a label, the rest is the command. stdout+stderr must not claim
  # the pin is current, and the status must be non-zero.
  label=$1
  shift
  out=$("$@" 2>&1) && fail "$label exited 0: $out"
  case "$out" in
    *"matches the pin"*) fail "$label claimed the pin is current: $out" ;;
  esac
}

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/src" "$work/zips"
printf 'old-c' > "$work/src/sqlite3.c"
printf 'old-h' > "$work/src/sqlite3.h"
hash_of() {
  python3 -c 'import hashlib,sys; print(hashlib.sha3_256(open(sys.argv[1],"rb").read()).hexdigest())' "$1"
}
c_hash=$(hash_of "$work/src/sqlite3.c")
h_hash=$(hash_of "$work/src/sqlite3.h")
cat > "$work/sqlite-pin" << EOF
version=3.53.4
version_number=3530400
relative_url=2026/sqlite-amalgamation-3530400.zip
zip_sha3_256=628a44cfe82c66aed1ccbbe85a562d2e33ebe64b3288981ed76285612227934e
sqlite3.c=$c_hash
sqlite3.h=$h_hash
EOF

"$PIN" verify --root "$work" >/dev/null

printf 'changed' > "$work/src/sqlite3.c"
assert_fail_silent "verify mismatch" "$PIN" verify --root "$work"
printf 'old-c' > "$work/src/sqlite3.c"
"$PIN" verify --root "$work" >/dev/null

cat > "$work/newer.html" << 'EOF'
<html>
<!--
PRODUCT,VERSION,RELATIVE-URL,SIZE-IN-BYTES,SHA3-HASH
PRODUCT,9.9.9,snapshot/sqlite-snapshot-999.zip,1,aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
PRODUCT,3.53.5,2026/sqlite-amalgamation-3530500.zip,2,bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
-->
</html>
EOF
before=$(cat "$work/src/sqlite3.c")
out=$("$PIN" check --root "$work" --page "$work/newer.html" 2>&1) && fail "newer check exited 0: $out"
case "$out" in
  *3.53.5*) ;;
  *) fail "newer check did not name 3.53.5: $out" ;;
esac
after=$(cat "$work/src/sqlite3.c")
[ "$before" = "$after" ] || fail "check edited sqlite3.c"

cat > "$work/same.html" << 'EOF'
<html>
<!--
PRODUCT,VERSION,RELATIVE-URL,SIZE-IN-BYTES,SHA3-HASH
PRODUCT,9.9.9,snapshot/sqlite-snapshot-999.zip,1,aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
PRODUCT,3.53.4,2026/sqlite-amalgamation-3530400.zip,2,cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-->
</html>
EOF
"$PIN" check --root "$work" --page "$work/same.html" >/dev/null

cat > "$work/empty.html" << 'EOF'
<html><p>no table</p></html>
EOF
assert_fail_silent "parse failure" "$PIN" check --root "$work" --page "$work/empty.html"
assert_fail_silent "network failure" "$PIN" check --root "$work" \
  --page "http://127.0.0.1:1/download.html" --timeout 2

python3 - << PY
import hashlib, zipfile
from pathlib import Path
work = Path("$work")
blob_c = b"new-c"
blob_h = b"new-h"
zpath = work / "zips" / "sqlite-amalgamation-3530500.zip"
with zipfile.ZipFile(zpath, "w") as z:
    z.writestr("sqlite-amalgamation-3530500/sqlite3.c", blob_c)
    z.writestr("sqlite-amalgamation-3530500/sqlite3.h", blob_h)
    z.writestr("sqlite-amalgamation-3530500/shell.c", b"not-kept")
digest = hashlib.sha3_256(zpath.read_bytes()).hexdigest()
(work / "good-hash").write_text(digest)
PY
good=$(cat "$work/good-hash")
bad=$(printf '%s' "$good" | tr '0-9a-f' '1-9a-f0')

cat > "$work/bad-update.html" << EOF
<html>
<!--
PRODUCT,VERSION,RELATIVE-URL,SIZE-IN-BYTES,SHA3-HASH
PRODUCT,3.53.5,sqlite-amalgamation-3530500.zip,2,$bad
-->
</html>
EOF
assert_fail_silent "hash mismatch" "$PIN" update --root "$work" \
  --page "$work/bad-update.html" --base "file://$work/zips"
[ "$(cat "$work/src/sqlite3.c")" = "old-c" ] || fail "mismatch update edited sqlite3.c"
[ "$(cat "$work/sqlite-pin" | head -n 1)" = "version=3.53.4" ] || fail "mismatch update edited the pin"

cat > "$work/good-update.html" << EOF
<html>
<!--
PRODUCT,VERSION,RELATIVE-URL,SIZE-IN-BYTES,SHA3-HASH
PRODUCT,3.53.5,sqlite-amalgamation-3530500.zip,2,$good
-->
</html>
EOF
"$PIN" update --root "$work" --page "$work/good-update.html" --base "file://$work/zips" >/dev/null
[ "$(cat "$work/src/sqlite3.c")" = "new-c" ] || fail "update did not replace sqlite3.c"
[ "$(cat "$work/src/sqlite3.h")" = "new-h" ] || fail "update did not replace sqlite3.h"
grep -q '^version=3.53.5$' "$work/sqlite-pin" || fail "pin version was not replaced"
grep -q '^version_number=3530500$' "$work/sqlite-pin" || fail "pin number was not replaced"
"$PIN" verify --root "$work" >/dev/null
# shell.c from the zip is not kept
[ ! -e "$work/src/shell.c" ] || fail "update kept shell.c"

echo "test_pin: pass"
