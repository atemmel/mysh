const std = @import("std");

pub const ValueArray = std.ArrayList(Value);

pub const Value = union(Kind) {
    pub const Kind = enum {
        string,
        boolean,
        integer,
        array,
    };

    string: []u8,
    boolean: bool,
    integer: i64,
    array: ValueArray,

    pub fn deinit(self: *const Value, ally: std.mem.Allocator) void {
        switch (self.*) {
            .string => |string| {
                ally.free(string);
            },
            .boolean => {},
            .integer => {},
            .array => |array| {
                array.deinit();
            },
        }
    }

    pub fn format(
        self: *const Value,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;

        switch (self.*) {
            .string => |string| {
                try writer.print("{s}", .{string});
            },
            .boolean => |boolean| {
                try writer.print("{}", .{boolean});
            },
            .integer => |integer| {
                try writer.print("{}", .{integer});
            },
            .array => |*array| {
                try writer.print("{any}", .{array.items});
            },
        }
    }
};

pub const SymTable = struct {
    pub fn init(ally: std.mem.Allocator) SymTable {
        _ = ally;
        return .{};
    }

    pub fn deinit(self: *SymTable) void {
        _ = self;
    }

    pub fn addScope(self: *SymTable) void {
        _ = self;
    }

    pub fn dropScope(self: *SymTable) void {
        _ = self;
    }
};
