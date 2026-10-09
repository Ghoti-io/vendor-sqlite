# SQLite amalgamation

**Status:** shipped as the bytes of the pinned zip.

The library is the official amalgamation of SQLite 3.53.4, the version named
in the Defiant spine. `sqlite-pin` records the version, the version number
`3530400`, the relative URL on `https://sqlite.org/`, the zip's SHA3-256, and
the SHA3-256 of `src/sqlite3.c` and `src/sqlite3.h`.

`make test` runs `tools/sqlite-pin.sh verify`, which compares those two files
to the recorded hashes and does not touch the network. `tools/sqlite-pin.sh
check` reads the CSV comment on the download page whose header is
`PRODUCT,VERSION,RELATIVE-URL,SIZE-IN-BYTES,SHA3-HASH`, ignores the snapshot
row, and compares the `sqlite-amalgamation-` row. A newer version is printed
and the command exits non-zero. `update` downloads that zip and replaces the
two files and the pin only when the published SHA3-256 matches.

The compile is the zip's own: no `SQLITE_OMIT_*` and no extra
`SQLITE_ENABLE_*`. `src/sqlite_api.h` is included with `-include` so
`SQLITE_API` marks the public functions visible under `-fvisibility=hidden`.
That header is not part of the amalgamation. `-Wno-strict-aliasing` and
`-Wno-float-conversion` are on for `sqlite3.c` only, because the amalgamation
is not clean under those two warnings and is not edited.

`sqlite3ext.h` and `shell.c` are in the zip and are not in this tree.
