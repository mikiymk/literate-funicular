pub fn main() !void {
    parse() catch |err| {
        std.debug.print("Error: {}\n", .{err});
    };
}

const source = "1 + (2 + 3) / (4 * 5) ^ 6";
const expected = "(1 + ((2 + 3) / ((4 * 5) ^ 6)))";
const allocator = std.heap.page_allocator;

fn parse() !void {
    const debug = lib.utils.debug;
    debug.enabled = true;

    for (lib.parse_fns) |parse_fn| {
        debug.printLn("ソース: {s}", .{source});

        var result = try parse_fn(allocator, source);
        defer result.deinit(allocator);

        const result_string = try std.fmt.allocPrint(allocator, "{}", .{result});
        defer allocator.free(result_string);

        debug.printLn("ソース: {s}", .{source});
        debug.printLn("結果  : {s}", .{result_string});

        if (!std.mem.eql(u8, expected, result_string)) {
            return error.ParseError;
        }
    }
}

const std = @import("std");
const lib = @import("literate_funicular_lib");
