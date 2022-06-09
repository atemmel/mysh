const std = @import("std");
const Token = @import("token.zig").Token;

const Kind = enum {
    identifier,
    bareword,
    string,
    boolean,
    integer,
    array,
    varDecl,
    fnDecl,
    ret,
    variable,
    scope,
    branch,
    loop,
    assignment,
    binary,
    unary,
    call,
};

const Identifier = struct {
    //value: []const u8,
};

const Bareword = struct {
    //value: []const u8,
};

const StringLiteral = struct {
    //value: []const u8,
};

const BoolLiteral = struct {
    value: bool,
};

const IntegerLiteral = struct {
    value: i64,
};

const ArrayLiteral = struct {
    value: []const Node,
};

const VarDeclaration = struct {
    declare: []const u8,
    expr: *?Node,
};

const FnDeclaration = struct {
    statements: []const Node,
    args: []const Token,
};

const Return = struct {
    expr: *?Node,
};

const Variable = struct {
    name: []const u8,
};

const Scope = struct {
    statements: []const Node,
};

const Branch = struct {
    condition: *Node,
    statement: *Node,
};

const Loop = struct {
    const Kind = enum(u1) {
        regular,
        for_in,
    };
    loop: union(Loop.Kind) {
        // regular loop
        regular: struct {
            init: *Node,
            condition: *Node,
            step: *Node,
        },
        // for in loop
        for_in: struct {
            iterator: *Node,
            iterable: *Node,
        },
    },
    statement: *Node,
};

const Assignment = struct {
    variable: *Node,
    expr: *Node,
};

const BinaryOperator = struct {
    lhs: *Node,
    rhs: *Node,
};

const UnaryOperator = struct {
    expr: *Node,
};

const FunctionCall = struct {
    name: []const u8,
    args: []const *const Node,
};

pub const Root = struct {
    pub const FnTable = std.StringHashMap(*FnDeclaration);

    pub fn init(ally: std.mem.Allocator) Root {
        return .{
            .fn_table = FnTable.init(ally),
            .children = &.{},
        };
    }

    pub fn deinit(self: *Root) void {
        //TODO: for key in FnTable free key
        //TODO: for child in children recursively free
        self.fn_table.deinit();
    }

    fn_table: FnTable,
    children: []*Node,
};

const NodeData = union(Kind) {
    identifier: Identifier,
    bareword: Bareword,
    string: StringLiteral,
    boolean: BoolLiteral,
    integer: IntegerLiteral,
    array: ArrayLiteral,
    varDecl: VarDeclaration,
    fnDecl: FnDeclaration,
    ret: Return,
    variable: Variable,
    scope: Scope,
    branch: Branch,
    loop: Loop,
    assignment: Assignment,
    binary: BinaryOperator,
    unary: UnaryOperator,
    call: FunctionCall,
};

pub const Node = struct {
    data: NodeData,
    token: *Token,
};

pub const Parser = struct {
    pub fn init(ally: std.mem.Allocator) Parser {
        return .{
            .ally = ally,
            .tokens = undefined,
        };
    }

    //TODO: either optional or error union, not just root
    pub fn parse(self: *Parser, tokens: []const Token) ?Root {
        self.tokens = tokens;

        //TODO: actual parsing
        return Root.init(self.ally);
    }

    ally: std.mem.Allocator,
    tokens: []const Token,
};
