const std = @import("std");

const Allocator = std.mem.Allocator;

const Token = union(enum) {
    number: i32,
    function: []const u8,
    operator: Operator,
    comma: []const u8,
    left_parenthesis: []const u8,
    right_parenthesis: []const u8,

    const Operator = struct {
        value: []const u8,

        const operator_priority = std.StaticStringMap(u8).initComptime(
            .{
                .{ "+", 1 },
                .{ "-", 1 },
                .{ "*", 2 },
                .{ "/", 2 },
                .{ "^", 3 },
            },
        );

        fn compare(self: Operator, other: Operator) std.math.Order {
            return std.math.order(
                operator_priority.get(self.value) orelse unreachable,
                operator_priority.get(other.value) orelse unreachable,
            );
        }

        fn leftAssociative(self: Operator) bool {
            return std.mem.eql(u8, self.value, "^");
        }
    };

    fn init(token_string: []const u8) Token {
        return switch (token_string[0]) {
            '0'...'9' => .{ .number = std.fmt.parseUnsigned(i32, token_string, 10) catch unreachable },
            '+', '-', '*', '/', '^' => .{ .operator = .{ .value = token_string } },
            '(' => .{ .left_parenthesis = token_string },
            ')' => .{ .right_parenthesis = token_string },
            ',' => .{ .comma = token_string },
            else => .{ .function = token_string },
        };
    }

    pub fn format(self: @This(), comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        switch (self) {
            .number => |value| try writer.print("{d}", .{value}),
            .operator => |value| try writer.print("\"{s}\"", .{value.value}),
            inline else => |value| try writer.print("\"{s}\"", .{value}),
        }
    }
};

pub const TokenReader = struct {
    tokens: std.mem.SplitIterator(u8, .scalar),

    pub fn init(source: []const u8) TokenReader {
        return .{
            .tokens = std.mem.splitScalar(u8, source, ' '),
        };
    }

    fn read(self: *TokenReader) ?Token {
        const token = self.tokens.next() orelse return null;
        return Token.init(token);
    }
};

pub const OutputQueue = struct {
    array: std.ArrayListUnmanaged(i32) = .empty,

    pub const empty: OutputQueue = .{};

    pub fn deinit(self: *OutputQueue, allocator: Allocator) void {
        self.array.deinit(allocator);
    }

    fn push(self: *OutputQueue, allocator: Allocator, token: Token) !void {
        std.debug.print("   output: {}\n", .{token});

        switch (token) {
            .number => |value| try self.array.append(allocator, value),
            .function => |value| {
                if (std.mem.eql(u8, value, "sin")) {
                    const arg = self.array.pop() orelse unreachable;

                    const sine: i32 = @intFromFloat(@floor(@sin(@as(f32, @floatFromInt(arg)))));
                    try self.array.append(allocator, sine);
                }
            },
            .operator => |value| {
                const right = self.array.pop() orelse unreachable;
                const left = self.array.pop() orelse unreachable;

                switch (value.value[0]) {
                    '+' => try self.array.append(allocator, left + right),
                    '-' => try self.array.append(allocator, left - right),
                    '*' => try self.array.append(allocator, left * right),
                    '/' => try self.array.append(allocator, @divFloor(left, right)),
                    '^' => try self.array.append(allocator, std.math.pow(i32, left, right)),
                    else => unreachable,
                }
            },
            else => unreachable,
        }
    }

    pub fn result(self: OutputQueue) i32 {
        if (self.array.items.len != 1) {
            @panic("invalid expression");
        }

        return self.array.items[0];
    }

    pub fn format(self: @This(), comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        var follow = false;
        for (self.array.items) |item| {
            if (follow) {
                try writer.print(", ", .{});
            }
            try writer.print("{}", .{item});
            follow = true;
        }
    }
};

const Stack = struct {
    array: std.ArrayListUnmanaged(Token) = .empty,

    fn deinit(self: *Stack, allocator: Allocator) void {
        self.array.deinit(allocator);
    }

    fn push(self: *Stack, allocator: Allocator, token: Token) !void {
        std.debug.print("   stack push: {} + {}\n", .{ self, token });

        try self.array.append(allocator, token);
    }

    fn pop(self: *Stack) ?Token {
        const token = self.array.pop();

        std.debug.print("   stack pop: {} - {?}\n", .{ self, token });

        return token;
    }

    fn get(self: Stack) Token {
        return self.array.getLast();
    }

    fn getOrNull(self: Stack) ?Token {
        return self.array.getLastOrNull();
    }

    pub fn format(self: @This(), comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        var follow = false;
        for (self.array.items) |item| {
            if (follow) {
                try writer.print(", ", .{});
            }
            try writer.print("{}", .{item});
            follow = true;
        }
    }
};

pub fn parse(allocator: Allocator, input: *TokenReader, output: *OutputQueue) !void {
    var stack: Stack = .{};

    std.debug.print("start parsing\n", .{});
    while (input.read()) |token| {
        std.debug.print("read token: {}\n", .{token});

        switch (token) {
            .number => {
                try output.push(allocator, token);
            },
            .function => {
                try stack.push(allocator, token);
            },
            .operator => |op| {
                while (true) {
                    const top = stack.getOrNull() orelse break;
                    if (top == .operator) {
                        const top_op = top.operator;
                        if (top_op.compare(op) == .gt or (top_op.compare(op) == .eq and op.leftAssociative())) {
                            _ = stack.pop();
                            try output.push(allocator, top);
                            continue;
                        }
                    }
                    break;
                }
                try stack.push(allocator, token);
            },
            .comma => {
                while (true) {
                    const stack_top = stack.get();
                    if (stack_top == .operator) {
                        _ = stack.pop();
                        try output.push(allocator, stack_top);
                    } else {
                        break;
                    }
                }
            },
            .left_parenthesis => try stack.push(allocator, token),
            .right_parenthesis => {
                while (true) {
                    const stack_top = stack.getOrNull() orelse {
                        @panic("mismatched parentheses");
                    };

                    if (stack_top != .left_parenthesis) {
                        _ = stack.pop();
                        try output.push(allocator, stack_top);
                    } else {
                        _ = stack.pop();
                        break;
                    }
                }

                {
                    const stack_top = stack.get();
                    if (stack_top == .function) {
                        _ = stack.pop();
                        try output.push(allocator, stack_top);
                    }
                }
            },
        }
    }
    std.debug.print("read token: none\n", .{});

    while (stack.pop()) |token| {
        if (token == .left_parenthesis) {
            @panic("mismatched parentheses");
        }
        try output.push(allocator, token);
    }

    std.debug.print("end parsing\n", .{});

    stack.deinit(allocator);
}
