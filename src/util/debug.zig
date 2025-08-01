const std = @import("std");
const Allocator = std.mem.Allocator;

/// オンにした場合のみ、出力する。
pub var enabled = false;

const indent_max = 20;
var indent_tags: [indent_max][]const u8 = undefined;
var indent_count: u8 = 0;

pub fn indent() void {
    if (enabled) {
        for (0..indent_count) |_| {
            print("  ", .{});
        }
    }
}

pub fn print(comptime fmt: []const u8, args: anytype) void {
    if (enabled) {
        std.debug.print(fmt, args);
    }
}

pub fn printLn(comptime fmt: []const u8, args: anytype) void {
    if (enabled) {
        indent();
        print(fmt ++ "\n", args);
    }
}

pub fn begin(name: []const u8) void {
    if (enabled) {
        printLn("{s}", .{name});
        indent_tags[indent_count] = name;
        indent_count += 1;
    }
}

pub fn end(name: []const u8) void {
    if (enabled) {
        while (indent_count > 0) {
            const indent_name = indent_tags[indent_count - 1];

            indent_count -= 1;
            printLn("{s}", .{indent_name});
            if (std.mem.eql(u8, indent_name, name)) break;
        }
    }
}
