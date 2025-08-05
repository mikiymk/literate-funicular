const std = @import("std");
const Allocator = std.mem.Allocator;
const Map = std.HashMapUnmanaged;

const util = @import("../util.zig");
const debug = util.debug;

pub fn AutoSet(T: type) type {
    return Set(T, std.hash_map.AutoContext(T));
}

pub fn Set(T: type, Context: type) type {
    return struct {
        const SelfMap = Map(T, void, Context, std.hash_map.default_max_load_percentage);

        map: SelfMap,
        pub const empty = @This(){ .map = SelfMap.empty };

        pub fn deinit(self: *@This(), a: Allocator) void {
            self.map.deinit(a);
        }

        pub fn insert(self: *@This(), a: Allocator, value: T) Allocator.Error!void {
            try self.map.put(a, value, {});
        }

        pub fn contains(self: *@This(), value: T) bool {
            return self.map.contains(value);
        }

        pub fn delete(self: *@This(), value: T) void {
            _ = self.map.remove(value);
        }

        pub fn clear(self: *@This()) void {
            self.map.clearRetainingCapacity();
        }

        pub fn count(self: *@This()) usize {
            return self.map.count();
        }

        pub fn unions(self: *@This(), a: Allocator, other: @This()) !@This() {
            var result = @This(){ .map = SelfMap.empty };
            try result.map.ensureTotalCapacity(a, self.map.count() + other.map.count());
            {
                var key_iterator = self.map.keyIterator();
                while (key_iterator.next()) |key| {
                    _ = try result.map.put(a, key.*, {});
                }
            }
            {
                var key_iterator = other.map.keyIterator();
                while (key_iterator.next()) |key| {
                    _ = try result.map.put(a, key.*, {});
                }
            }
            return result;
        }

        pub fn intersection(self: *@This(), a: Allocator, other: @This()) !@This() {
            var result = @This(){ .map = SelfMap.empty };
            try result.map.ensureTotalCapacity(a, @min(self.map.count(), other.map.count()));
            var key_iterator = self.map.keyIterator();
            while (key_iterator.next()) |key| {
                if (other.map.contains(key.*)) {
                    _ = try result.map.put(a, key.*, {});
                }
            }
            return result;
        }

        pub fn difference(self: *@This(), a: Allocator, other: @This()) !@This() {
            var result = @This(){ .map = SelfMap.empty };
            try result.map.ensureTotalCapacity(a, self.map.count());
            var key_iterator = self.map.keyIterator();
            while (key_iterator.next()) |key| {
                if (!other.map.contains(key.*)) {
                    _ = try result.map.put(a, key.*, {});
                }
            }
            return result;
        }

        pub fn iterator(self: @This()) SelfMap.KeyIterator {
            return self.map.keyIterator();
        }

        pub fn format(self: @This(), _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
            var iter = self.map.keyIterator();
            try writer.writeAll("{");
            try util.printIterator(&iter, writer);
            try writer.writeAll("}");
        }
    };
}

test Set {
    const testing = std.testing;
    const allocator = testing.allocator;

    const S = Set(u32, struct {
        pub fn eql(self: @This(), a: u32, b: u32) bool {
            _ = self;
            return a == b;
        }

        pub fn hash(self: @This(), value: u32) u32 {
            _ = self;
            return value;
        }
    });

    var set = S.empty;
    defer set.deinit(allocator);

    try set.insert(allocator, 1);
    try set.insert(allocator, 2);
    try set.insert(allocator, 3);

    try testing.expect(set.contains(1));
    try testing.expect(set.contains(2));
    try testing.expect(set.contains(3));

    var set2 = S.empty;
    defer set2.deinit(allocator);

    try set2.insert(allocator, 2);
    try set2.insert(allocator, 3);
    try set2.insert(allocator, 4);

    var unions = try set.unions(allocator, set2);
    defer unions.deinit(allocator);

    try testing.expect(unions.contains(1));
    try testing.expect(unions.contains(2));
    try testing.expect(unions.contains(3));
    try testing.expect(unions.contains(4));
    try testing.expectEqual(unions.count(), 4);

    var intersection = try set.intersection(allocator, set2);
    defer intersection.deinit(allocator);

    try testing.expect(intersection.contains(2));
    try testing.expect(intersection.contains(3));
    try testing.expectEqual(intersection.count(), 2);

    var difference = try set.difference(allocator, set2);
    defer difference.deinit(allocator);

    try testing.expect(difference.contains(1));
    try testing.expectEqual(difference.count(), 1);
}
