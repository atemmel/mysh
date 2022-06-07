const std = @import("std");
const globals = @import("globals.zig");

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(!gpa.deinit());
    var ally = gpa.allocator();
    try globals.init(ally);
    defer globals.deinit();

    // path dump
    for (globals.paths.items) |path| {
        std.debug.print("{s}\n", .{path});
    }
}
