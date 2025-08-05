//! By convention, root.zig is the root source file when making a library. If
//! you are making an executable, the convention is to delete this file and
//! start with main.zig instead.

const std = @import("std");
const testing = std.testing;

pub const utils = @import("./util.zig");

/// 再帰下降構文解析法
pub const recursive_descent = @import("./recursive_descent.zig");

/// ループを使用した再帰下降構文解析法
pub const recursive_descent_loop = @import("./recursive_descent_loop.zig");

/// ダイクストラの操車場アルゴリズム
pub const shunting_yard = @import("./shunting_yard.zig");

/// 優先順位上昇法
pub const precedence_climb = @import("./precedence_climb.zig");

/// テーブルを使う
pub const operator_precedence = @import("./operator_precedence.zig");

pub const ll_1 = @import("./ll_1.zig");

test {
    _ = shunting_yard;
    _ = recursive_descent;
    _ = recursive_descent_loop;
    _ = precedence_climb;
    _ = operator_precedence;
    _ = ll_1;

    _ = utils.Language1;
    _ = utils.Stack;
    _ = utils.Queue;
    _ = utils.Set;
    _ = utils.AutoSet;
    _ = utils.Map;
    _ = utils.AutoMap;
}

pub const ParseFn = *const fn (a: std.mem.Allocator, source: []const u8) utils.Language1.ParseError!utils.Language1.ParseTree;
pub const parse_fns = [_]ParseFn{
    // shunting_yard.parse,
    // recursive_descent.parse,
    // recursive_descent_loop.parse,
    // precedence_climb.parse,
    // operator_precedence.parse,
    ll_1.parse,
};
