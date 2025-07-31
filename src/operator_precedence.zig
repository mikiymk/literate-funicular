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
//!
//! ## 演算子優先順位法のアルゴリズム
//!

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
    const table = try createTable(a, &defines);
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

fn createTable(a: Allocator, operators: []const Define) !FunctionTable {
    for (operators) |*operator| {
        debug.print("{*}: {s}", .{ operator, operator.name });
    }
    debug.begin("create operator precedence table");

    const table = try RelationTable.init(a, operators);
    defer table.deinit(a);
    table.print();

    var graph = try Graph.init(a, table);
    defer graph.deinit(a);
    graph.print();

    const function_table = try FunctionTable.init(a, operators, graph);
    function_table.print();

    debug.end("create operator precedence table");
    return function_table;
}

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

        fn deinit(self: *Node, a: Allocator) void {
            self.symbols.deinit(a);
            self.links.deinit(a);
        }

        fn length(self: Node) usize {
            var max_length: usize = 0;
            for (self.links.items) |link| {
                max_length = @max(max_length, link.length());
            }

            return max_length + 1;
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
                var first = true;
                for (self.links.items) |link| {
                    if (!first) {
                        try writer.writeAll(", ");
                    }
                    try writer.print("{symbols}", .{link.*});
                    first = false;
                }
            } else {
                try writer.print("{symbols} -> {links}", .{ self, self });
            }
        }
    };

    nodes: Array(Node),
    enables: Array(bool),

    fn init(a: Allocator, table: RelationTable) !Graph {
        debug.begin("create precedence graph");
        const nodes = Array(Node).empty;
        const enables = Array(bool).empty;
        var graph: Graph = .{ .nodes = nodes, .enables = enables };

        for (table.operators) |*op| {
            try graph.addNode(a, .{ .f = op });
            try graph.addNode(a, .{ .g = op });
        }

        const Map = std.AutoArrayHashMapUnmanaged(*const Define, Array(*const Define));
        var left_equals = Map.empty;
        var right_equals = Map.empty;
        defer {
            for (left_equals.values()) |*items|
                items.deinit(a);
            left_equals.deinit(a);
            for (right_equals.values()) |*items|
                items.deinit(a);
            right_equals.deinit(a);
        }

        for (table.items) |item| {
            switch (item.precedence) {
                .none => {},
                .equal => {
                    try graph.contraction(a, .{ .f = item.left }, .{ .g = item.right });

                    var left_array = left_equals.get(item.left) orelse Array(*const Define).empty;
                    try left_array.append(a, item.right);
                    try left_equals.put(a, item.left, left_array);

                    var right_array = right_equals.get(item.right) orelse Array(*const Define).empty;
                    try right_array.append(a, item.left);
                    try right_equals.put(a, item.right, right_array);
                },
                .higher => try graph.addEdge(a, .{ .f = item.left }, .{ .g = item.right }),
                .lower => try graph.addEdge(a, .{ .g = item.right }, .{ .f = item.left }),
            }
        }

        for (left_equals.values()) |value| {
            if (value.items.len <= 1) continue;
            const first = value.items[0];
            for (value.items[1..]) |other| {
                try graph.contraction(a, .{ .f = first }, .{ .f = other });
            }
        }

        for (right_equals.values()) |value| {
            if (value.items.len <= 1) continue;
            const first = value.items[0];
            for (value.items[1..]) |other| {
                try graph.contraction(a, .{ .g = first }, .{ .g = other });
            }
        }

        debug.end("create precedence graph");
        return graph;
    }

    fn deinit(self: *Graph, a: Allocator) void {
        for (self.nodes.items, self.enables.items) |*node, enabled| {
            if (!enabled) continue;
            node.deinit(a);
        }
        self.nodes.deinit(a);
        self.enables.deinit(a);
    }

    fn addNode(self: *Graph, a: Allocator, symbol: Symbol) !void {
        try self.nodes.append(a, try Node.init(a, symbol));
        try self.enables.append(a, true);
    }

    fn get(self: *Graph, symbol: Symbol) *Node {
        for (self.nodes.items, self.enables.items) |*node, enable| {
            if (!enable) continue;
            for (node.symbols.items) |s| {
                if (s.equals(symbol)) {
                    return node;
                }
            }
        }

        unreachable;
    }

    fn getIndex(self: Graph, symbol: Symbol) usize {
        for (self.nodes.items, self.enables.items, 0..) |*node, enable, idx| {
            if (!enable) continue;
            for (node.symbols.items) |s| {
                if (s.equals(symbol)) {
                    return idx;
                }
            }
        }

        unreachable;
    }

    fn getLength(self: Graph, symbol: Symbol) usize {
        const index = self.getIndex(symbol);
        return self.nodes.items[index].length();
    }

    fn contraction(self: *Graph, a: Allocator, left: Symbol, right: Symbol) !void {
        const left_node = self.get(left);
        const right_node = self.get(right);
        const right_index = self.getIndex(right);

        for (right_node.symbols.items) |symbol| {
            try left_node.symbols.append(a, symbol);
        }
        for (right_node.links.items) |link| {
            try left_node.links.append(a, link);
        }

        for (self.nodes.items, self.enables.items) |node, enabled| {
            if (!enabled) continue;
            for (node.links.items) |*link| {
                if (link.* == right_node) {
                    link.* = left_node;
                }
            }
        }

        self.enables.items[right_index] = false;
        self.nodes.items[right_index].deinit(a);
        self.nodes.items[right_index] = undefined;
    }

    fn addEdge(self: *Graph, a: Allocator, left: Symbol, right: Symbol) !void {
        const left_node = self.get(left);
        const right_node = self.get(right);

        try left_node.links.append(a, right_node);
    }

    const Iterator = struct {
        graph: *const Graph,
        index: usize = 0,

        fn next(self: *Iterator) ?Node {
            while (self.index < self.graph.nodes.items.len) : (self.index += 1) {
                if (self.graph.enables.items[self.index]) {
                    return self.graph.nodes.items[self.index];
                }
            }
            return null;
        }
    };

    fn iterator(self: *const Graph) Iterator {
        return .{ .graph = self };
    }

    fn print(self: Graph) void {
        if (debug.enabled) {
            debug.begin("print precedence graph");
            for (self.nodes.items, self.enables.items) |node, enabled| {
                if (!enabled) continue;
                debug.indent();
                std.debug.print("{symbols} ->", .{node});
                for (node.links.items) |link| {
                    std.debug.print(" {symbols}", .{link});
                }
                std.debug.print("\n", .{});
            }
            debug.end("print precedence graph");
        }
    }
};

