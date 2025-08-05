const std = @import("std");
const Allocator = std.mem.Allocator;

const util = @import("../util.zig");
const debug = util.debug;

pub fn AutoMap(K: type, V: type) type {
    return Map(K, V, std.hash_map.AutoContext(K));
}

pub fn Map(K: type, V: type, Context: type) type {
    return struct {
        const SelfMap = std.HashMapUnmanaged(K, V, Context, std.hash_map.default_max_load_percentage);

        map: SelfMap,
        pub const empty = @This(){ .map = SelfMap.empty };

        pub fn deinit(self: *@This(), a: Allocator) void {
            self.map.deinit(a);
        }

        pub fn insert(self: *@This(), a: Allocator, key: K, value: V) Allocator.Error!void {
            try self.map.put(a, key, value);
        }

        pub fn get(self: @This(), key: K) ?V {
            return self.map.get(key);
        }

        pub fn contains(self: *@This(), key: K) bool {
            return self.map.contains(key);
        }

        pub fn delete(self: *@This(), key: K) void {
            _ = self.map.remove(key);
        }

        pub fn clear(self: *@This()) void {
            self.map.clearRetainingCapacity();
        }

        pub fn count(self: *@This()) usize {
            return self.map.count();
        }

        pub fn format(self: @This(), _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
            try writer.writeAll("{");
            var iterator = self.map.iterator();
            var follow = false;
            while (iterator.next()) |entry| {
                if (follow) {
                    try writer.print(", ", .{});
                }
                try writer.print("{}: {}", .{ entry.key_ptr.*, entry.value_ptr.* });
                follow = true;
            }
            try writer.writeAll("}");
        }
    };
}

test Map {
    const testing = std.testing;
    const allocator = testing.allocator;

    const M = Map(u32, f32, struct {
        pub fn eql(self: @This(), a: u32, b: u32) bool {
            _ = self;
            return a == b;
        }

        pub fn hash(self: @This(), value: u32) u32 {
            _ = self;
            return value;
        }
    });

    var map = M.empty;
    defer map.deinit(allocator);

    try map.insert(allocator, 1, 5.0);

    try testing.expect(map.contains(1));
    try testing.expectEqual(map.get(1), 5.0);
}
