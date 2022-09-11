const std = @import("std");
const Token = @import("token.zig").Token;

pub const ValueArray = std.ArrayList(Value);
pub const ValueTable = std.StringHashMap(Value);

pub const Value = struct {
    pub const Kind = enum {
        string,
        boolean,
        integer,
        array,
        table,

        pub fn format(
            self: *const Kind,
            comptime fmt: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            _ = fmt;
            _ = options;

            switch (self.*) {
                .string => {
                    try writer.writeAll("string");
                },
                .boolean => {
                    try writer.writeAll("bool");
                },
                .integer => {
                    try writer.writeAll("int");
                },
                .array => {
                    try writer.writeAll("[]");
                },
                .table => {
                    try writer.writeAll("struct");
                },
            }
        }
    };

    pub const Inner = union(Kind) {
        string: []const u8,
        boolean: bool,
        integer: i64,
        array: ValueArray,
        table: ValueTable,
    };

    inner: Inner = undefined,
    origin: ?*const Token = null,
    owned: bool = false,
    may_free: bool = true,

    pub const CloneError = std.mem.Allocator.Error;

    pub fn clone(self: *const Value, ally: std.mem.Allocator) CloneError!Value {
        switch (self.inner) {
            .string => |string| {
                if (!self.may_free) {
                    return self.*;
                }
                return Value{
                    .inner = .{
                        .string = try ally.dupe(u8, string),
                    },
                };
            },
            .boolean => return self.*,
            .integer => return self.*,
            .array => |array| {
                if (!self.may_free) {
                    return self.*;
                }
                var new_array = try ValueArray.initCapacity(ally, array.items.len);
                for (array.items) |*old_element| {
                    new_array.appendAssumeCapacity(try old_element.clone(ally));
                }
                return Value{
                    .inner = .{
                        .array = new_array,
                    },
                };
            },
            .table => |table| {
                if (!self.may_free) {
                    return self.*;
                }
                var new_struct = ValueTable.init(ally);
                var it = table.iterator();
                while (it.next()) |pair| {
                    const key = try ally.dupe(u8, pair.key_ptr.*);
                    const value = try pair.value_ptr.clone(ally);
                    try new_struct.put(key, value);
                }
                return Value{
                    .inner = .{
                        .table = new_struct,
                    },
                };
            },
        }
    }

    pub fn byConversion(original_str: []const u8) Value {
        const str = std.mem.trimRight(u8, original_str, &std.ascii.spaces);

        if (std.mem.eql(u8, str, "true")) {
            return Value{
                .inner = .{
                    .boolean = true,
                },
            };
        }

        if (std.mem.eql(u8, str, "false")) {
            return Value{
                .inner = .{
                    .boolean = false,
                },
            };
        }

        if (std.fmt.parseInt(i64, str, 0)) |integer| {
            return Value{
                .inner = .{
                    .integer = integer,
                },
            };
        } else |err| {
            err catch {};
        }

        // unconvertable, leave as-is
        return Value{
            .inner = .{
                .string = original_str,
            },
        };
    }

    pub fn deinit(self: *Value, ally: std.mem.Allocator) void {
        if (!self.owned) {
            self.deinitWithOwnership(ally);
        }
    }

    pub fn deinitWithOwnership(self: *Value, ally: std.mem.Allocator) void {
        if (!self.may_free) {
            return;
        }
        switch (self.inner) {
            .string => |string| {
                ally.free(string);
                //unreachable;
            },
            .boolean => {},
            .integer => {},
            .array => |array| {
                for (array.items) |*value| {
                    value.deinit(ally);
                }
                array.deinit();
            },
            .table => |*table| {
                var iterator = table.iterator();
                while (iterator.next()) |pair| {
                    ally.free(pair.key_ptr.*);
                    pair.value_ptr.deinit(ally);
                }
                table.deinit();
            },
        }
    }

    pub fn getKind(self: *const Value) Kind {
        return @as(Value.Kind, self.inner);
    }

    pub fn format(
        self: *const Value,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;

        switch (self.inner) {
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
                try writer.writeAll("[ ");
                for (array.items) |*element| {
                    try writer.print("{} ", .{element});
                }
                try writer.writeAll("]");
            },
            .table => |table| {
                try writer.writeAll("{ ");
                var iterator = table.iterator();
                while (iterator.next()) |pair| {
                    try writer.print("\"{s}\" = {} ", .{ pair.key_ptr.*, pair.value_ptr });
                }
                try writer.writeAll("}");
            },
        }
    }

    pub fn stringify(self: *const Value, ally: std.mem.Allocator) ![]u8 {
        return std.fmt.allocPrint(ally, "{}", .{self.*});
    }
};
