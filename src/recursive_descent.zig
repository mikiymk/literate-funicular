const std = @import("std");
const Allocator = std.mem.Allocator;

const utils = @import("./util.zig");

const Stack = utils.Stack;
const debug = utils.debug;

const OutputQueue = utils.Language1.OutputQueue;
const Token = utils.Language1.Token;
const TokenReader = utils.Language1.TokenReader;
const ParseTree = utils.Language1.ParseTree;
const Operator = utils.Language1.Operator;

const ParseError = error{InvalidSyntax} || Allocator.Error;

/// 左結合の木の一部
const PartialTreeLeft = union(enum) {
    const OperatorStruct = struct {
        operator: Operator,
        tree: ParseTree,
        child: *PartialTreeLeft,
    };

    operator: OperatorStruct,
    empty: void,

    fn initOperator(a: Allocator, operator: Token, tree: ParseTree, child: PartialTreeLeft) ParseError!PartialTreeLeft {
        const child_ptr = try a.create(PartialTreeLeft);
        child_ptr.* = child;
        return .{ .operator = .{
            .operator = operator.toOperator(),
            .tree = tree,
            .child = child_ptr,
        } };
    }

    fn deinit(self: *PartialTreeLeft, a: Allocator) void {
        switch (self.*) {
            .empty => {},
            .operator => |op| {
                op.child.deinit(a);
                a.destroy(op.child);
            },
        }
    }

    fn toTree(allocator: Allocator, tree: ParseTree, partial: PartialTreeLeft) ParseError!ParseTree {
        return switch (partial) {
            .empty => tree,
            .operator => |op| {
                return toTree(
                    allocator,
                    try ParseTree.initOperator(
                        allocator,
                        tree,
                        op.tree,
                        op.operator,
                    ),
                    op.child.*,
                );
            },
        };
    }

    pub fn format(self: @This(), comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        switch (self) {
            .empty => try writer.print("(e)", .{}),
            .operator => |op| {
                try writer.print("({} {} {})", .{ op.operator, op.tree, op.child });
            },
        }
    }
};

/// 右結合の木の一部
const PartialTreeRight = union(enum) {
    const OperatorStruct = struct {
        operator: Operator,
        tree: ParseTree,
    };

    operator: OperatorStruct,
    empty: void,

    fn initOperator(a: Allocator, operator: Token, tree: ParseTree, child: PartialTreeRight) ParseError!PartialTreeRight {
        return .{ .operator = .{
            .operator = operator.toOperator(),
            .tree = try toTree(a, tree, child),
        } };
    }

    fn toTree(allocator: Allocator, tree: ParseTree, partial: PartialTreeRight) ParseError!ParseTree {
        return switch (partial) {
            .empty => tree,
            .operator => |op| {
                return ParseTree.initOperator(
                    allocator,
                    tree,
                    op.tree,
                    op.operator,
                );
            },
        };
    }

    pub fn format(self: @This(), comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        switch (self) {
            .empty => try writer.print("(e)", .{}),
            .operator => |op| {
                try writer.print("({} {})", .{ op.operator, op.tree });
            },
        }
    }
};

pub fn parse(allocator: Allocator, source: []const u8) !ParseTree {
    var input = TokenReader.init(source);

    debug.begin("parsing");
    const tree = try parseAdd(allocator, &input);
    debug.end("parsing");

    return tree;
}

// 文法
// Expr -> Add
// Add  -> Mul Add'
// Add' -> + Mul Add' | - Mul Add' | empty
// Mul  -> Pow Mul'
// Mul' -> * Pow Mul' | / Pow Mul' | empty
// Pow  -> Prim Pow'
// Pow' -> ^ Prim Pow' | empty
// Prim -> ( Expr ) | num

fn parseAdd(allocator: Allocator, input: *TokenReader) ParseError!ParseTree {
    debug.begin("add-expr");

    // Mul
    const mul = try parseMul(allocator, input);

    // Add'
    var add2 = try parseAdd2(allocator, input);
    defer add2.deinit(allocator);

    // Add' を構文解析木に変換
    const tree = try PartialTreeLeft.toTree(allocator, mul, add2);

    debug.print("tree: {}\n", .{tree});
    debug.end("add-expr");
    return tree;
}

