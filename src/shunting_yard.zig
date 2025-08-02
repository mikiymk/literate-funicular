//! ## ダイクストラの操車場アルゴリズム

const std = @import("std");
const Allocator = std.mem.Allocator;

const utils = @import("./util.zig");

const debug = utils.debug;

const OutputQueue = utils.Language1.OutputQueue;
const Token = utils.Language1.Token;
const TokenReader = utils.Language1.TokenReader;
const ParseTree = utils.Language1.ParseTree;
const ParseError = utils.Language1.ParseError;
const Stack = utils.Stack;

/// 文字列を解析する
pub fn parse(a: Allocator, source: []const u8) ParseError!ParseTree {
    var input = TokenReader.init(source);
    var output = OutputQueue{};
    defer output.deinit(a);
    var stack: Stack(Token) = .empty;
    defer stack.deinit(a);

    debug.printLn("入力文字列: {s}", .{source});
    debug.begin("構文解析");

    debug.begin("入力");
    while (input.next()) |o1| {
        // 入力から1つのトークンを取り出し、処理を行なう
        debug.begin("入力の処理");
        debug.printLn("トークンを読み込み: {}({})", .{ o1, o1.tokenType() });

        try processToken(a, o1, &stack, &output);

        debug.end("入力の処理");
    }
    debug.end("入力");

    debug.begin("残りスタックの処理");
    // スタックに残ったものを順番に出力
    while (stack.pop()) |token| {
        // スタックに左括弧が残っていたら構文エラー
        if (token.is("(")) return error.InvalidSyntax;
        try output.push(a, token);
    }
    debug.end("残りスタックの処理");

    debug.end("構文解析");

    return output.toTree();
}

fn processToken(a: Allocator, o1: Token, stack: *Stack(Token), output: *OutputQueue) ParseError!void {
    // トークンの種類によって処理を分岐
    switch (o1.tokenType()) {
        // 数字
        .number => try output.push(a, o1),

        // 演算子
        .operator => {
            while (true) {
                // スタックトップが演算子でなければループを抜ける
                const o2 = stack.get() orelse break;
                if (o2.tokenType() != .operator) break;

                // 演算子の優先順位
                const o1_p = o1.precedence();
                const o2_p = o2.precedence();

                // o2 > o1 か、o2 == o1 かつ 左結合 ならば、ループを続行する
                if (!((o1_p < o2_p) or (o1_p == o2_p and o1.associative() == .left)))
                    break;

                // スタックトップを取り出して出力
                _ = stack.pop();
                try output.push(a, o2);
            }

            // 現在の入力をスタックに入れる
            try stack.push(a, o1);
        },

        // 括弧
        .parenthesis => {
            if (o1.is("(")) { // 左括弧
                // スタックに入れる
                try stack.push(a, o1);
            } else { // 右括弧
                while (true) {
                    // スタックトップを読み出す
                    // スタックが空なら構文エラー
                    const stack_top = stack.get() orelse return error.InvalidSyntax;
                    if (!stack_top.is("(")) { // スタックトップが左括弧でない
                        // スタックトップを取り出して出力
                        _ = stack.pop();
                        try output.push(a, stack_top);
                    } else { // スタックトップが左括弧
                        // スタックトップを取り出し、次の入力へ
                        _ = stack.pop();
                        break;
                    }
                }
            }
        },
    }
}

test "shunting yard algorithm" {
    const allocator = std.testing.allocator;
    utils.debug.enabled = false;

    for (utils.Language1.test_cases) |test_case| {
        const source = test_case.source;
        const expected = test_case.expected;

        var result = try parse(allocator, source);
        defer result.deinit(allocator);

        const result_string = try std.fmt.allocPrint(allocator, "{}", .{result});
        defer allocator.free(result_string);

        try std.testing.expectEqualStrings(expected, result_string);
    }
}
