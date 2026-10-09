#!/bin/sh
# ./cloc.sh <lib> prints the by-extension row. The amalgamation is the
# generated .c and .h; the hand-written visibility header is the written
# .h src column.
set -eu
cloc=${1:?usage: test_cloc.sh <path-to-cloc.sh>}
out=$("$cloc" vendor-sqlite)
row=$(printf '%s\n' "$out" | awk '$1 == "vendor-sqlite" { print; found=1 } END { if (!found) exit 1 }') || {
  echo "test_cloc: no vendor-sqlite row" >&2
  printf '%s\n' "$out" >&2
  exit 1
}
field() {
  printf '%s\n' "$row" | awk -v n="$1" '{ gsub(/,/, "", $n); print $n }'
}
written_c=$(field 2)
written_h=$(field 3)
generated_c=$(field 6)
generated_h=$(field 7)
if [ "$written_c" -ne 0 ]; then
  echo "test_cloc: written .c is $written_c; the amalgamation was counted as written" >&2
  exit 1
fi
if [ "$written_h" -le 0 ] || [ "$written_h" -ge 500 ]; then
  echo "test_cloc: written .h src is $written_h, want the scaffold header" >&2
  exit 1
fi
if [ "$generated_c" -le 100000 ] || [ "$generated_h" -le 1000 ]; then
  echo "test_cloc: generated .c $generated_c .h $generated_h; amalgamation was not excluded" >&2
  exit 1
fi
echo "test_cloc: written .h $written_h generated .c $generated_c .h $generated_h"
