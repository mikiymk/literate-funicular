const std = @import("std");
const Allocator = std.mem.Allocator;

const util = @import("../util.zig");
const debug = util.debug;

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
        return util.printArray(Token, self.array.items, writer);
    }
};
