const std = @import("std");

// machine-dependent definitions
// the following definitions are for the Tahoe
// they might have to be changed for other

// MAXCHAR is the largest unsigned character
// MAXSHORT is the largest value of a C short
// MINSHORT is the most negative value of a C
// MAXTABLE is the maximum table size
// BITS_PER_WORD is the number of bits in a C
// WORDSIZE computes the number of words needed
//  n bits
// BIT returns the value of the n-th bit
//  r (0-indexed)
// SETBIT sets the n-th bit starting from r

const MAXCHAR = 255;
const MAXSHORT = 32767;
const MINSHORT = 32768;
const MAXTABLE = 32500;
const BITS_PER_WORD = 32;

fn WORDSIZE(n: anytype) @TypeOf(n) {
    return (n + (BITS_PER_WORD - 1)) / BITS_PER_WORD;
}

fn BIT(r: anytype, n: @TypeOf(r)) @TypeOf(r) {
    return ((r[n >> 5]) >> (n & 31)) & 1;
}

fn SETBIT(r: anytype, n: anytype) void {
    r[n >> 5] |= @as(u32, 1) << (n & 31);
}

// character names

const NUL = '\x00'; // the null character
const NEWLINE = '\n'; // line feed
const SP = ' '; // space
const BS = '\x08'; // backspace
const HT = '\t'; // horizontal tab
const VT = '\x0b'; // vertical tab
const CR = '\r'; // carriage return
const FF = '\x0c'; // form feed
const QUOTE = '\''; // single quote
const DOUBLE_QUOTE = '\"'; // double quote
const BACKSLASH = '\\'; // backslash

// defines for constructing filenames

pub const CODE_SUFFIX = ".code.c";
const DEFINES_SUFFIX = ".tab.h";
pub const OUTPUT_SUFFIX = ".tab.c";
const VERBOSE_SUFFIX = ".output";

// keyword codes

const TOKEN = 0;
const LEFT = 1;
const RIGHT = 2;
const NONASSOC = 3;
const MARK = 4;
const TEXT = 5;
const TYPE = 6;
const START = 7;
const UNION = 8;
const IDENT = 9;
const EXPECT = 10;

// symbol classes

const UNKNOWN = 0;
const TERM = 1;
const NONTERM = 2;

// the undefined value

const UNDEFINED = (-1);

// action codes

const SHIFT = 1;
const REDUCE = 2;

// character macros

fn IS_IDENT(c: u8) bool {
    return std.ascii.isAlphanumeric(c) or (c) == '_' or (c) == '.' or (c) == '$';
}

fn NUMERIC_VALUE(c: u8) u8 {
    return ((c) - '0');
}

// symbol macros

fn ISTOKEN(s: comptime_int) bool {
    _ = s;
    // return ((s) < start_symbol);
}

fn ISVAR(s: comptime_int) bool {
    _ = s;
    // return ((s) >= start_symbol);
}

// storage allocation macros

// fn NEW(t) T {
//     return (allocate(sizeof(t)));
// }

// fn NEW2(n, t) T {
//     return (allocate((n) * sizeof(t)));
// }

/// the structure of a symbol table entry
const bucket = struct {
    link: *bucket,
    next: *bucket,
    name: *u8,
    tag: *u8,
    value: u16,
    index: u16,
    prec: u16,
    class: u8,
    assoc: u8,
};

/// the structure of the LR(0) state machine
const core = struct {
    next: *core,
    link: *core,
    number: u16,
    accessing_symbol: u16,
    nitems: u16,
    items: [1]u16,
};

/// the structure used to record shifts
const shifts = struct {
    next: *shifts,
    number: u16,
    nshifts: u16,
    shift: [1]u16,
};

/// the structure used to store reductions
const reductions = struct {
    next: *reductions,
    number: u16,
    nreds: u16,
    rules: [1]u16,
};

/// the structure used to represent parser actions
const action = struct {
    next: *action,
    symbol: u16,
    number: u16,
    prec: u16,
    action_code: u8,
    assoc: u8,
    suppressed: u8,
};

// global variables
