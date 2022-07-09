const std = @import("std");

pub const Token = struct {
    pub const Kind = enum {
        Newline, // \n
        VarKeyword, // var
        FnKeyword, // fn
        False, // false
        True, // true
        If, // if
        Else, // else
        While, // while
        Return, // return
        For, // For
        In, // in
        Assign, // =
        Add, // +
        Subtract, // -
        Multiply, // *
        Divide, // /
        Modulo, // %
        Less, // <
        Greater, // >
        Bang, // !
        Equals, // ==
        NotEquals, // !=
        GreaterEquals, // >=
        LessEquals, // <=
        And, // &
        Or, // |
        LogicalAnd, // &&
        LogicalOr, // ||
        LeftBrace, // {
        RightBrace, // }
        LeftPar, // (
        RightPar, // )
        LeftBrack, // [
        RightBrack, // ]
        Variable, // $hello
        StringLiteral, // "hello"
        Identifier, // hello
        Bareword, // --help
        IntegerLiteral, // 123678
        NTokens, // keep this last
    };

    pub const printable_strings = [_][]const u8{
        "Newline",
        "VarKeyword",
        "FnKeyword",
        "False",
        "True",
        "If",
        "Else",
        "While",
        "Return",
        "For",
        "In",
        "Assign",
        "Add",
        "Subtract",
        "Multiply",
        "Divide",
        "Modulo",
        "Less",
        "Greater",
        "Bang",
        "Equals",
        "NotEquals",
        "EqualsGreater",
        "EqualsLess",
        "And",
        "Or",
        "LogicalAnd",
        "LogicalOr",
        "LeftBrace",
        "RightBrace",
        "LeftPar",
        "RightPar",
        "LeftBrack",
        "RightBrack",
        "Variable",
        "StringLiteral",
        "Identifier",
        "Bareword",
        "IntegerLiteral",
    };

    pub const strings = [_][]const u8{
        "\n",
        "var",
        "fn",
        "false",
        "true",
        "if",
        "else",
        "while",
        "return",
        "for",
        "in",
        "=",
        "+",
        "-",
        "*",
        "/",
        "%",
        "<",
        ">",
        "!",
        "==",
        "!=",
        "<=",
        ">=",
        "&",
        "|",
        "&&",
        "||",
        "{",
        "}",
        "(",
        ")",
        "[",
        "]",
        "",
        "",
        "",
        "",
        "",
    };

    const precedences = [_]u32{
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        16, // =
        6, // +
        6, // -
        5, // *
        5, // /
        5, // %
        9, // <
        9, // >
        3, // !
        10, // ==
        10, // !=
        9, // <=
        9, // >=
        11, // &
        13, // |
        14, // &&
        15, // ||
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
    };

    pub const keyword_begin = 1;
    pub const keyword_end = 11;
    pub const operator_begin = 11;
    pub const operator_end = 34;

    pub fn precedence(self: *const Token) u32 {
        const idx: usize = @enumToInt(self.kind);
        const prec = precedences[idx];
        return prec;
    }

    pub fn print(self: *const Token) void {
        const printImpl = std.debug.print;
        printImpl("Row: {}, Column: {}, Kind: {s}", .{
            self.row,
            self.column,
            printable_strings[@enumToInt(self.kind)],
        });

        if (self.value.len > 0) {
            if (self.kind == .Newline) {
                printImpl("Value: \\n", .{});
            } else {
                printImpl("Value: {s}", .{self.value});
            }
        }
        printImpl("\n", .{});
    }

    kind: Kind,
    value: []const u8,
    column: usize,
    row: usize,
};

pub fn isOperator(slice: []const u8) bool {
    var i: usize = Token.operator_begin;
    while (i < Token.operator_end) : (i += 1) {
        const op = Token.strings[i];
        if (std.mem.eql(u8, op, slice)) {
            return true;
        }
    }
    return false;
}
