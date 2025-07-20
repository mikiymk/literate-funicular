const std = @import("std");
const Allocator = std.mem.Allocator;

pub const debug = struct {
    /// オンにした場合のみ、出力する。
    pub var enabled = false;
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
            indent_count += 1;
        }
    }

    pub fn end(name: []const u8) void {
        if (enabled) {
            indent_count -= 1;
            print("end {s}\n", .{name});
        }
    }
};

fn printArray(comptime T: type, array: std.ArrayListUnmanaged(T), writer: anytype) !void {
    var follow = false;
    for (array.items) |item| {
        if (follow) {
            try writer.print(", ", .{});
        }
        try writer.print("{}", .{item});
        follow = true;
    }
}

pub const Token = struct {
    value: []const u8,
    position: usize,

    const TokenType = enum {
        number,
        function,
        operator,
        separator,
        parenthesis,
    };

    const Direction = enum { left, right };

    fn init(token_string: []const u8, position: usize) Token {
        return .{
            .value = token_string,
            .position = position,
        };
    }

    pub fn tokenType(self: Token) TokenType {
        return switch (self.value[0]) {
            '0'...'9' => .number,
            'a'...'z' => .function,
            '+', '-', '*', '/', '^' => .operator,
            ',' => .separator,
            '(', ')' => .parenthesis,
            else => unreachable,
        };
    }

    pub fn precedence(self: Token) u8 {
        return switch (self.value[0]) {
            '+', '-' => 2,
            '*', '/' => 3,
            '^' => 4,
            else => unreachable,
        };
    }

    pub fn associative(self: Token) Direction {
        return switch (self.value[0]) {
            '+', '-', '*', '/' => .left,
            '^' => .right,
            else => unreachable,
        };
    }

    pub fn is(self: Token, token_string: []const u8) bool {
        return std.mem.eql(u8, self.value, token_string);
    }

    pub fn format(self: @This(), comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        switch (self.tokenType()) {
            .number, .function => try writer.print("{s}", .{self.value}),
            inline else => try writer.print("\"{s}\"", .{self.value}),
        }
    }
};

pub const TokenReader = struct {
    source: []const u8,
    index: usize = 0,

    pub fn init(source: []const u8) TokenReader {
        return .{ .source = source };
    }

    fn skipWhitespace(self: TokenReader) usize {
        var index = self.index;
        while (index < self.source.len) {
            switch (self.source[index]) {
                ' ', '\n', '\r', '\t' => index += 1,
                else => break,
            }
        }
        return index;
    }

    fn nextTokenLength(self: TokenReader) ?struct { usize, usize } {
        const index = self.skipWhitespace();
        if (self.source.len <= index) {
            return null;
        }

        const start = index;
        var end = index + 1;
        switch (self.source[start]) {
            '0'...'9' => while (end < self.source.len) {
                switch (self.source[end]) {
                    '0'...'9' => end += 1,
                    else => break,
                }
            },
            'a'...'z', 'A'...'Z', '_' => while (end < self.source.len) {
                switch (self.source[end]) {
                    'a'...'z', 'A'...'Z', '0'...'9', '_' => end += 1,
                    else => break,
                }
            },
            '+', '-', '*', '/', '^', ',', '(', ')' => {},
            else => unreachable,
        }

        return .{ start, end };
    }

    pub fn next(self: *TokenReader) ?Token {
        const start, const end = self.nextTokenLength() orelse return null;
        const token = Token.init(self.source[start..end], start);
        self.index = end;
        return token;
    }

    pub fn peek(self: TokenReader) ?Token {
        const start, const end = self.nextTokenLength() orelse return null;
        const token = Token.init(self.source[start..end], start);
        return token;
    }
};

pub const OutputQueue = struct {
    array: std.ArrayListUnmanaged(Token) = .empty,

    pub fn deinit(self: *OutputQueue, allocator: Allocator) void {
        self.array.deinit(allocator);
    }

    pub fn push(self: *OutputQueue, allocator: Allocator, token: Token) Allocator.Error!void {
        debug.print("output: {}\n", .{token});
        try self.array.append(allocator, token);
    }

    pub fn format(self: @This(), comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        return printArray(Token, self.array, writer);
    }
};

pub fn Stack(T: type) type {
    return struct {
        array: std.ArrayListUnmanaged(T),

        pub const empty: @This() = .{ .array = .empty };

        pub fn deinit(self: *@This(), allocator: Allocator) void {
            self.array.deinit(allocator);
        }

        pub fn push(self: *@This(), allocator: Allocator, token: T) !void {
            debug.print("stack push: {} + {}\n", .{ self, token });
            try self.array.append(allocator, token);
        }

        pub fn pop(self: *@This()) ?T {
            const token = self.array.pop();
            debug.print("stack pop: {} - {?}\n", .{ self, token });
            return token;
        }

        pub fn get(self: @This()) ?T {
            return self.array.getLastOrNull();
        }

        pub fn format(self: @This(), comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
            return printArray(T, self.array, writer);
        }
    };
}

pub fn Queue(comptime T: type) type {
    return struct {
        buf: []T,
        head: usize,
        count: usize,

        pub const empty: @This() = .{
            .buf = &.{},
            .head = 0,
            .count = 0,
        };

        pub fn deinit(self: @This(), allocator: Allocator) void {
            allocator.free(self.buf);
        }

        pub fn enqueue(self: *@This(), allocator: Allocator, item: T) !void {
            if (self.buf.len <= self.count) {
                try self.ensureCapacity(allocator);
            }

            self.buf[(self.head + self.count) & (self.buf.len - 1)] = item;
            self.count += 1;
        }

        pub fn dequeue(self: *@This()) ?T {
            if (self.count == 0) return null;
            const item = self.buf[self.head];
            self.discard();
            return item;
        }

        pub fn peek(self: @This()) ?T {
            if (self.count == 0) return null;
            return self.buf[self.head];
        }

        pub fn format(self: @This(), comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
            return printArray(T, self.array, writer);
        }

        fn ensureCapacity(self: *@This(), allocator: Allocator) error{OutOfMemory}!void {
            self.realign();
            const size = std.math.add(usize, self.count, 1) catch return error.OutOfMemory;
            const new_size = std.math.ceilPowerOfTwo(usize, size) catch return error.OutOfMemory;
            self.buf = try allocator.realloc(self.buf, new_size);
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
