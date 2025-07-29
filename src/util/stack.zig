const std = @import("std");
const Allocator = std.mem.Allocator;

const util = @import("../util.zig");
const debug = util.debug;

pub fn Stack(T: type) type {
    return struct {
        array: std.ArrayListUnmanaged(T),

        pub const empty: @This() = .{ .array = .empty };

        pub fn deinit(self: *@This(), a: Allocator) void {
            self.array.deinit(a);
        }

        pub fn push(self: *@This(), a: Allocator, token: T) !void {
            debug.print("stack push: {} + {}", .{ self, token });
            try self.array.append(a, token);
        }

        pub fn pop(self: *@This()) ?T {
            const token = self.array.pop();
            debug.print("stack pop: {} - {?}", .{ self, token });
            return token;
        }

        pub fn get(self: @This()) ?T {
            return self.array.getLastOrNull();
        }

        pub fn format(self: @This(), comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
            return util.printArray(T, self.array.items, writer);
        }
    };
}
