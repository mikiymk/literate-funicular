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

    debug.begin("parsing");
    const tree = try parseAdd(a, &input);
    debug.end("parsing");

    return tree;
}

// 文法
// Expr -> Add
// Add  -> Mul {+ Mul | - Mul}*
// Mul  -> Pow {* Pow | / Pow}*
// Pow  -> Prim {* Prim | / Prim}*
// Prim -> ( Expr ) | num

fn parseAdd(a: Allocator, input: *TokenReader) ParseError!ParseTree {
    debug.begin("add-expr");

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

    debug.print("tree: {}", .{tree});
    debug.end("add-expr");
    return tree;
}

fn parseMul(a: Allocator, input: *TokenReader) ParseError!ParseTree {
    debug.begin("mul-expr");

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

    debug.print("tree: {}", .{tree});
    debug.end("mul-expr");
    return tree;
}

fn parsePow(a: Allocator, input: *TokenReader) ParseError!ParseTree {
    debug.begin("pow-expr");

    // Prim
    var tree = try parsePrim(a, input);

    const Tokens = struct { token: Token, prim: ParseTree };
    var tokens_stack = Stack(Tokens).empty;
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

    var prev_tokens: ?Tokens = null;
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

    debug.print("tree: {}", .{tree});
    debug.end("pow-expr");
    return tree;
}

fn parsePrim(a: Allocator, input: *TokenReader) ParseError!ParseTree {
    debug.begin("prim-expr");
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
            try expect(input, "(");
            tree = try parseAdd(a, input);
            try expect(input, ")");
        },

        // それ以外
        // 構文エラー
        else => return error.InvalidSyntax,
    }

    debug.print("tree: {}", .{tree});
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
