SUITE := ghoti.io
PROJECT := vendor-sqlite

BUILD ?= release
MAJOR_VERSION := 0
MINOR_VERSION := 0.0
VERSION_MINOR_ONLY := $(word 1,$(subst ., ,$(MINOR_VERSION)))
VERSION_PATCH_ONLY := $(or $(word 2,$(subst ., ,$(MINOR_VERSION))),0)
VERSION := $(MAJOR_VERSION).$(MINOR_VERSION)

BRANCH ?= -$(MAJOR_VERSION)

ifeq ($(BRANCH),-$(MAJOR_VERSION))
VERSION_STRING := $(VERSION)
else
VERSION_STRING := $(VERSION)$(BRANCH)
endif

ifeq ($(BUILD),debug)
    override BRANCH := $(BRANCH)-debug
    override VERSION_STRING := $(VERSION_STRING)-debug
endif

# Tested before the platform rewrite below, so a command-line BUILD=debug and
# an environment BUILD=debug both select -O0. See CONVENTIONS.md section 6.
ifeq ($(BUILD),debug)
OPT_CFLAGS := -O0
else
OPT_CFLAGS := -O2
endif

BASE_NAME := lib$(SUITE)-$(PROJECT)$(BRANCH).so
LIBVER_SYMBOL := $(shell echo "ghotiio_$(PROJECT)$(BRANCH)" | sed 's/[.-]/_/g')
BASE_NAME_PREFIX := lib$(SUITE)-$(PROJECT)$(BRANCH)
SO_NAME := $(BASE_NAME).$(MAJOR_VERSION)
STATIC_TARGET := $(BASE_NAME_PREFIX).a

PKG_CONFIG_PATH_ENV := $(PKG_CONFIG_PATH)

UNAME_S := $(shell uname -s)

ifeq ($(UNAME_S), Linux)
	OS_NAME := Linux
	LIB_EXTENSION := so
	OS_SPECIFIC_CXX_FLAGS := -shared
	OS_SPECIFIC_LIBRARY_NAME_FLAG := -Wl,-soname,$(SO_NAME)
	TARGET := $(SO_NAME).$(MINOR_VERSION)
	EXE_EXTENSION :=
	PC_INSTALL_PATH := /usr/local/share/pkgconfig
	INCLUDE_INSTALL_PATH := /usr/local/include
	LIB_INSTALL_PATH := /usr/local/lib
	PC_INCLUDE_DIR := $(INCLUDE_INSTALL_PATH)/$(SUITE)/$(PROJECT)$(BRANCH)
	PC_LIB_DIR := $(LIB_INSTALL_PATH)/$(SUITE)
	override BUILD := linux/$(BUILD)

else ifeq ($(UNAME_S), Darwin)
	OS_NAME := Mac
	LIB_EXTENSION := dylib
	OS_SPECIFIC_CXX_FLAGS := -shared
	OS_SPECIFIC_LIBRARY_NAME_FLAG := -Wl,-install_name,$(BASE_NAME_PREFIX).dylib
	TARGET := $(BASE_NAME_PREFIX).dylib
	EXE_EXTENSION :=
	PC_INSTALL_PATH := /usr/local/share/pkgconfig
	INCLUDE_INSTALL_PATH := /usr/local/include
	LIB_INSTALL_PATH := /usr/local/lib
	PC_INCLUDE_DIR := $(INCLUDE_INSTALL_PATH)/$(SUITE)/$(PROJECT)$(BRANCH)
	PC_LIB_DIR := $(LIB_INSTALL_PATH)/$(SUITE)
	override BUILD := mac/$(BUILD)

# TODO(windows): this branch was copied from model and has not been run.
else ifeq ($(findstring MINGW32_NT,$(UNAME_S)),MINGW32_NT)
	OS_NAME := Windows
	LIB_EXTENSION := dll
	OS_SPECIFIC_CXX_FLAGS := -shared
	OS_SPECIFIC_LIBRARY_NAME_FLAG = -Wl,--out-implib,$(APP_DIR)/$(BASE_NAME_PREFIX).dll.a
	TARGET := $(BASE_NAME_PREFIX).dll
	EXE_EXTENSION := .exe
	PC_INSTALL_PATH := /mingw32/lib/pkgconfig
	INCLUDE_INSTALL_PATH := /mingw32/include
	LIB_INSTALL_PATH := /mingw32/lib
	BIN_INSTALL_PATH := /mingw32/bin
	PC_INCLUDE_DIR = $(shell cygpath -m $(INCLUDE_INSTALL_PATH)/$(SUITE)/$(PROJECT)$(BRANCH))
	PC_LIB_DIR = $(shell cygpath -m $(LIB_INSTALL_PATH)/$(SUITE))
	override BUILD := win32/$(BUILD)

