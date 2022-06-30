const std = @import("std");
const Token = @import("token.zig").Token;

const assert = std.debug.assert;

const Identifier = struct {
    token: *Token,
};

const Bareword = struct {
    token: *Token,
};

const StringLiteral = struct {
    token: *Token,
};

const BoolLiteral = struct {
    token: *Token,
    value: bool,
};

const IntegerLiteral = struct {
    token: *Token,
    value: i64,
};

const ArrayLiteral = struct {
    token: *Token,
    value: []const Expr,
};

const VarDeclaration = struct {
    token: *Token,
    expr: ?Expr,
};

const FnDeclaration = struct {
    token: *const Token,
    scope: Scope,
    args: []const Token,
};

const Return = struct {
    token: *const Token,
    expr: ?*Expr,
};

const Variable = struct {
    token: *Token,
    name: []const u8,
};

const Scope = struct {
    token: *const Token,
    statements: []const Statement,
};

const Branch = struct {
    token: *Token,
    condition: Expr,
    statements: []Statement,
};

const Loop = struct {
    const Kind = enum {
        regular,
        for_in,
    };
    loop: union(Loop.Kind) {
        // regular loop
        regular: struct {
            init: ?*Statement,
            condition: ?Expr,
            step: ?*Statement,
        },
        // for in loop
        for_in: struct {
            iterator: Token,
            iterable: Variable,
        },
    },
    token: *Token,
    scope: Scope,
};

const Assignment = struct {
    token: *Token,
    variable: Identifier,
    expr: ?Expr,
};

const BinaryOperator = struct {
    token: *const Token,
    lhs: *Expr,
    rhs: *Expr,
};

const UnaryOperator = struct {
    token: *Token,
    expr: *Expr,
};

const FunctionCall = struct {
    token: *const Token,
    args: []const Expr,
};

const ExprKind = enum {
    bareword,
    string_literal,
    boolean_literal,
    integer_literal,
    array_literal,
    variable,
    binary_operator,
    unary_operator,
    call,
};

const Expr = union(ExprKind) {
    bareword: Bareword,
    string_literal: StringLiteral,
    boolean_literal: BoolLiteral,
    integer_literal: IntegerLiteral,
    array_literal: ArrayLiteral,
    variable: Variable,
    binary_operator: BinaryOperator,
    unary_operator: UnaryOperator,
    call: FunctionCall,
};

const StatementKind = enum {
    var_decl,
    fn_decl,
    ret,
    scope,
    branch,
    loop,
    assignment,
    expr,
};

const Statement = union(StatementKind) {
    var_decl: VarDeclaration,
    fn_decl: FnDeclaration,
    ret: Return,
    scope: Scope,
    branch: Branch,
    loop: Loop,
    assignment: Assignment,
    expr: Expr,
};

