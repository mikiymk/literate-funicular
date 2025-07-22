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
        switch (self) {
            .add => try writer.writeAll("+"),
            .sub => try writer.writeAll("-"),
            .mul => try writer.writeAll("*"),
            .div => try writer.writeAll("/"),
            .pow => try writer.writeAll("^"),
        }
    }
};

pub const ParseTree = union(enum) {
    num: Token,
    operator: struct { left: *ParseTree, right: *ParseTree, op: Operator },

    pub fn initOperator(allocator: Allocator, left: ParseTree, right: ParseTree, op: Operator) Allocator.Error!ParseTree {
        const left_ptr = try allocator.create(ParseTree);
        const right_ptr = try allocator.create(ParseTree);
        left_ptr.* = left;
        right_ptr.* = right;

        return .{ .operator = .{
            .left = left_ptr,
            .right = right_ptr,
            .op = op,
        } };
    }

    pub fn deinit(self: *ParseTree, allocator: Allocator) void {
        switch (self.*) {
            .num => {},
            .operator => |op| {
                op.left.deinit(allocator);
                op.right.deinit(allocator);
                allocator.destroy(op.left);
                allocator.destroy(op.right);
            },
        }
    }

    pub fn format(self: @This(), comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        switch (self) {
            .num => |num| try writer.print("{}", .{num}),
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

    pub fn deinit(self: *OutputQueue, allocator: Allocator) void {
        self.array.deinit(allocator);
    }

    pub fn push(self: *OutputQueue, allocator: Allocator, token: Token) ParseError!void {
        debug.print("output: {}\n", .{token});

        if (token.tokenType() == .operator) {
            const right = self.array.pop() orelse return error.InvalidSyntax;
            const left = self.array.pop() orelse return error.InvalidSyntax;
            const op = token.toOperator();
            const tree = try ParseTree.initOperator(allocator, left, right, op);
            try self.array.push(allocator, tree);
        } else {
            try self.array.push(allocator, .{ .num = token });
        }
    }

    pub fn toTree(self: *OutputQueue) !ParseTree {
        return self.array.pop() orelse return error.InvalidSyntax;
    }

    pub fn format(self: @This(), comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        try writer.print("{}", .{self.array});
    }
};