# TODO(windows): this branch was copied from model and has not been run.
else ifeq ($(findstring MINGW64_NT,$(UNAME_S)),MINGW64_NT)
	OS_NAME := Windows
	LIB_EXTENSION := dll
	OS_SPECIFIC_CXX_FLAGS := -shared
	OS_SPECIFIC_LIBRARY_NAME_FLAG = -Wl,--out-implib,$(APP_DIR)/$(BASE_NAME_PREFIX).dll.a
	TARGET := $(BASE_NAME_PREFIX).dll
	EXE_EXTENSION := .exe
	PC_INSTALL_PATH := /mingw64/lib/pkgconfig
	INCLUDE_INSTALL_PATH := /mingw64/include
	LIB_INSTALL_PATH := /mingw64/lib
	BIN_INSTALL_PATH := /mingw64/bin
	PC_INCLUDE_DIR = $(shell cygpath -m $(INCLUDE_INSTALL_PATH)/$(SUITE)/$(PROJECT)$(BRANCH))
	PC_LIB_DIR = $(shell cygpath -m $(LIB_INSTALL_PATH)/$(SUITE))
	override BUILD := win64/$(BUILD)

else
    $(error Unsupported OS: $(UNAME_S))

endif

ifdef PREFIX
INCLUDE_INSTALL_PATH := $(PREFIX)/include
LIB_INSTALL_PATH := $(PREFIX)/lib
BIN_INSTALL_PATH := $(PREFIX)/bin
PC_INSTALL_PATH := $(PREFIX)/share/pkgconfig
ifeq ($(OS_NAME), Windows)
PC_INCLUDE_DIR = $(shell cygpath -m $(INCLUDE_INSTALL_PATH)/$(SUITE)/$(PROJECT)$(BRANCH))
PC_LIB_DIR = $(shell cygpath -m $(LIB_INSTALL_PATH)/$(SUITE))
else
PC_INCLUDE_DIR := $(INCLUDE_INSTALL_PATH)/$(SUITE)/$(PROJECT)$(BRANCH)
PC_LIB_DIR := $(LIB_INSTALL_PATH)/$(SUITE)
endif
LDCONF_INSTALL_PATH :=
endif

PKG_CONFIG_LOOKUP_PATH := $(if $(PKG_CONFIG_PATH_ENV),$(PKG_CONFIG_PATH_ENV):)$(PC_INSTALL_PATH)

CXX := g++
CXXFLAGS := -pedantic-errors -Wall -Wextra -Werror -Wno-error=unused-function -Wfatal-errors -std=c++20 -O1 -g $(EXTRA_CXXFLAGS)
CC := cc
CFLAGS := -pedantic-errors -Wall -Wextra -Werror -Wfloat-conversion -fstrict-aliasing -Wstrict-aliasing=1 -Wno-error=unused-function -Wfatal-errors -std=c17 $(OPT_CFLAGS) -g $(EXTRA_CFLAGS)

# SQLITE_API comes from src/sqlite_api.h, included on the command line so the
# amalgamation bytes stay the ones in the zip. These warning classes are
# off for this translation unit only: the amalgamation is not clean under
# them, and it is not edited. No SQLITE_OMIT_* and no SQLITE_ENABLE_*.
SQLITE_CFLAGS := -Wno-strict-aliasing -Wno-float-conversion -Wno-unused-but-set-variable -Wno-unused-parameter -include src/sqlite_api.h

LIB_CFLAGS := $(CFLAGS) -fvisibility=hidden $(SQLITE_CFLAGS) $(EXTRA_CFLAGS)
LDFLAGS := $(EXTRA_LDFLAGS)
ifeq ($(OS_NAME), Linux)
# TODO(windows): the Windows link line is not -pthread -ldl. See notes/suite/WINDOWS-TODO.md.
SQLITE_LIBS := -pthread -ldl -lm
else
SQLITE_LIBS :=
endif
LDFLAGS += $(SQLITE_LIBS)
ifdef PREFIX
LDFLAGS += -Wl,-rpath,$(LIB_INSTALL_PATH)/$(SUITE)
ifeq ($(OS_NAME), Windows)
export PATH := $(BIN_INSTALL_PATH):$(PATH)
endif
endif

