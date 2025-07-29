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

    const defines = [_]Define{
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
    const table = try Table.init(a, &defines);
    _ = table;

    return error.NotImplemented;
}

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

    fn name(self: @This()) []const u8 {
        return switch (self) {
            .none => "",
            .lower => "⋖",
            .equal => "≐",
            .higher => "⋗",
        };
    }

    pub fn format(self: @This(), comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        try writer.writeAll(self.name());
    }
};

const Define = struct {
    name: []const u8,
    type: OperatorKind,
};

const Table = struct {
    fn init(a: Allocator, operators: []const Define) !Table {
        for (operators) |*operator| {
            debug.print("{*}: {s}", .{ operator, operator.name });
        }

        debug.begin("create operator precedence table");

        const table = try RelationTable.init(a, operators);
        defer table.deinit(a);
        table.print();

        debug.begin("create precedence graph");
        var graph = try Graph.init(a, table);
        defer graph.deinit(a);

        graph.print();

        debug.end("create precedence graph");

        debug.end("create operator precedence table");
        return undefined;
    }
};

/// n * n の表の優先順位表
const RelationTable = struct {
    const Item = struct {
        left: *const Define,
        right: *const Define,
        precedence: Prec,
    };

    operators: []const Define,
    items: []const Item,

    fn init(a: Allocator, operators: []const Define) !RelationTable {
        debug.begin("create precedence table");
        const table = try a.alloc(Item, operators.len * operators.len);

        for (operators, 0..) |*left, left_idx| {
            for (operators, 0..) |*right, right_idx| {
                const idx = left_idx * operators.len + right_idx;
                table[idx] = .{
                    .left = left,
                    .right = right,
                    .precedence = try precedenceFromOperatorKind(left.type, right.type),
                };
            }
        }

        debug.end("create precedence table");
        return .{
            .items = table,
            .operators = operators,
        };
    }

    fn deinit(self: RelationTable, a: Allocator) void {
        a.free(self.items);
    }

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

    fn print(self: RelationTable) void {
        if (debug.enabled) {
            debug.begin("print operator precedence table");
            debug.indent();
            std.debug.print("   ", .{});
            for (self.operators) |right| {
                std.debug.print(" {s: <3}", .{right.name});
            }
            std.debug.print("\n", .{});

            for (self.operators, 0..) |left, left_idx| {
                debug.indent();
                std.debug.print("{s: <3}", .{left.name});
                for (self.operators, 0..) |_, right_idx| {
                    const idx = left_idx * self.operators.len + right_idx;
                    std.debug.print(" {s: <3}", .{self.items[idx].precedence.name()});
                }
                std.debug.print("\n", .{});
            }
            debug.end("print operator precedence table");
        }
    }
};

