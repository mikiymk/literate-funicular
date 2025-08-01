//! 優先順位上昇法
//!
//! 右側と左側の演算子の優先順位を比較し、優先順位の高い方を先に結合する

const std = @import("std");
const Allocator = std.mem.Allocator;

const utils = @import("./util.zig");

const TokenReader = utils.Language1.TokenReader;
const ParseTree = utils.Language1.ParseTree;
const ParseError = utils.Language1.ParseError;
const debug = utils.debug;

pub fn parse(a: Allocator, source: []const u8) !ParseTree {
    var input = TokenReader.init(source);

    debug.begin("parsing");
    const tree = try parseExpr(a, &input);
    debug.end("parsing");

    return tree;
}

fn parseExpr(a: Allocator, input: *TokenReader) ParseError!ParseTree {
    // 最初の左辺を読み込み、最小の優先順位を0とする
    return parseExpr1(a, input, try parsePrim(a, input), 0);
}

fn parseExpr1(a: Allocator, input: *TokenReader, lhs: ParseTree, min_precedence: u8) ParseError!ParseTree {
    var lhs_tree = lhs;
    debug.begin("expr");

    // 先読み
    var lookahead = input.peek();
    while (lookahead) |token1| {
        // 次のトークンが演算子で、優先順位が`min_precedence`以上の限りループする
        if (!(token1.tokenType() == .operator and token1.precedence() >= min_precedence)) break;
        _ = input.next(); // 先読みしたトークンを消費

        // 右辺を1つ読み込む
        var rhs_tree = try parsePrim(a, input);

        // 右辺の先読み
        lookahead = input.peek();
        while (lookahead) |token2| : (lookahead = input.peek()) {
            // 次のトークンが演算子で、優先順位が`token1`より高いか、同じで右結合になる限りループする
            if (token2.tokenType() != .operator) break;
            const token1_p = token1.precedence();
            const token2_p = token2.precedence();
            if (!(token2_p > token1_p or (token2_p == token1_p and token2.associative() == .right))) break;

            // 現在の右辺を左辺として、再帰的に右辺を読み込む
            rhs_tree = try parseExpr1(a, input, rhs_tree, if (token2_p > token1_p) token1_p + 1 else token1_p);
        }

        // 左辺と右辺を結合し、次の演算子のために左辺にする
        lhs_tree = try ParseTree.initOperator(a, lhs_tree, rhs_tree, token1.toOperator());
    }

    debug.end("expr");
    return lhs_tree;
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
            tree = try parseExpr(a, input);
            try expect(input, ")");
        },

        // それ以外
        // 構文エラー
        else => return error.InvalidSyntax,
    }

    debug.printLn("tree: {}", .{tree});
    debug.end("prim-expr");
    return tree;
}

fn expect(input: *TokenReader, token_string: []const u8) ParseError!void {
    const next_token = input.next() orelse return error.InvalidSyntax;
    if (!next_token.is(token_string)) return error.InvalidSyntax;
}

test "precedence climb parsing" {
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
