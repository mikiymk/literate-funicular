const std = @import("std");
const Allocator = std.mem.Allocator;

const util = @import("../util.zig");
const debug = util.debug;
const Stack = util.Stack;

pub const ParseError = error{InvalidSyntax} || Allocator.Error;

pub const Operator = enum {
    add,
    sub,
    mul,
    div,
    pow,

    pub fn format(self: @This(), comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        const str = switch (self) {
            .add => "+",
            .sub => "-",
            .mul => "*",
            .div => "/",
            .pow => "^",
        };

        try writer.writeAll(str);
    }
};

pub const ParseTree = union(enum) {
    num: []const u8,
    operator: struct { left: *ParseTree, right: *ParseTree, op: Operator },

    pub fn initNumber(token: Token) ParseTree {
        return .{ .num = token.value };
    }

    pub fn initOperator(a: Allocator, left: ParseTree, right: ParseTree, op: Operator) Allocator.Error!ParseTree {
        const left_ptr = try a.create(ParseTree);
        const right_ptr = try a.create(ParseTree);
        left_ptr.* = left;
        right_ptr.* = right;

        return .{ .operator = .{
            .left = left_ptr,
            .right = right_ptr,
            .op = op,
        } };
    }

    pub fn deinit(self: *ParseTree, a: Allocator) void {
        switch (self.*) {
            .num => {},
            .operator => |op| {
                op.left.deinit(a);
                op.right.deinit(a);
                a.destroy(op.left);
                a.destroy(op.right);
            },
        }
    }

    pub fn format(self: @This(), comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        switch (self) {
            .num => |num| try writer.print("{s}", .{num}),
            .operator => |op| try writer.print("({} {} {})", .{ op.left, op.op, op.right }),
        }
    }
};

pub const Token = struct {
    value: []const u8,
    position: usize,

    const TokenType = enum {
        number,
        operator,
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
            '+', '-', '*', '/', '^' => .operator,
            '(', ')' => .parenthesis,
            else => unreachable,
        };
    }

    // 優先順位。小さいほど優先順位が高い
    pub fn precedence(self: Token) u8 {
        return switch (self.value[0]) {
            '+', '-' => 20,
            '*', '/' => 30,
            '^' => 40,
            else => unreachable,
        };
    }

    // 連結する向き
    pub fn associative(self: Token) Direction {
        return switch (self.value[0]) {
            '+', '-', '*', '/' => .left,
            '^' => .right,
            else => unreachable,
        };
    }

    pub fn toOperator(self: Token) Operator {
        return switch (self.value[0]) {
            '+' => .add,
            '-' => .sub,
            '*' => .mul,
            '/' => .div,
            '^' => .pow,
            else => unreachable,
        };
    }

    pub fn is(self: Token, token_string: []const u8) bool {
        return std.mem.eql(u8, self.value, token_string);
    }

    pub fn format(self: @This(), comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        switch (self.tokenType()) {
            .number => try writer.print("{s}", .{self.value}),
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
            '+', '-', '*', '/', '^', '(', ')' => {},
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
    array: Stack(ParseTree) = .empty,

    pub fn deinit(self: *OutputQueue, a: Allocator) void {
        self.array.deinit(a);
    }

    pub fn push(self: *OutputQueue, a: Allocator, token: Token) ParseError!void {
        debug.printLn("output: {}", .{token});

        if (token.tokenType() == .operator) {
            const right = self.array.pop() orelse return error.InvalidSyntax;
            const left = self.array.pop() orelse return error.InvalidSyntax;
            const op = token.toOperator();
            const tree = try ParseTree.initOperator(a, left, right, op);
            try self.array.push(a, tree);
        } else {
            try self.array.push(a, ParseTree.initNumber(token));
        }
    }

    pub fn toTree(self: *OutputQueue) !ParseTree {
        return self.array.pop() orelse return error.InvalidSyntax;
    }

    pub fn format(self: @This(), comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        try writer.print("{}", .{self.array});
    }
};

pub const TestCase = struct { source: []const u8, expected: []const u8 };
pub const test_cases = [_]TestCase{
    .{
        .source = "10",
        .expected = "10",
    },
    .{
        .source = "1 + 2",
        .expected = "(1 + 2)",
    },
    .{
        .source = "1 * 2",
        .expected = "(1 * 2)",
    },
    .{
        .source = "1 ^ 2",
        .expected = "(1 ^ 2)",
    },
    .{
        .source = "1 + 2 * (3 - 4)",
        .expected = "(1 + (2 * (3 - 4)))",
    },
    .{
        .source = "1 + 2 + 3 - 4 + 5",
        .expected = "((((1 + 2) + 3) - 4) + 5)",
    },
    .{
        .source = "1 ^ 2 ^ 3",
        .expected = "(1 ^ (2 ^ 3))",
    },
    .{
        .source = "1 + (2 + 3) / (4 - 5) ^ 6",
        .expected = "(1 + ((2 + 3) / ((4 - 5) ^ 6)))",
    },
};
