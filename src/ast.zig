const std = @import("std");
const Token = @import("token.zig").Token;

const assert = std.debug.assert;

pub const Identifier = struct {
    token: *const Token,
};

pub const Bareword = struct {
    token: *const Token,
};

pub const StringLiteral = struct {
    token: *const Token,
};

pub const BoolLiteral = struct {
    token: *const Token,
    value: bool,
};

pub const IntegerLiteral = struct {
    token: *const Token,
    value: i64,
};

pub const ArrayLiteral = struct {
    token: *const Token,
    values: []const Expr,

    fn deinit(self: *const ArrayLiteral, ally: std.mem.Allocator) void {
        for (self.values) |expr| {
            expr.deinit(ally);
        }
        ally.free(self.values);
    }
};

pub const TableLiteral = struct {
    token: *const Token,
    names: []const []const u8,
    values: []const *const Expr,

    fn deinit(self: *const TableLiteral, ally: std.mem.Allocator) void {
        for (self.values) |expr| {
            expr.deinit(ally);
            ally.destroy(expr);
        }
        ally.free(self.values);
        ally.free(self.names);
    }
};

pub const VarDeclaration = struct {
    token: *const Token,
    decl: []const u8,
    expr: ?Expr,

    fn deinit(self: *const VarDeclaration, ally: std.mem.Allocator) void {
        if (self.expr) |e| {
            e.deinit(ally);
        }
    }
};

pub const FnDeclaration = struct {
    token: *const Token,
    scope: Scope,
    args: []const Token,

    fn deinit(self: *const FnDeclaration, ally: std.mem.Allocator) void {
        self.scope.deinit(ally);
    }
};

pub const Return = struct {
    token: *const Token,
    expr: ?*Expr,

    fn deinit(self: *const Return, ally: std.mem.Allocator) void {
        if (self.expr) |e| {
            e.deinit(ally);
            ally.destroy(e);
        }
    }
};

pub const Variable = struct {
    token: *const Token,
    name: []const u8,
};

pub const Scope = struct {
    token: *const Token,
    statements: []const Statement,

    fn deinit(self: *const Scope, ally: std.mem.Allocator) void {
        for (self.statements) |stmnt| {
            stmnt.deinit(ally);
        }
        ally.free(self.statements);
    }
};

pub const Branch = struct {
    token: *const Token,
    condition: ?Expr,
    scope: Scope,
    next: ?*Branch,

    fn deinit(self: *const Branch, ally: std.mem.Allocator) void {
        if (self.condition) |e| {
            e.deinit(ally);
        }
        self.scope.deinit(ally);
        if (self.next) |next| {
            next.deinit(ally);
            ally.destroy(next);
        }
    }
};

const LoopKind = enum {
    while_loop,
    for_in_loop,
};

pub const Loop = union(LoopKind) {

    // regular loop
    pub const WhileLoop = struct {
        condition: Expr,
        token: *const Token,
        scope: Scope,
    };

    // for in loop
    pub const ForInLoop = struct {
        iterator: Identifier,
        iterable: Expr,
        token: *const Token,
        scope: Scope,
    };

    while_loop: WhileLoop,
    for_in_loop: ForInLoop,

    fn deinit(self: *const Loop, ally: std.mem.Allocator) void {
        switch (self.*) {
            .while_loop => |*while_loop| {
                while_loop.condition.deinit(ally);
                while_loop.scope.deinit(ally);
            },
            .for_in_loop => |*for_in_loop| {
                for_in_loop.iterable.deinit(ally);
                for_in_loop.scope.deinit(ally);
            },
        }
    }
};

pub const Assignment = struct {
    token: *const Token,
    variable: Variable,
    expr: Expr,

    fn deinit(self: *const Assignment, ally: std.mem.Allocator) void {
        self.expr.deinit(ally);
    }
};

pub const BinaryOperator = struct {
    token: *const Token,
    lhs: ?*Expr,
    rhs: ?*Expr,

    fn deinit(self: *const BinaryOperator, ally: std.mem.Allocator) void {
        if (self.lhs) |lhs| {
            lhs.deinit(ally);
            ally.destroy(lhs);
        }
        if (self.rhs) |rhs| {
            rhs.deinit(ally);
            ally.destroy(rhs);
        }
    }
};

