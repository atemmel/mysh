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
    token: *Token,
    scope: Scope,
    args: []const *Token,
};

const Return = struct {
    token: *Token,
    expr: *?Expr,
};

const Variable = struct {
    token: *Token,
    name: []const u8,
};

const Scope = struct {
    token: *Token,
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
    token: *Token,
    lhs: *Expr,
    rhs: *Expr,
};

const UnaryOperator = struct {
    token: *Token,
    expr: *Expr,
};

const FunctionCall = struct {
    token: *Token,
    name: []const u8,
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
    binary,
};

const Statement = union(StatementKind) {
    var_decl: VarDeclaration,
    fn_decl: FnDeclaration,
    ret: Return,
    scope: Scope,
    branch: Branch,
    loop: Loop,
    assignment: Assignment,
    binary: BinaryOperator,
};

pub const Root = struct {
    pub const FnTable = std.StringHashMap(*FnDeclaration);

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
        };
    }

    //TODO: either optional or error union, not just root
    pub fn parse(self: *Parser, tokens: []const Token) !?Root {
        self.tokens = tokens;
        self.current = 0;
        var root = Root.init(self.ally);

        var statements = std.ArrayList(Statement).init(self.ally);

        //TODO: actual parsing
        while (!self.eof()) {
            if (self.parseStatement()) |stmnt| {
                try statements.append(stmnt);
            }

            unreachable;
        }

        root.statements = statements.toOwnedSlice();
        return root;
    }

    fn parseStatement(self: *Parser) ?Statement {
        _ = self;
        return null;
    }

    fn getIf(self: Parser, kind: Token.Kind) ?*const Token {
        if (!self.eof() and kind == self.get().kind) {
            const token = self.get();
            self.current += 1;
            return token;
        }
        return null;
    }

    fn eof(self: *Parser) bool {
        return self.current >= self.tokens.len;
    }

    fn get(self: *Parser) *const Token {
        assert(!self.eof());
        return self.tokens[self.current];
    }

    ally: std.mem.Allocator,
    tokens: []const Token,
    current: usize,
};
