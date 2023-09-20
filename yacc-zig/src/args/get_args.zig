const std = @import("std");
const getopt = @import("./getopt.zig");

pub const Args = struct {
    // プログラムのファイル名
    program_name: []const u8,

    // ファイルの接頭辞を決める
    // -b [prefix]で設定する
    file_prefix: ?[]const u8 = null,

    // ヘッダーファイルを作るかどうか
    // -dを指定すると作る
    declare_file: bool = false,

    // #lineディレクティブを使用するかどうか
    // -lを指定すると使用しない
    use_line: bool = true,

    // 出力ファイルのファイル名を決める
    // -o [file]で設定する
    output_file: ?[]const u8 = null,

    // 出力ファイル内のシンボル名の接頭辞を決める
    // -p [prefix]で設定する
    symbol_prefix: ?[]const u8 = null,

    // コードと出力を分離する
    // -rを指定すると分離する
    separate_code: bool = false,

    // 出力コードのデバッグフラグを設定する
    // -tを指定するとオンになる
    debug_mode: bool = false,

    // 詳細出力モード
    // -vを指定するとオンになる
    verbose: bool = false,

    input_file: []const u8 = "",
};

pub fn getargs(argv: [][]const u8) !Args {
    var iter = getopt.getopt(argv, "b:dlo:p:rtv");
    var args: Args = .{
        .program_name = argv[0],
    };

    while (iter.next() catch return error.Usage) |ch| {
        switch (ch.opt) {
            'b' => args.file_prefix = ch.arg,
            'd' => args.declare_file = true,
            'l' => args.use_line = true,
            'o' => args.output_file = ch.arg,
            'p' => args.symbol_prefix = ch.arg,
            'r' => args.separate_code = true,
            't' => args.debug_mode = true,
            'v' => args.verbose = true,
            else => return error.Usage,
        }
    }

    if (argv.len - iter.optind != 1) {
        return error.Usage;
    }

    args.input_file = argv[iter.optind];

    return args;
}
