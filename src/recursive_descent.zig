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

    fn initFromExpr2(allocator: Allocator, factor: ParseTree, expr2: Expr2) ParseTree {
        return switch (expr2) {
            .empty => factor,
            .operator => |op| {
                const operator, const tree, const expr2_child = op;
                return initFromExpr2(
                    allocator,
                    initOperator(allocator, factor, tree, operator),
                    expr2_child.*,
                );
            },
        };
    }

    fn initFromTerm2(allocator: Allocator, factor: ParseTree, term2: Term2) ParseTree {
        return switch (term2) {
            .empty => factor,
            .operator => |op| {
                const operator, const tree, const term2_child = op;
                return initFromTerm2(
                    allocator,
                    initOperator(allocator, factor, tree, operator),
                    term2_child.*,
                );
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

    debug.begin("parsing");
    const tree = try parseExpr(allocator, &input);
    debug.end("parsing");

    return tree;
}

// Expr   -> Term Expr'
// Expr'  -> + Term Expr' | - Term Expr' | empty
// Term   -> Factor Term'
// Term'  -> * Factor Term' | / Factor Term' | empty
// Factor -> ( Expr ) | num

fn parseExpr(allocator: Allocator, input: *TokenReader) ParseError!ParseTree {
    debug.begin("expr");
    const term = try parseTerm(allocator, input);
    var expr2 = try parseExpr2(allocator, input);
    defer expr2.deinit(allocator);
    const tree = ParseTree.initFromExpr2(allocator, term, expr2);
    debug.print("tree: {}\n", .{tree});
    debug.end("expr");
    return tree;
}

const Expr2Operator = struct { Token, ParseTree, *Expr2 };
const Expr2 = union(enum) {
    operator: Expr2Operator,
    empty: void,

    fn initOperator(allocator: Allocator, token: Token, factor: ParseTree, expr2: Expr2) ParseError!Expr2 {
        const expr2_ptr = try allocator.create(Expr2);
        expr2_ptr.* = expr2;
        return .{ .operator = .{ token, factor, expr2_ptr } };
    }

    fn deinit(self: *Expr2, allocator: Allocator) void {
        switch (self.*) {
            .empty => {},
            .operator => |op| {
                _, _, const expr2 = op;
                expr2.deinit(allocator);
                allocator.destroy(expr2);
            },
        }
    }

    pub fn format(self: @This(), comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        switch (self) {
            .empty => try writer.print("(e)", .{}),
            .operator => |op| {
                const token, const factor, const expr2 = op;
                try writer.print("({} {} {})", .{ token, factor, expr2 });
            },
        }
    }
};

fn parseExpr2(allocator: Allocator, input: *TokenReader) ParseError!Expr2 {
    debug.begin("expr'");
    var tree: Expr2 = .empty;
    if (input.peek()) |token| {
        if (token.is("+") or token.is("-")) {
            _ = input.next();
            const term = try parseTerm(allocator, input);
            const expr2 = try parseExpr2(allocator, input);
            tree = try Expr2.initOperator(allocator, token, term, expr2);
        }
    }
    debug.print("tree: {}\n", .{tree});
    debug.end("expr'");
    return tree;
}

fn parseTerm(allocator: Allocator, input: *TokenReader) ParseError!ParseTree {
    debug.begin("term");
    const factor = try parseFactor(allocator, input);
    var term2 = try parseTerm2(allocator, input);
    defer term2.deinit(allocator);
    const tree = ParseTree.initFromTerm2(allocator, factor, term2);
    debug.print("tree: {}\n", .{tree});
    debug.end("term");
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
    debug.begin("term'");
    var tree: Term2 = .empty;
    if (input.peek()) |token| {
        if (token.is("*") or token.is("/")) {
            _ = input.next();
            const factor = try parseFactor(allocator, input);
            const term2 = try parseTerm2(allocator, input);
            tree = try Term2.initOperator(allocator, token, factor, term2);
        }
    }
    debug.print("tree: {}\n", .{tree});
    debug.end("term'");
    return tree;
}

fn parseFactor(allocator: Allocator, input: *TokenReader) ParseError!ParseTree {
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
            tree = try parseExpr(allocator, input);
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
