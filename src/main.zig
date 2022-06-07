const std = @import("std");
const globals = @import("globals.zig");
const Tokenizer = @import("tokenizer.zig").Tokenizer;

var ally: std.mem.Allocator = undefined;

pub fn doEverything(path: []const u8) !void {
    const source = try std.fs.cwd().readFileAlloc(ally, path, std.math.maxInt(usize));
    defer ally.free(source);

    var tokenizer = Tokenizer.init(ally);
    var tokens = try tokenizer.tokenize(source);
    defer tokens.deinit();
}

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(!gpa.deinit());
    ally = gpa.allocator();
    try globals.init(ally);
    defer globals.deinit();

    // path dump
    for (globals.paths.items) |path| {
        std.debug.print("{s}\n", .{path});
    }

    try doEverything("./test/bad.mysh");
}
