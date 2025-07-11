const std = @import("std");
const Allocator = std.mem.Allocator;

const utils = @import("./utils.zig");
const OutputQueue = utils.OutputQueue;
const Token = utils.Token;
const TokenReader = utils.TokenReader;
const Stack = utils.Stack;
const debug = utils.debug;

pub fn parse(allocator: Allocator, source: []const u8) !OutputQueue {
    var input = TokenReader.init(source);
    var output = OutputQueue{};
    var stack: Stack = .{};
    defer stack.deinit(allocator);

    debug.begin("parsing");

    while (input.next()) |o1| {
        debug.begin("process");
        debug.print("read token: {}\n", .{o1});

        switch (o1.tokenType()) {
            .number => try output.push(allocator, o1),
            .function => try stack.push(allocator, o1),
            .operator => {
                while (true) {
                    const o2 = stack.get() orelse break;
                    if (o2.tokenType() != .operator) break;
                    const o1_p = o1.precedence();
                    const o2_p = o2.precedence();
                    if (o1_p < o2_p or (o1_p == o2_p and o1.associative() == .left)) {
                        _ = stack.pop();
                        try output.push(allocator, o2);
                    } else {
                        break;
                    }
                }
                try stack.push(allocator, o1);
            },
            .separator => {
                while (true) {
                    const stack_top = stack.get() orelse return error.InvalidSyntax;
                    if (stack_top.is("(")) break;
                    _ = stack.pop();
                    try output.push(allocator, stack_top);
                }
            },
            .parenthesis => {
                if (o1.is("(")) {
                    try stack.push(allocator, o1);
                } else {
                    // )
                    while (true) {
                        const stack_top = stack.get() orelse return error.InvalidSyntax;
                        if (!stack_top.is("(")) {
                            _ = stack.pop();
                            try output.push(allocator, stack_top);
                        } else {
                            _ = stack.pop();
                            break;
                        }
                    }

                    if (stack.get()) |stack_top| {
                        if (stack_top.tokenType() == .function) {
                            _ = stack.pop();
                            try output.push(allocator, stack_top);
                        }
                    }
                }
            },
        }

        debug.end("process");
    }

    debug.print("read token: none\n", .{});

    while (stack.pop()) |token| {
        if (token.is("(")) return error.InvalidSyntax;
        try output.push(allocator, token);
    }

    debug.end("process");

    return output;
}

test "shunting yard algorithm" {
    const allocator = std.testing.allocator;
    utils.debug.enabled = false;

    {
        const source = "1 + 2 * ( 3 - 4 )";
        var result = try parse(allocator, source);
        defer result.deinit(allocator);

        const result_string = try std.fmt.allocPrint(allocator, "{}", .{result});
        defer allocator.free(result_string);

        try std.testing.expectEqualStrings(
            \\1, 2, 3, 4, "-", "*", "+"
        , result_string);
    }

    {
        const source = "1 + 2 + 3 - 4 + 5";
        var result = try parse(allocator, source);
        defer result.deinit(allocator);

        const result_string = try std.fmt.allocPrint(allocator, "{}", .{result});
        defer allocator.free(result_string);

        try std.testing.expectEqualStrings(
            \\1, 2, "+", 3, "+", 4, "-", 5, "+"
        , result_string);
    }

    {
        const source = "a ( b ( c ( d ( e ( f ( g ( 0 ) ) ) ) ) ) )";
        var result = try parse(allocator, source);
        defer result.deinit(allocator);

        const result_string = try std.fmt.allocPrint(allocator, "{}", .{result});
        defer allocator.free(result_string);

        try std.testing.expectEqualStrings(
            \\0, g, f, e, d, c, b, a
        , result_string);
    }
}
