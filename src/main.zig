pub fn main() !void {
    parse() catch |err| {
        std.debug.print("Error: {}\n", .{err});
    };
}

fn parse() !void {
    try lib.callParse();
}

const std = @import("std");
const lib = @import("literate_funicular_lib");