pub const UnaryOperator = struct {
    token: *const Token,
    expr: *Expr,

    fn deinit(self: *const UnaryOperator, ally: std.mem.Allocator) void {
        self.expr.deinit(ally);
        ally.destroy(self.expr);
    }
};

pub const FunctionCall = struct {
    token: *const Token,
    name: *const Expr,
    args: []const Expr,

    fn deinit(self: *const FunctionCall, ally: std.mem.Allocator) void {
        self.name.deinit(ally);
        for (self.args) |arg| {
            arg.deinit(ally);
        }
        ally.free(self.args);
        ally.destroy(self.name);
    }
};

pub const ExprKind = enum {
    bareword,
    identifier,
    string_literal,
    boolean_literal,
    integer_literal,
    array_literal,
    table_literal,
    variable,
    binary_operator,
    unary_operator,
    call,
};

pub const Expr = union(ExprKind) {
    bareword: Bareword,
    identifier: Identifier,
    string_literal: StringLiteral,
    boolean_literal: BoolLiteral,
    integer_literal: IntegerLiteral,
    array_literal: ArrayLiteral,
    table_literal: TableLiteral,
    variable: Variable,
    binary_operator: BinaryOperator,
    unary_operator: UnaryOperator,
    call: FunctionCall,

    fn deinit(self: *const Expr, ally: std.mem.Allocator) void {
        switch (self.*) {
            .bareword => {},
            .identifier => {},
            .string_literal => {},
            .boolean_literal => {},
            .integer_literal => {},
            .table_literal => |table| {
                table.deinit(ally);
            },
            .array_literal => |array| {
                array.deinit(ally);
            },
            .variable => {},
            .binary_operator => |bin| {
                bin.deinit(ally);
            },
            .unary_operator => |unary| {
                unary.deinit(ally);
            },
            .call => |call| {
                call.deinit(ally);
            },
        }
    }
};

pub const StatementKind = enum {
    var_decl,
    fn_decl,
    ret,
    scope,
    branch,
    loop,
    assignment,
    expr,
};

pub const Statement = union(StatementKind) {
    var_decl: VarDeclaration,
    fn_decl: FnDeclaration,
    ret: Return,
    scope: Scope,
    branch: Branch,
    loop: Loop,
    assignment: Assignment,
    expr: Expr,

    fn deinit(self: *const Statement, ally: std.mem.Allocator) void {
        switch (self.*) {
            .var_decl => |var_decl| {
                var_decl.deinit(ally);
            },
            .assignment => |assignment| {
                assignment.deinit(ally);
            },
            .fn_decl => |fn_decl| {
                fn_decl.deinit(ally);
            },
            .ret => |ret| {
                ret.deinit(ally);
            },
            .scope => |scope| {
                scope.deinit(ally);
            },
            .branch => |branch| {
                branch.deinit(ally);
            },
            .loop => |loop| {
                loop.deinit(ally);
            },
            .expr => |expr| {
                expr.deinit(ally);
            },
        }
    }
};

pub const Root = struct {
    pub const FnTable = std.StringHashMap(FnDeclaration);

    pub fn init(ally: std.mem.Allocator, tokens: []const Token, source: []const u8, path: []const u8) Root {
        return .{
            .ally = ally,
            .fn_table = FnTable.init(ally),
            .statements = &.{},
            .tokens = tokens,
            .source = source,
            .path = path,
        };
    }

    pub fn deinit(self: *Root) void {
        var it = self.fn_table.iterator();
        while (it.next()) |fn_node| {
            fn_node.value_ptr.deinit(self.ally);
        }
        self.fn_table.deinit();

        for (self.statements) |stmnt| {
            stmnt.deinit(self.ally);
        }
        self.ally.free(self.statements);
    }

    ally: std.mem.Allocator,
    fn_table: FnTable,
    statements: []Statement,
    tokens: []const Token,
    source: []const u8,
    path: []const u8,
};