const FunctionTable = struct {
    operators: []const Define,
    f_predicates: []const usize,
    g_predicates: []const usize,

    fn init(a: Allocator, operators: []const Define, graph: Graph) !FunctionTable {
        debug.begin("create precedence function table");
        var f_predicates = try a.alloc(usize, operators.len);
        var g_predicates = try a.alloc(usize, operators.len);

        for (operators, 0..) |*operator, idx| {
            f_predicates[idx] = graph.getLength(.{ .f = operator });
            g_predicates[idx] = graph.getLength(.{ .g = operator });
        }

        debug.end("create precedence function table");
        return .{
            .operators = operators,
            .f_predicates = f_predicates,
            .g_predicates = g_predicates,
        };
    }

    fn deinit(self: FunctionTable, a: Allocator) void {
        a.free(self.f_predicates);
        a.free(self.g_predicates);
    }

    fn print(self: FunctionTable) void {
        if (debug.enabled) {
            debug.begin("print function table");

            debug.indent();
            std.debug.print("op :", .{});
            for (self.operators) |operator| {
                std.debug.print(" {s: >3}", .{operator.name});
            }
            std.debug.print("\n", .{});

            debug.indent();
            std.debug.print("f  :", .{});
            for (self.f_predicates) |predicate| {
                std.debug.print(" {d: >3}", .{predicate});
            }
            std.debug.print("\n", .{});

            debug.indent();
            std.debug.print("g  :", .{});
            for (self.g_predicates) |predicate| {
                std.debug.print(" {d: >3}", .{predicate});
            }
            std.debug.print("\n", .{});
            debug.end("print function table");
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