BUILD_DIR := ./build/$(BUILD)
OBJ_DIR := $(BUILD_DIR)/objects
FLAGS_STAMP := $(OBJ_DIR)/.flags
APP_DIR := $(BUILD_DIR)/apps

ifeq ($(UNAME_S), Linux)
	LIB_CFLAGS += -fPIC
endif

# Callers of the uninstalled tree include sqlite3.h from src/. The installed
# header is the same file, and the .pc -I is the directory that holds it.
INCLUDE := -I src

# Objects are the amalgamation and nothing else.
SOURCES := src/sqlite3.c
LIBOBJECTS := $(patsubst src/%.c,$(OBJ_DIR)/%.o,$(SOURCES))

TESTFLAGS := $(shell PKG_CONFIG_PATH=$(PKG_CONFIG_LOOKUP_PATH) pkg-config --libs --cflags gtest)

# check-symbols rejects a non-sqlite3_ export. check-pin is the offline hash
# gate. check-matrix covers the download-page and symbol-leak rows without
# the network. The line count is a workspace command (./cloc.sh), not a
# gate here: a clone of this repository has no workspace cloc.sh. The
# upstream check is tools/sqlite-pin.sh check and is not in this list.
TEST_GATES ?= check-symbols check-pin check-matrix

VALGRIND_FLAGS := --leak-check=full --show-leak-kinds=definite,indirect,possible --track-origins=yes --error-exitcode=1 --suppressions=tests/valgrind.supp

TEST_HELPER_SRC := $(wildcard tests/test_helpers.cpp)
TEST_HELPER_OBJ := $(patsubst tests/%.cpp,$(OBJ_DIR)/tests/%.o,$(TEST_HELPER_SRC))

SQLITELIBRARY := -Wl,--whole-archive $(APP_DIR)/$(STATIC_TARGET) -Wl,--no-whole-archive $(SQLITE_LIBS)

TEST_PAIRS := $(shell find tests -type f -name 'test_*.cpp' 2>/dev/null | sort | grep -v test_helpers | while read f; do \
	echo "$$f|$$(basename "$$f" .cpp | sed 's/test_/test/; s/^test\([a-z]\)/test\U\1/')"; done)
TEST_SOURCES := $(foreach pair,$(TEST_PAIRS),$(word 1,$(subst |, ,$(pair))))
TEST_NAMES := $(foreach pair,$(TEST_PAIRS),$(word 2,$(subst |, ,$(pair))))
TEST_EXECUTABLES := $(addprefix $(APP_DIR)/,$(addsuffix $(EXE_EXTENSION),$(TEST_NAMES)))

EXAMPLE_SOURCES := $(shell find examples -type f -name '*.c' 2>/dev/null)
EXAMPLES := $(patsubst examples/%.c,$(APP_DIR)/examples/%$(EXE_EXTENSION),$(EXAMPLE_SOURCES))

all: $(APP_DIR)/$(TARGET) $(APP_DIR)/$(STATIC_TARGET) ## Build shared + static libraries

TEST_DEPFILES := $(foreach pair,$(TEST_PAIRS),$(OBJ_DIR)/tests/$(basename $(notdir $(word 1,$(subst |, ,$(pair))))).d)
DEPFILES := $(LIBOBJECTS:.o=.d) $(TEST_HELPER_OBJ:.o=.d) $(TEST_DEPFILES)
-include $(DEPFILES)

$(OBJ_DIR)/%.o: src/%.c $(FLAGS_STAMP)
	@printf "\n### Compiling $@ ###\n"
	@mkdir -p $(@D)
	$(CC) $(LIB_CFLAGS) $(INCLUDE) -c $< -MMD -MP -MF $(@:.o=.d) -o $@

$(APP_DIR)/$(TARGET): $(LIBOBJECTS)
	@printf "\n### Linking Vendor SQLite ###\n"
	@mkdir -p $(@D)
	$(CC) -shared -o $@ $^ $(LDFLAGS) $(OS_SPECIFIC_LIBRARY_NAME_FLAG)
ifeq ($(OS_NAME), Linux)
	@ln -f -s $(TARGET) $(APP_DIR)/$(SO_NAME)
	@ln -f -s $(SO_NAME) $(APP_DIR)/$(BASE_NAME)
endif

$(APP_DIR)/$(STATIC_TARGET): $(LIBOBJECTS)
	@printf "\n### Archiving Vendor SQLite ###\n"
	@mkdir -p $(@D)
	@rm -f $@
	ar rcs $@ $^

