//! 演算子優先順位法
//!
//! 文脈自由文法。ただし、2つの条件を満たす文法のみ
//! - 右側に空がない
//! - 右側に2つの非終端記号が連続していない

const std = @import("std");
const Allocator = std.mem.Allocator;

const utils = @import("./util.zig");

const Token = utils.Language1.Token;
const TokenReader = utils.Language1.TokenReader;
const Operator = utils.Language1.Operator;
const ParseTree = utils.Language1.ParseTree;
const ParseError = utils.Language1.ParseError;
const debug = utils.debug;

pub fn parse(a: Allocator, source: []const u8) !ParseTree {
    _ = a;
    _ = source;

    return error.NotImplemented;
}

const Precedence = enum {
    /// `p ⋖ q` p は q よりも優先されない。
    Left,
    /// `p ⋗ q` p は q よりも優先される。
    Right,
    /// `p ≐ q` p は q と同じ優先順位を持つ。
    Same,

    pub fn format(self: @This(), comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        switch (self) {
            .Left => try writer.writeAll("⋖"),
            .Right => try writer.writeAll("⋗"),
            .Same => try writer.writeAll("≐"),
        }
    }
};

/// ## 演算子の優先順位
///
/// - p ⋖ q - p は q より優先順位が低い。
/// - p ⋗ q - p は q よりも優先されます。
/// - p ≐ q - p は q と同じ優先順位を持つ。
///
/// ## 演算子優先表の作成
///
/// 1. Aの優先順位 > Bの優先順位ならば、`A ⋗ B`かつ`B ⋖ A`。 (Aが優先)
/// 2. Aの優先順位 = Bの優先順位のとき、
///    - 左結合ならば、`A ⋗ B`かつ`B ⋗ A`。 (左側が優先)
///    - 右結合ならば、`A ⋖ B`かつ`B ⋖ A`。 (右側が優先)
/// 3. id は最も高い優先順位を持つ。
///    - `A ⋖ id`かつ`id ⋗ A`。
///    - `( ⋖ id`かつ`id ⋗ )`。(`id ⋖ (`や`) ⋗ id`ではない。)
///    - `$ ⋖ id`かつ`id ⋗ $`。
/// 4. $ は最も低い優先順位を持つ。
///    - `$ ⋖ A`かつ`A ⋗ $`。
///    - `$ ⋖ (`かつ`) ⋗ $`。
/// 5. 括弧の優先順位
///    - `A ⋖ (`かつ`( ⋖ A`。 (左側が優先)
///    - `) ⋗ A`かつ`A ⋗ )`。 (右側が優先)
///    - `( ≐ )`
///    - `( ⋖ (`かつ`) ⋗ )`。 (内側が優先)
///
/// ## 優先順位表
///
/// `左の記号 op 上の記号`のopの部分。
///
/// |      | id  | +, - | *, / | ^   | (   | )   | $   |
/// | ---- | --- | ---- | ---- | --- | --- | --- | --- |
/// | id   |     | ⋗    | ⋗    | ⋗   |     | ⋗   | ⋗   |
/// | +, - | ⋖   | ⋗    | ⋖    | ⋖   | ⋖   | ⋗   | ⋗   |
/// | *, / | ⋖   | ⋗    | ⋗    | ⋖   | ⋖   | ⋗   | ⋗   |
/// | ^    | ⋖   | ⋗    | ⋗    | ⋖   | ⋖   | ⋗   | ⋗   |
/// | (    | ⋖   | ⋖    | ⋖    | ⋖   | ⋖   | ≐   |     |
/// | )    |     | ⋗    | ⋗    | ⋗   |     | ⋗   | ⋗   |
/// | $    | ⋖   | ⋖    | ⋖    | ⋖   | ⋖   |     | A   |
fn operatorPrecedenceTable(left: Token, right: Token) Precedence {
    _ = left;
    _ = right;
    return .eq;
}

test "operator precedence parsing" {
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
