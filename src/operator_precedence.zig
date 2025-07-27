//! # 演算子優先順位法
//!
//! 文脈自由文法。ただし、2つの条件を満たす文法のみ
//! - 右側に空がない
//! - 右側に2つの非終端記号が連続していない
//!
//! ## 演算子の優先順位
//!
//! - p ⋖ q - p は q より優先順位が低い。
//! - p ⋗ q - p は q よりも優先されます。
//! - p ≐ q - p は q と同じ優先順位を持つ。
//!
//! ## 演算子優先表の作成
//!
//! 1. Aの優先順位 > Bの優先順位ならば、`A ⋗ B`かつ`B ⋖ A`。 (Aが優先)
//! 2. Aの優先順位 = Bの優先順位のとき、
//!    - 左結合ならば、`A ⋗ B`かつ`B ⋗ A`。 (左側が優先)
//!    - 右結合ならば、`A ⋖ B`かつ`B ⋖ A`。 (右側が優先)
//! 3. id は最も高い優先順位を持つ。
//!    - `A ⋖ id`かつ`id ⋗ A`。
//!    - `( ⋖ id`かつ`id ⋗ )`。
//!    - `$ ⋖ id`かつ`id ⋗ $`。
//! 4. $ は最も低い優先順位を持つ。
//!    - `$ ⋖ A`かつ`A ⋗ $`。
//!    - `$ ⋖ (`かつ`) ⋗ $`。
//! 5. 括弧の優先順位
//!    - `A ⋖ (`かつ`( ⋖ A`。 (左側が優先)
//!    - `) ⋗ A`かつ`A ⋗ )`。 (右側が優先)
//!    - `( ≐ )`
//!    - `( ⋖ (`かつ`) ⋗ )`。 (内側が優先)
//!
//! ## 優先順位関数
//!
//! それぞれの終端記号について、条件を満たす関数 f と g を定義する。
//!
//! - `a ⋖ b` のとき、`f(a) < g(b)`
//! - `a ≐ b` のとき、`f(a) = g(b)`
//! - `a ⋗ b` のとき、`f(a) > g(b)`
//!
//! 1. グラフを作成する。
//!    1. 各 `f(a)` と `g(a)` のノードを作成する。
//!    2. `a ≐ b` のとき、 `f(a)` と `g(b)` は同一ノードになる。
//!    3. `a ≐ b` かつ `c ≐ b` のとき、 `f(a)` と `f(c)` は同一ノードになる。
//!    4. `a ⋖ b` のとき、 `g(b)` から `f(a)` への辺を追加する。
//!    5. `a ⋗ b` のとき、 `f(a)` から `g(b)` への辺を追加する。
//! 2. グラフがサイクルを持つ場合、優先順位関数は存在しない。
//! 3. グラフがサイクルを持たない場合
//!    - `f(a) = f(a) を含むノードからの最長パス`
//!    - `g(a) = g(a) を含むノードからの最長パス`

const std = @import("std");
const Allocator = std.mem.Allocator;

const utils = @import("./util.zig");

const Token = utils.Language1.Token;
const TokenReader = utils.Language1.TokenReader;
const ParseTree = utils.Language1.ParseTree;
const ParseError = utils.Language1.ParseError;
const debug = utils.debug;

pub fn parse(a: Allocator, source: []const u8) !ParseTree {
    _ = source;
    _ = operator_precedence_table;
    _ = operatorPrecedenceTable;

    _ = createOperatorPrecedenceTable(a, &.{});

    return error.NotImplemented;
}

const OperatorType = enum {
    id,
    /// +, -
    add_sub,
    /// *, /
    mul_div,
    /// ^
    pow,
    /// (
    left_paren,
    /// )
    right_paren,
    /// $ (言語の先頭と終端につける記号)
    end,

    pub fn format(self: @This(), comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        switch (self) {
            .id => try writer.writeAll("id"),
            .add_sub => try writer.writeAll("+, -"),
            .mul_div => try writer.writeAll("*, /"),
            .pow => try writer.writeAll("^"),
            .left_paren => try writer.writeAll("("),
            .right_paren => try writer.writeAll(")"),
            .end => try writer.writeAll("$"),
        }
    }
};