ifneq ($(TEST_HELPER_SRC),)
$(TEST_HELPER_OBJ): $(TEST_HELPER_SRC) $(FLAGS_STAMP)
	@mkdir -p $(@D)
	$(CXX) $(CXXFLAGS) $(INCLUDE) -c $< -MMD -MP -MF $(@:.o=.d) -o $@
endif

$(OBJ_DIR)/tests/%.o: tests/%.cpp $(FLAGS_STAMP)
	@mkdir -p $(@D)
	$(CXX) $(CXXFLAGS) $(INCLUDE) -c $< -MMD -MP -MF $(@:.o=.d) -o $@

$(OBJ_DIR)/tests/%.o: tests/unit/%.cpp $(FLAGS_STAMP)
	@mkdir -p $(@D)
	$(CXX) $(CXXFLAGS) $(INCLUDE) -c $< -MMD -MP -MF $(@:.o=.d) -o $@

define test-executable-rule
TEST_OBJ_$1 := $(OBJ_DIR)/tests/$(basename $(notdir $1)).o

$(APP_DIR)/$2$(EXE_EXTENSION): $$(TEST_OBJ_$1) $(TEST_HELPER_OBJ) \
		$(APP_DIR)/$(STATIC_TARGET) | $(APP_DIR)/$(TARGET)
	@printf "\n### Linking Test: $2 ###\n"
	@mkdir -p $$(@D)
	$(CXX) $(CXXFLAGS) -o $$@ $$(TEST_OBJ_$1) $(TEST_HELPER_OBJ) $(LDFLAGS) $(SQLITELIBRARY) $(TESTFLAGS)
endef

$(foreach pair,$(TEST_PAIRS),\
	$(eval $(call test-executable-rule,$(word 1,$(subst |, ,$(pair))),$(word 2,$(subst |, ,$(pair))))))

$(APP_DIR)/examples/%$(EXE_EXTENSION): examples/%.c $(APP_DIR)/$(STATIC_TARGET) \
		$(FLAGS_STAMP) | $(APP_DIR)/$(TARGET)
	@mkdir -p $(@D)
	$(CC) $(CFLAGS) $(INCLUDE) -o $@ $< $(LDFLAGS) $(SQLITELIBRARY)

.PHONY: clean cloc docs docs-pdf examples coverage check-symbols check-pin check-matrix
.PHONY: all install test test-quiet test-asan test-valgrind test-valgrind-quiet test-watch uninstall watch
.PHONY: all-debug install-debug test-debug test-valgrind-debug test-watch-debug uninstall-debug watch-debug
.PHONY: fuzz fuzz-clean

watch: ## Watch the file directory for changes and compile the target
	@while true; do \
		$(MAKE) --no-print-directory all; \
		printf "\033[0;32m\n# Waiting for changes..\n\033[0m\n"; \
		inotifywait -qre close_write,move,create,delete src include tests examples Makefile 2>/dev/null || exit 0; \
	done

test-watch: ## Watch the file directory for changes and run the unit tests
	@while true; do \
		$(MAKE) --no-print-directory test; \
		inotifywait -qre close_write,move,create,delete src include tests examples Makefile 2>/dev/null || exit 0; \
	done

examples: ## Build all examples
examples: $(APP_DIR)/$(TARGET) $(EXAMPLES)

TEST_LD_PATH := $(APP_DIR):$(LIB_INSTALL_PATH)/$(SUITE)

check-symbols: ## Fail if any exported symbol is outside sqlite3_*
check-symbols: $(APP_DIR)/$(TARGET)
ifeq ($(OS_NAME), Linux)
	@tools/check-sqlite-symbols.sh $(APP_DIR)/$(TARGET)
else
	@printf "check-symbols: skipped (Linux only)\n"
endif

check-pin: ## Fail if the amalgamation bytes do not match sqlite-pin
	@tools/sqlite-pin.sh verify

check-matrix: ## Pin-script and symbol-leak rows
	@tests/matrix/test_pin.sh
	@tests/matrix/test_symbols.sh

test: ## Make and run the unit tests
test: $(APP_DIR)/$(TARGET) $(TEST_EXECUTABLES) $(TEST_GATES)
	@for test_exe in $(TEST_EXECUTABLES); do \
		test_name=$$(basename $$test_exe $(EXE_EXTENSION)); \
		printf "\033[0;30;43m\n### Running %s tests ###\033[0m\n\n" "$$test_name"; \
		LD_LIBRARY_PATH="$(TEST_LD_PATH)" $$test_exe --gtest_brief=1 || exit 1; \
	done

