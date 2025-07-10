const std = @import("std");
const Allocator = std.mem.Allocator;

const utils = @import("./utils.zig");
const OutputQueue = utils.OutputQueue;
const Token = utils.Token;
const TokenReader = utils.TokenReader;
const Stack = utils.Stack;
const debug = utils.debug;

const ParseError = error{InvalidSyntax} || Allocator.Error;

const ParseTree = union(enum) {
    num: Token,
    operator: struct { left: *ParseTree, right: *ParseTree, op: Token },

    fn initFromExpression2(allocator: Allocator, factor: ParseTree, expression2: Expression2) ParseTree {
        return switch (expression2) {
            .empty => factor,
            .operator => |op| {
                const operator, const tree, const expression2_child = op;
                return initFromExpression2(allocator, initOperator(allocator, factor, tree, operator), expression2_child.*);
            },
        };
    }

    fn initFromTerm2(allocator: Allocator, factor: ParseTree, term2: Term2) ParseTree {
        return switch (term2) {
            .empty => factor,
            .operator => |op| {
                const operator, const tree, const term2_child = op;
                return initFromTerm2(allocator, initOperator(allocator, factor, tree, operator), term2_child.*);
            },
        };
    }

    fn initOperator(allocator: Allocator, left: ParseTree, right: ParseTree, op: Token) ParseTree {
        const left_ptr = allocator.create(ParseTree) catch unreachable;
        const right_ptr = allocator.create(ParseTree) catch unreachable;
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

pub fn parse(allocator: Allocator, source: []const u8) !ParseTree {
    var input = TokenReader.init(source);

    debug("parsing start\n", .{});
    const tree = try parseExpression(allocator, &input);
    debug("parsing end\n", .{});

    return tree;
}

// Expression  -> Term Expression'
// Expression' -> + Term Expression' | - Term Expression' | empty
// Term        -> Factor Term'
// Term'       -> * Factor Term' | / Factor Term' | empty
// Factor      -> ( Expression ) | num

fn parseExpression(allocator: Allocator, input: *TokenReader) ParseError!ParseTree {
    debug("expression start\n", .{});
    const term = try parseTerm(allocator, input);
    var expression2 = try parseExpression2(allocator, input);
    defer expression2.deinit(allocator);
    const tree = ParseTree.initFromExpression2(allocator, term, expression2);
    debug("expression end: {}\n", .{tree});
    return tree;
}

const Expression2Operator = struct { Token, ParseTree, *Expression2 };
const Expression2 = union(enum) {
    operator: Expression2Operator,
    empty: void,

    fn initOperator(allocator: Allocator, token: Token, factor: ParseTree, expression2: Expression2) ParseError!Expression2 {
        const expression2_ptr = try allocator.create(Expression2);
        expression2_ptr.* = expression2;
        return .{ .operator = .{ token, factor, expression2_ptr } };
    }

    fn deinit(self: *Expression2, allocator: Allocator) void {
        switch (self.*) {
            .empty => {},
            .operator => |op| {
                _, _, const expression2 = op;
                expression2.deinit(allocator);
                allocator.destroy(expression2);
            },
        }
    }

    pub fn format(self: @This(), comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        switch (self) {
            .empty => try writer.print("(e)", .{}),
            .operator => |op| {
                const token, const factor, const expression2 = op;
                try writer.print("({} {} {})", .{ token, factor, expression2 });
            },
        }
    }
};

fn parseExpression2(allocator: Allocator, input: *TokenReader) ParseError!Expression2 {
    debug("expression' start\n", .{});
    var tree: Expression2 = .empty;
    if (input.peek()) |token| {
        if (token.is("+") or token.is("-")) {
            _ = input.next();
            const term = try parseTerm(allocator, input);
            const expression2 = try parseExpression2(allocator, input);
            tree = try Expression2.initOperator(allocator, token, term, expression2);
        }
    }
    debug("expression' end: {}\n", .{tree});
    return tree;
}

fn parseTerm(allocator: Allocator, input: *TokenReader) ParseError!ParseTree {
    debug("term start\n", .{});
    const factor = try parseFactor(allocator, input);
    var term2 = try parseTerm2(allocator, input);
    defer term2.deinit(allocator);
    const tree = ParseTree.initFromTerm2(allocator, factor, term2);
    debug("term end: {}\n", .{tree});
    return tree;
}

const Term2Operator = struct { Token, ParseTree, *Term2 };
const Term2 = union(enum) {
    operator: Term2Operator,
    empty: void,

    fn initOperator(allocator: Allocator, token: Token, factor: ParseTree, term2: Term2) ParseError!Term2 {
        const term2_ptr = try allocator.create(Term2);
        term2_ptr.* = term2;
        return .{ .operator = .{ token, factor, term2_ptr } };
    }

    fn deinit(self: *Term2, allocator: Allocator) void {
        switch (self.*) {
            .empty => {},
            .operator => |op| {
                _, _, const term2 = op;
                term2.deinit(allocator);
                allocator.destroy(term2);
            },
        }
    }

    pub fn format(self: @This(), comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        switch (self) {
            .empty => try writer.print("(e)", .{}),
            .operator => |op| {
                const token, const factor, const term2 = op;
                try writer.print("({} {} {})", .{ token, factor, term2 });
            },
        }
    }
};

fn parseTerm2(allocator: Allocator, input: *TokenReader) ParseError!Term2 {
    debug("term' start\n", .{});
    var tree: Term2 = .empty;
    if (input.peek()) |token| {
        if (token.is("*") or token.is("/")) {
            _ = input.next();
            const factor = try parseFactor(allocator, input);
            const term2 = try parseTerm2(allocator, input);
            tree = try Term2.initOperator(allocator, token, factor, term2);
        }
    }
    debug("term' end: {}\n", .{tree});
    return tree;
}

fn parseFactor(allocator: Allocator, input: *TokenReader) ParseError!ParseTree {
    debug("factor start\n", .{});
    const token = input.peek() orelse return error.InvalidSyntax;
    var tree: ParseTree = undefined;
    switch (token.tokenType()) {
        .number => {
            _ = input.next();
            tree = .{ .num = token };
        },
        .parenthesis => {
            try expect(input, "(");
            tree = try parseExpression(allocator, input);
            try expect(input, ")");
        },
        else => return error.InvalidSyntax,
    }
    debug("factor end: {}\n", .{tree});
    return tree;
}

fn expect(input: *TokenReader, token_string: []const u8) ParseError!void {
    const next_token = input.next() orelse return error.InvalidSyntax;
    if (!next_token.is(token_string)) return error.InvalidSyntax;
}

test "recursive descent parsing" {
    const allocator = std.testing.allocator;
    utils.debug_enabled = true;

    {
        const source = "1 + 2 * ( 3 - 4 )";
        var result = try parse(allocator, source);
        defer result.deinit(allocator);

        const result_string = try std.fmt.allocPrint(allocator, "{}", .{result});
        defer allocator.free(result_string);

        try std.testing.expectEqualStrings(
            \\(1 "+" (2 "*" (3 "-" 4)))
        , result_string);
    }

    {
        const source = "1 + 2 + 3 - 4 + 5";
        var result = try parse(allocator, source);
        defer result.deinit(allocator);

        const result_string = try std.fmt.allocPrint(allocator, "{}", .{result});
        defer allocator.free(result_string);

        try std.testing.expectEqualStrings(
            \\((((1 "+" 2) "+" 3) "-" 4) "+" 5)
        , result_string);
    }
}
