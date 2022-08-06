const std = @import("std");

pub const ValueArray = std.ArrayList(Value);

pub const Value = struct {
    pub const Kind = enum {
        string,
        boolean,
        integer,
        array,
    };

    pub const Inner = union(Kind) {
        string: []const u8,
        boolean: bool,
        integer: i64,
        array: ValueArray,
    };

    inner: Inner = undefined,
    owned: bool = false,
    may_free: bool = true,

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

    pub fn deinit(self: *const Value, ally: std.mem.Allocator) void {
        if (!self.owned) {
            self.deinitWithOwnership(ally);
        }
    }

    pub fn deinitWithOwnership(self: *const Value, ally: std.mem.Allocator) void {
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
                try writer.print("{any}", .{array.items});
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

        if (scope.get(name)) |*prev_value| {
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
