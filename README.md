# Ghoti.io Vendor SQLite

SQLite **3.53.4**, the official amalgamation, built as a suite library so more
than one library can link the same pin. The public API is `sqlite3_*`. There
is no `G` prefix and no wrapper.

Callers include `sqlite3.h` from the directory pkg-config reports:

```c
#include <sqlite3.h>
#include <stdio.h>

int main(void) {
  sqlite3 * db = NULL;
  if (sqlite3_open(":memory:", &db) != SQLITE_OK) {
    return 1;
  }
  printf("%s\n", sqlite3_libversion());
  sqlite3_close(db);
  return 0;
}
```

`sqlite3_libversion_number()` is `3530400`. `sqlite3_load_extension` is in
the binary and stays off until the caller enables it for one connection.
The amalgamation is compiled as the zip ships it: no `SQLITE_OMIT_*` and no
extra `SQLITE_ENABLE_*`.

## Building

```bash
make test PREFIX=/path/to/prefix
make install PREFIX=/path/to/prefix
cc -o show show.c $(pkg-config --cflags --libs ghoti.io-vendor-sqlite-0)
```

The module name ends in the major version, `-0`. A build made with
`make BRANCH=-dev` installs `ghoti.io-vendor-sqlite-dev` instead.

`make test` checks the pinned bytes against `sqlite-pin` and does not use
the network. `tools/sqlite-pin.sh check` reads
<https://www.sqlite.org/download.html> and exits non-zero when a newer
amalgamation is listed. `tools/sqlite-pin.sh update` replaces `src/sqlite3.c`,
`src/sqlite3.h` and `sqlite-pin` only after the published SHA3-256 matches.
Neither command commits.

## API

The header is upstream `sqlite3.h`. Its comments are the API. This library
adds no names of its own.

## Status

The committed amalgamation is SQLite 3.53.4
(`sqlite-amalgamation-3530400.zip`, SHA3-256
`628a44cfe82c66aed1ccbbe85a562d2e33ebe64b3288981ed76285612227934e`).
The files keep SQLite's public-domain header. The shell is not included.
