const std = @import("std.zig");
const Token = @import("token.zig").Token;

const Kind = enum {
    Identifier,
    Bareword,
    StringLiteral,
    BoolLiteral,
    IntegerLiteral,
    ArrayLiteral,
    VarDeclaration,
    FnDeclaration,
    Return,
    Scope,
    Branch,
    Loop,
    Assignment,
    BinaryOperator,
    UnaryOperator,
    FunctionCall,
};

const Identifier = struct {
    value: []const u8,
};

const Bareword = struct {
    value: []const u8,
};

const StringLiteral = struct {
    value: []const u8,
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

const BranchNode = struct {
    condition: *Node,
    statement: *Node,
};

const LoopNode = struct {
    const Kind = enum(u1) {
        Regular,
        ForIn,
    };
    loop: union(LoopNode.Kind) {
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

const Root = struct {
    fn_table: std.StringHashMap(*FnDeclaration),
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
    assignment: Assignment,
    binary: BinaryOperator,
    unary: UnaryOperator,
    call: FunctionCall,
};

const Node = struct {
    data: NodeData,
    token: *Token,
};
