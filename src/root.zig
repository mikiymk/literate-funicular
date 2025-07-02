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

pub const shunting_yard = @import("./shunting_yard.zig");

test "shunting yard algorithm" {
    const source = "1 + 2 * ( 3 + 4 ) - double ( 1 - 5 ^ 2 )";
    const allocator = testing.allocator;

    var reader = shunting_yard.TokenReader.init(source);
    var output = shunting_yard.OutputQueue.empty;
    defer output.deinit(allocator);

    try shunting_yard.parse(allocator, &reader, &output);
    std.debug.print("output: {}\n", .{output});

    try testing.expectEqual(63, output.result());
}
