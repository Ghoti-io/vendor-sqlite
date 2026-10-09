/*
 * SPDX-License-Identifier: LGPL-3.0-only
 *
 * Copyright (C) 2026 Corey Pennycuff
 *
 * This file is part of Ghoti.io Vendor SQLite.
 *
 * Ghoti.io Vendor SQLite is free software: you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public License
 * version 3 as published by the Free Software Foundation.
 *
 * Ghoti.io Vendor SQLite is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser
 * General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

/**
 * @file sqlite_api.h
 * @brief Visibility of the SQLite amalgamation under -fvisibility=hidden.
 *
 * Forced in with -include so sqlite3.c and sqlite3.h stay the bytes from
 * the pinned zip. SQLITE_API is not a feature flag: the amalgamation is
 * still compiled with no SQLITE_OMIT_* and no extra SQLITE_ENABLE_*.
 */

#ifndef GHOTI_IO_VENDOR_SQLITE_API_H
#define GHOTI_IO_VENDOR_SQLITE_API_H

#if defined(_WIN32)
/* TODO(windows): dllexport has not been compiled or run. */
#  define SQLITE_API __declspec(dllexport)
#else
#  define SQLITE_API __attribute__((visibility("default")))
#endif

#endif /* GHOTI_IO_VENDOR_SQLITE_API_H */
