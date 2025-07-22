const std = @import("std");
const Allocator = std.mem.Allocator;

const utils = @import("./util.zig");

const debug = utils.debug;

const OutputQueue = utils.Language1.OutputQueue;
const Token = utils.Language1.Token;
const TokenReader = utils.Language1.TokenReader;
const ParseTree = utils.Language1.ParseTree;

/// 文字列を解析する
pub fn parse(allocator: Allocator, source: []const u8) !ParseTree {

    // 入力
    var input = TokenReader.init(source);

    // 出力
    var output = OutputQueue{};
    defer output.deinit(allocator);

    // スタック
    var stack: utils.Stack(Token) = .empty;
    defer stack.deinit(allocator);

    debug.begin("parsing");

    while (input.next()) |o1| {
        // 入力から1つのトークンを取り出し、処理を行なう
        debug.begin("process");
        debug.print("read token: {}\n", .{o1});

        switch (o1.tokenType()) {
            // トークンの種類によって処理を分岐

            // 数字
            // そのまま出力
            .number => try output.push(allocator, o1),

            // 演算子
            .operator => {
                while (true) {
                    // スタックトップが演算子でなければループを抜ける
                    const o2 = stack.get() orelse break;
                    if (o2.tokenType() != .operator) break;

                    // 演算子の優先順位
                    const o1_p = o1.precedence();
                    const o2_p = o2.precedence();

                    {
                        // o2 > o1 か、o2 == o1 かつ 左結合 ならば、ループを続行する
                        _ = !((o1_p < o2_p) or (o1_p == o2_p and o1.associative() == .left));

                        // ↓反転

                        // o2 < o1 か、o2 == o1 かつ 右結合 ならば、ループを抜ける
                        _ = o1_p > o2_p or (o1_p == o2_p and o1.associative() != .left);
                    }

                    if (o1_p > o2_p or (o1_p == o2_p and o1.associative() != .left))
                        break;

                    // スタックトップを取り出して出力
                    _ = stack.pop();
                    try output.push(allocator, o2);
                }

                // 現在の入力をスタックに入れる
                try stack.push(allocator, o1);
            },

            // 括弧
            .parenthesis => {
                if (o1.is("(")) {
                    // 左括弧
                    // スタックに入れる
                    try stack.push(allocator, o1);
                } else {
                    // 右括弧
                    while (true) {
                        // スタックトップを読み出す
                        // スタックが空なら構文エラー
                        const stack_top = stack.get() orelse return error.InvalidSyntax;
                        if (!stack_top.is("(")) {
                            // スタックトップが左括弧でない
                            // スタックトップを取り出して出力
                            _ = stack.pop();
                            try output.push(allocator, stack_top);
                        } else {
                            // スタックトップが左括弧
                            // スタックトップを取り出す
                            _ = stack.pop();
                            break;
                        }
                    }
                }
            },
        }

        debug.end("process");
    }

    debug.print("read token: none\n", .{});
    // 入力が終わった

    // スタックに残ったものを順番に出力
    while (stack.pop()) |token| {
        // スタックに左括弧が残っていたら構文エラー
        if (token.is("(")) return error.InvalidSyntax;
        try output.push(allocator, token);
    }

    debug.end("process");

    return output.toTree();
}

test "shunting yard algorithm" {
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
