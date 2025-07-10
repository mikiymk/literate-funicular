const std = @import("std");

pub var debug_enabled = false;
const Allocator = std.mem.Allocator;

/// デバッグ出力をオンにした場合のみ、出力する。
fn debug(comptime fmt: []const u8, args: anytype) void {
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

    fn tokenType(self: Token) TokenType {
        return switch (self.value[0]) {
            '0'...'9' => .number,
            'a'...'z' => .function,
            '+', '-', '*', '/', '^' => .operator,
            ',' => .separator,
            '(', ')' => .parenthesis,
            else => unreachable,
        };
    }

    fn precedence(self: Token) u8 {
        return switch (self.value[0]) {
            '+', '-' => 2,
            '*', '/' => 3,
            '^' => 4,
            else => unreachable,
        };
    }

    const Direction = enum { left, right };

    fn associative(self: Token) Direction {
        return switch (self.value[0]) {
            '+', '-', '*', '/' => .left,
            '^' => .right,
            else => unreachable,
        };
    }

    fn is(self: Token, token_string: []const u8) bool {
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

    pub fn init(source: []const u8) TokenReader {
        return .{
            .tokens = std.mem.splitScalar(u8, source, ' '),
        };
    }

    fn read(self: *TokenReader) ?Token {
        const token = self.tokens.next() orelse return null;
        return Token.init(token);
    }
};

pub const OutputQueue = struct {
    array: std.ArrayListUnmanaged(Token) = .empty,

    pub fn deinit(self: *OutputQueue, allocator: Allocator) void {
        self.array.deinit(allocator);
    }

    fn push(self: *OutputQueue, allocator: Allocator, token: Token) !void {
        debug("  output: {}\n", .{token});
        try self.array.append(allocator, token);
    }

    pub fn format(self: @This(), comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        return writer.print("{}", .{arrayFormat(Token, self.array)});
    }
};

const Stack = struct {
    array: std.ArrayListUnmanaged(Token) = .empty,

    fn deinit(self: *Stack, allocator: Allocator) void {
        self.array.deinit(allocator);
    }

    fn push(self: *Stack, allocator: Allocator, token: Token) !void {
        debug("  stack push: {} + {}\n", .{ self, token });
        try self.array.append(allocator, token);
    }

    fn pop(self: *Stack) ?Token {
        const token = self.array.pop();
        debug("  stack pop: {} - {?}\n", .{ self, token });
        return token;
    }

    fn get(self: Stack) ?Token {
        return self.array.getLastOrNull();
    }

    pub fn format(self: @This(), comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        return writer.print("{}", .{arrayFormat(Token, self.array)});
    }
};

pub fn parse(allocator: Allocator, source: []const u8) !OutputQueue {
    var input = TokenReader.init(source);
    var output = OutputQueue{};
    var stack: Stack = .{};
    defer stack.deinit(allocator);

    debug("start parsing\n", .{});

    while (input.read()) |o1| {
        debug("read token: {}\n", .{o1});

        switch (o1.tokenType()) {
            .number => try output.push(allocator, o1),
            .function => try stack.push(allocator, o1),
            .operator => {
                while (true) {
                    const o2 = stack.get() orelse break;
                    if (o2.tokenType() != .operator) break;
                    const o1_p = o1.precedence();
                    const o2_p = o2.precedence();
                    if (o1_p < o2_p or (o1_p == o2_p and o1.associative() == .left)) {
                        _ = stack.pop();
                        try output.push(allocator, o2);
                    } else {
                        break;
                    }
                }
                try stack.push(allocator, o1);
            },
            .separator => {
                while (true) {
                    const stack_top = stack.get() orelse return error.InvalidSyntax;
                    if (stack_top.is("(")) break;
                    _ = stack.pop();
                    try output.push(allocator, stack_top);
                }
            },
            .parenthesis => {
                if (o1.is("(")) {
                    try stack.push(allocator, o1);
                    continue;
                }
                // )
                while (true) {
                    const stack_top = stack.get() orelse return error.InvalidSyntax;
                    if (!stack_top.is("(")) {
                        _ = stack.pop();
                        try output.push(allocator, stack_top);
                    } else {
                        _ = stack.pop();
                        break;
                    }
                }

                if (stack.get()) |stack_top| {
                    if (stack_top.tokenType() == .function) {
                        _ = stack.pop();
                        try output.push(allocator, stack_top);
                    }
                }
            },
        }
    }

    debug("read token: none\n", .{});

    while (stack.pop()) |token| {
        if (token.is("(")) return error.InvalidSyntax;
        try output.push(allocator, token);
    }

    debug("end parsing\n", .{});

    return output;
}

test "shunting yard algorithm" {
    const allocator = std.testing.allocator;
    debug_enabled = false;

    {
        const source = "1 + 2 * ( 3 - 4 )";
        var result = try parse(allocator, source);
        defer result.deinit(allocator);

        const result_string = try std.fmt.allocPrint(allocator, "{}", .{result});
        defer allocator.free(result_string);

        try std.testing.expectEqualStrings(
            \\1, 2, 3, 4, "-", "*", "+"
        , result_string);
    }

    {
        const source = "1 + 2 + 3 - 4 + 5";
        var result = try parse(allocator, source);
        defer result.deinit(allocator);

        const result_string = try std.fmt.allocPrint(allocator, "{}", .{result});
        defer allocator.free(result_string);

        try std.testing.expectEqualStrings(
            \\1, 2, "+", 3, "+", 4, "-", 5, "+"
        , result_string);
    }

    {
        const source = "a ( b ( c ( d ( e ( f ( g ( 0 ) ) ) ) ) ) )";
        var result = try parse(allocator, source);
        defer result.deinit(allocator);

        const result_string = try std.fmt.allocPrint(allocator, "{}", .{result});
        defer allocator.free(result_string);

        try std.testing.expectEqualStrings(
            \\0, g, f, e, d, c, b, a
        , result_string);
    }
}