/// 優先関係をグラフで表したグラフ。
const Graph = struct {
    const Symbol = union(enum) {
        f: *const Define,
        g: *const Define,

        fn equals(self: Symbol, other: Symbol) bool {
            return (self == .f and other == .f and self.f == other.f) or
                (self == .g and other == .g and self.g == other.g);
        }

        pub fn format(self: Symbol, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
            switch (self) {
                .f => try writer.print("f({s})", .{self.f.name}),
                .g => try writer.print("g({s})", .{self.g.name}),
            }
        }
    };

    const Node = struct {
        symbols: Array(Symbol),
        links: Array(*Node) = .empty,

        fn init(a: Allocator, symbol: Symbol) !Node {
            var symbols = Array(Symbol).empty;
            try symbols.append(a, symbol);
            return .{ .symbols = symbols };
        }

        pub fn format(self: Node, comptime fmt: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
            if (std.mem.eql(u8, fmt, "symbols")) {
                try writer.writeAll("\"");
                var first = true;
                for (self.symbols.items) |symbol| {
                    if (!first) {
                        try writer.writeAll(" ");
                    }
                    try writer.print("{}", .{symbol});
                    first = false;
                }
                try writer.writeAll("\"");
            } else if (std.mem.eql(u8, fmt, "links")) {
                if (std.mem.eql(u8, fmt, "symbols")) {
                    var first = true;
                    for (self.links.items) |link| {
                        if (!first) {
                            try writer.writeAll(", ");
                        }
                        try writer.print("{symbols:}", .{link.*});
                        first = false;
                    }
                }
            } else {
                try writer.print("{symbols:} -> {links:}", .{ self, self });
            }
        }
    };

    nodes: Array(Node),

    fn init(a: Allocator, table: RelationTable) !Graph {
        var nodes = Array(Node).empty;
        for (table.operators) |*op| {
            try nodes.append(a, try Node.init(a, .{ .f = op }));
            try nodes.append(a, try Node.init(a, .{ .g = op }));
        }

        var graph: Graph = .{ .nodes = nodes };

        var left_array = Array(struct { *const Define, Array(*const Define) }).empty;
        defer left_array.deinit(a);
        var right_array = Array(struct { *const Define, Array(*const Define) }).empty;
        defer right_array.deinit(a);

        for (table.items) |item| {
            switch (item.precedence) {
                .none => {},
                .equal => {
                    try graph.contraction(a, .{ .f = item.left }, .{ .g = item.right });
                    for (left_array.items) |*left_item| {
                        if (left_item[0] == item.left) {
                            try left_item[1].append(a, item.right);
                            break;
                        }
                    } else {
                        try left_array.append(a, .{ item.left, .empty });
                    }
                    for (right_array.items) |*right_item| {
                        if (right_item[0] == item.right) {
                            try right_item[1].append(a, item.left);
                            break;
                        }
                    } else {
                        try right_array.append(a, .{ item.right, .empty });
                    }
                },
                .higher => try graph.addEdge(a, .{ .f = item.left }, .{ .g = item.right }),
                .lower => try graph.addEdge(a, .{ .g = item.left }, .{ .f = item.right }),
            }
        }

        for (left_array.items) |item| {
            if (item[1].items.len <= 1) continue;
            const first = item[1].items[0];
            for (item[1].items[1..]) |other| {
                try graph.contraction(a, .{ .f = first }, .{ .f = other });
            }
        }

        for (right_array.items) |item| {
            if (item[1].items.len <= 1) continue;
            const first = item[1].items[0];
            for (item[1].items[1..]) |other| {
                try graph.contraction(a, .{ .g = first }, .{ .g = other });
            }
        }

        return graph;
    }

    fn deinit(self: *Graph, a: Allocator) void {
        for (self.nodes.items) |*node| {
            node.symbols.deinit(a);
            node.links.deinit(a);
        }
        self.nodes.deinit(a);
    }

    fn get(self: Graph, symbol: Symbol) *Node {
        for (self.nodes.items) |*node| {
            for (node.symbols.items) |s| {
                if (s.equals(symbol)) {
                    return node;
                }
            }
        }

        unreachable;
    }

    fn getIndex(self: Graph, symbol: Symbol) usize {
        for (self.nodes.items, 0..) |*node, idx| {
            for (node.symbols.items) |s| {
                if (s.equals(symbol)) {
                    return idx;
                }
            }
        }

        unreachable;
    }

    fn contraction(self: *Graph, a: Allocator, left: Symbol, right: Symbol) !void {
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

    fn addEdge(self: *Graph, a: Allocator, left: Symbol, right: Symbol) !void {
        const left_node = self.get(left);
        const right_node = self.get(right);

        try left_node.links.append(a, right_node);
    }

    fn print(self: Graph) void {
        if (debug.enabled) {
            debug.begin("print precedence graph");
            for (self.nodes.items) |node| {
                for (node.links.items) |link| {
                    debug.print("{symbols} -> {symbols}", .{ node, link });
                }
            }
            debug.end("print precedence graph");
        }
    }
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
