const std = @import("std");
const Token = @import("token.zig").Token;

pub const ValueArray = std.ArrayList(Value);
pub const ValueTable = std.StringHashMap(Value);

pub const Value = struct {
    holder: *Holder,
    //inner: Inner = undefined,
    origin: ?*const Token = null,
    //owned: bool = false,
    //may_free: bool = true,

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
                    try writer.writeAll("table");
                },
            }
        }
    };

    pub const Holder = struct {
        inner: Inner,
        refCount: u32,
    };

    pub const Inner = union(Kind) {
        string: []const u8,
        boolean: bool,
        integer: i64,
        array: ValueArray,
        table: ValueTable,

        pub fn deinit(self: Inner, ally: std.mem.Allocator) void {
            switch (self.inner) {
                .string => |string| {
                    ally.free(string);
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
    };

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

    pub fn init(ally: std.mem.Allocator, inner: anytype, origin: *const Token) !Value {
        return switch (@TypeOf(inner)) {
            []const u8 => initString(ally, inner, origin),
            i64 => initInteger(ally, inner, origin),
            bool => initBoolean(ally, inner, origin),
            ValueArray => initArray(ally, inner, origin),
            ValueTable => initTable(ally, inner, origin),
            else => unreachable,
        };
    }

    pub fn initString(ally: std.mem.Allocator, str: []const u8, origin: *const Token) !Value {
        var holder = try ally.create(Holder);
        holder = .{
            .inner = .{
                .string = try ally.dupe(u8, str),
            },
            .refCount = 1,
        };
        return Value{
            holder,
            origin,
        };
    }

    pub fn initInteger(ally: std.mem.Allocator, integer: i64, origin: *const Token) !Value {
        var holder = try ally.create(Holder);
        holder.* = .{
            .inner = .{
                .integer = integer,
            },
            .refCount = 1,
        };
        return Value{
            .holder = holder,
            .origin = origin,
        };
    }

    pub fn initBoolean(ally: std.mem.Allocator, boolean: bool, origin: *const Token) !Value {
        var holder = try ally.create(Holder);
        holder.* = .{
            .inner = .{
                .boolean = boolean,
            },
            .refCount = 1,
        };
        return Value{
            .holder = holder,
            .origin = origin,
        };
    }

    pub fn initArray(ally: std.mem.Allocator, array: ValueArray, origin: *const Token) !Value {
        var holder = try ally.create(Holder);
        holder.* = .{
            .inner = .{
                .array = array,
            },
            .refCount = 1,
        };
        return Value{
            .holder = holder,
            .origin = origin,
        };
    }

    pub fn initTable(ally: std.mem.Allocator, table: ValueTable, origin: *const Token) !Value {
        var holder = try ally.create(Holder);
        holder.* = .{
            .inner = .{
                .table = table,
            },
            .refCount = 1,
        };
        return Value{
            .holder = holder,
            .origin = origin,
        };
    }

    pub fn byConversion(ally: std.mem.Allocator, original_str: []const u8, token: *const Token) Value {
        const str = std.mem.trimRight(u8, original_str, &std.ascii.spaces);

        if (std.mem.eql(u8, str, "true")) {
            return Value.initBoolean(true, ally, token);
        }

        if (std.mem.eql(u8, str, "false")) {
            return Value.initBoolean(false, ally, token);
        }

        if (std.fmt.parseInt(i64, str, 0)) |integer| {
            return Value.initInteger(integer, ally, token);
        } else |err| {
            err catch {};
        }

        // unconvertable, leave as-is
        return Value.initString(ally, original_str, token);
    }

    pub fn deinit(self: *Value, ally: std.mem.Allocator) void {
        self.holder.refCount -= 1;
        if (self.holder.refCount == 0) {
            self.holder.inner.deinit(ally);
        }
    }

    pub fn ref(self: *Value) Value {
        self.holder.refCount += 1;
        return self.*;
    }

    pub fn getKind(self: *const Value) Kind {
        return @as(Value.Kind, self.holder.inner);
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
