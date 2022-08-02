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
    collected_value: ?Value = null,
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
            .call_args = ValueArray.init(ally),
            .sym_table = SymTable.init(ally),
            .builtins = builtins,
        };
    }

    pub fn deinit(self: *Interpreter) void {
        self.call_args.deinit();
        self.sym_table.deinit();
        self.builtins.deinit();
    }

    pub fn interpret(self: *Interpreter, root_node: *ast.Root) !bool {
        self.root_node = root_node;
        try self.sym_table.addScope();
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
        }
    }

    fn handleStatement(self: *Interpreter, stmnt: *ast.Statement) !void {
        switch (stmnt.*) {
            .var_decl => |*var_decl| {
                try self.handleVarDeclaration(var_decl);
            },
            .fn_decl => unreachable,
            .ret => unreachable,
            .scope => unreachable,
            .branch => unreachable,
            .loop => unreachable,
            .assignment => unreachable,
            .expr => |*expr| {
                const err_maybe_value = self.handleExpr(expr);
                if (err_maybe_value) |maybe_value| {
                    if (maybe_value) |value| {
                        const value_array = [_]Value{
                            value,
                        };
                        _ = try builtinPrint(self, &value_array);
                    }
                } else |err| {
                    return err;
                }
            },
        }
    }

    fn handleVarDeclaration(self: *Interpreter, var_decl: *const ast.VarDeclaration) !void {
        _ = self;
        _ = var_decl;

        const var_name = var_decl.decl;
        var var_value: Value = undefined;

        assert(var_decl.expr != null);
        const err_maybe_value = self.handleExpr(&var_decl.expr.?);
        if (err_maybe_value) |maybe_value| {
            if (maybe_value) |value| {
                var_value = value;
            } else {
                unreachable;
            }
        } else |err| {
            return err;
        }

        try self.sym_table.put(var_name, &var_value);
    }

    fn handleExpr(self: *Interpreter, expr: *const ast.Expr) anyerror!?Value {
        return switch (expr.*) {
            .bareword => unreachable,
            .identifier => |*identifier| try self.handleIdentifier(identifier),
            .string_literal => |*string| try self.handleStringLiteral(string),
            .boolean_literal => unreachable,
            .integer_literal => |*integer| self.handleIntegerLiteral(integer),
            .array_literal => unreachable,
            .variable => |*variable| try self.handleVariable(variable),
            .binary_operator => |*binary| try self.handleBinaryOperator(binary),
            .unary_operator => unreachable,
            .call => |*call| try self.handleCall(call),
        };
    }

    fn handleIdentifier(self: *Interpreter, identifier: *const ast.Identifier) !Value {
        return Value{
            .string = try self.ally.dupe(u8, identifier.token.value),
        };
    }

    fn handleStringLiteral(self: *Interpreter, string: *const ast.StringLiteral) !Value {
        return Value{
            .string = try self.ally.dupe(u8, string.token.value),
        };
    }

    fn handleIntegerLiteral(_: *Interpreter, integer: *const ast.IntegerLiteral) Value {
        return .{
            .integer = integer.value,
        };
    }

    fn handleVariable(self: *Interpreter, variable: *const ast.Variable) !Value {
        const name = variable.name;
        const maybe_value = self.sym_table.get(name);
        //TODO: this is looking up a variable that does not exist
        assert(maybe_value != null);
        return maybe_value.?;
    }

    fn handleBinaryOperator(self: *Interpreter, binary: *const ast.BinaryOperator) !Value {
        assert(binary.lhs != null);
        assert(binary.rhs != null);
        const expr_lhs = binary.lhs.?;
        const expr_rhs = binary.rhs.?;

        var lhs = (try self.handleExpr(expr_lhs)) orelse unreachable;
        var rhs = (try self.handleExpr(expr_rhs)) orelse unreachable;
        defer {
            lhs.deinit(self.ally);
            rhs.deinit(self.ally);
        }

        return switch (binary.token.kind) {
            .Add => self.addValues(&lhs, &rhs),
            else => unreachable,
        };
    }

    fn handleCall(self: *Interpreter, call: *const ast.FunctionCall) !?Value {
        const name = call.token.value;

        //TODO: stdin check
        const stdin_arg: ?Value = null;

        const n_args = call.args.len;

        var args_array = try ValueArray.initCapacity(self.ally, n_args);
        defer {
            for (args_array.items) |arg| {
                arg.deinit(self.ally);
            }
            args_array.deinit();
        }

        for (call.args) |*arg| {
            const err_maybe_arg = self.handleExpr(arg);
            if (err_maybe_arg) |maybe_arg| {
                assert(maybe_arg != null);
                args_array.appendAssumeCapacity(maybe_arg.?);
            } else |err| {
                return err;
            }
        }

        assert(args_array.items.len == n_args);

        return try self.executeFunction(name, args_array.items, stdin_arg);
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

    fn addValues(self: *Interpreter, lhs: *const Value, rhs: *const Value) Value {
        _ = self;
        assert(@as(Value.Kind, lhs.*) == .integer);
        assert(@as(Value.Kind, rhs.*) == .integer);

        return .{
            .integer = lhs.integer + rhs.integer,
        };
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