const Precedence = enum {
    /// `p q` p と q は優先順位を持たない。
    none,
    /// `p ⋗ q` p は q よりも優先される。
    left,
    /// `p ⋖ q` p は q よりも優先されない。
    right,
    /// `p ≐ q` p は q と同じ優先順位を持つ。
    same,

    pub fn format(self: @This(), comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        switch (self) {
            .left => try writer.writeAll("⋗"),
            .right => try writer.writeAll("⋖"),
            .same => try writer.writeAll("≐"),
        }
    }
};

const OperatorPrecedenceTable = struct {
    const length: usize = @typeInfo(OperatorType).@"enum".fields.len;

    precedence_array: [length * length]Precedence,

    fn indexOf(left: OperatorType, right: OperatorType) usize {
        return @intFromEnum(left) * length + @intFromEnum(right);
    }

    fn set(self: *OperatorPrecedenceTable, left: OperatorType, right: OperatorType, precedence: Precedence) void {
        self.precedence_array[indexOf(left, right)] = precedence;
    }

    fn get(self: OperatorPrecedenceTable, left: OperatorType, right: OperatorType) Precedence {
        return self.precedence_array[indexOf(left, right)];
    }
};

const OperatorDefine = struct {
    name: []const u8,
    type: enum { operator, id, left_paren, right_paren, end },
    associative: ?enum { left, right } = null,
    precedence: ?usize = null,
};

fn createOperatorPrecedenceTable(a: Allocator, operators: []const OperatorDefine) OperatorPrecedenceTable {
    _ = a;
    _ = operators;
    return undefined;
}

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
const operator_precedence_table = blk: {
    var table: OperatorPrecedenceTable = undefined;

    table.set(.id, .id, .none);
    table.set(.id, .add_sub, .left);
    table.set(.id, .mul_div, .left);
    table.set(.id, .pow, .left);
    table.set(.id, .left_paren, .none);
    table.set(.id, .right_paren, .left);
    table.set(.id, .end, .left);

    table.set(.add_sub, .id, .right);
    table.set(.add_sub, .add_sub, .left);
    table.set(.add_sub, .mul_div, .right);
    table.set(.add_sub, .pow, .right);
    table.set(.add_sub, .left_paren, .right);
    table.set(.add_sub, .right_paren, .left);
    table.set(.add_sub, .end, .left);

    table.set(.mul_div, .id, .right);
    table.set(.mul_div, .add_sub, .left);
    table.set(.mul_div, .mul_div, .left);
    table.set(.mul_div, .pow, .right);
    table.set(.mul_div, .left_paren, .right);
    table.set(.mul_div, .right_paren, .left);
    table.set(.mul_div, .end, .left);

    table.set(.pow, .id, .right);
    table.set(.pow, .add_sub, .left);
    table.set(.pow, .mul_div, .left);
    table.set(.pow, .pow, .right);
    table.set(.pow, .left_paren, .right);
    table.set(.pow, .right_paren, .left);
    table.set(.pow, .end, .left);

    table.set(.left_paren, .id, .right);
    table.set(.left_paren, .add_sub, .right);
    table.set(.left_paren, .mul_div, .right);
    table.set(.left_paren, .pow, .right);
    table.set(.left_paren, .left_paren, .right);
    table.set(.left_paren, .right_paren, .same);
    table.set(.left_paren, .end, .none);

    table.set(.right_paren, .id, .none);
    table.set(.right_paren, .add_sub, .left);
    table.set(.right_paren, .mul_div, .left);
    table.set(.right_paren, .pow, .left);
    table.set(.right_paren, .left_paren, .none);
    table.set(.right_paren, .right_paren, .left);
    table.set(.right_paren, .end, .left);

    table.set(.right_paren, .id, .right);
    table.set(.right_paren, .add_sub, .right);
    table.set(.right_paren, .mul_div, .right);
    table.set(.right_paren, .pow, .right);
    table.set(.right_paren, .left_paren, .right);
    table.set(.right_paren, .right_paren, .none);
    table.set(.right_paren, .end, .none);

    break :blk table;
};

fn operatorPrecedenceTable(left: OperatorType, right: OperatorType) Precedence {
    return operator_precedence_table.get(left, right);
}

const PrecedenceFunctions = struct {
    const length: usize = @typeInfo(OperatorType).@"enum".fields.len;

    left_precedences: [length]usize,
    right_precedences: [length]usize,
};

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
