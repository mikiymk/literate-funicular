const std = @import("std");
const Allocator = std.mem.Allocator;

const utils = @import("./util.zig");

const Stack = utils.Stack;
const debug = utils.debug;

const Token = utils.Language1.Token;
const TokenReader = utils.Language1.TokenReader;
const ParseTree = utils.Language1.ParseTree;

const ParseError = error{InvalidSyntax} || Allocator.Error;

pub fn parse(a: Allocator, source: []const u8) !ParseTree {
    var input = TokenReader.init(source);

    debug.begin("構文解析");
    const tree = try parseAdd(a, &input);
    debug.end("構文解析");

    return tree;
}

// 文法
// Expr -> Add
// Add  -> Mul {+ Mul | - Mul}*
// Mul  -> Pow {* Pow | / Pow}*
// Pow  -> Prim {* Prim | / Prim}*
// Prim -> ( Expr ) | num

fn parseAdd(a: Allocator, input: *TokenReader) ParseError!ParseTree {
    debug.begin("Add-Expr");

    // Mul
    var tree = try parseMul(a, input);

    while (input.peek()) |token| {
        if (!(token.is("+") or token.is("-"))) break;
        // トークンがあり、+ - の限り

        // トークンを読みこむ
        _ = input.next();

        // Mul
        const mul = try parseMul(a, input);

        tree = try ParseTree.initOperator(a, tree, mul, token.toOperator());
    }

    debug.printLn("現在の構文解析木: {}", .{tree});
    debug.end("Add-Expr");
    return tree;
}

fn parseMul(a: Allocator, input: *TokenReader) ParseError!ParseTree {
    debug.begin("Mul-Expr");

    // Pow
    var tree = try parsePow(a, input);

    while (input.peek()) |token| {
        if (!(token.is("*") or token.is("/"))) break;
        // トークンがあり、* / の限り

        // トークンを読みこむ
        _ = input.next();

        // Pow
        const pow = try parsePow(a, input);

        tree = try ParseTree.initOperator(a, tree, pow, token.toOperator());
    }

    debug.printLn("現在の構文解析木: {}", .{tree});
    debug.end("Mul-Expr");
    return tree;
}

const PartialTree = struct {
    token: Token,
    prim: ParseTree,

    pub fn format(
        self: @This(),
        _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        try writer.print("({} {})", .{ self.token, self.prim });
    }
};

fn parsePow(a: Allocator, input: *TokenReader) ParseError!ParseTree {
    debug.begin("Pow-Expr");

    // Prim
    var tree = try parsePrim(a, input);

    var tokens_stack = Stack(PartialTree).empty;
    defer tokens_stack.deinit(a);

    while (input.peek()) |token| {
        if (!token.is("^")) break;
        // トークンがあり、^ の限り

        // トークンを読みこむ
        _ = input.next();

        // Prim
        const prim = try parsePrim(a, input);

        try tokens_stack.push(a, .{ .token = token, .prim = prim });
    }

    // 右結合の演算子の構文木を作る
    var prev_tokens: ?PartialTree = null;
    while (tokens_stack.pop()) |tokens| {
        const token = tokens.token;
        var prim = tokens.prim;

        if (prev_tokens) |pt| {
            prim = try ParseTree.initOperator(a, prim, pt.prim, pt.token.toOperator());
        }

        prev_tokens = .{ .token = token, .prim = prim };
    }

    if (prev_tokens) |pt| {
        tree = try ParseTree.initOperator(a, tree, pt.prim, pt.token.toOperator());
    }

    debug.printLn("現在の構文解析木: {}", .{tree});
    debug.end("Pow-Expr");
    return tree;
}

fn parsePrim(a: Allocator, input: *TokenReader) ParseError!ParseTree {
    debug.begin("Prim-Expr");
    var tree: ParseTree = undefined;

    // トークンの種類で分岐
    const token = input.peek() orelse return error.InvalidSyntax;
    switch (token.tokenType()) {
        // 数字
        .number => {
            _ = input.next();
            tree = ParseTree.initNumber(token);
        },

        // 括弧
        .parenthesis => {
            // ( Expr )
            try input.expect("(");
            tree = try parseAdd(a, input);
            try input.expect(")");
        },

        // それ以外
        // 構文エラー
        else => return error.InvalidSyntax,
    }

    debug.printLn("現在の構文解析木: {}", .{tree});
    debug.end("Prim-Expr");
    return tree;
}

test "recursive descent parsing" {
    const allocator = std.testing.allocator;
    utils.debug.enabled = false;

    const test_cases = utils.Language1.test_cases;

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
