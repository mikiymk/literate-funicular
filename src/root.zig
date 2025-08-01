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

/// テーブルを使う
pub const operator_precedence = @import("./operator_precedence.zig");

test {
    _ = shunting_yard;
    _ = recursive_descent;
    _ = recursive_descent_loop;
    _ = precedence_climb;
    _ = operator_precedence;
}

pub fn callParse() !void {
    const utils = @import("./util.zig");
    const ParseFn = *const fn (a: std.mem.Allocator, source: []const u8) utils.Language1.ParseError!utils.Language1.ParseTree;
    const parse_fns = [_]ParseFn{
        shunting_yard.parse,
        recursive_descent.parse,
        recursive_descent_loop.parse,
        precedence_climb.parse,
        operator_precedence.parse,
    };
    const test_cases = utils.Language1.test_cases;
    utils.debug.enabled = true;

    const allocator = std.heap.page_allocator;

    for (parse_fns) |parse_fn| {
        for (test_cases) |test_case| {
            const source = test_case.source;
            const expected = test_case.expected;

            utils.debug.print("source  : {s}", .{source});

            var result = try parse_fn(allocator, source);
            defer result.deinit(allocator);

            const result_string = try std.fmt.allocPrint(allocator, "{}", .{result});
            defer allocator.free(result_string);

            utils.debug.print("expected: {s}", .{expected});
            utils.debug.print("result  : {s}", .{result_string});
        }
    }
}
