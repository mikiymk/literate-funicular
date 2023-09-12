const std = @import("std");
const getopt = @import("./getopt.zig");

const defs = @import("./defs.zig");
const error_zig = @import("./error.zig");

const Allocator = std.mem.Allocator;

// #include <sys/types.h>
// #include <fcntl.h>
// #include "paths.h"
// #include <stdlib.h>
// // #include <unistd.h>
// #include "defs.h"

var __progname: [:0]const u8 = undefined;

// char dflag;
var dflag = false;
// char lflag;
var lflag = false;
// char rflag;
var rflag = false;
// char tflag;
var tflag = false;
// char vflag;
var vflag = false;

// char *symbol_prefix;
var symbol_prefix: []const u8 = undefined;
// char *file_prefix = "y";
var file_prefix: []const u8 = "y";

// int lineno;
// int outline;

// int explicit_file_name;
var explicit_file_name = false;

// char *code_file_name;
pub var code_file_name: []const u8 = undefined;
// char *defines_file_name;
pub var defines_file_name: []const u8 = undefined;
// char *input_file_name = "";
pub var input_file_name: []const u8 = "";
// char *output_file_name;
var output_file_name: ?[]const u8 = null;
// char *verbose_file_name;
var verbose_file_name: ?[]const u8 = null;

// FILE *action_file;	/* a temp file, used to save actions associated    */
// 			/* with rules until the parser is written	   */
// FILE *code_file;	/* y.code.c (used when the -r option is specified) */
// FILE *defines_file;	/* y.tab.h					   */
// FILE *input_file;	/* the input file				   */
var input_file: std.fs.File = undefined;
// FILE *output_file;	/* y.tab.c					   */
// FILE *text_file;	/* a temp file, used to save text until all	   */
// 			/* symbols have been defined			   */
// FILE *union_file;	/* a temp file, used to save the union		   */
// 			/* definition until all symbol have been	   */
// 			/* defined					   */
// FILE *verbose_file;	/* y.output					   */

// int nitems;
// int nrules;
// int nsyms;
// int ntokens;
// int nvars;

// int start_symbol;
// char **symbol_name;
// short *symbol_value;
// short *symbol_prec;
// char *symbol_assoc;

// short *ritem;
// short *rlhs;
// short *rrhs;
// short *rprec;
// char *rassoc;
// short **derives;
// char *nullable;

// void usage(void);
// void getargs(int, char *[]);
// void create_file_names(void);
// void open_files(void);

// void
// usage(void)
// {
// 	fprintf(stderr, "usage: %s [-dlrtv] [-b file_prefix] [-o output_file] [-p symbol_prefix] file\n", __progname);
// 	exit(1);
// }
pub fn usage(arg0: [:0]const u8) !void {
    const stderr = std.io.getStdErr();
    stderr.writer().print("usage: {s} [-dlrtv] [-b file_prefix] [-o output_file] [-p symbol_prefix] file\n", .{arg0}) catch unreachable;

    return error.Usage;
}

pub fn getargs(argv: [][:0]const u8) !void {
    var iter = getopt.getopt(argv, "b:dlo:p:rtv");
    __progname = argv[0];

    while (iter.next() catch return usage(argv[0])) |ch| {
        switch (ch.opt) {
            'b' => file_prefix = ch.arg orelse continue,
            'd' => dflag = true,
            'l' => lflag = true,
            'o' => {
                output_file_name = ch.arg orelse continue;
                explicit_file_name = true;
            },
            'p' => symbol_prefix = ch.arg orelse continue,
            'r' => rflag = true,
            't' => tflag = true,
            'v' => vflag = true,
            else => try usage(argv[0]),
        }
    }

    var my_argv = argv[iter.optind..];

    if (my_argv.len != 1) {
        try usage(argv[0]);
    }

    if (std.mem.order(u8, my_argv[0], "-") == .eq) {
        input_file = std.io.getStdIn();
    } else {
        input_file_name = my_argv[0];
    }
}

// void *
// allocate(size_t n)
// {
// 	void *v;

// 	v = NULL;
// 	if (n) {
// 		v = calloc(1, n);
// 		if (!v)
// 			no_space();
// 	}
// 	return (v);
// }

