const std = @import("std");

pub fn getopt(argv: [][]const u8, comptime optstring: []const u8) OptionsIterator {
    return OptionsIterator{
        .argv = argv,
        .optstring = comptime parseOptString(optstring),
    };
}

const Option = struct {
    opt: u8 = 0,
    arg: ?[]const u8 = null,
};

const OptionsIterator = struct {
    argv: [][]const u8,
    optstring: []const OptFlag,

    optind: usize = 1,

    pub fn next(self: *OptionsIterator) !?Option {
        if (self.argv.len <= self.optind) {
            return null;
        }
        var current = self.argv[self.optind];

        if (current.len < 2) {
            return null;
        }

        var option: Option = .{};

        if (current[0] == '-') {
            var current_flag = current[1];

            for (self.optstring) |flag| {
                if (current_flag == flag.key) {
                    option.opt = current_flag;

                    if (flag.arg != .none) {
                        if (current.len > 2) {
                            option.arg = current[2..];
                        } else {
                            self.optind += 1;
                            if (self.optind < self.argv.len) {
                                option.arg = self.argv[self.optind];
                            }
                        }

                        if (flag.arg == .require and option.arg == null) {
                            return error.MissingArgument;
                        }
                    }

                    self.optind += 1;
                    return option;
                }
            }

            return error.NotSpecifiedOption;
        }

        return null;
    }
};

const OptFlagArg = enum { require, option, none };
const OptFlag = struct {
    key: u8,
    arg: OptFlagArg = .none,
};

fn parseOptString(comptime optstring: []const u8) []const OptFlag {
    comptime var colon_count: usize = 0;
    inline for (optstring) |char| {
        if (char == ':') {
            colon_count += 1;
        }
    }

    comptime var prev = .none;
    comptime var opt_flags = [_]OptFlag{OptFlag{ .key = 0 }} ** (optstring.len - colon_count);
    comptime var index: usize = 0;

    inline for (optstring) |char| {
        if (char == ':') {
            if (prev == .key) {
                opt_flags[index - 1].arg = .require;
                prev = .colon1;
            } else if (prev == .colon1) {
                opt_flags[index - 1].arg = .option;
                prev = .none;
            }
        } else {
            opt_flags[index].key = char;
            prev = .key;
            index += 1;
        }
    }

    return &opt_flags;
}

test "parsing optstring" {
    const testing = std.testing;

    try testing.expectEqualSlices(OptFlag, &.{
        .{ .key = 'a' },
        .{ .key = 'b' },
        .{ .key = 'c' },
    }, parseOptString("abc"));

    try testing.expectEqualSlices(OptFlag, &.{
        .{ .key = 'a' },
        .{ .key = 'b', .arg = .require },
        .{ .key = 'c' },
    }, parseOptString("ab:c"));

    try testing.expectEqualSlices(OptFlag, &.{
        .{ .key = 'a' },
        .{ .key = 'b', .arg = .option },
        .{ .key = 'c' },
    }, parseOptString("ab::c"));
}

test "iterating option" {
    const testing = std.testing;

    {
        var args = [_][]const u8{"progname"};
        var iter = getopt(&args, "ab:c::d::");

        var expected: anyerror!?Option = null;
        var actual = iter.next();
        try testing.expectEqual(expected, actual);
    }

    {
        var args = [_][]const u8{ "progname", "-a" };
        var iter = getopt(&args, "ab:c::");

        var expected: anyerror!?Option = .{ .opt = 'a', .arg = null };
        var actual = iter.next();
        try testing.expectEqual(expected, actual);

        expected = null;
        actual = iter.next();
        try testing.expectEqual(expected, actual);
    }

    {
        var args = [_][]const u8{ "progname", "-b", "arg" };
        var iter = getopt(&args, "ab:c::");

        var expected: anyerror!?Option = .{ .opt = 'b', .arg = "arg" };
        var actual = iter.next();
        try testing.expectEqual(expected, actual);

        expected = null;
        actual = iter.next();
        try testing.expectEqual(expected, actual);
    }

    {
        var args = [_][]const u8{ "progname", "-b" };
        var iter = getopt(&args, "ab:c::");

        var expected: anyerror!?Option = error.MissingArgument;
        var actual = iter.next();
        try testing.expectEqual(expected, actual);

        expected = null;
        actual = iter.next();
        try testing.expectEqual(expected, actual);
    }

    {
        var args = [_][]const u8{ "progname", "-c", "arg" };
        var iter = getopt(&args, "ab:c::");

        var expected: anyerror!?Option = .{ .opt = 'c', .arg = "arg" };
        var actual = iter.next();
        try testing.expectEqual(expected, actual);

        expected = null;
        actual = iter.next();
        try testing.expectEqual(expected, actual);
    }

    {
        var args = [_][]const u8{ "progname", "-c" };
        var iter = getopt(&args, "ab:c::");

        var expected: anyerror!?Option = .{ .opt = 'c', .arg = null };
        var actual = iter.next();
        try testing.expectEqual(expected, actual);

        expected = null;
        actual = iter.next();
        try testing.expectEqual(expected, actual);
    }
}
