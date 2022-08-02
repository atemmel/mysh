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
            entry.value_ptr.deinit(self.ally);
        }
    }

    fn lookup(self: *SymTable, name: []const u8) usize {
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
        try scope.put(name, value.*);
    }

    pub fn get(self: *SymTable, name: []const u8) ?Value {
        const idx = self.lookup(name);
        var scope = &self.scopes.items[idx];
        return scope.get(name);
    }
};
