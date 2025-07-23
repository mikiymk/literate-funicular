const std = @import("std");
const Allocator = std.mem.Allocator;

const utils = @import("./util.zig");

const TokenReader = utils.Language1.TokenReader;
const Operator = utils.Language1.Operator;
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

// parse_expression()
//     return parse_expression_1(parse_primary(), 0)
fn parseExpr(a: Allocator, input: *TokenReader) ParseError!ParseTree {
    return parseExpr1(a, input, try parsePrim(a, input), 0);
}

// parse_expression_1(lhs, min_precedence)
fn parseExpr1(a: Allocator, input: *TokenReader, lhs: ParseTree, min_precedence: u8) ParseError!ParseTree {
    var lhs_tree = lhs;

    // lookahead := peek next token
    var lookahead = input.peek();

    // while lookahead is a binary operator whose precedence is >= min_precedence
    while (lookahead) |la| {
        if (!(la.tokenType() == .operator and la.precedence() >= min_precedence)) break;

        //     op := lookahead
        const op = la;

        //     advance to next token
        _ = input.next();

        //     rhs := parse_primary ()
        var rhs_tree = try parsePrim(a, input);

        //     lookahead := peek next token
        lookahead = input.peek();

        //     while lookahead is a binary operator whose precedence is greater
        //                 than op's, or a right-associative operator
        //                 whose precedence is equal to op's
        while (lookahead) |la2| {
            if (!(la2.tokenType() == .operator and
                (la2.precedence() > op.precedence() or
                    (la2.precedence() == op.precedence() and
                        la2.associative() == .right)))) break;

            //         rhs := parse_expression_1 (rhs, precedence of op + (1 if lookahead precedence is greater, else 0))
            var precedence = op.precedence();
            if (la2.precedence() > op.precedence()) precedence += 1;
            rhs_tree = try parseExpr1(a, input, rhs_tree, precedence);

            //         lookahead := peek next token
            lookahead = input.peek();
        }

        //     lhs := the result of applying op with operands lhs and rhs
        lhs_tree = try ParseTree.initOperator(a, lhs_tree, rhs_tree, op.toOperator());
    }

    // return lhs
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
            tree = .{ .num = token };
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

    debug.print("tree: {}\n", .{tree});
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
