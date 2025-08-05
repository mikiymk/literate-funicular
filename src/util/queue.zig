const std = @import("std");
const Allocator = std.mem.Allocator;

const util = @import("../util.zig");
const debug = util.debug;

pub fn Queue(T: type) type {
    return struct {
        buf: []T,
        head: usize,
        count: usize,

        pub const empty: @This() = .{
            .buf = &.{},
            .head = 0,
            .count = 0,
        };

        pub fn deinit(self: @This(), a: Allocator) void {
            a.free(self.buf);
        }

        pub fn enqueue(self: *@This(), a: Allocator, item: T) !void {
            debug.printLn("enqueue: {} + {}", .{ self, item });

            if (self.buf.len <= self.count) {
                try self.ensureCapacity(a);
            }

            self.buf[(self.head + self.count) & (self.buf.len - 1)] = item;
            self.count += 1;
        }

        pub fn dequeue(self: *@This()) ?T {
            if (self.count == 0) {
                debug.printLn("dequeue: {} - {?}", .{ self, null });
                return null;
            }

            const item = self.buf[self.head];
            self.discard();

            debug.printLn("dequeue: {} - {}", .{ self, item });
            return item;
        }

        pub fn peek(self: @This()) ?T {
            if (self.count == 0) return null;
            return self.buf[self.head];
        }

        pub fn format(self: @This(), comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
            try writer.writeAll("{");
            if (self.head + self.count <= self.buf.len) {
                try util.printArray(T, self.buf[self.head..(self.head + self.count)], writer);
            } else {
                try util.printArray(T, self.buf[self.head..], writer);
                try writer.print(", ", .{});
                try util.printArray(T, self.buf[0..(self.head + self.count - self.buf.len)], writer);
            }
            try writer.writeAll("}");
        }

        fn ensureCapacity(self: *@This(), a: Allocator) error{OutOfMemory}!void {
            self.realign();
            const size = std.math.add(usize, self.count, 1) catch return error.OutOfMemory;
            const new_size = std.math.ceilPowerOfTwo(usize, size) catch return error.OutOfMemory;
            self.buf = try a.realloc(self.buf, new_size);
        }

        fn realign(self: *@This()) void {
            if (self.buf.len - self.head >= self.count) {
                std.mem.copyForwards(T, self.buf[0..self.count], self.buf[self.head..][0..self.count]);
                self.head = 0;
            } else {
                var tmp: [4096 / 2 / @sizeOf(T)]T = undefined;

                while (self.head != 0) {
                    const n = @min(self.head, tmp.len);
                    const m = self.buf.len - n;
                    @memcpy(tmp[0..n], self.buf[0..n]);
                    std.mem.copyForwards(T, self.buf[0..m], self.buf[n..][0..m]);
                    @memcpy(self.buf[m..][0..n], tmp[0..n]);
                    self.head -= n;
                }
            }

            const unused = std.mem.sliceAsBytes(self.buf[self.count..]);
            @memset(unused, undefined);
        }

        fn discard(self: *@This()) void {
            const slice = self.readableSliceMut(0);
            if (slice.len >= 1) {
                const unused = std.mem.sliceAsBytes(slice[0..1]);
                @memset(unused, undefined);
            } else {
                const unused = std.mem.sliceAsBytes(slice[0..]);
                @memset(unused, undefined);
                const unused2 = std.mem.sliceAsBytes(self.readableSliceMut(slice.len)[0 .. 1 - slice.len]);
                @memset(unused2, undefined);
            }

            self.head = (self.head + 1) & (self.buf.len -% 1);
            self.count -= 1;
        }

        fn readableSliceMut(self: @This(), offset: usize) []T {
            if (offset > self.count) return &[_]T{};

            var start = self.head + offset;
            if (start >= self.buf.len) {
                start -= self.buf.len;
                return self.buf[start .. start + (self.count - offset)];
            } else {
                const end = @min(self.head + self.count, self.buf.len);
                return self.buf[start..end];
            }
        }
    };
}

test Queue {
    const testing = std.testing;
    const allocator = testing.allocator;

    var fifo: Queue(usize) = .empty;
    defer fifo.deinit(allocator);

    try fifo.enqueue(allocator, 0);
    try fifo.enqueue(allocator, 1);
    try testing.expectEqual(fifo.peek(), 0);
    try testing.expectEqual(fifo.dequeue(), 0);
    try testing.expectEqual(fifo.peek(), 1);
    try testing.expectEqual(fifo.dequeue(), 1);
}
