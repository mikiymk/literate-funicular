const std = @import("std");

const Allocator = std.mem.Allocator;

fn ArrayFormat(T: type) type {
    return struct {
        array: std.ArrayListUnmanaged(T) = .empty,

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
}

fn arrayFormat(comptime T: type, array: std.ArrayListUnmanaged(T)) ArrayFormat(T) {
    return .{ .array = array };
}

const Token = union(enum) {
    number: i32,
    function: Function,
    operator: Operator,
    separator: void,
    parenthesis: Parenthesis,

    const Function = struct {
        value: []const u8,

        fn argLength(self: Function) u8 {
            if (std.mem.eql(u8, self.value, "double")) {
                return 1;
            }

            return 1;
        }

        fn execute(self: Function, args: []const i32) i32 {
            if (std.mem.eql(u8, self.value, "double")) {
                return args[0] * 2;
            }
            return args[0];
        }
    };

    const Operator = enum {
        add,
        sub,
        mul,
        div,
        pow,

        fn init(c: u8) Operator {
            return switch (c) {
                '+' => .add,
                '-' => .sub,
                '*' => .mul,
                '/' => .div,
                '^' => .pow,
                else => unreachable,
            };
        }

        const operator_priority = std.EnumArray(Operator, u8).init(
            .{ .add = 1, .sub = 1, .mul = 2, .div = 2, .pow = 3 },
        );

        fn compare(self: Operator, other: Operator) std.math.Order {
            return std.math.order(operator_priority.get(self), operator_priority.get(other));
        }

        fn leftAssociative(self: Operator) bool {
            return self == .pow;
        }

        fn execute(self: Operator, left: i32, right: i32) i32 {
            switch (self) {
                .add => return left + right,
                .sub => return left - right,
                .mul => return left * right,
                .div => return @divFloor(left, right),
                .pow => return std.math.pow(i32, left, right),
            }
        }

        pub fn format(self: @This(), comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
            switch (self) {
                .add => try writer.print("+", .{}),
                .sub => try writer.print("-", .{}),
                .mul => try writer.print("*", .{}),
                .div => try writer.print("/", .{}),
                .pow => try writer.print("^", .{}),
            }
        }
    };

    const Parenthesis = enum {
        left_parenthesis,
        right_parenthesis,

        pub fn format(self: @This(), comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
            switch (self) {
                .left_parenthesis => try writer.print("(", .{}),
                .right_parenthesis => try writer.print(")", .{}),
            }
        }
    };

    fn init(token_string: []const u8) Token {
        return switch (token_string[0]) {
            '0'...'9' => .{ .number = std.fmt.parseUnsigned(i32, token_string, 10) catch unreachable },
            '+', '-', '*', '/', '^' => .{ .operator = Operator.init(token_string[0]) },
            '(' => .{ .parenthesis = .left_parenthesis },
            ')' => .{ .parenthesis = .right_parenthesis },
            ',' => .{ .separator = void{} },
            else => .{ .function = .{ .value = token_string } },
        };
    }

    pub fn format(self: @This(), comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        switch (self) {
            .number => |value| try writer.print("{d}", .{value}),
            .function => |value| try writer.print("\"{s}\"", .{value.value}),
            .separator => try writer.print("\",\"", .{}),
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
        std.debug.print("  output: {}\n", .{token});

        switch (token) {
            .number => |value| try self.array.append(allocator, value),
            .function => |value| {
                var args = std.ArrayListUnmanaged(i32).empty;
                defer args.deinit(allocator);
                for (0..value.argLength()) |_| {
                    const arg = self.array.pop() orelse unreachable;
                    try args.append(allocator, arg);
                }
                const res = value.execute(args.allocatedSlice());
                try self.array.append(allocator, res);
            },
            .operator => |value| {
                const right = self.array.pop() orelse unreachable;
                const left = self.array.pop() orelse unreachable;
                try self.array.append(allocator, value.execute(left, right));
            },
            else => unreachable,
        }

        std.debug.print("  output stack: {}\n", .{arrayFormat(i32, self.array)});
    }

    pub fn result(self: OutputQueue) i32 {
        if (self.array.items.len != 1) {
            @panic("invalid expression");
        }
        return self.array.items[0];
    }

    pub fn format(self: @This(), comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        return writer.print("{}", .{arrayFormat(i32, self.array)});
    }
};

const Stack = struct {
    array: std.ArrayListUnmanaged(Token) = .empty,

    fn deinit(self: *Stack, allocator: Allocator) void {
        self.array.deinit(allocator);
    }

    fn push(self: *Stack, allocator: Allocator, token: Token) !void {
        std.debug.print("  stack push: {} + {}\n", .{ self, token });
        try self.array.append(allocator, token);
    }

    fn pop(self: *Stack) ?Token {
        const token = self.array.pop();
        std.debug.print("  stack pop: {} - {?}\n", .{ self, token });
        return token;
    }

    fn get(self: Stack) Token {
        return self.array.getLast();
    }

    fn getOrNull(self: Stack) ?Token {
        return self.array.getLastOrNull();
    }

    pub fn format(self: @This(), comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        return writer.print("{}", .{arrayFormat(Token, self.array)});
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
            .separator => {
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
            .parenthesis => |parenthesis| {
                if (parenthesis == .left_parenthesis) {
                    try stack.push(allocator, token);
                    continue;
                }

                while (true) {
                    const stack_top = stack.getOrNull() orelse {
                        @panic("mismatched parentheses");
                    };

                    if (stack_top != .parenthesis or stack_top.parenthesis != .left_parenthesis) {
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
        if (token == .parenthesis and token.parenthesis == .left_parenthesis) {
            @panic("mismatched parentheses");
        }
        try output.push(allocator, token);
    }

    std.debug.print("end parsing\n", .{});

    stack.deinit(allocator);
}
