const std = @import("std");
const globals = @import("globals.zig");
const Tokenizer = @import("tokenizer.zig").Tokenizer;
const ArgParser = @import("argparser.zig").ArgParser;

var ally: std.mem.Allocator = undefined;

pub fn doEverything(path: []const u8) !void {
    const source = try std.fs.cwd().readFileAlloc(ally, path, std.math.maxInt(usize));
    defer ally.free(source);

    var tokenizer = Tokenizer.init(ally);
    var tokens = try tokenizer.tokenize(source);
    defer ally.free(tokens);
}

pub fn main() anyerror!u8 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(!gpa.deinit());
    ally = gpa.allocator();
    try globals.init(ally);
    defer globals.deinit();

    // path dump
    for (globals.paths.items) |path| {
        std.debug.print("{s}\n", .{path});
    }

    const alloced_args = try std.process.argsAlloc(ally);
    defer std.process.argsFree(ally, alloced_args);
    const args = alloced_args[0..alloced_args.len];

    var arg_parser = ArgParser.init(ally, &[_]ArgParser.Flag{
        ArgParser.boolean(&globals.verbose, "--verbose", "Enable verbose mode"),
    });

    const remainder = try arg_parser.parse(args);
    defer ally.free(remainder);

    if (remainder.len > 0) {
        const path = remainder[0];
        try doEverything(path);
        return 0;
    }

    const stderr = std.io.getStdErr().writer();
    try stderr.print("No file specified, exiting...\n", .{});
    return 1;
}