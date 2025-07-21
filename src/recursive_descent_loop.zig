const std = @import("std");
const Allocator = std.mem.Allocator;

const utils = @import("./util.zig");

const Stack = utils.Stack;
const debug = utils.debug;

const Token = utils.Language1.Token;
const TokenReader = utils.Language1.TokenReader;

const ParseError = error{InvalidSyntax} || Allocator.Error;

const ParseTree = union(enum) {
    num: Token,
    operator: struct { left: *ParseTree, right: *ParseTree, op: Token },

    fn initOperator(a: Allocator, left: ParseTree, right: ParseTree, op: Token) ParseError!ParseTree {
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
            .num => |num| try writer.print("{}", .{num}),
            .operator => |op| try writer.print("({} {} {})", .{ op.left, op.op, op.right }),
        }
    }
};

pub fn parse(a: Allocator, source: []const u8) !ParseTree {
    var input = TokenReader.init(source);

    debug.begin("parsing");
    const tree = try parseExpr(a, &input);
    debug.end("parsing");

    return tree;
}

// Expr   -> Term {+ Term | - Term}*
// Term   -> Factor {* Factor | / Factor}*
// Factor -> ( Expr ) | num

fn parseExpr(a: Allocator, input: *TokenReader) ParseError!ParseTree {
    debug.begin("expr");
    var tree = try parseTerm(a, input);

    while (input.peek()) |token| {
        if (!(token.is("+") or token.is("-"))) break;
        _ = input.next();
        const term = try parseTerm(a, input);

        tree = try ParseTree.initOperator(a, tree, term, token);
    }

    debug.print("tree: {}\n", .{tree});
    debug.end("expr");
    return tree;
}

fn parseTerm(a: Allocator, input: *TokenReader) ParseError!ParseTree {
    debug.begin("term");
    var tree = try parseFactor(a, input);

    while (input.peek()) |token| {
        if (!(token.is("*") or token.is("/"))) break;
        _ = input.next();
        const term = try parseFactor(a, input);

        tree = try ParseTree.initOperator(a, tree, term, token);
    }

    debug.print("tree: {}\n", .{tree});
    debug.end("term");
    return tree;
}

fn parseFactor(a: Allocator, input: *TokenReader) ParseError!ParseTree {
    debug.begin("factor");
    const token = input.peek() orelse return error.InvalidSyntax;
    var tree: ParseTree = undefined;
    switch (token.tokenType()) {
        .number => {
            _ = input.next();
            tree = .{ .num = token };
        },
        .parenthesis => {
            try expect(input, "(");
            tree = try parseExpr(a, input);
            try expect(input, ")");
        },
        else => return error.InvalidSyntax,
    }
    debug.print("tree: {}\n", .{tree});
    debug.end("factor");
    return tree;
}

fn expect(input: *TokenReader, token_string: []const u8) ParseError!void {
    const next_token = input.next() orelse return error.InvalidSyntax;
    if (!next_token.is(token_string)) return error.InvalidSyntax;
}

test "recursive descent parsing" {
    const allocator = std.testing.allocator;
    utils.debug.enabled = false;

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
