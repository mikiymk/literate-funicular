//! By convention, root.zig is the root source file when making a library. If
//! you are making an executable, the convention is to delete this file and
//! start with main.zig instead.

const std = @import("std");
const testing = std.testing;

pub export fn add(a: i32, b: i32) i32 {
    return a + b;
}

test "basic add functionality" {
    try testing.expect(add(3, 7) == 10);
}

/// 再帰下降構文解析法
pub const recursive_descent = @import("./recursive_descent.zig");

/// ループを使用した再帰下降構文解析法
pub const recursive_descent_loop = @import("./recursive_descent_loop.zig");

/// ダイクストラの操車場アルゴリズム
pub const shunting_yard = @import("./shunting_yard.zig");

/// 優先順位上昇法
pub const precedence_climb = @import("./precedence_climb.zig");

// テーブルを使う

pub const operator_precedence = @import("./operator_precedence.zig");

test {
    _ = shunting_yard;
    _ = recursive_descent;
    _ = recursive_descent_loop;
    _ = precedence_climb;
}
