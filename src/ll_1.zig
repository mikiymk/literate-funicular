const std = @import("std");
const Allocator = std.mem.Allocator;
const Array = std.ArrayListUnmanaged;

const utils = @import("./util.zig");

const Token = utils.Language1.Token;
const TokenReader = utils.Language1.TokenReader;
const OutputQueue = utils.Language1.OutputQueue;
const ParseTree = utils.Language1.ParseTree;
const ParseError = utils.Language1.ParseError;
const Stack = utils.Stack;
const Set = utils.Set;
const AutoSet = utils.AutoSet;
const Map = utils.Map;
const AutoMap = utils.AutoMap;
const debug = utils.debug;

const GrammarError = ParseError || error{InvalidGrammar};

pub fn parse(a: Allocator, source: []const u8) ParseError!ParseTree {
    _ = source;

    const defines = &[_]Define{
        .{ .left = expr, .right = &.{Symbol{ .n_term = add_expr }} },
        .{ .left = add_expr, .right = &.{Symbol{ .n_term = mul_expr }} },
        .{ .left = add_expr, .right = &.{ Symbol{ .n_term = add_expr }, Symbol{ .term = plus }, Symbol{ .n_term = mul_expr } } },
        .{ .left = add_expr, .right = &.{ Symbol{ .n_term = add_expr }, Symbol{ .term = minus }, Symbol{ .n_term = mul_expr } } },
        .{ .left = mul_expr, .right = &.{Symbol{ .n_term = pow_expr }} },
        .{ .left = mul_expr, .right = &.{ Symbol{ .n_term = mul_expr }, Symbol{ .term = multiply }, Symbol{ .n_term = pow_expr } } },
        .{ .left = mul_expr, .right = &.{ Symbol{ .n_term = mul_expr }, Symbol{ .term = divide }, Symbol{ .n_term = pow_expr } } },
        .{ .left = pow_expr, .right = &.{Symbol{ .n_term = prim_expr }} },
        .{ .left = pow_expr, .right = &.{ Symbol{ .n_term = prim_expr }, Symbol{ .term = power }, Symbol{ .n_term = pow_expr } } },
        .{ .left = prim_expr, .right = &.{Symbol{ .term = number }} },
        .{ .left = prim_expr, .right = &.{ Symbol{ .term = paren_left }, Symbol{ .n_term = expr }, Symbol{ .term = paren_right } } },
    };
    const table = createTable(a, defines) catch |err| switch (err) {
        error.InvalidGrammar => {
            debug.printLn("invalid grammar", .{});
            return error.InvalidSyntax;
        },
        else => |e| return e,
    };
    table.deinit(a);

    debug.begin("構文解析");

    debug.end("構文解析");

    return undefined;
}

const Term = struct {
    name: []const u8,

    pub fn format(self: @This(), _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        try writer.writeAll(self.name);
    }
};

const TermOrEmpty = union(enum) {
    term: Term,
    empty: void,

    pub fn format(self: @This(), _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        switch (self) {
            .term => |t| try writer.writeAll(t.name),
            .empty => try writer.writeAll("empty"),
        }
    }
};

const TermOrEnd = union(enum) {
    term: Term,
    end: void,

    pub fn format(self: @This(), _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        switch (self) {
            .term => |t| try writer.writeAll(t.name),
            .end => try writer.writeAll("$"),
        }
    }
};

const NTerm = struct {
    name: []const u8,

    pub fn format(self: @This(), _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        try writer.writeAll(self.name);
    }
};

const TermContext = struct {
    pub fn hash(_: @This(), t: anytype) u64 {
        return std.hash_map.hashString(t.name);
    }

    pub fn eql(_: @This(), l: anytype, r: @TypeOf(l)) bool {
        return std.hash_map.eqlString(l.name, r.name);
    }
};

const ExTermContext = struct {
    pub fn hash(_: @This(), v: anytype) u64 {
        const Tag = std.meta.Tag(@TypeOf(v));
        var h = std.hash.Wyhash.init(0);
        h.update(std.mem.asBytes(&@as(Tag, v)));
        switch (v) {
            .term => |t| h.update(t.name),
            else => {},
        }
        return h.final();
    }

    pub fn eql(_: @This(), l: anytype, r: @TypeOf(l)) bool {
        const Tag = std.meta.Tag(@TypeOf(l));
        if (@as(Tag, l) != @as(Tag, r)) return false;
        return switch (l) {
            .term => std.hash_map.eqlString(l.term.name, r.term.name),
            else => true,
        };
    }
};

const Symbol = union(enum) {
    n_term: NTerm,
    term: Term,
};

const Define = struct {
    left: NTerm,
    right: []const Symbol,

    pub fn format(self: @This(), _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        try writer.print("{} ->", .{self.left});
        for (self.right) |symbol| {
            switch (symbol) {
                inline else => |s| try writer.print(" {}", .{s}),
            }
        }
    }
};

