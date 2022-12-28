const std = @import("std");
const Token = @import("token.zig").Token;
const Value = @import("value.zig").Value;

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

    pub fn put(self: *SymTable, name: []const u8, value: *Value) !void {
        const idx = self.lookup(name);
        var scope = &self.scopes.items[idx];

        if (scope.getPtr(name)) |prev_value| {
            prev_value.deinit(self.ally);
        }

        try scope.put(name, value.*);
    }

    pub fn get(self: *const SymTable, name: []const u8) ?Value {
        const idx = self.lookup(name);
        var scope = &self.scopes.items[idx];
        return scope.get(name);
    }

    pub fn dump(self: *const SymTable) void {
        var depth: usize = 0;
        for (self.scopes.items) |*scope| {
            pad(depth);
            var it = scope.iterator();
            while (it.next()) |entry| {
                std.debug.print("({*}) {s} = {}\n", .{ entry.value_ptr.holder, entry.key_ptr.*, entry.value_ptr });
            }
            depth += 1;
        }
    }

    fn pad(u: usize) void {
        var i: usize = 0;
        while (i < u) : (i += 1) {
            std.debug.print("  ", .{});
        }
    }
};
