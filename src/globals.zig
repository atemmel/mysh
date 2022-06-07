const std = @import("std");

const StringViews = std.ArrayList([]const u8);

const MyshInitError = error{
    NoPath,
};

pub fn init(ally: std.mem.Allocator) !void {
    paths = StringViews.init(ally);
    const path = std.os.getenv("PATH") orelse return MyshInitError.NoPath;
    var iterator = std.mem.tokenize(u8, path, ":");
    while (iterator.next()) |piece| {
        try paths.append(piece);
    }
}

pub fn deinit() void {
    paths.deinit();
}

pub var verbose = false;
pub var paths: StringViews = undefined;