const TermSet = Set(Term, TermContext);
const NTermSet = Set(NTerm, TermContext);

const expr = NTerm{ .name = "Expr" };
const add_expr = NTerm{ .name = "Add" };
const mul_expr = NTerm{ .name = "Mul" };
const pow_expr = NTerm{ .name = "Pow" };
const prim_expr = NTerm{ .name = "Prim" };

const number = Term{ .name = "number" };
const paren_left = Term{ .name = "(" };
const paren_right = Term{ .name = ")" };
const plus = Term{ .name = "+" };
const minus = Term{ .name = "-" };
const multiply = Term{ .name = "*" };
const divide = Term{ .name = "/" };
const power = Term{ .name = "^" };

fn createTable(a: Allocator, defines: []const Define) GrammarError!LLTable {
    debug.begin("構文解析表の作成");

    var term_set, var non_term_set = try createSymbolSet(a, defines);
    defer term_set.deinit(a);
    defer non_term_set.deinit(a);

    debug.printLn("終端記号  : {}", .{term_set});
    debug.printLn("非終端記号: {}", .{non_term_set});

    var first_sets = try FirstSets.init(a, defines);
    defer first_sets.deinit(a);

    var follow_sets = try FollowSets.init(a, defines, first_sets);
    defer follow_sets.deinit(a);

    const ll_table = try createLLTable(a, defines, term_set, non_term_set, first_sets, follow_sets);

    debug.end("構文解析表の作成");
    return ll_table;
}

fn createSymbolSet(a: Allocator, defines: []const Define) Allocator.Error!struct { TermSet, NTermSet } {
    debug.begin("記号集合の作成");
    var term_set = TermSet.empty;
    var non_term_set = NTermSet.empty;

    for (defines) |define| {
        try non_term_set.insert(a, define.left);
        for (define.right) |symbol| {
            switch (symbol) {
                .n_term => |n_term| {
                    try non_term_set.insert(a, n_term);
                },
                .term => |term| {
                    try term_set.insert(a, term);
                },
            }
        }
    }

    debug.end("記号集合の作成");
    return .{ term_set, non_term_set };
}

fn createFollowSets(a: Allocator, defines: []const Define, term_set: TermSet, non_term_set: NTermSet, first_sets: FirstSets) Allocator.Error!FollowSets {
    debug.begin("First集合の作成");
    const follow_sets: FollowSets = undefined;
    _ = a;
    _ = defines;
    _ = term_set;
    _ = non_term_set;
    _ = first_sets;

    debug.end("First集合の作成");
    return follow_sets;
}

fn createLLTable(a: Allocator, defines: []const Define, term_set: TermSet, non_term_set: NTermSet, first_sets: FirstSets, follow_sets: FollowSets) Allocator.Error!LLTable {
    debug.begin("LL構文解析表の作成");
    const ll_table: LLTable = undefined;
    _ = a;
    _ = defines;
    _ = term_set;
    _ = non_term_set;
    _ = first_sets;
    _ = follow_sets;

    debug.end("LL構文解析表の作成");
    return ll_table;
}

const FirstSets = struct {
    const FirstSet = Set(TermOrEmpty, ExTermContext);
    const NonTermMap = Map(NTerm, FirstSet, TermContext);

    non_term_first_sets: NonTermMap,

    fn init(a: Allocator, defines: []const Define) Allocator.Error!FirstSets {
        debug.begin("First集合の作成");

        var sets = FirstSets{ .non_term_first_sets = .empty };

        while (true) {
            var updated = false;
            for (defines) |define| {
                if (define.right.len == 0) {
                    updated = try sets.add(a, define.left, .empty) or updated;
                    continue;
                }
                for (define.right) |symbol| {
                    switch (symbol) {
                        .term => |term| {
                            updated = try sets.add(a, define.left, .{ .term = term }) or updated;
                            break;
                        },
                        .n_term => |n_term| {
                            const set = sets.non_term_first_sets.get(n_term) orelse FirstSet.empty;
                            var iter = set.iterator();
                            var has_empty = false;
                            while (iter.next()) |term| {
                                updated = try sets.add(a, define.left, term.*) or updated;
                                has_empty = has_empty or term.* == .empty;
                            }
                            if (!has_empty) break;
                        },
                    }
                }
            }

            debug.printLn("First集合: {}", .{sets.non_term_first_sets});

            if (!updated) break;
        }

        debug.end("First集合の作成");
        return sets;
    }

    pub fn deinit(self: *FirstSets, a: Allocator) void {
        var iter = self.non_term_first_sets.map.valueIterator();
        while (iter.next()) |first_set| {
            first_set.deinit(a);
        }
        self.non_term_first_sets.deinit(a);
    }

    fn add(self: *FirstSets, a: Allocator, n_term: NTerm, term: TermOrEmpty) Allocator.Error!bool {
        var first_set = self.non_term_first_sets.get(n_term) orelse FirstSet.empty;
        const prev_count = first_set.count();
        try first_set.insert(a, term);
        try self.non_term_first_sets.insert(a, n_term, first_set);
        return prev_count != first_set.count();
    }

    /// 記号列からFirst集合を取得する
    fn get(self: FirstSets, a: Allocator, symbols: []const Symbol) Allocator.Error!FirstSet {
        var set = FirstSet.empty;

        if (symbols.len == 0) {
            try set.insert(a, .empty);
            return set;
        }

        for (symbols) |symbol| {
            switch (symbol) {
                .term => |term| {
                    set.delete(.empty);
                    try set.insert(a, .{ .term = term });
                    break;
                },
                .n_term => |n_term| {
                    set.delete(.empty);
                    const n_term_set = self.non_term_first_sets.get(n_term) orelse FirstSet.empty;
                    var iter = n_term_set.iterator();
                    var has_empty = false;
                    while (iter.next()) |term_or_empty| {
                        switch (term_or_empty.*) {
                            .term => |term| {
                                try set.insert(a, .{ .term = term });
                            },
                            .empty => has_empty = true,
                        }
                    }

                    if (!has_empty) {
                        break;
                    }
                },
            }
        }

        return set;
    }

    fn equals(self: FirstSets, other: FirstSets) bool {
        if (self.non_term_first_sets.count() != other.non_term_first_sets.count()) return false;
        var iter = self.non_term_first_sets.map.iterator();
        while (iter.next()) |entry| {
            const other_set = other.non_term_first_sets.get(entry.key_ptr.*) orelse return false;
            if (!entry.value_ptr.equal(other_set)) return false;
        }
        return true;
    }
};