test-quiet: ## Run tests with minimal output (one line per test suite)
test-quiet: $(APP_DIR)/$(TARGET) $(TEST_EXECUTABLES) $(TEST_GATES)
	@for test_exe in $(TEST_EXECUTABLES); do \
		LD_LIBRARY_PATH="$(TEST_LD_PATH)" $$test_exe --gtest_brief=1 >/dev/null || exit 1; \
	done

test-valgrind: ## Run all tests under valgrind (Linux only)
test-valgrind: $(APP_DIR)/$(TARGET) $(TEST_EXECUTABLES)
ifeq ($(OS_NAME), Linux)
	@for test_exe in $(TEST_EXECUTABLES); do \
		test_name=$$(basename $$test_exe $(EXE_EXTENSION)); \
		printf "\033[0;30;43m\n### Running %s tests under Valgrind ###\033[0m\n\n" "$$test_name"; \
		LD_LIBRARY_PATH="$(TEST_LD_PATH)" valgrind $(VALGRIND_FLAGS) $$test_exe --gtest_brief=1 || exit 1; \
	done
else
	@printf "Valgrind is only available on Linux\n" >&2
	@exit 1
endif

test-valgrind-quiet: ## Run tests under valgrind with minimal output (Linux only)
test-valgrind-quiet: test-valgrind

UBSAN_CHECKS := undefined,float-cast-overflow
ASAN_UBSAN_FLAGS := -fsanitize=address,$(UBSAN_CHECKS) -fno-sanitize-recover=$(UBSAN_CHECKS) -fno-omit-frame-pointer -g -O1
COV_BUILD_DIR := ./build/$(BUILD)-cov

ASAN_BUILD_DIR := ./build/$(BUILD)-asan
ASAN_OBJ_DIR := $(ASAN_BUILD_DIR)/objects
ASAN_FLAGS_STAMP := $(ASAN_OBJ_DIR)/.flags
ASAN_APP_DIR := $(ASAN_BUILD_DIR)/apps
ASAN_LIBOBJECTS := $(patsubst src/%.c,$(ASAN_OBJ_DIR)/%.o,$(SOURCES))
ASAN_DEPFILES := $(ASAN_LIBOBJECTS:.o=.d) \
    $(foreach pair,$(TEST_PAIRS),$(ASAN_OBJ_DIR)/tests/$(basename $(notdir $(word 1,$(subst |, ,$(pair))))).d)
-include $(ASAN_DEPFILES)
ASAN_TARGET := $(BASE_NAME_PREFIX)-asan.$(LIB_EXTENSION)

ASAN_CFLAGS := $(CFLAGS) -fvisibility=hidden $(ASAN_UBSAN_FLAGS) $(SQLITE_CFLAGS)
ASAN_CXXFLAGS := $(CXXFLAGS) $(ASAN_UBSAN_FLAGS)
ASAN_LDFLAGS := $(LDFLAGS) $(ASAN_UBSAN_FLAGS)
ifeq ($(UNAME_S), Linux)
	ASAN_CFLAGS += -fPIC
endif

$(ASAN_OBJ_DIR)/%.o: src/%.c $(ASAN_FLAGS_STAMP)
	@mkdir -p $(@D)
	$(CC) $(ASAN_CFLAGS) $(INCLUDE) -c $< -MMD -MP -MF $(@:.o=.d) -o $@

$(ASAN_APP_DIR)/$(ASAN_TARGET): $(ASAN_LIBOBJECTS)
	@mkdir -p $(@D)
	$(CC) $(ASAN_CXXFLAGS) -shared -o $@ $^ $(ASAN_LDFLAGS)

$(ASAN_OBJ_DIR)/tests/%.o: tests/unit/%.cpp $(ASAN_FLAGS_STAMP)
	@mkdir -p $(@D)
	$(CXX) $(ASAN_CXXFLAGS) $(INCLUDE) -c $< -MMD -MP -MF $(@:.o=.d) -o $@

define asan-test-executable-rule
ASAN_TEST_OBJ_$1 := $(ASAN_OBJ_DIR)/tests/$(basename $(notdir $1)).o

$(ASAN_APP_DIR)/$2$(EXE_EXTENSION): $$(ASAN_TEST_OBJ_$1) $(ASAN_APP_DIR)/$(ASAN_TARGET)
	@mkdir -p $$(@D)
	$(CXX) $(ASAN_CXXFLAGS) -o $$@ $$(ASAN_TEST_OBJ_$1) $(ASAN_LDFLAGS) -L $(ASAN_APP_DIR) -l$(SUITE)-$(PROJECT)$(BRANCH)-asan $(TESTFLAGS)
