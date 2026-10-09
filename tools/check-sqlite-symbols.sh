#!/bin/sh
# Fail unless every dynamic export is sqlite3_*, and the two names the pin
# requires are present: the version and load_extension (compiled in, and
# left disabled until a caller enables it).
set -eu
lib=${1:?usage: check-sqlite-symbols.sh <shared-object>}
if ! nm -D --defined-only "$lib" >/dev/null 2>&1; then
  echo "check-sqlite-symbols: nm failed on $lib" >&2
  exit 1
fi
# POSIX format puts the name in field 1 for every symbol type. An
# underscore name is an export, the same as any other.
names=$(nm -D --defined-only -P "$lib" | awk '{print $1}')
leaked=$(printf '%s\n' "$names" | grep -v '^sqlite3_' | grep -v '^$' || true)
if [ -n "$leaked" ]; then
  echo "check-sqlite-symbols: exported symbols outside sqlite3_:" >&2
  printf '%s\n' "$leaked" >&2
  exit 1
fi
missing=""
for need in sqlite3_libversion_number sqlite3_load_extension; do
  if ! printf '%s\n' "$names" | grep -qx "$need"; then
    missing="$missing $need"
  fi
done
if [ -n "$missing" ]; then
  echo "check-sqlite-symbols: missing required export(s):$missing" >&2
  exit 1
fi
echo "check-sqlite-symbols: exports are sqlite3_* only"
