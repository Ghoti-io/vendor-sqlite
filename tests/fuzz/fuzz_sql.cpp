/**
 * @file
 * libFuzzer harness: one in-memory connection, the input as SQL.
 *
 * Limits and a progress handler keep a single input from running away.
 * The harness does not enable load_extension.
 */

#include <sqlite3.h>

#include <cstddef>
#include <cstdint>
#include <cstdlib>
#include <cstring>

namespace {

int progress(void * count) {
  int * steps = static_cast<int *>(count);
  *steps += 1;
  return *steps > 40 ? 1 : 0;
}

} // namespace

extern "C" int LLVMFuzzerTestOneInput(const uint8_t * data, size_t size) {
  if (size > 65536) {
    return 0;
  }
  char * sql = static_cast<char *>(std::malloc(size + 1));
  if (sql == nullptr) {
    return 0;
  }
  if (size > 0) {
    std::memcpy(sql, data, size);
  }
  sql[size] = '\0';

  sqlite3 * db = nullptr;
  if (sqlite3_open(":memory:", &db) != SQLITE_OK) {
    std::free(sql);
    if (db != nullptr) {
      sqlite3_close(db);
    }
    return 0;
  }
  sqlite3_limit(db, SQLITE_LIMIT_LENGTH, 100000);
  sqlite3_limit(db, SQLITE_LIMIT_SQL_LENGTH, 8192);
  sqlite3_limit(db, SQLITE_LIMIT_COLUMN, 64);
  sqlite3_limit(db, SQLITE_LIMIT_EXPR_DEPTH, 32);
  sqlite3_limit(db, SQLITE_LIMIT_COMPOUND_SELECT, 8);
  sqlite3_limit(db, SQLITE_LIMIT_VDBE_OP, 25000);
  sqlite3_limit(db, SQLITE_LIMIT_FUNCTION_ARG, 8);
  sqlite3_hard_heap_limit64(8 * 1024 * 1024);
  int steps = 0;
  sqlite3_progress_handler(db, 1000, progress, &steps);
  char * error = nullptr;
  sqlite3_exec(db, sql, nullptr, nullptr, &error);
  sqlite3_free(error);
  sqlite3_close(db);
  std::free(sql);
  return 0;
}
