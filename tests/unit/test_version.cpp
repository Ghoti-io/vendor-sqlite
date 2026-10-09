/**
 * @file
 * The amalgamation reports the pinned version, and load_extension is in
 * the binary and off until a caller enables it.
 */

#include <sqlite3.h>

#include <gtest/gtest.h>

#include <string>

TEST(Version, LibraryNumberIsThePin) {
  // The zip name sqlite-amalgamation-3530400 packs 3.53.4 as 3XXYY00.
  // sqlite3_libversion_number() is SQLITE_VERSION_NUMBER, which the header
  // defines as X*1000000 + Y*1000 + Z. For 3.53.4 that is 3053004.
  EXPECT_EQ(3053004, sqlite3_libversion_number());
  EXPECT_EQ(SQLITE_VERSION_NUMBER, sqlite3_libversion_number());
  EXPECT_STREQ("3.53.4", sqlite3_libversion());
}

TEST(LoadExtension, StaysOffUntilACallerEnablesIt) {
  sqlite3 * db = nullptr;
  ASSERT_EQ(SQLITE_OK, sqlite3_open(":memory:", &db));

  int enabled = 1;
  ASSERT_EQ(SQLITE_OK, sqlite3_db_config(
      db, SQLITE_DBCONFIG_ENABLE_LOAD_EXTENSION, -1, &enabled));
  EXPECT_EQ(0, enabled);

  char * error = nullptr;
  EXPECT_NE(SQLITE_OK, sqlite3_load_extension(db, "no-such-module", nullptr, &error));
  sqlite3_free(error);

  ASSERT_EQ(SQLITE_OK, sqlite3_enable_load_extension(db, 1));
  enabled = 0;
  ASSERT_EQ(SQLITE_OK, sqlite3_db_config(
      db, SQLITE_DBCONFIG_ENABLE_LOAD_EXTENSION, -1, &enabled));
  EXPECT_EQ(1, enabled);

  ASSERT_EQ(SQLITE_OK, sqlite3_enable_load_extension(db, 0));
  EXPECT_EQ(SQLITE_OK, sqlite3_close(db));
}

TEST(CompileOptions, ShipsNoOmitAndNoExtraEnable) {
  for (int i = 0;; i++) {
    const char * option = sqlite3_compileoption_get(i);
    if (option == nullptr) {
      break;
    }
    const std::string text(option);
    EXPECT_EQ(std::string::npos, text.find("OMIT_")) << text;
    EXPECT_EQ(std::string::npos, text.find("ENABLE_")) << text;
  }
}

int main(int argc, char ** argv) {
  ::testing::InitGoogleTest(&argc, argv);
  return RUN_ALL_TESTS();
}