pub const Parser = struct {
    pub fn init(ally: std.mem.Allocator) Parser {
        return .{
            .ally = ally,
            .tokens = undefined,
            .current = undefined,
            .may_read_pipe = true,
            .token_we_wanted = Token.Kind.NTokens,
            .thing_we_wanted = Expectable.n_expectables,
            .token_we_got = null,
            .inside_fn_call_expr = false,
        };
    }

    pub fn parse(self: *Parser, tokens: []const Token, source: []const u8, path: []const u8) !?Root {
        self.tokens = tokens;
        self.current = 0;
        var root = Root.init(self.ally, tokens, source, path);

        var statements = std.ArrayList(Statement).init(self.ally);

        while (!self.eot()) {
            if (try self.parseStatement()) |stmnt| {
                try statements.append(stmnt);
                continue;
            }
            if (try self.parseFnDeclaration()) |fn_decl| {
                const name = fn_decl.token.value;
                try root.fn_table.put(name, fn_decl);
                continue;
            }

            if (!self.encounteredError()) {
                self.expected(Expectable.statement);
            }

            root.deinit();
            for (statements.items) |stmnt| {
                stmnt.deinit(self.ally);
            }
            statements.deinit();
            return null;
        }

        root.statements = statements.toOwnedSlice();
        return root;
    }

    pub fn encounteredError(self: *Parser) bool {
        return self.token_we_got != null or self.token_we_wanted != Token.Kind.NTokens or self.thing_we_wanted != Expectable.n_expectables;
    }

    pub fn dumpError(self: *Parser) void {
        const print = std.debug.print;
        const bad_token = self.token_we_got orelse &self.tokens[self.tokens.len - 1];
        std.debug.print("Error when parsing file\nrow: {} column: {} ", .{ bad_token.row, bad_token.column });

        if (self.token_we_wanted == Token.Kind.NTokens and self.thing_we_wanted == Expectable.n_expectables) {
            print("expected: <error report failed>", .{});
        } else if (self.token_we_wanted != Token.Kind.NTokens) {
            print("expected: {s}", .{@tagName(self.token_we_wanted)});
        } else {
            print("expected: {s}", .{@tagName(self.thing_we_wanted)});
        }

        if (!self.eot()) {
            print(", found: {s}", .{@tagName(bad_token.kind)});
            switch (bad_token.kind) {
                .Newline => print(" ( \\n )\n", .{}),
                else => print(" ({s})\n", .{bad_token.value}),
            }
        } else {
            print(", found: end of file\n", .{});
        }
    }

    fn parseStatement(self: *Parser) anyerror!?Statement {
        const checkpoint = self.current;
        if (try self.parseFunctionCall()) |expr| {
            if ((!self.eot() and self.getIf(Token.Kind.Newline) != null) or self.eot()) {
                return Statement{
                    .expr = expr,
                };
            }
            self.current = checkpoint;
            expr.deinit(self.ally);
        }

        if (try self.parseDeclaration()) |decl| {
            return Statement{
                .var_decl = decl,
            };
        }

        if (try self.parseAssignment()) |assign| {
            return Statement{
                .assignment = assign,
            };
        }

        if (try self.parseScope(.{})) |scope| {
            return Statement{
                .scope = scope,
            };
        }

        if (try self.parseBranch()) |branch| {
            return Statement{
                .branch = branch,
            };
        }

        if (try self.parseLoop()) |loop| {
            return Statement{
                .loop = loop,
            };
        }

        if (self.encounteredError()) {
            return null;
        }

        if (try self.parseExprMaybeTrailingNewline(true)) |expr| {
            return Statement{
                .expr = expr,
            };
        }

        return null;
    }

    fn parseFunctionCall(self: *Parser) anyerror!?Expr {
        var name: Expr = undefined;
        var token = self.getIf(Token.Kind.Identifier);
        if (token == null and !self.inside_fn_call_expr) {
            return null;
        } else if (token == null and self.inside_fn_call_expr) {
            token = self.getIf(Token.Kind.StringLiteral);
            if (token == null) {
                return null;
            }
            name = .{ .string_literal = .{
                .token = token.?,
            } };
        } else {
            name = .{ .identifier = .{
                .token = token.?,
            } };
        }

        self.may_read_pipe = false;
        var children = std.ArrayList(Expr).init(self.ally);
        defer {
            for (children.items) |child| {
                child.deinit(self.ally);
            }
            children.deinit();
        }

        while (try self.parseExpr()) |expr| {
            try children.append(expr);
        }

        var name_expr = try self.ally.create(Expr);
        name_expr.* = name;

        self.may_read_pipe = true;

        // pipe chain check
        if (self.getIf(Token.Kind.Or)) |pipe| {
            var rhs_call = try self.parseFunctionCall();
            if (rhs_call == null) {
                // TODO:
                self.expected(Expectable.callable);
                return null;
            }

            var lhs = try self.ally.create(Expr);
            lhs.* = Expr{
                .call = FunctionCall{
                    .token = token.?,
                    .name = name_expr,
                    .args = children.toOwnedSlice(),
                },
            };
            var rhs = try self.ally.create(Expr);
            rhs.* = rhs_call.?;

            var bin = BinaryOperator{
                .token = pipe,
                .lhs = lhs,
                .rhs = rhs,
            };

            return Expr{
                .binary_operator = bin,
            };
        }

        return Expr{
            .call = FunctionCall{
                .token = token.?,
                .name = name_expr,
                .args = children.toOwnedSlice(),
            },
        };
    }

    fn parseFunctionCallExpr(self: *Parser) !?Expr {
        const checkpoint = self.current;
        const token = self.getIf(Token.Kind.LeftPar);
        if (token == null) {
            return null;
        }

        self.inside_fn_call_expr = true;
        defer self.inside_fn_call_expr = false;

        const call = try self.parseFunctionCall();
        if (call == null) {
            self.current = checkpoint;
            return null;
        }

        if (self.getIf(Token.Kind.RightPar) == null) {
            call.?.deinit(self.ally);
            self.expectedToken(Token.Kind.RightPar);
            return null;
        }

        return call;
    }

    fn parseDeclaration(self: *Parser) !?VarDeclaration {
        const token = self.getIf(Token.Kind.VarKeyword);
        if (token == null) {
            return null;
        }

        const identifier = self.getIf(Token.Kind.Identifier);
        if (identifier == null) {
            self.expectedToken(Token.Kind.Identifier);
            return null;
        }

        const assign = self.getIf(Token.Kind.Assign);
        if (assign == null) {
            self.expectedToken(Token.Kind.Assign);
            return null;
        }

        const expr = try self.parseExpr();
        if (expr == null) {
            self.expected(Expectable.expression);
            return null;
        }

        if (!self.eot()) {
            if (self.getIf(Token.Kind.Newline) == null) {
                self.expectedToken(Token.Kind.Newline);
                return null;
            }
        }

        return VarDeclaration{
            .token = token.?,
            .decl = identifier.?.value,
            .expr = expr.?,
        };
    }

    fn parseFnDeclaration(self: *Parser) !?FnDeclaration {
        var token = self.getIf(Token.Kind.FnKeyword);
        if (token == null) {
            return null;
        }

        token = self.getIf(Token.Kind.Identifier);
        if (token == null) {
            self.expectedToken(Token.Kind.Identifier);
            return null;
        }

        const args_begin = self.current;
        var args_end = self.current;
        while (self.getIf(Token.Kind.Identifier)) |_| {
            args_end += 1;
        }

        var args = self.tokens[args_begin..args_end];

        var scope = try self.parseScope(.{
            .end_with_newline = true,
            .may_return = true,
        });
        if (scope == null) {
            self.expected(Expectable.scope);
            return null;
        }

        return FnDeclaration{
            .token = token.?,
            .scope = scope.?,
            .args = args,
        };
    }

    fn parseReturn(self: *Parser) !?Return {
        const token = self.getIf(Token.Kind.Return);
        if (token == null) {
            return null;
        }

        var expr: ?*Expr = undefined;
        if (try self.parseExpr()) |parsed_expr| {
            expr = try self.ally.create(Expr);
            expr.?.* = parsed_expr;
        } else {
            expr = null;
        }

        return Return{
            .token = token.?,
            .expr = expr,
        };
    }

    fn parseExprMaybeTrailingNewline(self: *Parser, trailingNewline: bool) !?Expr {
        var expr = try self.parsePrimaryExpr();
        if (expr == null) {
            return null;
        }

        var checkpoint = self.current;
        var bin = self.parseBinaryOperator();
        if (bin == null) {
            return expr;
        }

        var token = bin.?.token;

        // if pipe found where not applicable, drop it
        if (!self.may_read_pipe and token.kind == Token.Kind.Or) {
            self.current = checkpoint;
            return expr;
        }

        // shunting yard algorithm
        // https://en.wikipedia.org/wiki/Shunting_yard_algorithm
        const Operands = std.ArrayList(Expr);
        const BinaryOperators = std.ArrayList(BinaryOperator);
        var operands = Operands.init(self.ally);
        var operators = BinaryOperators.init(self.ally);

        defer {
            for (operands.items) |op| {
                op.deinit(self.ally);
            }
            for (operators.items) |op| {
                op.deinit(self.ally);
            }
            operands.deinit();
            operators.deinit();
        }

        try operands.append(expr.?);
        try operators.append(bin.?);

        if (token.kind == Token.Kind.Or) {
            if (try self.parseCallableExpr()) |call| {
                expr = call;
            } else {
                self.expected(Expectable.callable);
                return null;
            }
        } else {
            expr = try self.parsePrimaryExpr();
            if (expr == null) {
                self.expected(Expectable.expression);
                return null;
            }
        }

        try operands.append(expr.?);

        checkpoint = self.current;
        bin = self.parseBinaryOperator();
        if (!self.may_read_pipe and bin != null and bin.?.token.kind == Token.Kind.Or) {
            self.current = checkpoint;
            bin = null;
        }

        while (bin != null) {
            var top_operator = &operators.items[operators.items.len - 1];
            if (bin.?.token.precedence() >= top_operator.token.precedence()) {
                var rhs = operands.pop();
                var lhs = operands.pop();
                var op = operators.pop();

                op.rhs = try self.ally.create(Expr);
                op.lhs = try self.ally.create(Expr);
                op.rhs.?.* = rhs;
                op.lhs.?.* = lhs;

                try operands.append(Expr{
                    .binary_operator = op,
                });
            }

            token = bin.?.token;
            try operators.append(bin.?);

            if (token.kind == Token.Kind.Or) {
                if (try self.parseCallableExpr()) |call| {
                    expr = call;
                } else {
                    self.expected(Expectable.callable);
                    return null;
                }
            } else {
                expr = try self.parsePrimaryExpr();
                if (expr == null) {
                    self.expected(Expectable.expression);
                    return null;
                }
            }

            try operands.append(expr.?);
            checkpoint = self.current;
            bin = self.parseBinaryOperator();
            if (!self.may_read_pipe and bin != null and bin.?.token.kind == Token.Kind.Or) {
                self.current = checkpoint;
                bin = null;
            }
        }

        while (operators.items.len > 0) {
            var rhs = operands.pop();
            var lhs = operands.pop();
            var op = operators.pop();

            op.rhs = try self.ally.create(Expr);
            op.lhs = try self.ally.create(Expr);
            op.rhs.?.* = rhs;
            op.lhs.?.* = lhs;
            try operands.append(Expr{
                .binary_operator = op,
            });
        }

        if (trailingNewline and !self.eot() and self.getIf(Token.Kind.Newline) == null) {
            self.expectedToken(Token.Kind.Newline);
            return null;
        }

        return operands.pop();
    }

    fn parseExpr(self: *Parser) !?Expr {
        return try self.parseExprMaybeTrailingNewline(false);
    }

    fn parsePrimaryExpr(self: *Parser) anyerror!?Expr {
        if (try self.parseUnaryExpression()) |unary| {
            return Expr{
                .unary_operator = unary,
            };
        }

        if (try self.parseFunctionCallExpr()) |call| {
            return call;
        }

        if (self.parseIdentifier()) |identifier| {
            return Expr{
                .identifier = identifier,
            };
        }

        if (self.parseBareword()) |bareword| {
            return Expr{
                .bareword = bareword,
            };
        }

        if (self.parseVariable()) |variable| {
            return Expr{
                .variable = variable,
            };
        }

        if (self.parseStringLiteral()) |string| {
            return Expr{
                .string_literal = string,
            };
        }

        if (try self.parseIntegerLiteral()) |int| {
            return Expr{
                .integer_literal = int,
            };
        }

        if (self.parseBoolLiteral()) |boolean| {
            return Expr{
                .boolean_literal = boolean,
            };
        }

        if (try self.parseArrayLiteral()) |array| {
            return Expr{
                .array_literal = array,
            };
        }

        if (try self.parseTableLiteral()) |table| {
            return Expr{
                .table_literal = table,
            };
        }

        if (try self.parseFunctionCall()) |call| {
            return call;
        }

        return null;
    }

    fn parseCallableExpr(self: *Parser) !?Expr {
        if (try self.parseFunctionCall()) |call| {
            return call;
        }
        return null;
    }

    fn parseIterableExpr(self: *Parser) void {
        _ = self;
    }

    fn parseIdentifier(self: *Parser) ?Identifier {
        const checkpoint = self.current;
        const token = self.getIf(Token.Kind.Identifier);
        if (token == null) {
            return null;
        }

        if (!self.eot()) {
            var i = @enumToInt(self.get().kind);

            // if next token is symbol
            //if (i >= Token.symbol_begin and i < Token.symbol_end) {
            if (i >= Token.operator_begin and i < Token.operator_end) {
                // if we can't look two tokens backwards
                if (self.current < 2) {
                    // fail the parse
                    self.current = checkpoint;
                    return null;
                }
            }

            // look two tokens backwards
            const prior_token = self.tokens[self.current - 2];
            i = @enumToInt(prior_token.kind);
            //if (i >= Token.symbol_begin and i < Token.symbol_end) {
            if (i >= Token.operator_begin and i < Token.operator_end) {
                // fail the parse
                self.current = checkpoint;
                return null;
            }
        }
        return Identifier{
            .token = token.?,
        };
    }

    fn parseBareword(self: *Parser) ?Bareword {
        if (self.getIf(Token.Kind.Bareword)) |token| {
            return Bareword{
                .token = token,
            };
        }
        return null;
    }

    fn parseVariable(self: *Parser) ?Variable {
        const token = self.getIf(.Variable);
        if (token == null) {
            return null;
        }

        const variable = token.?;

        return Variable{
            .token = variable,
            .name = variable.value[1..],
        };
    }

    fn parseBranch(self: *Parser) anyerror!?Branch {
        const branch_begin = self.getIf(Token.Kind.If);
        if (branch_begin == null) {
            return null;
        }

        var expr = (try self.parseFunctionCall()) orelse try self.parseExpr();

        //var expr = try self.parseExpr();
        if (expr == null) {
            self.expected(Expectable.expression);
            return null;
        }

        var scope = try self.parseScope(.{ .end_with_newline = false });
        if (scope == null) {
            self.expected(Expectable.scope);
            return null;
        }

        var branch = Branch{
            .token = branch_begin.?,
            .condition = expr.?,
            .scope = scope.?,
            .next = null,
        };

        // single if
        if (self.eot() or self.getIf(Token.Kind.Newline) != null) {
            return branch;
        }

        // else could mean:
        if (self.getIf(Token.Kind.Else)) |next_begin| {
            if (try self.parseBranch()) |child| {
                // if else check
                var next = try self.ally.create(Branch);
                next.* = child;
                branch.next = next;
                return branch;
            } else if (try self.parseScope(.{})) |child| {
                // solo else check
                var next = try self.ally.create(Branch);
                next.* = .{
                    .token = next_begin,
                    .condition = null,
                    .scope = child,
                    .next = null,
                };
                branch.next = next;
                return branch;
            }
        }

        self.expectedToken(Token.Kind.Else);
        return null;
    }

    fn parseLoop(self: *Parser) !?Loop {
        if (try self.parseWhile()) |while_loop| {
            return Loop{
                .while_loop = while_loop,
            };
        } else if (try self.parseForInLoop()) |for_in_loop| {
            return Loop{
                .for_in_loop = for_in_loop,
            };
        }
        return null;
    }

    fn parseWhile(self: *Parser) !?Loop.WhileLoop {
        const token = self.getIf(Token.Kind.While);
        if (token == null) {
            return null;
        }

        var expr = try self.parseExpr();
        if (expr == null) {
            self.expected(Expectable.expression);
            return null;
        }

        var scope = try self.parseScope(.{});
        if (scope == null) {
            self.expected(Expectable.scope);
            return null;
        }

        return Loop.WhileLoop{
            .token = token.?,
            .condition = expr.?,
            .scope = scope.?,
        };
    }

    fn parseForInLoop(self: *Parser) !?Loop.ForInLoop {
        _ = self;
        const token = self.getIf(Token.Kind.For);
        if (token == null) {
            return null;
        }

        var identifier = self.parseIdentifier();
        if (identifier == null) {
            self.expectedToken(.Identifier);
            return null;
        }

        if (self.getIf(.In) == null) {
            self.expectedToken(.In);
            return null;
        }

        var iterable = try self.parseExpr();
        if (iterable == null) {
            self.expected(.iterable);
            return null;
        }

        var scope = try self.parseScope(.{});
        if (scope == null) {
            self.expected(.scope);
            return null;
        }

        return Loop.ForInLoop{
            .iterator = identifier.?,
            .iterable = iterable.?,
            .token = token.?,
            .scope = scope.?,
        };
    }

    const ParseScopeOptions = struct {
        end_with_newline: bool = true,
        may_return: bool = false,
    };

    fn parseScope(self: *Parser, options: ParseScopeOptions) !?Scope {
        const lbrace = self.getIf(Token.Kind.LeftBrace);
        if (lbrace == null) {
            return null;
        }

        if (self.getIf(Token.Kind.Newline) == null) {
            self.expectedToken(Token.Kind.Newline);
            return null;
        }

        var statements = std.ArrayList(Statement).init(self.ally);
        defer {
            for (statements.items) |stmnt| {
                stmnt.deinit(self.ally);
            }
            statements.deinit();
        }

        while (true) {
            if (try self.parseStatement()) |statement| {
                try statements.append(statement);
                continue;
            }

            if (options.may_return) {
                if (try self.parseReturn()) |ret| {
                    try statements.append(.{
                        .ret = ret,
                    });
                    if (self.getIf(Token.Kind.Newline)) |_| {
                        continue;
                    } else {
                        self.expectedToken(Token.Kind.Newline);
                    }
                }
            }

            if (self.getIf(Token.Kind.RightBrace)) |_| {
                break;
            }

            self.expectedToken(Token.Kind.RightBrace);
            return null;
        }

        if (options.end_with_newline) {
            if (!self.eot()) {
                if (self.getIf(Token.Kind.Newline) == null) {
                    self.expectedToken(Token.Kind.Newline);
                    return null;
                }
            }
        }

        return Scope{
            .token = lbrace.?,
            .statements = statements.toOwnedSlice(),
        };
    }

    fn parseAssignment(self: *Parser) !?Assignment {
        const checkpoint = self.current;
        const variable = self.parseVariable();
        if (variable == null) {
            return null;
        }

        const equals = self.getIf(Token.Kind.Assign);
        if (equals == null) {
            self.current = checkpoint;
            return null;
        }

        const expr = try self.parseExpr();
        if (expr == null) {
            self.expected(Expectable.expression);
            return null;
        }

        const newline = self.getIf(Token.Kind.Newline);
        if (newline == null and !self.eot()) {
            self.expectedToken(Token.Kind.Newline);
            return null;
        }

        return Assignment{ .token = equals.?, .variable = variable.?, .expr = expr.? };
    }

    fn parseBinaryOperator(self: *Parser) ?BinaryOperator {
        if (self.eot()) {
            return null;
        }

        switch (self.tokens[self.current].kind) {
            .Add, .Subtract, .Multiply, .Divide, .Modulo, .Less, .Greater, .Equals, .NotEquals, .GreaterEquals, .LessEquals, .LogicalAnd, .LogicalOr, .Or => {},
            else => {
                return null;
            },
        }

        const token = self.get();
        self.current += 1;

        return BinaryOperator{
            .token = token,
            .lhs = null,
            .rhs = null,
        };
    }

    fn parseUnaryExpression(self: *Parser) !?UnaryOperator {
        const checkpoint = self.current;
        const unary = self.parseUnaryOperator();
        if (unary == null) {
            return null;
        }

        const parsed_expr = try self.parsePrimaryExpr();

        if (parsed_expr == null) {
            self.current = checkpoint;
            return null;
        }

        var expr = try self.ally.create(Expr);
        expr.* = parsed_expr.?;

        return UnaryOperator{
            .token = unary.?,
            .expr = expr,
        };
    }

    fn parseUnaryOperator(self: *Parser) ?*const Token {
        if (self.eot()) {
            return null;
        }

        const token = self.get();

        switch (token.*.kind) {
            .Subtract, .Bang => {},
            else => {
                return null;
            },
        }

        self.current += 1;
        return token;
    }

    fn parseStringLiteral(self: *Parser) ?StringLiteral {
        const token = self.getIf(Token.Kind.StringLiteral);
        if (token == null) {
            return null;
        }
        return StringLiteral{
            .token = token.?,
        };
    }

    fn parseBoolLiteral(self: *Parser) ?BoolLiteral {
        if (self.getIf(Token.Kind.False)) |false_literal| {
            return BoolLiteral{
                .token = false_literal,
                .value = false,
            };
        } else if (self.getIf(Token.Kind.True)) |true_literal| {
            return BoolLiteral{
                .token = true_literal,
                .value = true,
            };
        }
        return null;
    }

    fn parseIntegerLiteral(self: *Parser) !?IntegerLiteral {
        if (self.getIf(Token.Kind.IntegerLiteral)) |token| {
            const value = try std.fmt.parseInt(i64, token.value, 0);
            return IntegerLiteral{
                .token = token,
                .value = value,
            };
        }
        return null;
    }

    fn parseArrayLiteral(self: *Parser) !?ArrayLiteral {
        const token = self.getIf(Token.Kind.LeftBrack);
        if (token == null) {
            return null;
        }

        var exprs = std.ArrayList(Expr).init(self.ally);
        defer exprs.deinit();
        while (try self.parseExpr()) |expr| {
            try exprs.append(expr);
        }

        if (self.getIf(Token.Kind.RightBrack) == null) {
            self.expectedToken(Token.Kind.RightBrack);
            exprs.deinit();
            return null;
        }

        return ArrayLiteral{
            .token = token.?,
            .values = exprs.toOwnedSlice(),
        };
    }

    fn parseTableLiteral(self: *Parser) !?TableLiteral {
        const token = self.getIf(.Member);
        if (token == null) {
            return null;
        }
        const lbrace = self.getIf(.LeftBrace);
        if (lbrace == null) {
            self.expectedToken(.LeftBrace);
            return null;
        }

        var names = std.ArrayList([]const u8).init(self.ally);
        var values = std.ArrayList(*const Expr).init(self.ally);
        defer {
            for (values.items) |value| {
                self.ally.destroy(value);
            }
            names.deinit();
            values.deinit();
        }

        while (true) {
            while (self.getIf(.Newline) != null) {}
            if (self.getIf(.RightBrace) != null) {
                break;
            }
            const key = self.parseKey();
            if (key == null) {
                self.expectedToken(.Identifier);
                return null;
            }
            if (!self.parseKeyValueSeparator()) {
                self.expectedToken(.Colon);
                return null;
            }

            const value = try self.parseExpr();
            if (value == null) {
                self.expected(.expression);
                return null;
            }

            if (!self.parseKeyValuePairSeparator()) {
                if (self.get().kind != .RightBrace) {
                    self.expectedToken(.Newline);
                    return null;
                }
            }

            const value_ptr = try self.ally.create(Expr);
            value_ptr.* = value.?;

            try names.append(key.?);
            try values.append(value_ptr);
        }

        return TableLiteral{
            .token = token.?,
            .names = names.toOwnedSlice(),
            .values = values.toOwnedSlice(),
        };
    }

    fn parseKey(self: *Parser) ?[]const u8 {
        if (self.parseStringLiteral()) |string| {
            return string.token.value;
        } else if (self.parseIdentifier()) |identifier| {
            return identifier.token.value;
        }
        return null;
    }

    fn parseKeyValueSeparator(self: *Parser) bool {
        if (self.getIf(.Colon) != null) { // or self.getIf(.Comma)
            return true;
        }
        return false;
    }

    fn parseKeyValuePairSeparator(self: *Parser) bool {
        if (self.getIf(.Newline) != null) { // or self.getIf(.Comma)
            return true;
        }
        return false;
    }

    fn getIf(self: *Parser, kind: Token.Kind) ?*const Token {
        if (!self.eot() and kind == self.get().kind) {
            const token = self.get();
            self.current += 1;
            return token;
        }
        return null;
    }

    fn eot(self: *const Parser) bool {
        return self.current >= self.tokens.len;
    }

    fn get(self: *const Parser) *const Token {
        assert(!self.eot());
        return &self.tokens[self.current];
    }

    fn expectedToken(self: *Parser, kind: Token.Kind) void {
        if (self.encounteredError()) {
            return;
        }

        self.token_we_wanted = kind;
        if (!self.eot()) {
            self.token_we_got = self.get();
        }
    }

    fn expected(self: *Parser, kind: Expectable) void {
        if (self.encounteredError()) {
            return;
        }

        self.thing_we_wanted = kind;
        if (!self.eot()) {
            self.token_we_got = self.get();
        }
    }

    const Expectable = enum {
        expression,
        scope,
        callable,
        iterable,
        statement,
        n_expectables,
    };

    ally: std.mem.Allocator,
    tokens: []const Token,
    current: usize,
    may_read_pipe: bool = undefined,
    token_we_wanted: Token.Kind = undefined,
    thing_we_wanted: Expectable = undefined,
    token_we_got: ?*const Token = undefined,
    inside_fn_call_expr: bool = false,
};
