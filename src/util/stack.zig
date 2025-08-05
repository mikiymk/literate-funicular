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
            debug.printLn("スタック({s})に追加:", .{util.typeName(T)});
            debug.printLn("        {{{}}} + {}", .{ self, token });
            try self.array.append(a, token);
        }

        pub fn pop(self: *@This()) ?T {
            const token = self.array.pop();
            debug.printLn("スタック({s})から取り出し:", .{util.typeName(T)});
            debug.printLn("        {{{}}} - {?}", .{ self, token });
            return token;
        }

        pub fn get(self: @This()) ?T {
            return self.array.getLastOrNull();
        }

        pub fn format(self: @This(), comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
            try writer.writeAll("{");
            try util.printArray(T, self.array.items, writer);
            try writer.writeAll("}");
        }
    };
}
