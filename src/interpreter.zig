const std = @import("std");
const ast = @import("ast.zig");
const Token = @import("token.zig").Token;
const SymTable = @import("symtable.zig").SymTable;
const Value = @import("symtable.zig").Value;
const ValueArray = @import("symtable.zig").ValueArray;
const spawn = @import("spawn.zig");
const interpolate = @import("interpolate.zig");
const escape = @import("escape.zig");
const mysh_builtins = @import("builtins.zig");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const todo = std.debug.todo;
const print = std.debug.print;
const math = std.math;

const InterpreterError = error{
    RuntimeError,
};

pub const Interpreter = struct {
    const Builtins = std.StringHashMap(mysh_builtins.Signature);

    const ErrorInfo = union(Kind) {
        const Kind = enum {
            valueless_expression,
            type_mismatch,
            argument_count_mismatch,
        };

        const ValuelessExpression = struct {
            // token which caused the error
            token: *const Token = undefined,
            // expected type
            expected_type: Value.Kind = undefined,
        };

        const TypeMismatch = struct {
            // token which caused the error
            token: *const Token = undefined,
            expected_type: Value.Kind = undefined,
            found_type: Value.Kind = undefined,
        };

        const ArgumentCountMismatch = struct {
            // token which caused the error
            token: *const Token = undefined,
            expected_argument_count: usize = undefined,
            found_argument_count: usize = undefined,
        };

        valueless_expression: ValuelessExpression,
        type_mismatch: TypeMismatch,
        argument_count_mismatch: ArgumentCountMismatch,
    };

    ally: Allocator = undefined,
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
    error_info: ?ErrorInfo = null,

    pub fn init(ally: Allocator) !Interpreter {
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

    pub fn interpret(self: *Interpreter, root_node: *ast.Root) !void {
        self.root_node = root_node;
        try self.sym_table.addScope();
        defer self.sym_table.dropScope();
        try self.handleRoot();
    }

    pub fn reportError(self: *Interpreter) void {
        if (self.error_info) |*error_info| {
            switch (error_info.*) {
                .valueless_expression => {
                    todo("Handle valueless_expression error");
                },
                .type_mismatch => |*mismatch| {
                    //TODO: fix the error msg ordering
                    print("Type mismatch, expected: {}, found: {}\n", .{
                        mismatch.expected_type,
                        mismatch.found_type,
                    });
                    self.reportTokenCausingError(mismatch.token);
                },
                .argument_count_mismatch => {
                    todo("Handle argument_count_mismatch error");
                },
            }
        }
    }

    fn reportTokenCausingError(self: *Interpreter, token: *const Token) void {
        //TODO: clean this mess up
        const tokens = self.root_node.tokens;
        const source = self.root_node.source;
        const first = @ptrToInt(tokens.ptr);
        const needle = @ptrToInt(token);
        const token_struct_size = @sizeOf(Token);
        const idx = (needle - first) / token_struct_size;

        var look_behind: usize = idx;
        var look_ahead: usize = idx;
        while (look_behind > 0) : (look_behind -= 1) {
            if (tokens[look_behind].kind == .Newline) {
                look_behind += 1;
                break;
            }
        }

        while (look_ahead < tokens.len) : (look_ahead += 1) {
            if (tokens[look_ahead].kind == .Newline) {
                break;
            }
        }

        const source_begin = tokens[look_behind].value;
        const source_end = tokens[look_ahead].value;
        const source_begin_addr = @ptrToInt(source_begin.ptr);
        const source_end_addr = @ptrToInt(source_end.ptr);

        const source_ptr_addr = @ptrToInt(source.ptr);

        const source_begin_idx = (source_begin_addr - source_ptr_addr) / @sizeOf(u8);
        const source_end_idx = (source_end_addr - source_ptr_addr) / @sizeOf(u8);

        const source_slice = source[source_begin_idx..source_end_idx];

        const bad_source_begin_addr = @ptrToInt(token.value.ptr);
        const bad_source_begin_idx = (bad_source_begin_addr - source_ptr_addr) / @sizeOf(u8);
        const bad_source_end_idx = bad_source_begin_idx + token.value.len;

        print("row: {}, column:{} \x1b[31merror:\x1b[0m ", .{ token.row, token.column });
        print("Token no. {} was bad blablabla\n", .{idx});
        print("{s}\n", .{source_slice});

        var left = source_begin_idx;
        var right = source_end_idx;
        while (left < right) : (left += 1) {
            if (left + 1 >= bad_source_begin_idx and left <= bad_source_end_idx) {
                print("\x1b[32m^", .{});
            } else {
                print("\x1b[0m ", .{});
            }
        }
        print("\n", .{});
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
                        defer value.deinit(self.ally);
                        const value_array = [_]Value{
                            value,
                        };
                        _ = try mysh_builtins.print(self, &value_array);
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

        //TODO: Consider this, likely not useful
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
            const args_value = Value{
                .inner = args[i].inner,
                .may_free = false,
            };
            try self.sym_table.put(args_name, &args_value);
        }

        self.collected_return = null;
        self.return_just_handled = false;

        for (fn_decl.scope.statements) |*stmnt| {
            try self.handleStatement(stmnt);
            if (self.return_just_handled) {
                self.return_just_handled = false;
                const return_copy = self.collected_return;
                self.collected_return = null;
                return return_copy;
            }
        }

        self.return_just_handled = false;
        const return_copy = self.collected_return;
        self.collected_return = null;

        return return_copy;
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
            .for_in_loop => |*for_in_loop| try self.forInLoop(for_in_loop),
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
            .bareword => |*bareword| try self.handleBareword(bareword),
            .identifier => |*identifier| self.handleIdentifier(identifier),
            .string_literal => |*string| try self.handleStringLiteral(string),
            .boolean_literal => |*boolean| self.handleBoolLiteral(boolean),
            .integer_literal => |*integer| self.handleIntegerLiteral(integer),
            .array_literal => |*array| try self.handleArrayLiteral(array),
            .variable => |*variable| try self.handleVariable(variable),
            .binary_operator => |*binary| try self.handleBinaryOperator(binary),
            .unary_operator => |*unary| try self.handleUnaryOperator(unary),
            .call => |*call| try self.handleCall(call),
        };
    }

    fn handleBareword(self: *Interpreter, bareword: *const ast.Bareword) !Value {
        return Value{
            .inner = .{
                .string = try self.ally.dupe(u8, bareword.token.value),
            },
            .origin = bareword.token,
        };
    }

    fn handleIdentifier(self: *Interpreter, identifier: *const ast.Identifier) Value {
        _ = self;
        return Value{
            .inner = .{
                .string = identifier.token.value,
            },
            .may_free = false,
            .origin = identifier.token,
        };
    }

    fn handleStringLiteral(self: *Interpreter, string: *const ast.StringLiteral) !Value {
        var final_string = string.token.value;
        var may_free = false;

        if (try interpolate.maybe(self.ally, final_string, &self.sym_table)) |interpolated| {
            final_string = interpolated;
            may_free = true;
        }

        if (try escape.maybe(self.ally, final_string)) |escaped| {
            if (may_free) {
                self.ally.free(final_string);
            }

            final_string = escaped;
            may_free = true;
        }

        return Value{
            .inner = .{
                .string = final_string,
            },
            .may_free = may_free,
            .origin = string.token,
        };
    }

    fn handleBoolLiteral(_: *Interpreter, boolean: *const ast.BoolLiteral) Value {
        return .{
            .inner = .{
                .boolean = boolean.value,
            },
            .origin = boolean.token,
        };
    }

    fn handleIntegerLiteral(_: *Interpreter, integer: *const ast.IntegerLiteral) Value {
        return .{
            .inner = .{
                .integer = integer.value,
            },
            .origin = integer.token,
        };
    }

    fn handleArrayLiteral(self: *Interpreter, array: *const ast.ArrayLiteral) !Value {
        var value = try ValueArray.initCapacity(self.ally, array.value.len);

        for (array.value) |*element| {
            const err_maybe_val = self.handleExpr(element);
            if (err_maybe_val) |maybe_val| {
                assert(maybe_val != null);
                value.appendAssumeCapacity(maybe_val.?);
            } else |err| {
                return err;
            }
        }

        assert(value.items.len == array.value.len);

        return Value{
            .inner = .{
                .array = value,
            },
            .origin = array.token,
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
            .Add => self.addValues(&lhs, &rhs, binary.token) catch |err| return err,
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
            .Bang => self.notValue(&value),
            else => unreachable,
        };
    }

    fn handleCall(self: *Interpreter, call: *const ast.FunctionCall) !?Value {
        const maybe_name_value = try self.handleExpr(call.name);
        assert(maybe_name_value != null);
        assert(@as(Value.Kind, maybe_name_value.?.inner) == .string);
        defer maybe_name_value.?.deinit(self.ally);
        const name = maybe_name_value.?.inner.string;

        const has_stdin_arg = self.piped_value != null;
        const n_args = if (has_stdin_arg)
            call.args.len + 1
        else
            call.args.len;

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

    fn forInLoop(self: *Interpreter, loop: *const ast.Loop.ForInLoop) anyerror!void {
        const maybe_iterable = try self.handleExpr(&loop.iterable);
        assert(maybe_iterable != null);
        const iterable = maybe_iterable.?;
        assert(@as(Value.Kind, iterable.inner) == .array);
        defer iterable.deinit(self.ally);

        const iterator_name = loop.iterator.token.value;
        try self.sym_table.addScope();
        defer self.sym_table.dropScope();

        for (iterable.inner.array.items) |*value| {
            try self.sym_table.put(iterator_name, value);
            for (loop.scope.statements) |*stmnt| {
                try self.handleStatement(stmnt);
                if (self.return_just_handled) {
                    return;
                }
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
        //defer {
        //if (self.piped_value) |*val| {
        //val.deinit(self.ally);
        //self.piped_value = null;
        //}
        //}
        if (unpipe) {
            self.is_piping = false;
        }

        return self.handleExpr(next);
    }

    pub fn executeFunction(self: *Interpreter, name: []const u8, args: []const Value, has_stdin_arg: bool) !?Value {
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
                    const shrinked_stdout = std.mem.trimRight(u8, stdout, &std.ascii.spaces);
                    _ = self.ally.resize(stdout, shrinked_stdout.len);
                    const returned_value = Value.byConversion(shrinked_stdout);
                    // if converted from string
                    if (@as(Value.Kind, returned_value.inner) != .string) {
                        // free string
                        self.ally.free(shrinked_stdout);
                    }
                    return returned_value;
                }
            }
        }

        return null;
    }

    fn addValues(self: *Interpreter, lhs: *const Value, rhs: *const Value, backup_token: *const Token) !Value {
        //assert(@as(Value.Kind, lhs.inner) == .integer);
        //assert(@as(Value.Kind, rhs.inner) == .integer);
        //try self.assertExpectedType(lhs.getKind(), .integer, lhs.origin orelse backup_token);
        try self.assertExpectedType(lhs, .integer, backup_token);
        try self.assertExpectedType(rhs, .integer, backup_token);

        return Value{
            .inner = .{
                .integer = lhs.inner.integer + rhs.inner.integer,
            },
            .origin = null,
        };
    }

    fn subtractValues(self: *Interpreter, lhs: *const Value, rhs: *const Value) Value {
        _ = self;
        assert(@as(Value.Kind, lhs.inner) == .integer);
        assert(@as(Value.Kind, rhs.inner) == .integer);

        return .{
            .inner = .{
                .integer = lhs.inner.integer - rhs.inner.integer,
            },
            .origin = null,
        };
    }

    fn negateValue(self: *Interpreter, value: *const Value) Value {
        _ = self;
        assert(@as(Value.Kind, value.inner) == .integer);

        return .{
            .inner = .{
                .integer = -value.inner.integer,
            },
            .origin = null,
        };
    }

    fn multiplyValues(self: *Interpreter, lhs: *const Value, rhs: *const Value) Value {
        _ = self;
        assert(@as(Value.Kind, lhs.inner) == .integer);
        assert(@as(Value.Kind, rhs.inner) == .integer);

        return .{
            .inner = .{
                .integer = lhs.inner.integer * rhs.inner.integer,
            },
            .origin = null,
        };
    }

    fn divideValues(self: *Interpreter, lhs: *const Value, rhs: *const Value) !Value {
        _ = self;
        assert(@as(Value.Kind, lhs.inner) == .integer);
        assert(@as(Value.Kind, rhs.inner) == .integer);

        return Value{
            .inner = .{
                .integer = try math.divTrunc(i64, lhs.inner.integer, rhs.inner.integer),
            },
            .origin = null,
        };
    }

    fn moduloValues(self: *Interpreter, lhs: *const Value, rhs: *const Value) !Value {
        _ = self;
        assert(@as(Value.Kind, lhs.inner) == .integer);
        assert(@as(Value.Kind, rhs.inner) == .integer);

        return Value{
            .inner = .{
                .integer = try math.mod(i64, lhs.inner.integer, rhs.inner.integer),
            },
            .origin = null,
        };
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
            .origin = null,
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
            .origin = null,
        };
    }

    fn notValue(self: *Interpreter, value: *const Value) Value {
        _ = self;
        assert(@as(Value.Kind, value.inner) == .boolean);
        return .{
            .inner = .{
                .boolean = !value.inner.boolean,
            },
            .origin = null,
        };
    }

    fn equalsValues(self: *Interpreter, lhs: *const Value, rhs: *const Value) Value {
        _ = self;
        const lhs_kind = @as(Value.Kind, lhs.inner);
        const rhs_kind = @as(Value.Kind, rhs.inner);
        assert(lhs_kind == rhs_kind);
        return .{
            .inner = .{
                .boolean = switch (lhs_kind) {
                    .integer => lhs.inner.integer == rhs.inner.integer,
                    .string => std.mem.order(u8, lhs.inner.string, rhs.inner.string) == .eq,
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
            .origin = null,
        };
    }

    fn notEqualsValues(self: *Interpreter, lhs: *const Value, rhs: *const Value) Value {
        _ = self;
        const lhs_kind = @as(Value.Kind, lhs.inner);
        const rhs_kind = @as(Value.Kind, rhs.inner);
        assert(lhs_kind == rhs_kind);
        return .{
            .inner = .{
                .boolean = switch (lhs_kind) {
                    .integer => lhs.inner.integer != rhs.inner.integer,
                    .string => !std.mem.eql(u8, lhs.inner.string, rhs.inner.string),
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
            .origin = null,
        };
    }

    fn lessEqualsValues(self: *Interpreter, lhs: *const Value, rhs: *const Value) Value {
        _ = self;
        const lhs_kind = @as(Value.Kind, lhs.inner);
        const rhs_kind = @as(Value.Kind, rhs.inner);
        assert(lhs_kind == rhs_kind);
        return .{
            .inner = .{
                .boolean = switch (lhs_kind) {
                    .integer => lhs.inner.integer <= rhs.inner.integer,
                    .string => switch (std.mem.order(u8, lhs.inner.string, rhs.inner.string)) {
                        .lt, .eq => true,
                        .gt => false,
                    },
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
            .origin = null,
        };
    }

    fn greaterEqualsValues(self: *Interpreter, lhs: *const Value, rhs: *const Value) Value {
        _ = self;
        const lhs_kind = @as(Value.Kind, lhs.inner);
        const rhs_kind = @as(Value.Kind, rhs.inner);
        assert(lhs_kind == rhs_kind);
        return .{
            .inner = .{
                .boolean = switch (lhs_kind) {
                    .integer => lhs.inner.integer >= rhs.inner.integer,
                    .string => switch (std.mem.order(u8, lhs.inner.string, rhs.inner.string)) {
                        .gt, .eq => true,
                        .lt => false,
                    },
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
            .origin = null,
        };
    }

    fn logicalAndValues(self: *Interpreter, lhs: *const Value, rhs: *const Value) Value {
        _ = self;
        assert(@as(Value.Kind, lhs.inner) == .boolean);
        assert(@as(Value.Kind, rhs.inner) == .boolean);
        return .{
            .inner = .{
                .boolean = lhs.inner.boolean and rhs.inner.boolean,
            },
            .origin = null,
        };
    }

    fn logicalOrValues(self: *Interpreter, lhs: *const Value, rhs: *const Value) Value {
        _ = self;
        assert(@as(Value.Kind, lhs.inner) == .boolean);
        assert(@as(Value.Kind, rhs.inner) == .boolean);
        return .{
            .inner = .{
                .boolean = lhs.inner.boolean or rhs.inner.boolean,
            },
            .origin = null,
        };
    }

    fn assertExpectedType(self: *Interpreter, value: *const Value, expected: Value.Kind, fallback: *const Token) !void {
        if (value.getKind() != expected) {
            self.error_info = ErrorInfo{
                .type_mismatch = .{
                    .token = value.origin orelse fallback,
                    .expected_type = expected,
                    .found_type = value.getKind(),
                },
            };
            return InterpreterError.RuntimeError;
        }
    }
};

const builtin_signature = fn (interp: *Interpreter, args: []const Value) anyerror!?Value;

const builtins_array = .{
    .{ "print", mysh_builtins.print },
    .{ "append", mysh_builtins.append },
    .{ "filter", mysh_builtins.filter },
    .{ "len", mysh_builtins.len },
};
