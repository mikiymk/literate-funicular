const std = @import("std");
const Allocator = std.mem.Allocator;

pub var debug_enabled = false;
/// デバッグ出力をオンにした場合のみ、出力する。
pub fn debug(comptime fmt: []const u8, args: anytype) void {
    if (debug_enabled) {
        std.debug.print(fmt, args);
    }
}

fn ArrayFormat(T: type) type {
    return struct {
        array: std.ArrayListUnmanaged(T) = .empty,

        pub fn format(self: @This(), comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
            var follow = false;
            for (self.array.items) |item| {
                if (follow) {
                    try writer.print(", ", .{});
                }
                try writer.print("{}", .{item});
                follow = true;
            }
        }
    };
}

fn arrayFormat(comptime T: type, array: std.ArrayListUnmanaged(T)) ArrayFormat(T) {
    return .{ .array = array };
}

pub const Token = struct {
    value: []const u8,

    fn init(token_string: []const u8) Token {
        return .{ .value = token_string };
    }

    const TokenType = enum {
        number,
        function,
        operator,
        separator,
        parenthesis,
    };

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

    const Direction = enum { left, right };

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
    tokens: std.mem.SplitIterator(u8, .scalar),
    peeked_token: ?[]const u8 = null,

    pub fn init(source: []const u8) TokenReader {
        return .{
            .tokens = std.mem.splitScalar(u8, source, ' '),
        };
    }

    pub fn next(self: *TokenReader) ?Token {
        if (self.peeked_token) |peeked_token| {
            self.peeked_token = null;
            return Token.init(peeked_token);
        }
        const token = self.tokens.next() orelse return null;
        return Token.init(token);
    }

    pub fn peek(self: *TokenReader) ?Token {
        if (self.peeked_token) |peeked_token| {
            return Token.init(peeked_token);
        }
        const token = self.tokens.next() orelse return null;
        self.peeked_token = token;
        return Token.init(token);
    }
};

pub const OutputQueue = struct {
    array: std.ArrayListUnmanaged(Token) = .empty,

    pub fn deinit(self: *OutputQueue, allocator: Allocator) void {
        self.array.deinit(allocator);
    }

    pub fn push(self: *OutputQueue, allocator: Allocator, token: Token) Allocator.Error!void {
        debug("  output: {}\n", .{token});
        try self.array.append(allocator, token);
    }

    pub fn format(self: @This(), comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        return writer.print("{}", .{arrayFormat(Token, self.array)});
    }
};

pub const Stack = struct {
    array: std.ArrayListUnmanaged(Token) = .empty,

    pub fn deinit(self: *Stack, allocator: Allocator) void {
        self.array.deinit(allocator);
    }

    pub fn push(self: *Stack, allocator: Allocator, token: Token) !void {
        debug("  stack push: {} + {}\n", .{ self, token });
        try self.array.append(allocator, token);
    }

    pub fn pop(self: *Stack) ?Token {
        const token = self.array.pop();
        debug("  stack pop: {} - {?}\n", .{ self, token });
        return token;
    }

    pub fn get(self: Stack) ?Token {
        return self.array.getLastOrNull();
    }

    pub fn format(self: @This(), comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        return writer.print("{}", .{arrayFormat(Token, self.array)});
    }
};
