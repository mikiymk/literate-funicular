const std = @import("std");
const Allocator = std.mem.Allocator;

pub const debug = @import("./util/debug.zig");
pub const Stack = @import("./util/stack.zig").Stack;
pub const Queue = @import("./util/queue.zig").Queue;

pub const Language1 = @import("./util/lang-1.zig");

pub fn printArray(comptime T: type, array: []const T, writer: anytype) !void {
    var follow = false;
    for (array) |item| {
        if (follow) {
            try writer.print(", ", .{});
        }
        try writer.print("{}", .{item});
        follow = true;
    }
}

pub fn typeName(T: type) []const u8 {
    const full_name = @typeName(T);
    if (std.mem.lastIndexOfScalar(u8, full_name, '.')) |index| {
        return full_name[index + 1 ..];
    } else {
        return full_name;
    }
}
