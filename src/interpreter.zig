const std = @import("std");
const ast = @import("ast.zig");
const SymTable = @import("symtable.zig").SymTable;
const Value = @import("symtable.zig").Value;
const ValueArray = @import("symtable.zig").ValueArray;
const spawn = @import("spawn.zig");
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
            .scope => |*scope| {
                try self.handleScope(scope);
            },
            .branch => |*branch| {
                try self.handleBranch(branch);
            },
            .loop => |*loop| {
                try self.handleLoop(loop);
            },
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

    fn handleScope(self: *Interpreter, scope: *const ast.Scope) anyerror!void {
        try self.sym_table.addScope();
        defer self.sym_table.dropScope();

        for (scope.statements) |*stmnt| {
            try self.handleStatement(stmnt);
            if (self.return_just_handled) {
                return;
            }
        }
    }

    fn handleBranch(self: *Interpreter, branch: *const ast.Branch) anyerror!void {
        // else branch
        if (branch.condition == null) {
            try self.handleScope(&branch.scope);
            return;
        }

        const maybe_condition = try self.handleExpr(&branch.condition.?);
        assert(maybe_condition != null);
        const condition = maybe_condition.?;
        assert(@as(Value.Kind, condition.inner) == .boolean);

        if (condition.inner.boolean) {
            try self.handleScope(&branch.scope);
        } else if (branch.next) |next| {
            try self.handleBranch(next);
        }
    }

    fn handleLoop(self: *Interpreter, loop: *const ast.Loop) !void {
        try self.sym_table.addScope();
        defer self.sym_table.dropScope();

        switch (loop.*) {
            .while_loop => |*while_loop| try self.whileLoop(while_loop),
            .for_in_loop => unreachable,
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
        return Value{ .inner = .{
            .string = try self.ally.dupe(u8, identifier.token.value),
        } };
    }

    fn handleStringLiteral(self: *Interpreter, string: *const ast.StringLiteral) !Value {
        return Value{ .inner = .{
            .string = try self.ally.dupe(u8, string.token.value),
        } };
    }

    fn handleBoolLiteral(_: *Interpreter, boolean: *const ast.BoolLiteral) Value {
        return .{ .inner = .{
            .boolean = boolean.value,
        } };
    }

    fn handleIntegerLiteral(_: *Interpreter, integer: *const ast.IntegerLiteral) Value {
        return .{ .inner = .{
            .integer = integer.value,
        } };
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
            .Less => self.lessValues(&lhs, &rhs),
            .Greater => self.greaterValues(&lhs, &rhs),
            .Equals => self.equalsValues(&lhs, &rhs),
            .NotEquals => self.notEqualsValues(&lhs, &rhs),
            .LessEquals => self.lessEqualsValues(&lhs, &rhs),
            .GreaterEquals => self.greaterEqualsValues(&lhs, &rhs),
            .LogicalAnd => self.logicalAndValues(&lhs, &rhs),
            .LogicalOr => self.logicalOrValues(&lhs, &rhs),
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

    fn whileLoop(self: *Interpreter, loop: *const ast.Loop.WhileLoop) !void {
        while (true) {
            var maybe_value = try self.handleExpr(&loop.condition);
            assert(maybe_value != null);
            var inner = maybe_value.?.inner;
            assert(@as(Value.Kind, inner) == .boolean);

            if (!inner.boolean) {
                return;
            }

            try self.handleScope(&loop.scope);
            if (self.return_just_handled) {
                return;
            }
        }
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
                const n_args = if (has_stdin_arg) args.len else args.len + 1;
                const to_stringify_args = if (has_stdin_arg) args[1..] else args;
                const stringified_args = try self.ally.alloc([]u8, n_args);
                var stringified_stdin: ?[]u8 = null;
                defer {
                    if (stringified_stdin) |stdin| {
                        self.ally.free(stdin);
                    }
                    for (stringified_args) |arg| {
                        self.ally.free(arg);
                    }
                    self.ally.free(stringified_args);
                }

                if (has_stdin_arg) {
                    stringified_stdin = try args[0].stringify(self.ally);
                }

                stringified_args[0] = try self.ally.dupe(u8, name);
                for (to_stringify_args) |*value, i| {
                    stringified_args[i + 1] = try value.stringify(self.ally);
                }

                const opts = spawn.SpawnCommandOptions{
                    .capture_stdout = true,
                    .stdin_slice = stringified_stdin,
                };

                const result = try spawn.cmd(self.ally, stringified_args, opts);

                if (result.stdout) |stdout| {
                    return Value{
                        .inner = .{
                            .string = std.mem.trimRight(u8, stdout, &std.ascii.spaces),
                        },
                    };
                }
            }
        }

        return null;
    }

    fn addValues(self: *Interpreter, lhs: *const Value, rhs: *const Value) Value {
        _ = self;
        assert(@as(Value.Kind, lhs.inner) == .integer);
        assert(@as(Value.Kind, rhs.inner) == .integer);

        return .{ .inner = .{
            .integer = lhs.inner.integer + rhs.inner.integer,
        } };
    }

    fn subtractValues(self: *Interpreter, lhs: *const Value, rhs: *const Value) Value {
        _ = self;
        assert(@as(Value.Kind, lhs.inner) == .integer);
        assert(@as(Value.Kind, rhs.inner) == .integer);

        return .{ .inner = .{
            .integer = lhs.inner.integer - rhs.inner.integer,
        } };
    }

    fn negateValue(self: *Interpreter, value: *const Value) Value {
        _ = self;
        assert(@as(Value.Kind, value.inner) == .integer);

        return .{ .inner = .{
            .integer = -value.inner.integer,
        } };
    }

    fn multiplyValues(self: *Interpreter, lhs: *const Value, rhs: *const Value) Value {
        _ = self;
        assert(@as(Value.Kind, lhs.inner) == .integer);
        assert(@as(Value.Kind, rhs.inner) == .integer);

        return .{ .inner = .{
            .integer = lhs.inner.integer * rhs.inner.integer,
        } };
    }

    fn divideValues(self: *Interpreter, lhs: *const Value, rhs: *const Value) !Value {
        _ = self;
        assert(@as(Value.Kind, lhs.inner) == .integer);
        assert(@as(Value.Kind, rhs.inner) == .integer);

        return Value{ .inner = .{
            .integer = try math.divTrunc(i64, lhs.inner.integer, rhs.inner.integer),
        } };
    }

    fn moduloValues(self: *Interpreter, lhs: *const Value, rhs: *const Value) !Value {
        _ = self;
        assert(@as(Value.Kind, lhs.inner) == .integer);
        assert(@as(Value.Kind, rhs.inner) == .integer);

        return Value{ .inner = .{
            .integer = try math.mod(i64, lhs.inner.integer, rhs.inner.integer),
        } };
    }

    fn lessValues(self: *Interpreter, lhs: *const Value, rhs: *const Value) Value {
        _ = self;
        const lhs_kind = @as(Value.Kind, lhs.inner);
        const rhs_kind = @as(Value.Kind, rhs.inner);
        assert(lhs_kind == rhs_kind);
        return .{
            .inner = .{
                .boolean = switch (lhs_kind) {
                    .integer => lhs.inner.integer < rhs.inner.integer,
                    .string => std.mem.lessThan(u8, lhs.inner.string, rhs.inner.string),
                    .array => {
                        //TODO: should maybe work(?)
                        unreachable;
                    },
                    .boolean => {
                        // should be error
                        assert(false);
                        unreachable;
                    },
                },
            },
        };
    }

    fn greaterValues(self: *Interpreter, lhs: *const Value, rhs: *const Value) Value {
        _ = self;
        const lhs_kind = @as(Value.Kind, lhs.inner);
        const rhs_kind = @as(Value.Kind, rhs.inner);
        assert(lhs_kind == rhs_kind);
        return .{
            .inner = .{
                .boolean = switch (lhs_kind) {
                    .integer => lhs.inner.integer > rhs.inner.integer,
                    .string => std.mem.order(u8, lhs.inner.string, rhs.inner.string) == .gt,
                    .array => {
                        //TODO: should maybe work(?)
                        unreachable;
                    },
                    .boolean => {
                        // should be error
                        assert(false);
                        unreachable;
                    },
                },
            },
        };
    }

    fn notValue(self: *Interpreter, value: *const Value) Value {
        _ = self;
        _ = value;
        unreachable;
    }

    fn equalsValues(self: *Interpreter, lhs: *const Value, rhs: *const Value) Value {
        _ = self;
        _ = lhs;
        _ = rhs;
        unreachable;
    }

    fn notEqualsValues(self: *Interpreter, lhs: *const Value, rhs: *const Value) Value {
        _ = self;
        _ = lhs;
        _ = rhs;
        unreachable;
    }

    fn lessEqualsValues(self: *Interpreter, lhs: *const Value, rhs: *const Value) Value {
        _ = self;
        _ = lhs;
        _ = rhs;
        unreachable;
    }

    fn greaterEqualsValues(self: *Interpreter, lhs: *const Value, rhs: *const Value) Value {
        _ = self;
        _ = lhs;
        _ = rhs;
        unreachable;
    }

    fn logicalAndValues(self: *Interpreter, lhs: *const Value, rhs: *const Value) Value {
        _ = self;
        _ = lhs;
        _ = rhs;
        unreachable;
    }

    fn logicalOrValues(self: *Interpreter, lhs: *const Value, rhs: *const Value) Value {
        _ = self;
        _ = lhs;
        _ = rhs;
        unreachable;
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
        switch (last_arg.inner) {
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
