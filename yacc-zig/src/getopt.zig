const std = @import("std");

pub fn getopt(argv: [][:0]const u8, comptime optstring: []const u8) OptionsIterator {
    return OptionsIterator{
        .argv = argv,
        .optstring = parseOptString(optstring),
    };
}

const Option = struct {
    opt: u8,
    arg: ?[]const u8,
};

const OptionsIterator = struct {
    argv: [][:0]const u8,
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

        var option: Option = undefined;

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

const OptFlag = struct {
    key: u8,
    arg: enum { require, option, none } = .none,
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
            index += 1;
        }
    }

    comptime std.debug.assert(index == opt_flags.len);

    return opt_flags[0 .. index - 1];
}