fn parseAdd2(allocator: Allocator, input: *TokenReader) ParseError!PartialTreeLeft {
    debug.begin("add-expr'");
    var tree: PartialTreeLeft = .empty;

    // トークンがあり、+ - なら
    if (input.peek()) |token| {
        if (token.is("+") or token.is("-")) {
            // トークンを読みこむ
            _ = input.next();

            // Mul
            const mul = try parseMul(allocator, input);

            // Add'
            const add2 = try parseAdd2(allocator, input);

            tree = try PartialTreeLeft.initOperator(allocator, token, mul, add2);
        }
    }

    debug.print("tree: {}\n", .{tree});
    debug.end("add-expr'");
    return tree;
}

fn parseMul(allocator: Allocator, input: *TokenReader) ParseError!ParseTree {
    debug.begin("mul-expr");

    // Pow
    const pow = try parsePow(allocator, input);

    // Mul'
    var mul2 = try parseMul2(allocator, input);
    defer mul2.deinit(allocator);

    // Mul' を構文解析木に変換
    const tree = try PartialTreeLeft.toTree(allocator, pow, mul2);

    debug.print("tree: {}\n", .{tree});
    debug.end("mul-expr");
    return tree;
}

fn parseMul2(allocator: Allocator, input: *TokenReader) ParseError!PartialTreeLeft {
    debug.begin("mul-expr'");
    var tree: PartialTreeLeft = .empty;

    // トークンがあり、* / なら
    if (input.peek()) |token| {
        if (token.is("*") or token.is("/")) {
            // トークンを読みこむ
            _ = input.next();

            // Pow
            const pow = try parsePow(allocator, input);

            // Mul'
            const mul2 = try parseMul2(allocator, input);

            tree = try PartialTreeLeft.initOperator(allocator, token, pow, mul2);
        }
    }

    debug.print("tree: {}\n", .{tree});
    debug.end("mul-expr'");
    return tree;
}

fn parsePow(allocator: Allocator, input: *TokenReader) ParseError!ParseTree {
    debug.begin("pow-expr");

    // Prim
    const prim = try parsePrim(allocator, input);

    // Pow'
    const pow2 = try parsePow2(allocator, input);

    // Pow' を構文解析木に変換
    const tree = try PartialTreeRight.toTree(allocator, prim, pow2);

    debug.print("tree: {}\n", .{tree});
    debug.end("pow-expr");
    return tree;
}

fn parsePow2(allocator: Allocator, input: *TokenReader) ParseError!PartialTreeRight {
    debug.begin("pow-expr'");
    var tree: PartialTreeRight = .empty;

    // トークンがあり、^ なら
    if (input.peek()) |token| {
        if (token.is("^")) {
            // トークンを読みこむ
            _ = input.next();

            // Prim
            const prim = try parsePrim(allocator, input);

            // Pow'
            const pow2 = try parsePow2(allocator, input);

            tree = try PartialTreeRight.initOperator(allocator, token, prim, pow2);
        }
    }

    debug.print("tree: {}\n", .{tree});
    debug.end("pow-expr'");
    return tree;
}

fn parsePrim(allocator: Allocator, input: *TokenReader) ParseError!ParseTree {
    debug.begin("prim-expr");
    var tree: ParseTree = undefined;

    // トークンの種類で分岐
    const token = input.peek() orelse return error.InvalidSyntax;
    switch (token.tokenType()) {
        // 数字
        .number => {
            _ = input.next();
            tree = .{ .num = token };
        },

        // 括弧
        .parenthesis => {
            // ( Expr )
            try expect(input, "(");
            tree = try parseAdd(allocator, input);
            try expect(input, ")");
        },

        // それ以外
        // 構文エラー
        else => return error.InvalidSyntax,
    }

    debug.print("tree: {}\n", .{tree});
    debug.end("prim-expr");
    return tree;
}

fn expect(input: *TokenReader, token_string: []const u8) ParseError!void {
    const next_token = input.next() orelse return error.InvalidSyntax;
    if (!next_token.is(token_string)) return error.InvalidSyntax;
}

test "recursive descent parsing" {
    const allocator = std.testing.allocator;
    utils.debug.enabled = false;

    const test_cases = [_]struct {
        source: []const u8,
        expected: []const u8,
    }{
        .{
            .source = "1 + 2 * ( 3 - 4 )",
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
    };

    for (test_cases) |test_case| {
        const source = test_case.source;
        const expected = test_case.expected;

        var result = try parse(allocator, source);
        defer result.deinit(allocator);

        const result_string = try std.fmt.allocPrint(allocator, "{}", .{result});
        defer allocator.free(result_string);

        try std.testing.expectEqualStrings(expected, result_string);
    }
}
