const std = @import("std");
const globals = @import("globals.zig");
const Tokenizer = @import("tokenizer.zig").Tokenizer;
const ArgParser = @import("argparser.zig").ArgParser;
const ast = @import("ast.zig");
const astprint = @import("astprint.zig");
const Interpreter = @import("interpreter.zig").Interpreter;

const stderr = std.io.getStdErr().writer();
var ally: std.mem.Allocator = undefined;

fn doEverythingWithPath(path: []const u8) !bool {
    const source = std.fs.cwd().readFileAlloc(ally, path, std.math.maxInt(usize)) catch {
        try stderr.print("Unable to open file: {s}\n", .{path});
        return false;
    };
    defer ally.free(source);
    return doEverything(source);
}

pub fn doEverything(source: []const u8) !bool {
    var tokenizer = Tokenizer.init(ally);
    var tokens = try tokenizer.tokenize(source);
    defer ally.free(tokens);
    if (globals.verbose) {
        for (tokens) |*token| {
            token.print();
        }
    }

    var parser = ast.Parser.init(ally);
    var maybe_root = try parser.parse(tokens);

    if (maybe_root == null) {
        try stderr.print("Parse failed, no root!\n", .{});
        if (parser.encounteredError()) {
            parser.dumpError();
            return false;
        }
    }

    var root = maybe_root.?;
    defer root.deinit();

    if (globals.verbose) {
        astprint.print(&root);
    }

    var interpreter = try Interpreter.init(ally);
    defer interpreter.deinit();

    if (!try interpreter.interpret(&root)) {
        interpreter.reportError();
        return false;
    }
    return true;
}

pub fn main() anyerror!u8 {
    var gpa = std.heap.GeneralPurposeAllocator(.{
        .stack_trace_frames = 10,
    }){};
    defer std.debug.assert(!gpa.deinit());
    ally = gpa.allocator();
    try globals.init(ally);
    defer globals.deinit();

    // path dump
    if (false) {
        for (globals.paths.items) |path| {
            std.debug.print("{s}\n", .{path});
        }
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
        return if (try doEverythingWithPath(path)) 0 else 1;
    }

    try stderr.print("No file specified, exiting...\n", .{});
    return 2;
}

comptime {
    _ = @import("spawn.zig");
    _ = @import("interpolate.zig");
}
