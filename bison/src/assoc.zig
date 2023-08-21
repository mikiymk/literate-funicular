// Associativity information.

// Copyright (C) 2002, 2006, 2008-2015, 2018-2021 Free Software
// Foundation, Inc.

// This file is part of Bison, the GNU Compiler Compiler.

// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

const abort = @import("std").os.abort;

/// Associativity values for tokens and rules.
const Assoc = enum {
    undef_assoc, // Not defined.
    right_assoc, // %right
    left_assoc, // %left
    non_assoc, // %nonassoc
    precedence_assoc, // %precedence

    pub fn toString(a: Assoc) []const u8 {
        return switch (a) {
            .undef_assoc => "undefined associativity",
            .right_assoc => "%right",
            .left_assoc => "%left",
            .non_assoc => "%nonassoc",
            .precedence_assoc => "%precedence",
            else => {
                abort();
            },
        };
    }
};
