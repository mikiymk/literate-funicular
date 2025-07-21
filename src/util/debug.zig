const std = @import("std");
const Allocator = std.mem.Allocator;

/// オンにした場合のみ、出力する。
pub var enabled = false;
var indent_tags: [10][]const u8 = undefined;
var indent_count: u8 = 0;

pub fn print(comptime fmt: []const u8, args: anytype) void {
    if (enabled) {
        for (0..indent_count) |_| {
            std.debug.print("  ", .{});
        }

        std.debug.print(fmt, args);
    }
}

pub fn begin(name: []const u8) void {
    if (enabled) {
        print("begin {s}\n", .{name});
        indent_tags[indent_count] = name;
        indent_count += 1;
    }
}

pub fn end(name: []const u8) void {
    if (enabled) {
        while (indent_count > 0) {
            const indent_name = indent_tags[indent_count];

            indent_count -= 1;
            print("end {s}\n", .{indent_name});
            if (std.mem.eql(u8, indent_name, name)) break;
        }
    }
}