const FollowSets = struct {
    const FollowSet = Set(TermOrEnd, ExTermContext);
    const NonTermMap = Map(NTerm, FollowSet, TermContext);

    non_term_follow_sets: NonTermMap,

    fn init(a: Allocator, defines: []const Define, first_sets: FirstSets) Allocator.Error!FollowSets {
        debug.begin("Follow集合の作成");

        var sets: FollowSets = .{ .non_term_follow_sets = .empty };
        _ = try sets.add(a, defines[0].left, .end);

        // Fo(a)にFo(b)を追加する関係のリスト
        var follow_set_array = Array(struct { a: NTerm, b: NTerm }).empty;
        defer follow_set_array.deinit(a);

        for (defines) |define| { // 各ルールをループ
            debug.printLn("ルール: {}", .{define});
            for (0..define.right.len) |index| { // 右辺を順番に見る
                switch (define.right[index]) {
                    .n_term => |target| { // 非終端記号を見つけたら
                        debug.printLn("非終端記号を発見: {}", .{target});
                        var set = try first_sets.get(a, define.right[index + 1 ..]);
                        defer set.deinit(a);
                        debug.printLn("First集合を追加: {}", .{set});

                        var iter = set.iterator();
                        var has_empty = false;
                        while (iter.next()) |term_or_empty| {
                            switch (term_or_empty.*) {
                                .term => |term| {
                                    _ = try sets.add(a, target, .{ .term = term });
                                },
                                .empty => has_empty = true,
                            }
                        }
                        if (has_empty) {
                            // Fo(a)にFo(b)を追加はあとで処理する
                            try follow_set_array.append(a, .{ .a = target, .b = define.left });
                        }
                    },
                    else => {},
                }
            }
        }

        debug.printLn("Follow集合: {}", .{sets.non_term_follow_sets});

        var updated = true;
        while (updated) { // 完成まで繰り返す
            updated = false;

            for (follow_set_array.items) |item| {
                const follow_set = sets.non_term_follow_sets.get(item.b) orelse FollowSet.empty;
                var iter = follow_set.iterator();
                while (iter.next()) |term_or_end| {
                    updated = try sets.add(a, item.a, term_or_end.*) or updated;
                }
            }

            debug.printLn("Follow集合: {}", .{sets.non_term_follow_sets});
        }

        debug.end("Follow集合の作成");
        return sets;
    }

    pub fn deinit(self: *FollowSets, a: Allocator) void {
        var iter = self.non_term_follow_sets.map.valueIterator();
        while (iter.next()) |first_set| {
            first_set.deinit(a);
        }
        self.non_term_follow_sets.deinit(a);
    }

    fn add(self: *FollowSets, a: Allocator, n_term: NTerm, term: TermOrEnd) Allocator.Error!bool {
        var set = self.non_term_follow_sets.get(n_term) orelse FollowSet.empty;
        const prev_count = set.count();
        try set.insert(a, term);
        try self.non_term_follow_sets.insert(a, n_term, set);
        return prev_count != set.count();
    }
};

const LLTable = struct {
    const empty = @This(){};

    pub fn deinit(self: @This(), a: Allocator) void {
        _ = self;
        _ = a;
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
