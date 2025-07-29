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
const Array = std.ArrayListUnmanaged;

const utils = @import("./util.zig");

const Token = utils.Language1.Token;
const TokenReader = utils.Language1.TokenReader;
const ParseTree = utils.Language1.ParseTree;
const ParseError = utils.Language1.ParseError;
const debug = utils.debug;

pub fn parse(a: Allocator, source: []const u8) !ParseTree {
    _ = source;

    const defines = [_]operator_precedence.Define{
        .{ .name = "id", .type = .id },
        .{ .name = "+", .type = .{ .operator = .{ .associative = .left, .precedence = 10 } } },
        .{ .name = "-", .type = .{ .operator = .{ .associative = .left, .precedence = 10 } } },
        .{ .name = "*", .type = .{ .operator = .{ .associative = .left, .precedence = 20 } } },
        .{ .name = "/", .type = .{ .operator = .{ .associative = .left, .precedence = 20 } } },
        .{ .name = "^", .type = .{ .operator = .{ .associative = .right, .precedence = 30 } } },
        .{ .name = "(", .type = .{ .left_paren = .{ .right = ")" } } },
        .{ .name = ")", .type = .{ .right_paren = .{ .left = "(" } } },
        .{ .name = "$", .type = .end },
    };
    const table = try operator_precedence.create(a, &defines);
    _ = table;

    return error.NotImplemented;
}
const operator_precedence = struct {
    const OperatorKind = union(enum) {
        id: void,
        operator: struct {
            associative: enum { left, right },
            precedence: usize,
        },
        left_paren: struct { right: []const u8 },
        right_paren: struct { left: []const u8 },
        end: void,
    };

    const Prec = enum {
        none,
        /// - LOWER_PRECEDENCE: ⋖ (優先順位を譲る)
        lower,
        /// - EQUAL_PRECEDENCE: ≐ (同じ優先順位)
        equal,
        /// - HIGHER_PRECEDENCE: ⋗ (優先順位が高い)
        higher,

        fn symbol(self: @This()) []const u8 {
            return switch (self) {
                .none => "",
                .lower => "⋖",
                .equal => "≐",
                .higher => "⋗",
            };
        }

        pub fn format(self: @This(), comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
            try writer.writeAll(self.symbol());
        }
    };

    const Define = struct {
        name: []const u8,
        type: OperatorKind,
    };

    fn create(a: Allocator, operators: []const Define) !OperatorPrecedenceTable {
        debug.begin("create operator precedence table");

        debug.begin("create precedence table");
        const table = try a.alloc(TableItem, operators.len * operators.len);
        defer a.free(table);

        for (operators, 0..) |left, left_idx| {
            for (operators, 0..) |right, right_idx| {
                const idx = left_idx * operators.len + right_idx;
                table[idx] = .{
                    &left,
                    &right,
                    try precedenceFromOperatorKind(left.type, right.type),
                };
            }
        }

        printTable(operators, table);
        debug.end("create precedence table");

        debug.begin("create precedence graph");
        var graph = try Graph.init(a, operators);
        defer graph.deinit(a);

        // debug.print("{any}\n", .{graph});
        for (graph.nodes.items) |node| {
            debug.print("{}\n", .{node});
        }
        // printGraph(graph);

        for (operators) |op| {
            debug.print("{s}", .{op.name});
        }
        if (true) return error.E;

        var left_array = Array(struct { *const Define, Array(*const Define) }).empty;
        var right_array = Array(struct { *const Define, Array(*const Define) }).empty;
        for (table) |table_item| {
            const left, const right, const prec = table_item;
            switch (prec) {
                .none => {},
                .equal => {
                    try graph.unions(a, .{ .f = left }, .{ .g = right });
                    for (left_array.items) |*left_item| {
                        if (left_item[0] == left) {
                            try left_item[1].append(a, right);
                            break;
                        }
                    } else {
                        try left_array.append(a, .{ left, .empty });
                    }
                    for (right_array.items) |*right_item| {
                        if (right_item[0] == right) {
                            try right_item[1].append(a, left);
                            break;
                        }
                    } else {
                        try right_array.append(a, .{ right, .empty });
                    }
                },
                .higher => try graph.addEdge(a, .{ .f = left }, .{ .g = right }),
                .lower => try graph.addEdge(a, .{ .g = left }, .{ .f = right }),
            }
        }

        printGraph(graph);

        debug.end("create precedence graph");

        debug.end("create operator precedence table");
        return undefined;
    }

    const TableItem = struct { *const Define, *const Define, Prec };

    const NodeSymbol = union(enum) {
        f: *const Define,
        g: *const Define,

        fn equals(self: NodeSymbol, other: NodeSymbol) bool {
            return (self == .f and other == .f and self.f == other.f) or
                (self == .g and other == .g and self.g == other.g);
        }

        pub fn format(self: NodeSymbol, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
            switch (self) {
                .f => try writer.print("f({s})", .{self.f.name}),
                .g => try writer.print("g({s})", .{self.g.name}),
            }
        }
    };

    const Node = struct {
        symbols: Array(NodeSymbol),
        links: Array(*Node) = .empty,

        fn init(a: Allocator, symbol: NodeSymbol) !Node {
            var symbols = Array(NodeSymbol).empty;
            try symbols.append(a, symbol);
            return .{ .symbols = symbols };
        }

        pub fn format(self: Node, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
            try writer.writeAll("Node:");
            for (self.symbols.items) |symbol| {
                try writer.print(" {}", .{symbol});
            }
            try writer.writeAll("->");
            for (self.links.items) |node| {
                try writer.print(" {*}", .{node});
            }
        }
    };

    const Graph = struct {
        nodes: Array(Node),

        fn init(a: Allocator, operators: []const Define) !Graph {
            var nodes = Array(Node).empty;
            for (operators) |op| {
                try nodes.append(a, try Node.init(a, .{ .f = &op }));
                try nodes.append(a, try Node.init(a, .{ .g = &op }));
            }

            return .{ .nodes = nodes };
        }

        fn deinit(self: *Graph, a: Allocator) void {
            for (self.nodes.items) |*node| {
                node.symbols.deinit(a);
                node.links.deinit(a);
            }
            self.nodes.deinit(a);
        }

        fn get(self: Graph, symbol: NodeSymbol) *Node {
            for (self.nodes.items) |*node| {
                for (node.symbols.items) |s| {
                    if (s.equals(symbol)) {
                        return node;
                    }
                }
            }

            unreachable;
        }

        fn unions(self: *Graph, a: Allocator, left: NodeSymbol, right: NodeSymbol) !void {
            const left_node = self.get(left);
            const right_node = self.get(right);

            for (right_node.symbols.items) |symbol| {
                try left_node.symbols.append(a, symbol);
            }
            for (right_node.links.items) |link| {
                try left_node.links.append(a, link);
            }

            for (self.nodes.items) |*node| {
                for (node.links.items) |*link| {
                    if (link.* == right_node) {
                        link.* = left_node;
                    }
                }
            }
        }

        fn addEdge(self: *Graph, a: Allocator, left: NodeSymbol, right: NodeSymbol) !void {
            const left_node = self.get(left);
            const right_node = self.get(right);

            try left_node.links.append(a, right_node);
        }
    };

    fn precedenceFromOperatorKind(left: OperatorKind, right: OperatorKind) !Prec {
        return switch (left) {
            .id => switch (right) {
                .id => .none, // l:id ≠ r:id
                .left_paren => .none, // l:id ≠ r:(
                .operator, .right_paren, .end => .higher, // l:id ⋗ r:others
            },
            .operator => |left_op| switch (right) {
                .id => .lower, // l:op ⋖ r:id
                .operator => |right_op| switch (std.math.order(left_op.precedence, right_op.precedence)) {
                    .gt => .higher, // l:op ⋗ r:op
                    .lt => .lower, // l:op ⋖ r:op
                    .eq => if (left_op.associative == right_op.associative)
                        switch (left_op.associative) {
                            .left => .higher, // l:op ⋗ r:op
                            .right => .lower, // l:op ⋖ r:op
                        }
                    else
                        error.InvalidGrammar,
                },
                .left_paren => .lower, // l:op ⋖ r:(
                .right_paren => .higher, // l:op ⋗ r
                .end => .higher, // l:op ⋗ r:$
            },
            .left_paren => switch (right) {
                .id => .lower, // l:( ⋖ r:id
                .operator => .lower, // l:( ⋖ r:op
                .left_paren => .lower, // l:( ⋖ r:(
                .right_paren => .equal, // l:( ≐ r:)
                .end => .none, // l:( ≠ r:$
            },
            .right_paren => switch (right) {
                .id => .none, // l:) ≠ r:id
                .operator => .higher, // l:) ⋗ r:op
                .left_paren => .none, // l:) ≠ r:(
                .right_paren => .higher, // l:) ⋗ r:)
                .end => .higher, // l:) ⋗ r:$
            },
            .end => switch (right) {
                .id => .lower, // l:$ ⋖ r:id
                .operator => .lower, // l:$ ⋖ r:op
                .left_paren => .lower, // l:$ ⋖ r:(
                .right_paren => .none, // l:$ ≠ r:)
                .end => .none, // l:$ ≠ r:$
            },
        };
    }

    fn printTable(operators: []const Define, table: []const TableItem) void {
        const print = std.debug.print;
        if (debug.enabled) {
            debug.begin("print operator precedence table");
            debug.indent();
            print("   ", .{});
            for (operators) |right| {
                print(" {s: <3}", .{right.name});
            }
            print("\n", .{});

            for (operators, 0..) |left, left_idx| {
                debug.indent();
                print("{s: <3}", .{left.name});
                for (operators, 0..) |_, right_idx| {
                    const idx = left_idx * operators.len + right_idx;
                    print(" {s: <3}", .{table[idx][2].symbol()});
                }
                print("\n", .{});
            }
            debug.end("print operator precedence table");
        }
    }

    fn printGraph(graph: Graph) void {
        const print = std.debug.print;
        if (debug.enabled) {
            debug.begin("print precedence graph");
            for (graph.nodes.items) |node| {
                debug.indent();
                print("node:", .{});
                for (node.symbols.items) |symbol| {
                    print(" {}", .{symbol});
                }
                print("\n", .{});
                for (node.links.items) |link| {
                    debug.indent();
                    print(" ->", .{});
                    for (link.symbols.items) |symbol| {
                        print(" {}", .{symbol});
                    }
                    print("\n", .{});
                }
                print("\n", .{});
            }
            debug.end("print precedence graph");
        }
    }
};

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
    utils.debug.enabled = true;

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
