/**
 * @file
 * The amalgamation reports the pinned version, and load_extension is in
 * the binary and off until a caller enables it.
 */

#include <sqlite3.h>

#include <gtest/gtest.h>

#include <fstream>
#include <string>

#include <unistd.h>

// The test binary lives under build/, so walk up from it until sqlite-pin
// is found. That does not depend on the working directory.
static std::string PinVersion() {
  char buf[4096];
  const ssize_t n = ::readlink("/proc/self/exe", buf, sizeof(buf) - 1);
  if (n < 0) {
    return {};
  }
  std::string path(buf, static_cast<std::size_t>(n));
  for (int i = 0; i < 8; ++i) {
    const auto slash = path.find_last_of('/');
    if (slash == std::string::npos) {
      break;
    }
    path.erase(slash);
    std::ifstream in((path + "/sqlite-pin").c_str());
    if (!in) {
      continue;
    }
    std::string line;
    while (std::getline(in, line)) {
      if (!line.empty() && line.back() == '\r') {
        line.pop_back();
      }
      if (line.compare(0, 15, "version_number=") == 0) {
        continue;
      }
      if (line.compare(0, 8, "version=") == 0) {
        return line.substr(8);
      }
    }
    return {};
  }
  return {};
}

TEST(Version, LibraryNumberIsThePin) {
  EXPECT_EQ(SQLITE_VERSION_NUMBER, sqlite3_libversion_number());
  EXPECT_STREQ(SQLITE_VERSION, sqlite3_libversion());
  const std::string pinned = PinVersion();
  ASSERT_FALSE(pinned.empty());
  EXPECT_STREQ(pinned.c_str(), sqlite3_libversion());
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
