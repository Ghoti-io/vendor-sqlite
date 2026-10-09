#!/bin/sh
# A shared object that exports a name outside sqlite3_* fails the same
# gate the Makefile runs. One that exports only sqlite3_* passes.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
GATE=$ROOT/tools/check-sqlite-symbols.sh
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

cat > "$work/good.c" << 'EOF'
__attribute__((visibility("default"))) int sqlite3_libversion_number(void) { return 0; }
__attribute__((visibility("default"))) int sqlite3_load_extension(void) { return 0; }
EOF
cat > "$work/bad.c" << 'EOF'
__attribute__((visibility("default"))) int sqlite3_libversion_number(void) { return 0; }
__attribute__((visibility("default"))) int sqlite3_load_extension(void) { return 0; }
__attribute__((visibility("default"))) int not_sqlite(void) { return 0; }
EOF
cat > "$work/under.c" << 'EOF'
__attribute__((visibility("default"))) int sqlite3_libversion_number(void) { return 0; }
__attribute__((visibility("default"))) int sqlite3_load_extension(void) { return 0; }
__attribute__((visibility("default"))) int _not_sqlite(void) { return 0; }
EOF
cc -shared -fPIC -fvisibility=hidden -o "$work/good.so" "$work/good.c"
cc -shared -fPIC -fvisibility=hidden -o "$work/bad.so" "$work/bad.c"
cc -shared -fPIC -fvisibility=hidden -o "$work/under.so" "$work/under.c"

"$GATE" "$work/good.so" >/dev/null
if "$GATE" "$work/bad.so" >"$work/bad.out" 2>&1; then
  echo "test_symbols: bad export was accepted" >&2
  exit 1
fi
grep -q 'not_sqlite' "$work/bad.out" || {
  echo "test_symbols: failure did not name not_sqlite" >&2
  cat "$work/bad.out" >&2
  exit 1
}
if "$GATE" "$work/under.so" >"$work/under.out" 2>&1; then
  echo "test_symbols: underscore export was accepted" >&2
  exit 1
fi
grep -q '_not_sqlite' "$work/under.out" || {
  echo "test_symbols: failure did not name _not_sqlite" >&2
  cat "$work/under.out" >&2
  exit 1
}
echo "test_symbols: pass"
