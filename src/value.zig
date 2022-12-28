const std = @import("std");
const Token = @import("token.zig").Token;

pub const ValueArray = std.ArrayList(Value);
pub const ValueTable = std.StringHashMap(Value);

pub const Value = struct {
    holder: *Holder,
    origin: ?*const Token = null,

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
                    try writer.writeAll("list");
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

        pub fn deinit(self: *Inner, ally: std.mem.Allocator) void {
            switch (self.*) {
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
        switch (self.holder.inner) {
            .string => |string| {
                return Value.initString(ally, string, self.origin);
            },
            .boolean => |boolean| {
                return Value.initBoolean(ally, boolean, self.origin);
            },
            .integer => |integer| {
                return Value.initInteger(ally, integer, self.origin);
            },
            .array => |array| {
                var new_array = try ValueArray.initCapacity(ally, array.items.len);
                for (array.items) |*old_element| {
                    new_array.appendAssumeCapacity(try old_element.clone(ally));
                }
                return Value.initArray(ally, new_array, self.origin);
            },
            .table => |table| {
                var new_table = ValueTable.init(ally);
                var it = table.iterator();
                while (it.next()) |pair| {
                    const key = try ally.dupe(u8, pair.key_ptr.*);
                    const value = try pair.value_ptr.clone(ally);
                    try new_table.put(key, value);
                }
                return Value.initTable(ally, new_table, self.origin);
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

    pub fn initString(ally: std.mem.Allocator, str: []const u8, origin: ?*const Token) !Value {
        return Value{
            .holder = try initHolder(ally, .{
                .string = try ally.dupe(u8, str),
            }),
            .origin = origin,
        };
    }

    pub fn initInteger(ally: std.mem.Allocator, integer: i64, origin: ?*const Token) !Value {
        return Value{
            .holder = try initHolder(ally, .{
                .integer = integer,
            }),
            .origin = origin,
        };
    }

    pub fn initBoolean(ally: std.mem.Allocator, boolean: bool, origin: ?*const Token) !Value {
        return Value{
            .holder = try initHolder(ally, .{
                .boolean = boolean,
            }),
            .origin = origin,
        };
    }

    pub fn initArray(ally: std.mem.Allocator, array: ValueArray, origin: ?*const Token) !Value {
        return Value{
            .holder = try initHolder(ally, .{
                .array = array,
            }),
            .origin = origin,
        };
    }

    pub fn initTable(ally: std.mem.Allocator, table: ValueTable, origin: ?*const Token) !Value {
        return Value{
            .holder = try initHolder(ally, .{
                .table = table,
            }),
            .origin = origin,
        };
    }

    fn initHolder(ally: std.mem.Allocator, inner: Inner) !*Holder {
        var holder = try ally.create(Holder);
        holder.* = .{
            .inner = inner,
            .refCount = 1,
        };
        std.debug.print("initing {*}\n", .{holder});
        return holder;
    }

    pub fn byConversion(ally: std.mem.Allocator, original_str: []const u8, token: *const Token) !Value {
        const str = std.mem.trimRight(u8, original_str, &std.ascii.spaces);

        if (std.mem.eql(u8, str, "true")) {
            return Value.initBoolean(ally, true, token);
        }

        if (std.mem.eql(u8, str, "false")) {
            return Value.initBoolean(ally, false, token);
        }

        if (std.fmt.parseInt(i64, str, 0)) |integer| {
            return Value.initInteger(ally, integer, token);
        } else |err| {
            err catch {};
        }

        // unconvertable, leave as-is
        return Value.initString(ally, original_str, token);
    }

    pub fn deinit(self: *Value, ally: std.mem.Allocator) void {
        std.debug.print("deiniting {*}\n", .{self.holder});
        std.debug.assert(self.holder.refCount >= 0);
        self.holder.refCount -= 1;
        if (self.holder.refCount == 0) {
            self.holder.inner.deinit(ally);
            ally.destroy(self.holder);
        }
    }

    pub fn refOrClone(self: *Value, ally: std.mem.Allocator) !Value {
        std.debug.print("ref/cloning: {*}\n", .{self.holder});
        return switch (self.holder.inner) {
            .string, .integer, .boolean => try self.clone(ally),
            .array, .table => self.ref(),
        };
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

        switch (self.holder.inner) {
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