endef

$(foreach pair,$(TEST_PAIRS),\
	$(eval $(call asan-test-executable-rule,$(word 1,$(subst |, ,$(pair))),$(word 2,$(subst |, ,$(pair))))))

ASAN_TEST_EXECUTABLES := $(addprefix $(ASAN_APP_DIR)/,$(addsuffix $(EXE_EXTENSION),$(TEST_NAMES)))
ASAN_RUNTIME := $(shell $(CC) -print-file-name=libasan.so 2>/dev/null)

test-asan: ## Build with ASan+UBSan and run the test suite
test-asan: $(ASAN_TEST_EXECUTABLES)
	@for test_exe in $(ASAN_TEST_EXECUTABLES); do \
		test_name=$$(basename $$test_exe $(EXE_EXTENSION)); \
		printf "\033[0;30;43m\n### Running %s (ASan+UBSan) ###\033[0m\n\n" "$$test_name"; \
		LD_PRELOAD="$(ASAN_RUNTIME)$${LD_PRELOAD:+:$$LD_PRELOAD}" \
		LD_LIBRARY_PATH="$(ASAN_APP_DIR):$(LIB_INSTALL_PATH)/$(SUITE)" \
			$$test_exe --gtest_brief=1 || exit 1; \
	done
	@printf "\033[0;32m\nASan+UBSan suite clean.\033[0m\n"

FUZZ_CC ?= clang
FUZZ_CXX ?= clang++
FUZZ_CC_OK := $(shell which $(FUZZ_CC) 2>/dev/null)
FUZZ_SAN := -fsanitize=address,$(UBSAN_CHECKS) -fno-omit-frame-pointer -g -O1 -fstrict-aliasing
FUZZ_LIB_FLAGS := $(FUZZ_SAN) -fsanitize=fuzzer-no-link
FUZZ_BIN_FLAGS := $(FUZZ_SAN) -fsanitize=fuzzer
FUZZ_DIR := $(BUILD_DIR)/fuzz
FUZZ_OBJ_DIR := $(FUZZ_DIR)/objects
FUZZ_FLAGS_STAMP := $(FUZZ_OBJ_DIR)/.flags
FUZZ_APP_DIR := $(FUZZ_DIR)/apps
FUZZ_OBJECTS := $(patsubst src/%.c,$(FUZZ_OBJ_DIR)/%.o,$(SOURCES))
FUZZ_CORPUS := tests/fuzz/corpus
FUZZ_TIME ?= 60

$(FUZZ_OBJ_DIR)/%.o: src/%.c $(FUZZ_FLAGS_STAMP)
	@mkdir -p $(@D)
	@$(FUZZ_CC) $(FUZZ_LIB_FLAGS) -std=c17 -w $(SQLITE_CFLAGS) $(INCLUDE) -c $< -o $@

define fuzz-rule
fuzz-$2: ## Build the $2 fuzz harness (requires clang)
fuzz-$2: $$(FUZZ_APP_DIR)/$1

$$(FUZZ_APP_DIR)/$1: tests/fuzz/$1.cpp $$(FUZZ_OBJECTS) $$(FUZZ_FLAGS_STAMP)
	@if [ -z "$$(FUZZ_CC_OK)" ]; then \
		echo "fuzzing requires $$(FUZZ_CXX); install clang or set FUZZ_CC/FUZZ_CXX"; \
		exit 1; \
	fi
	@mkdir -p $$(@D) $$(FUZZ_CORPUS)/$2
	@printf "\n### Building fuzz harness: $1 ###\n"
	$$(FUZZ_CXX) $$(FUZZ_BIN_FLAGS) -std=c++20 -w $$(INCLUDE) \
		-o $$@ $$< $$(FUZZ_OBJECTS) $(SQLITE_LIBS)

fuzz-run-$2: ## Run the $2 fuzzer for $$(FUZZ_TIME) seconds
fuzz-run-$2: $$(FUZZ_APP_DIR)/$1
	@mkdir -p $$(FUZZ_CORPUS)/$2
	@printf "\n### Fuzzing $2 for $$(FUZZ_TIME)s ###\n"
	@$$(FUZZ_APP_DIR)/$1 $$(FUZZ_CORPUS)/$2 \
		-max_total_time=$$(FUZZ_TIME) -print_final_stats=1
endef

