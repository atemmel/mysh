const std = @import("std");
const ast = @import("ast.zig");
const SymTable = @import("symtable.zig").SymTable;
const Value = @import("symtable.zig").Value;
const ValueArray = @import("symtable.zig").ValueArray;
const assert = std.debug.assert;
const print = std.debug.print;

pub const Interpreter = struct {
    const Builtins = std.StringHashMap(builtin_signature);

    ally: std.mem.Allocator = undefined,
    root_node: *ast.Root = undefined,
    collected_values: ValueArray = undefined,
    call_args: ValueArray = undefined,
    to_return: ?Value = null,
    last_visited_variable: ?*ast.Variable = null,
    sym_table: SymTable = undefined,
    piping: bool = false,
    builtins: Builtins = undefined,

    pub fn init(ally: std.mem.Allocator) !Interpreter {
        var builtins = Builtins.init(ally);

        inline for (builtins_array) |builtin| {
            try builtins.put(builtin[0], builtin[1]);
        }

        return Interpreter{
            .ally = ally,
            .collected_values = ValueArray.init(ally),
            .call_args = ValueArray.init(ally),
            .sym_table = SymTable.init(ally),
            .builtins = builtins,
        };
    }

    pub fn deinit(self: *Interpreter) void {
        self.collected_values.deinit();
        self.call_args.deinit();
        self.sym_table.deinit();
        self.builtins.deinit();
    }

    pub fn interpret(self: *Interpreter, root_node: *ast.Root) !bool {
        self.root_node = root_node;
        self.sym_table.addScope();
        try self.handleRoot();
        self.sym_table.dropScope();
        return true;
    }

    pub fn reportError(self: *Interpreter) void {
        _ = self;
        print("Reporting errors :)))\n", .{});
    }

    fn handleRoot(self: *Interpreter) !void {
        var root = self.root_node;
        for (root.statements) |*stmnt| {
            try self.handleStatement(stmnt);

            const n_collected = self.collected_values.items.len;
            if (n_collected > 0) {
                assert(n_collected == 1);
                //builtinPrint(self, collected_values.items);
            }
            self.collected_values.clearRetainingCapacity();
        }
    }

    fn handleStatement(self: *Interpreter, stmnt: *ast.Statement) !void {
        switch (stmnt.*) {
            .var_decl => unreachable,
            .fn_decl => unreachable,
            .ret => unreachable,
            .scope => unreachable,
            .branch => unreachable,
            .loop => unreachable,
            .assignment => unreachable,
            .expr => |*expr| {
                try self.handleExpr(expr);
            },
        }
    }

    fn handleExpr(self: *Interpreter, expr: *const ast.Expr) anyerror!void {
        switch (expr.*) {
            .bareword => unreachable,
            .identifier => |*identifier| {
                try self.handleIdentifier(identifier);
            },
            .string_literal => |*string| {
                try self.handleStringLiteral(string);
            },
            .boolean_literal => unreachable,
            .integer_literal => unreachable,
            .array_literal => unreachable,
            .variable => unreachable,
            .binary_operator => unreachable,
            .unary_operator => unreachable,
            .call => |*call| {
                try self.handleCall(call);
            },
        }
    }

    fn handleIdentifier(self: *Interpreter, identifier: *const ast.Identifier) !void {
        try self.collected_values.append(.{
            .string = try self.ally.dupe(u8, identifier.token.value),
        });
    }

    fn handleStringLiteral(self: *Interpreter, string: *const ast.StringLiteral) !void {
        try self.collected_values.append(.{
            .string = try self.ally.dupe(u8, string.token.value),
        });
    }

    fn handleCall(self: *Interpreter, call: *const ast.FunctionCall) !void {
        const name = call.token.value;

        //TODO: stdin check
        const stdin_arg: ?Value = null;

        const n_args = call.args.len;

        try self.collected_values.ensureTotalCapacity(n_args);
        for (call.args) |*arg| {
            try self.handleExpr(arg);
        }

        var args = self.collected_values.toOwnedSlice();
        defer {
            for (args) |arg| {
                arg.deinit(self.ally);
            }
            self.ally.free(args);
        }

        assert(args.len == n_args);

        var maybe_result = try self.executeFunction(name, args, stdin_arg);
        if (maybe_result) |result| {
            try self.collected_values.append(result);
        } else {
            //TODO: ?
        }
    }

    fn executeFunction(self: *Interpreter, name: []const u8, args: []const Value, stdin_arg: ?Value) !?Value {
        _ = stdin_arg;

        if (self.builtins.get(name)) |func| {
            return try func(self, args);
        } else {
            unreachable;
        }

        return null;
    }
};

const builtin_signature = fn (interp: *Interpreter, args: []const Value) anyerror!?Value;

const builtins_array = .{
    .{ "print", builtinPrint },
};

fn builtinPrint(interp: *Interpreter, args: []const Value) !?Value {
    _ = interp;
    for (args) |*arg| {
        print("{} ", .{arg.*});
    }

    // trailing newline check
    if (args.len > 0) {
        const last_arg = args[args.len - 1];
        switch (last_arg) {
            .string => |string| {
                if (string.len > 0) {
                    const last_byte = string[string.len - 1];
                    if (last_byte == '\n') {
                        return null;
                    }
                }
            },
            else => {},
        }
    }
    print("\n", .{});
    return null;
}