pub fn create_file_names(allocator: Allocator) !void {
    if (output_file_name == null) {
        // asprintf(&output_file_name, "%s%s", file_prefix, OUTPUT_SUFFIX) == -1
        output_file_name = std.fmt.allocPrint(
            allocator,
            "{s}{s}",
            .{ file_prefix, defs.OUTPUT_SUFFIX },
        ) catch {
            try error_zig.no_space();
        };
    }

    if (rflag) {
        // asprintf(&code_file_name, "%s%s", file_prefix, CODE_SUFFIX) == -1
        code_file_name = std.fmt.allocPrint(
            allocator,
            "{s}{s}",
            .{ file_prefix, defs.CODE_SUFFIX },
        ) catch {
            try error_zig.no_space();
        };
    } else {
        code_file_name = output_file_name.?;
    }

    if (dflag) {
        if (explicit_file_name) {
            // defines_file_name = strdup(output_file_name);
            // if (defines_file_name == 0)
            //     no_space();
            defines_file_name = std.fmt.allocPrint(
                allocator,
                "{?s}",
                .{output_file_name},
            ) catch {
                try error_zig.no_space();
            };

            // does the output_file_name have a known suffix
            // (suffix = strrchr(output_file_name, '.')) != 0
            var suffix: ?[]const u8 = blk: {
                var i = output_file_name.?.len;
                while (0 <= i) {
                    i -= 1;
                    const char = output_file_name.?[i];
                    if (char == '.') {
                        break :blk output_file_name.?[i .. output_file_name.?.len - 1];
                    }
                }
                break :blk null;
            };

            if (if (suffix) |suffix_|
                (!std.mem.eql(u8, suffix_, ".c") or // good, old-fashioned C
                    !std.mem.eql(u8, suffix_, ".C") or // C++, or C on Windows
                    !std.mem.eql(u8, suffix_, ".cc") or // C++
                    !std.mem.eql(u8, suffix_, ".cxx") or // C++
                    !std.mem.eql(u8, suffix_, ".cpp"))
            else
                false)
            { // C++ (Windows)
                const defines_file_name_len = output_file_name.?.len - suffix.?.len + 2;

                var name = try allocator.alloc(u8, defines_file_name_len);
                @memcpy(name, output_file_name.?[0 .. output_file_name.?.len - suffix.?.len + 1]);
                name[output_file_name.?.len - suffix.?.len + 1] = 'h';
                name[output_file_name.?.len - suffix.?.len + 2] = '\x00';

                defines_file_name = name;
            } else {
                const stderr = std.io.getStdErr().writer();
                try stderr.print(
                    "{s}: suffix of output file name {?s} not recognized, no -d file generated.\n",
                    .{ __progname, output_file_name },
                );

                dflag = false;
                allocator.free(defines_file_name);
                defines_file_name = "";
            }
        } else {
            // asprintf(&defines_file_name, "%s%s", file_prefix, DEFINES_SUFFIX)
            defines_file_name = std.fmt.allocPrint(
                allocator,
                "{s}{s}",
                .{ file_prefix, defs.DEFINES_SUFFIX },
            ) catch {
                try error_zig.no_space();
            };
        }
    }

    if (vflag) {
        // asprintf(&verbose_file_name, "%s%s", file_prefix, VERBOSE_SUFFIX) == -1
        verbose_file_name = std.fmt.allocPrint(allocator, "{s}{s}", .{ file_prefix, defs.VERBOSE_SUFFIX }) catch {
            try error_zig.no_space();
        };
    }
}

// FILE *
// create_temp(void)
// {
// 	FILE *f;

// 	f = tmpfile();
// 	if (f == NULL)
// 		tempfile_error();
// 	return f;
// }

pub fn open_files(allocator: Allocator) !void {
    try create_file_names(allocator);

    // if (input_file == NULL) {
    //     input_file = fopen(input_file_name, "r");
    //     if (input_file == NULL)
    //         open_error(input_file_name);
    // }
    // action_file = create_temp();

    // text_file = create_temp();

    // if (vflag) {
    //     verbose_file = fopen(verbose_file_name, "w");
    //     if (verbose_file == NULL)
    //         open_error(verbose_file_name);
    // }
    // if (dflag) {
    //     defines_file = fopen(defines_file_name, "w");
    //     if (defines_file == NULL)
    //         open_write_error(defines_file_name);
    //     union_file = create_temp();
    // }
    // output_file = fopen(output_file_name, "w");
    // if (output_file == NULL)
    //     open_error(output_file_name);

    // if (rflag) {
    //     code_file = fopen(code_file_name, "w");
    //     if (code_file == NULL)
    //         open_error(code_file_name);
    // } else code_file = output_file;
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var argv: [][:0]const u8 = try std.process.argsAlloc(allocator);

    try getargs(argv);
    try open_files(allocator);
    // reader();
    // lr0();
    // lalr();
    // make_parser();
    // verbose();
    // output();
    return;
}
