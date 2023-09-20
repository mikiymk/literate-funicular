const std = @import("std");
const get_args = @import("./args/get_args.zig");

const defs = @import("./defs.zig");
const error_zig = @import("./error.zig");

const Allocator = std.mem.Allocator;

test {
    std.testing.refAllDeclsRecursive(@This());
}

const String = []const u8;

// #include <sys/types.h>
// #include <fcntl.h>
// #include "paths.h"
// #include <stdlib.h>
// // #include <unistd.h>
// #include "defs.h"

var progname: [:0]const u8 = undefined;

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

fn usage(arg0: []const u8) void {
    const stderr = std.io.getStdErr();
    stderr.writer().print("usage: {s} [-dlrtv] [-b file_prefix] [-o output_file] [-p symbol_prefix] file\n", .{arg0}) catch unreachable;
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

const FileNames = struct {
    output_file_name: []const u8,
    code_file_name: []const u8,
    defines_file_name: ?[]const u8,
    verbose_file_name: ?[]const u8,
};

pub fn create_file_names(allocator: Allocator, args: *get_args.Args) !FileNames {
    var local_file_prefix = args.file_prefix orelse "y";

    var local_output_file_name: String = if (args.output_file) |output_file|
        output_file
    else
        std.fmt.allocPrint(
            allocator,
            "{s}{s}",
            .{ local_file_prefix, defs.OUTPUT_SUFFIX },
        ) catch {
            try error_zig.no_space();
        };

    var local_code_file_name: String = if (args.separate_code)
        std.fmt.allocPrint(
            allocator,
            "{s}{s}",
            .{ file_prefix, defs.CODE_SUFFIX },
        ) catch {
            try error_zig.no_space();
        }
    else
        local_output_file_name;

    var local_defines_file_name: ?[]const u8 = null;
    if (args.declare_file) {
        if (args.output_file != null) {
            // does the output_file_name have a known suffix
            // (suffix = strrchr(output_file_name, '.')) != 0
            var i = blk: {
                var i = local_output_file_name.len;
                while (0 < i) {
                    i -= 1;
                    const char = local_output_file_name[i];
                    if (char == '.') {
                        break :blk i;
                    }
                }
                break :blk local_output_file_name.len;
            };

            var local_output_file_name_without_extension = local_output_file_name[0..i];
            var local_output_file_extension = local_output_file_name[i..local_output_file_name.len];

            if ((std.mem.eql(u8, local_output_file_extension, ".c") or // good, old-fashioned C
                std.mem.eql(u8, local_output_file_extension, ".C") or // C++, or C on Windows
                std.mem.eql(u8, local_output_file_extension, ".cc") or // C++
                std.mem.eql(u8, local_output_file_extension, ".cxx") or // C++
                std.mem.eql(u8, local_output_file_extension, ".cpp")))
            { // C++ (Windows)
                const name_len = local_output_file_name_without_extension.len;
                var name = allocator.alloc(u8, name_len + 2) catch {
                    try error_zig.no_space();
                };
                @memcpy(name[0..name_len], local_output_file_name_without_extension);
                name[name_len] = '.';
                name[name_len + 1] = 'h';

                local_defines_file_name = name;
            } else {
                const stderr = std.io.getStdErr().writer();
                try stderr.print(
                    "{s}: suffix of output file name {?s} not recognized, no -d file generated.\n",
                    .{ args.program_name, local_output_file_name },
                );

                args.declare_file = false;
                local_defines_file_name = "";
            }
        } else {
            // asprintf(&defines_file_name, "%s%s", file_prefix, DEFINES_SUFFIX)
            local_defines_file_name = std.fmt.allocPrint(
                allocator,
                "{s}{s}",
                .{ local_file_prefix, defs.DEFINES_SUFFIX },
            ) catch {
                try error_zig.no_space();
            };
        }
    }

    var local_verbose_file_name: ?[]const u8 = if (args.verbose)
        std.fmt.allocPrint(allocator, "{s}{s}", .{ file_prefix, defs.VERBOSE_SUFFIX }) catch {
            try error_zig.no_space();
        }
    else
        null;

    std.debug.print("output file  = \"{s}\"\n", .{local_output_file_name});
    std.debug.print("code file    = \"{s}\"\n", .{local_code_file_name});
    if (local_defines_file_name) |name| {
        std.debug.print("defines file = \"{?s}\"\n", .{name});
    } else {
        std.debug.print("defines file = null\n", .{});
    }
    if (local_verbose_file_name) |name| {
        std.debug.print("verbose file = \"{?s}\"\n", .{name});
    } else {
        std.debug.print("verbose file = null\n", .{});
    }

    return .{
        .output_file_name = local_output_file_name,
        .code_file_name = local_code_file_name,
        .defines_file_name = local_defines_file_name,
        .verbose_file_name = local_verbose_file_name,
    };
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

pub fn open_files(allocator: Allocator, args: *get_args.Args) !void {
    _ = try create_file_names(allocator, args);

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

    var argv: [][:0]u8 = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, argv);
    var args = get_args.getargs(argv) catch |err| switch (err) {
        error.Usage => {
            usage(argv[0]);
            return err;
        },
        else => return err,
    };

    try open_files(allocator, &args);
    // reader();
    // lr0();
    // lalr();
    // make_parser();
    // verbose();
    // output();
    return;
}