pub const Root = struct {
    pub const FnTable = std.StringHashMap(FnDeclaration);

    pub fn init(ally: std.mem.Allocator) Root {
        return .{
            .fn_table = FnTable.init(ally),
            .statements = &.{},
        };
    }

    pub fn deinit(self: *Root) void {
        //TODO: for key in FnTable free key
        //TODO: for child in children recursively free
        self.fn_table.deinit();
    }

    fn_table: FnTable,
    statements: []Statement,
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
        };
    }

    //TODO: either optional or error union, not just root
    pub fn parse(self: *Parser, tokens: []const Token) !?Root {
        self.tokens = tokens;
        self.current = 0;
        var root = Root.init(self.ally);

        var statements = std.ArrayList(Statement).init(self.ally);

        //TODO: actual parsing
        while (!self.eot()) {
            if (try self.parseStatement()) |stmnt| {
                try statements.append(stmnt);
                continue;
            }
            if (try self.parseFnDeclaration()) |fn_decl| {
                const name = fn_decl.token.value;
                try root.fn_table.put(name, fn_decl);
            }

            if (!self.encounteredError()) {
                self.expected(Expectable.statement);
            }
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

    fn parseStatement(self: *Parser) !?Statement {
        const checkpoint = self.current;
        if (try self.parseFunctionCall()) |expr| {
            if ((!self.eot() and self.getIf(Token.Kind.Newline) != null) or self.eot()) {
                return Statement{
                    .expr = expr,
                };
            }
            self.current = checkpoint;
        }

        // Unaltered original cpp version
        //      auto checkpoint = current;
        //	if(auto child = parseFunctionCall();
        //		child != nullptr) {
        //		if((!eot() && getIf(Token::Kind::Newline) != nullptr) || eot()) {
        //			return child;
        //		}
        //		current = checkpoint;
        //	}
        //
        //	if(auto child = parseDeclaration();
        //		child != nullptr) {
        //		return child;
        //	}
        //
        //	if(auto child = parseAssignment();
        //		child != nullptr) {
        //		return child;
        //	}
        //
        //	if(auto child = parseScope();
        //		child != nullptr) {
        //		return child;
        //	}

        //	if(auto child = parseBranch();
        //		child != nullptr) {
        //		return child;
        //	}

        //	if(auto child = parseLoop();
        //		child != nullptr) {
        //		return child;
        //	}

        //	if(auto child = parseExpr(true);
        //		child != nullptr) {
        //		return child;
        //	}

        return null;
    }

    //const CallOrPipeKind = enum {
    //call,
    //pipe,
    //};

    //const CallOrPipe = union(FuncOrPipeKind) {
    //call: FunctionCall,
    //pipe: BinaryOperator,
    //};

    //fn parseFunctionCall(self: *Parser) anyerror!?FuncOrPipe {
    fn parseFunctionCall(self: *Parser) anyerror!?Expr {
        var token = self.getIf(Token.Kind.Identifier);
        if (token == null) {
            return null;
        }

        self.may_read_pipe = false;
        var children = std.ArrayList(Expr).init(self.ally);

        while (try self.parseExpr()) |expr| {
            try children.append(expr);
        }

        self.may_read_pipe = true;

        var call = FunctionCall{
            .token = token.?,
            .args = children.toOwnedSlice(),
        };

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
                .call = call,
            };
            var rhs = try self.ally.create(Expr);
            rhs.* = rhs_call.?;
            //rhs.* = Expr{
            //.call = rhs_call.?,
            //};

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
            .call = call,
        };
    }

    fn parseFunctionCallExpr() void {}

    fn parseDeclaration() void {}

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

        if (!self.may_read_pipe and token.kind == Token.Kind.Or) {
            self.current = checkpoint;
            return expr;
        }

        // shunting yard algorithm
        // https://en.wikipedia.org/wiki/Shunting_yard_algorithm
        var operands = std.ArrayList(Expr).init(self.ally);
        var operators = std.ArrayList(BinaryOperator).init(self.ally);

        defer operands.deinit();
        defer operators.deinit();

        try operands.append(expr.?);
        try operators.append(bin.?);

        if (token.kind == Token.Kind.Or) {
            if (self.parseCallableExpr()) |call| {
                expr = Expr{
                    .call = call,
                };
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
                op.rhs.* = rhs;
                op.lhs.* = lhs;

                try operands.append(Expr{
                    .binary_operator = op,
                });
            }

            token = bin.?.token;
            try operators.append(bin.?);

            if (token.kind == Token.Kind.Or) {
                if (self.parseCallableExpr()) |call| {
                    expr = Expr{
                        .call = call,
                    };
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
            op.rhs.* = rhs;
            op.lhs.* = lhs;
            try operands.append(Expr{
                .binary_operator = op,
            });
        }

        if (trailingNewline and !self.eot() and self.getIf(Token.Kind.Newline) == null) {
            self.expectedToken(Token.Kind.Newline);
            return null;
        }

        var binary_operator = operators.pop();
        return Expr{
            .binary_operator = binary_operator,
        };
    }

    fn parseExpr(self: *Parser) !?Expr {
        return try self.parseExprMaybeTrailingNewline(false);
    }

    fn parsePrimaryExpr(self: *Parser) !?Expr {
        _ = self;
        return null;
    }

    fn parseCallableExpr(self: *Parser) ?FunctionCall {
        _ = self;
        return null;
    }

    fn parseIterableExpr(self: *Parser) void {
        _ = self;
    }

    fn parseIdentifier(self: *Parser) void {
        _ = self;
    }

    fn parseBareword(self: *Parser) void {
        _ = self;
    }

    fn parseVariable(self: *Parser) void {
        _ = self;
    }

    fn parseBranch(self: *Parser) void {
        _ = self;
    }

    fn parseLoop(self: *Parser) void {
        _ = self;
    }

    fn parseWhile(self: *Parser) void {
        _ = self;
    }

    fn parseForInLoop(self: *Parser) void {
        _ = self;
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
        defer statements.deinit();

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
                    continue;
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

    fn parseAssignment(self: *Parser) void {
        _ = self;
    }

    fn parseBinaryExpression(self: *Parser) void {
        _ = self;
    }

    fn parseBinaryOperator(self: *Parser) ?BinaryOperator {
        _ = self;
        return null;
    }

    fn parseUnaryExpression(self: *Parser) void {
        _ = self;
    }

    fn parseUnaryOperator(self: *Parser) void {
        _ = self;
    }

    fn parseStringLiteral(self: *Parser) void {
        _ = self;
    }

    fn parseBoolLiteral(self: *Parser) void {
        _ = self;
    }

    fn parseIntegerLiteral(self: *Parser) void {
        _ = self;
    }

    fn parseArrayLiteral(self: *Parser) void {
        _ = self;
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
};