$(eval $(call fuzz-rule,fuzz_sql,sql))

fuzz: ## Build and run every fuzzer for $(FUZZ_TIME) seconds each
fuzz: fuzz-run-sql

fuzz-clean: ## Remove the fuzz build (keeps the corpus)
	-@rm -rf $(FUZZ_DIR)

LDCONF_INSTALL_PATH ?= /etc/ld.so.conf.d
PKGCONFIG_INSTALL_PATH ?= $(PC_INSTALL_PATH)

install: ## Install the library globally, requires sudo
install: all
	@mkdir -p $(LIB_INSTALL_PATH)/$(SUITE)
ifeq ($(OS_NAME), Linux)
	@cp $(APP_DIR)/$(TARGET) $(LIB_INSTALL_PATH)/$(SUITE)/
	@ln -f -s $(TARGET) $(LIB_INSTALL_PATH)/$(SUITE)/$(SO_NAME)
	@ln -f -s $(SO_NAME) $(LIB_INSTALL_PATH)/$(SUITE)/$(BASE_NAME)
	@if [ -n "$(LDCONF_INSTALL_PATH)" ]; then mkdir -p $(LDCONF_INSTALL_PATH); fi
	@if [ -n "$(LDCONF_INSTALL_PATH)" ]; then echo "$(LIB_INSTALL_PATH)/$(SUITE)" > $(LDCONF_INSTALL_PATH)/$(SUITE)-$(PROJECT)$(BRANCH).conf; fi
endif
ifeq ($(OS_NAME), Windows)
	@mkdir -p $(BIN_INSTALL_PATH) $(LIB_INSTALL_PATH)/$(SUITE)
	@cp $(APP_DIR)/$(TARGET).a $(LIB_INSTALL_PATH)/$(SUITE)/
	@cp $(APP_DIR)/$(TARGET) $(BIN_INSTALL_PATH)/
endif
	@rm -rf $(INCLUDE_INSTALL_PATH)/$(SUITE)/$(PROJECT)$(BRANCH)
	@mkdir -p $(INCLUDE_INSTALL_PATH)/$(SUITE)/$(PROJECT)$(BRANCH)
	@cp src/sqlite3.h $(INCLUDE_INSTALL_PATH)/$(SUITE)/$(PROJECT)$(BRANCH)/sqlite3.h
	@mkdir -p $(PKGCONFIG_INSTALL_PATH)
	@sed 's/(SUITE)/$(SUITE)/g; s/(PROJECT)/$(PROJECT)/g; s/(BRANCH)/$(BRANCH)/g; s/(VERSION)/$(VERSION)/g; s|(PC_LIB_DIR)|$(PC_LIB_DIR)|g; s|(PC_INCLUDE_DIR)|$(PC_INCLUDE_DIR)|g' \
		pkgconfig/$(SUITE)-$(PROJECT).pc > $(PKGCONFIG_INSTALL_PATH)/$(SUITE)-$(PROJECT)$(BRANCH).pc
ifeq ($(OS_NAME), Linux)
	@if [ -n "$(LDCONF_INSTALL_PATH)" ]; then ldconfig >> /dev/null 2>&1; fi
endif
	@echo "Ghoti.io $(PROJECT)$(BRANCH) installed"

uninstall: ## Delete the globally-installed files.  Requires sudo.
ifeq ($(OS_NAME), Linux)
	@rm -f $(LIB_INSTALL_PATH)/$(SUITE)/$(BASE_NAME)*
	@rm -f $(LDCONF_INSTALL_PATH)/$(SUITE)-$(PROJECT)$(BRANCH).conf
endif
ifeq ($(OS_NAME), Windows)
	@rm -f $(LIB_INSTALL_PATH)/$(SUITE)/$(TARGET).a
	@rm -f $(BIN_INSTALL_PATH)/$(TARGET)
endif
	@rm -rf $(INCLUDE_INSTALL_PATH)/$(SUITE)/$(PROJECT)$(BRANCH)
	@rm -f $(PKGCONFIG_INSTALL_PATH)/$(SUITE)-$(PROJECT)$(BRANCH).pc
	@rmdir --ignore-fail-on-non-empty $(INCLUDE_INSTALL_PATH)/$(SUITE)
	@rmdir --ignore-fail-on-non-empty $(LIB_INSTALL_PATH)/$(SUITE)
ifeq ($(OS_NAME), Linux)
	@if [ -n "$(LDCONF_INSTALL_PATH)" ]; then ldconfig >> /dev/null 2>&1; fi
