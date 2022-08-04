const std = @import("std");
const ast = @import("ast.zig");
const SymTable = @import("symtable.zig").SymTable;
const Value = @import("symtable.zig").Value;
const ValueArray = @import("symtable.zig").ValueArray;
const assert = std.debug.assert;
const print = std.debug.print;
const math = std.math;

pub const Interpreter = struct {
    const Builtins = std.StringHashMap(builtin_signature);

    ally: std.mem.Allocator = undefined,
    root_node: *ast.Root = undefined,
    collected_value: ?Value = null,
    return_just_handled: bool = false,
    call_args: ValueArray = undefined,
    collected_return: ?Value = null,
    last_visited_variable: ?*ast.Variable = null,
    sym_table: SymTable = undefined,
    piped_value: ?Value = null,
    is_piping: bool = false,
    builtins: Builtins = undefined,

    pub fn init(ally: std.mem.Allocator) !Interpreter {
        var builtins = Builtins.init(ally);

        inline for (builtins_array) |builtin| {
            const name = builtin[0];
            const func = builtin[1];
            try builtins.put(name, func);
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

    fn handleStatement(self: *Interpreter, stmnt: *const ast.Statement) !void {
        switch (stmnt.*) {
            .var_decl => |*var_decl| {
                try self.handleVarDeclaration(var_decl);
            },
            .fn_decl => unreachable,
            .ret => |*ret| {
                try self.handleReturn(ret);
            },
            .scope => unreachable,
            .branch => unreachable,
            .loop => unreachable,
            .assignment => |*assignment| {
                try self.handleAssignment(assignment);
            },
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

        //TODO: redeclaration check
        assert(self.sym_table.get(var_name) == null);
        try self.sym_table.put(var_name, &var_value);
    }

    fn handleFnDeclaration(self: *Interpreter, fn_decl: *const ast.FnDeclaration, args: []const Value) !?Value {
        assert(args.len == fn_decl.args.len);

        try self.sym_table.addScope();
        defer self.sym_table.dropScope();
        var i: usize = 0;
        while (i < args.len) : (i += 1) {
            const args_name = fn_decl.args[i].value;
            const args_value = &args[i];
            try self.sym_table.put(args_name, args_value);
        }

        self.collected_return = null;
        self.return_just_handled = false;

        for (fn_decl.scope.statements) |*stmnt| {
            try self.handleStatement(stmnt);
            if (self.return_just_handled) {
                return self.collected_return;
            }
        }

        return null;
    }

    fn handleReturn(self: *Interpreter, ret: *const ast.Return) !void {
        self.return_just_handled = true;
        if (ret.expr) |expr| {
            const value = (try self.handleExpr(expr)) orelse unreachable;
            self.collected_return = value;
        }
    }

    fn handleAssignment(self: *Interpreter, assign: *const ast.Assignment) !void {
        const name = assign.variable.name;
        const maybe_value = try self.handleExpr(&assign.expr);
        assert(maybe_value != null);
        try self.sym_table.put(name, &maybe_value.?);
    }

    fn handleExpr(self: *Interpreter, expr: *const ast.Expr) anyerror!?Value {
        return switch (expr.*) {
            .bareword => unreachable,
            .identifier => |*identifier| try self.handleIdentifier(identifier),
            .string_literal => |*string| try self.handleStringLiteral(string),
            .boolean_literal => |*boolean| self.handleBoolLiteral(boolean),
            .integer_literal => |*integer| self.handleIntegerLiteral(integer),
            .array_literal => unreachable,
            .variable => |*variable| try self.handleVariable(variable),
            .binary_operator => |*binary| try self.handleBinaryOperator(binary),
            .unary_operator => |*unary| try self.handleUnaryOperator(unary),
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

    fn handleBoolLiteral(_: *Interpreter, boolean: *const ast.BoolLiteral) Value {
        return .{
            .boolean = boolean.value,
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
        //TODO: this is looking up a variable that does not exist, should be an error message
        assert(maybe_value != null);
        return maybe_value.?;
    }

    fn handleBinaryOperator(self: *Interpreter, binary: *const ast.BinaryOperator) !?Value {
        assert(binary.lhs != null);
        assert(binary.rhs != null);
        const expr_lhs = binary.lhs.?;
        const expr_rhs = binary.rhs.?;

        // pipe check
        switch (binary.token.kind) {
            .Or => {
                return self.pipe(expr_lhs, expr_rhs);
            },
            else => {},
        }

        var lhs = (try self.handleExpr(expr_lhs)) orelse unreachable;
        var rhs = (try self.handleExpr(expr_rhs)) orelse unreachable;
        defer {
            lhs.deinit(self.ally);
            rhs.deinit(self.ally);
        }

        return switch (binary.token.kind) {
            .Add => self.addValues(&lhs, &rhs),
            .Subtract => self.subtractValues(&lhs, &rhs),
            .Multiply => self.multiplyValues(&lhs, &rhs),
            .Divide => try self.divideValues(&lhs, &rhs),
            .Modulo => try self.moduloValues(&lhs, &rhs),
            else => unreachable,
        };
    }

    fn handleUnaryOperator(self: *Interpreter, unary: *const ast.UnaryOperator) !Value {
        var value = (try self.handleExpr(unary.expr)) orelse unreachable;

        return switch (unary.token.kind) {
            .Subtract => self.negateValue(&value),
            else => unreachable,
        };
    }

    fn handleCall(self: *Interpreter, call: *const ast.FunctionCall) !?Value {
        const name = call.token.value;
        const has_stdin_arg = self.piped_value != null;
        const n_args = if (has_stdin_arg) call.args.len + 1 else call.args.len;

        var args_array = try ValueArray.initCapacity(self.ally, n_args);
        defer {
            for (args_array.items) |arg| {
                arg.deinit(self.ally);
            }
            args_array.deinit();
        }

        if (self.piped_value) |value| {
            try args_array.append(value);
            self.piped_value = null;
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

        return try self.executeFunction(name, args_array.items, has_stdin_arg);
    }

    fn pipe(self: *Interpreter, current: *const ast.Expr, next: *const ast.Expr) !?Value {
        var unpipe = false;
        if (!self.is_piping) {
            self.is_piping = true;
            unpipe = true;
        }

        self.piped_value = (try self.handleExpr(current)) orelse unreachable;
        if (unpipe) {
            self.is_piping = false;
        }

        return self.handleExpr(next);
    }

    fn executeFunction(self: *Interpreter, name: []const u8, args: []const Value, has_stdin_arg: bool) !?Value {

        //TODO: external cmd piping
        _ = has_stdin_arg;

        if (self.builtins.get(name)) |func| {
            return try func(self, args);
        } else {
            if (self.root_node.fn_table.get(name)) |*fn_node| {
                return try self.handleFnDeclaration(fn_node, args);
            } else {
                unreachable;
            }
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

    fn subtractValues(self: *Interpreter, lhs: *const Value, rhs: *const Value) Value {
        _ = self;
        assert(@as(Value.Kind, lhs.*) == .integer);
        assert(@as(Value.Kind, rhs.*) == .integer);

        return .{
            .integer = lhs.integer - rhs.integer,
        };
    }

    fn negateValue(self: *Interpreter, value: *const Value) Value {
        _ = self;
        assert(@as(Value.Kind, value.*) == .integer);

        return .{
            .integer = -value.integer,
        };
    }

    fn multiplyValues(self: *Interpreter, lhs: *const Value, rhs: *const Value) Value {
        _ = self;
        assert(@as(Value.Kind, lhs.*) == .integer);
        assert(@as(Value.Kind, rhs.*) == .integer);

        return .{
            .integer = lhs.integer * rhs.integer,
        };
    }

    fn divideValues(self: *Interpreter, lhs: *const Value, rhs: *const Value) !Value {
        _ = self;
        assert(@as(Value.Kind, lhs.*) == .integer);
        assert(@as(Value.Kind, rhs.*) == .integer);

        return Value{
            .integer = try math.divTrunc(i64, lhs.integer, rhs.integer),
        };
    }

    fn moduloValues(self: *Interpreter, lhs: *const Value, rhs: *const Value) !Value {
        _ = self;
        assert(@as(Value.Kind, lhs.*) == .integer);
        assert(@as(Value.Kind, rhs.*) == .integer);

        return Value{
            .integer = try math.mod(i64, lhs.integer, rhs.integer),
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
