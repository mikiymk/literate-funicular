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
    _ = table;

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

const NTerm = struct {
    name: []const u8,

    pub fn format(self: @This(), _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        try writer.writeAll(self.name);
    }
};

const Symbol = union(enum) {
    n_term: NTerm,
    term: Term,
};

const Define = struct {
    left: NTerm,
    right: []const Symbol,
};

const TermSet = Set(Term, struct {
    pub fn hash(_: @This(), t: Term) u64 {
        return std.hash_map.hashString(t.name);
    }
    pub fn eql(_: @This(), l: Term, r: Term) bool {
        return std.hash_map.eqlString(l.name, r.name);
    }
});

const NTermSet = Set(NTerm, struct {
    pub fn hash(_: @This(), t: NTerm) u64 {
        return std.hash_map.hashString(t.name);
    }
    pub fn eql(_: @This(), l: NTerm, r: NTerm) bool {
        return std.hash_map.eqlString(l.name, r.name);
    }
});

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

    var first_sets = try createFirstSets(a, defines, term_set, non_term_set);
    defer first_sets.deinit(a);

    var follow_sets = try createFollowSets(a, defines, term_set, non_term_set, first_sets);
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

fn createFirstSets(a: Allocator, defines: []const Define, term_set: TermSet, non_term_set: NTermSet) Allocator.Error!FirstSets {
    debug.begin("First集合の作成");
    const first_sets: FirstSets = undefined;
    _ = a;
    _ = defines;
    _ = term_set;
    _ = non_term_set;

    debug.end("First集合の作成");
    return first_sets;
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
    const empty = @This(){};

    pub fn deinit(self: @This(), a: Allocator) void {
        _ = self;
        _ = a;
    }
};

const FollowSets = struct {
    const empty = @This(){};

    pub fn deinit(self: @This(), a: Allocator) void {
        _ = self;
        _ = a;
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
