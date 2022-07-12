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
    value: []const Expr,
};

pub const VarDeclaration = struct {
    token: *const Token,
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
    token: *Token,
    condition: Expr,
    statements: []Statement,

    fn deinit(self: *const Branch, ally: std.mem.Allocator) void {
        for (self.statements) |stmnt| {
            stmnt.deinit(ally);
        }
        ally.free(self.statements);
    }
};

pub const Loop = struct {
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

    fn deinit(self: *const Loop, ally: std.mem.Allocator) void {
        switch (self.loop) {
            .regular => |regular| {
                if (regular.init) |init| {
                    init.deinit(ally);
                    ally.destroy(init);
                }
                if (regular.step) |step| {
                    step.deinit(ally);
                    ally.destroy(step);
                }
            },
            .for_in => {},
        }

        self.scope.deinit(ally);
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
    args: []const Expr,

    fn deinit(self: *const FunctionCall, ally: std.mem.Allocator) void {
        for (self.args) |arg| {
            arg.deinit(ally);
        }
        ally.free(self.args);
    }
};

pub const ExprKind = enum {
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

pub const Expr = union(ExprKind) {
    bareword: Bareword,
    string_literal: StringLiteral,
    boolean_literal: BoolLiteral,
    integer_literal: IntegerLiteral,
    array_literal: ArrayLiteral,
    variable: Variable,
    binary_operator: BinaryOperator,
    unary_operator: UnaryOperator,
    call: FunctionCall,

    fn deinit(self: *const Expr, ally: std.mem.Allocator) void {
        switch (self.*) {
            .bareword => {},
            .string_literal => {},
            .boolean_literal => {},
            .integer_literal => {},
            .array_literal => {},
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

    pub fn init(ally: std.mem.Allocator) Root {
        return .{
            .ally = ally,
            .fn_table = FnTable.init(ally),
            .statements = &.{},
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

    fn parseFunctionCall(self: *Parser) anyerror!?Expr {
        var token = self.getIf(Token.Kind.Identifier);
        if (token == null) {
            return null;
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

        if (try self.parseFunctionCall()) |call| {
            return call;
        }

        //if(auto un = parseUnaryExpression();
        //un != nullptr) {
        //return un;
        //}
        //if(auto call = parseFunctionCallExpr();
        //call != nullptr) {
        //return call;
        //}
        //if(auto identifier = parseIdentifier();
        //identifier != nullptr) {
        //return identifier;
        //}
        //if(auto bareword = parseBareword();
        //bareword != nullptr) {
        //return bareword;
        //}
        //if(auto variable = parseVariable();
        //variable != nullptr) {
        //return variable;
        //}
        //if(auto stringLiteral = parseStringLiteral();
        //stringLiteral != nullptr) {
        //return stringLiteral;
        //}
        //if(auto integerLiteral = parseIntegerLiteral();
        //integerLiteral != nullptr) {
        //return integerLiteral;
        //}
        //if(auto boolLiteral = parseBoolLiteral();
        //boolLiteral != nullptr) {
        //return boolLiteral;
        //}
        //if(auto arrayLiteral = parseArrayLiteral();
        //arrayLiteral != nullptr) {
        //return arrayLiteral;
        //}
        //if(auto call = parseFunctionCall();
        //call != nullptr) {
        //return call;
        //}
        //return nullptr;

        _ = self;
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

    fn parseIdentifier(self: *Parser) void {
        _ = self;
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
            .name = variable.value,
        };
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