endif
	@echo "Ghoti.io $(PROJECT)$(BRANCH) has been uninstalled"

debug: ## Build the project in DEBUG mode
	$(MAKE) all BUILD=debug

install-debug: ## Install the DEBUG library globally, requires sudo
	$(MAKE) install BUILD=debug

uninstall-debug: ## Delete the DEBUG globally-installed files.  Requires sudo.
	$(MAKE) uninstall BUILD=debug

test-debug: ## Make and run the Unit tests in DEBUG mode
	$(MAKE) test BUILD=debug

test-valgrind-debug: ## Run all tests under valgrind in DEBUG mode (Linux only)
	$(MAKE) test-valgrind BUILD=debug

watch-debug: ## Watch the file directory for changes and compile the target in DEBUG mode
	$(MAKE) watch BUILD=debug

test-watch-debug: ## Watch the file directory for changes and run the unit tests in DEBUG mode
	$(MAKE) test-watch BUILD=debug

docs: ## Generate the documentation in the ./docs subdirectory
	doxygen

docs-pdf: docs ## Generate the documentation as a pdf, at ./docs/(SUITE)-(PROJECT)(BRANCH).pdf
	cd ./docs/latex/ && $(MAKE)
	mv -f ./docs/latex/refman.pdf ./docs/$(SUITE)-$(PROJECT)$(BRANCH)-docs.pdf

cloc: ## Count the lines of code used in the project
	cloc src include tests Makefile

coverage: ## Build instrumented, run the tests, and report line coverage
	@rm -rf $(COV_BUILD_DIR)/objects/*.gcda \
		$(COV_BUILD_DIR)/objects/*/*.gcda 2> /dev/null || true
	@status=0; \
	$(MAKE) --no-print-directory test TEST_GATES='check-pin check-matrix' \
		BUILD_DIR=$(COV_BUILD_DIR) \
		EXTRA_CFLAGS="--coverage -O0" \
		EXTRA_LDFLAGS="--coverage" > /dev/null || status=$$?; \
	if [ $$status -eq 0 ]; then \
		tools/coverage.sh $(COV_BUILD_DIR)/objects || status=$$?; \
	else \
		printf "coverage: the instrumented test run failed; no report\n" >&2; \
	fi; \
	exit $$status

clean: ## Remove all contents of the build directories.
	-@rm -rf $(COV_BUILD_DIR)
	-@rm -rf $(OBJ_DIR)/*
	-@rm -rf $(APP_DIR)/*
	-@rm -rf $(ASAN_BUILD_DIR)
	-@rm -rf $(FUZZ_DIR)

help: ## Display this help
	@grep -E '^[ a-zA-Z_-]+:.*?## .*$$' Makefile | sort | sed 's/\([^:]*\):.*## \(.*\)/\1:\2/' | awk -F: '{printf "%-20s %s\n", $$1, $$2}' | sed "s/(SUITE)/$(SUITE)/g; s/(PROJECT)/$(PROJECT)/g; s/(BRANCH)/$(BRANCH)/g"

.PHONY: force-flags

$(FLAGS_STAMP): force-flags
	@mkdir -p $(@D)
	@printf '%s\n' '$(CC) $(CXX) $(LIB_CFLAGS) $(CFLAGS) $(CXXFLAGS) $(LDFLAGS) $(INCLUDE) $(SQLITELIBRARY) $(TESTFLAGS) $(OS_SPECIFIC_LIBRARY_NAME_FLAG)' > $@.new
	@cmp -s $@.new $@ 2>/dev/null && rm -f $@.new || mv -f $@.new $@

$(ASAN_FLAGS_STAMP): force-flags
	@mkdir -p $(@D)
	@printf '%s\n' '$(CC) $(CXX) $(ASAN_CFLAGS) $(ASAN_CXXFLAGS) $(ASAN_LDFLAGS) $(INCLUDE) $(TESTFLAGS)' > $@.new
	@cmp -s $@.new $@ 2>/dev/null && rm -f $@.new || mv -f $@.new $@

$(FUZZ_FLAGS_STAMP): force-flags
	@mkdir -p $(@D)
	@printf '%s\n' '$(FUZZ_CC) $(FUZZ_CXX) $(FUZZ_SAN) $(FUZZ_LIB_FLAGS) $(FUZZ_BIN_FLAGS) $(INCLUDE) $(SQLITE_CFLAGS) $(SQLITE_LIBS)' > $@.new
	@cmp -s $@.new $@ 2>/dev/null && rm -f $@.new || mv -f $@.new $@
