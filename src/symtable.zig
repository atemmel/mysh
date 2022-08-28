const std = @import("std");
const Token = @import("token.zig").Token;

pub const ValueArray = std.ArrayList(Value);
pub const ValueStruct = std.StringHashMap(Value);

pub const Value = struct {
    pub const Kind = enum {
        string,
        boolean,
        integer,
        array,
        struct_,

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
                .struct_ => {
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
        struct_: ValueStruct,
    };

    inner: Inner = undefined,
    origin: ?*const Token = undefined,
    owned: bool = false,
    may_free: bool = true,

    pub fn clone(self: *const Value, ally: std.mem.Allocator) std.mem.Allocator.Error!Value {
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
                for (new_array.items) |*element, i| {
                    element.* = try array.items[i].clone(ally);
                }
                return Value{
                    .inner = .{
                        .array = new_array,
                    },
                };
            },
            .struct_ => |struct_| {
                if (!self.may_free) {
                    return self.*;
                }
                var new_struct = ValueStruct.init(ally);
                var it = struct_.iterator();
                while (it.next()) |pair| {
                    const key = try ally.dupe(u8, pair.key_ptr.*);
                    const value = try pair.value_ptr.clone(ally);
                    try new_struct.put(key, value);
                }
                return Value{
                    .inner = .{
                        .struct_ = new_struct,
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
            },
            .boolean => {},
            .integer => {},
            .array => |array| {
                for (array.items) |*value| {
                    value.deinit(ally);
                }
                array.deinit();
            },
            .struct_ => |*struct_| {
                var iterator = struct_.iterator();
                while (iterator.next()) |pair| {
                    ally.free(pair.key_ptr.*);
                    pair.value_ptr.deinit(ally);
                }
                struct_.deinit();
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
            .struct_ => |struct_| {
                try writer.writeAll("{ ");
                var iterator = struct_.iterator();
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

pub const SymTable = struct {
    const Scope = std.StringHashMap(Value);
    const Scopes = std.ArrayList(Scope);

    scopes: Scopes = undefined,
    ally: std.mem.Allocator = undefined,

    pub fn init(ally: std.mem.Allocator) SymTable {
        return .{
            .ally = ally,
            .scopes = Scopes.init(ally),
        };
    }

    pub fn deinit(self: *SymTable) void {
        defer self.scopes.deinit();
        while (self.scopes.items.len > 0) {
            self.dropScope();
        }
    }

    pub fn addScope(self: *SymTable) !void {
        try self.scopes.append(
            Scope.init(self.ally),
        );
    }

    pub fn dropScope(self: *SymTable) void {
        var scope = self.scopes.pop();
        defer scope.deinit();
        var iterator = scope.iterator();
        while (iterator.next()) |entry| {
            entry.value_ptr.deinitWithOwnership(self.ally);
        }
    }

    fn lookup(self: *const SymTable, name: []const u8) usize {
        const n_scopes = self.scopes.items.len;
        const last_scope = n_scopes - 1;
        var i: usize = 0;
        while (i < n_scopes) : (i += 1) {
            var scope = &self.scopes.items[i];
            if (scope.get(name) != null) {
                return i;
            }
        }
        return last_scope;
    }

    pub fn put(self: *SymTable, name: []const u8, value: *const Value) !void {
        const idx = self.lookup(name);
        var scope = &self.scopes.items[idx];

        if (scope.getPtr(name)) |prev_value| {
            prev_value.deinitWithOwnership(self.ally);
        }

        const inserted_value: Value = .{
            .inner = value.inner,
            .owned = true,
            .may_free = value.may_free,
        };
        try scope.put(name, inserted_value);
    }

    pub fn get(self: *const SymTable, name: []const u8) ?Value {
        const idx = self.lookup(name);
        var scope = &self.scopes.items[idx];
        return scope.get(name);
    }
};
