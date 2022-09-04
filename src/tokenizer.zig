const std = @import("std");
const mysh_token = @import("token.zig");
const Token = mysh_token.Token;

const assert = std.debug.assert;

const isSpace = std.ascii.isSpace;
const isAlpha = std.ascii.isAlpha;

fn isDigit(what: u8) bool {
    return std.ascii.isDigit(what);
}

fn isAlnum(what: u8) bool {
    return isAlpha(what) or isDigit(what);
}

const Tokens = std.ArrayList(Token);

pub const Tokenizer = struct {
    pub fn init(ally: std.mem.Allocator) Tokenizer {
        return Tokenizer{
            .tokens = Tokens.init(ally),
        };
    }

    pub fn tokenize(self: *Tokenizer, src: []const u8) ![]Token {
        self.source = src;
        self.current = 0;
        self.end = src.len;
        self.current_column = 1;
        self.current_row = 1;

        while (!self.eof()) {
            const c = self.peek();

            if (try self.readNewline()) {
                self.member_chain_alive = false;
                continue;
            }

            if (isSpace(c) and c != '\n') {
                self.skipWhitespace();
                self.member_chain_alive = false;
                continue;
            }

            if (c == '#') {
                self.skipComments();
                continue;
            }

            if (try self.readVariable()) {
                if (self.member_chain_alive) {
                    self.member_chain_alive = false;
                } else {
                    self.member_chain_alive = true;
                }
                continue;
            }
            if (try self.readKeyword()) {
                continue;
            }
            if (try self.readIdentifier()) {
                if (self.member_chain_alive and self.prevTokenKindWas(Token.Kind.Member)) {} else {
                    self.member_chain_alive = false;
                }
                continue;
            }
            if (try self.readSymbol()) {
                continue;
            }
            if (try self.readStringLiteral()) {
                continue;
            }
            if (try self.readIntegerLiteral()) {
                continue;
            }
            if (try self.readBareword()) {
                continue;
            }

            assert(false);
        }

        return self.tokens.toOwnedSlice();
    }

    fn prevTokenKindWas(self: *const Tokenizer, kind: Token.Kind) bool {
        const tokens = self.tokens.items;
        if (tokens.len < 2) {
            return false;
        }
        return tokens[tokens.len - 2].kind == kind;
    }

    fn eof(self: *const Tokenizer) bool {
        return self.current >= self.end;
    }

    fn peek(self: *const Tokenizer) u8 {
        assert(self.current < self.end);
        return self.source[self.current];
    }

    fn next(self: *Tokenizer) void {
        assert(self.current < self.end);
        if (self.peek() == '\n') {
            self.current_row += 1;
            self.current_column = 0;
        }
        self.current += 1;
        self.current_column += 1;
    }

    fn readNewline(self: *Tokenizer) !bool {
        const c = self.peek();
        if (c != '\n') {
            return false;
        }

        const n_tokens = self.tokens.items.len;

        if (n_tokens == 0) {
            self.next();
            return true;
        }

        const prev_token_kind = self.tokens.items[n_tokens - 1].kind;
        if (prev_token_kind == .Newline) {
            self.next();
            return true;
        }

        try self.tokens.append(.{
            .kind = .Newline,
            .value = self.source[self.current .. self.current + 1],
            .column = self.current_column,
            .row = self.current_row,
        });
        self.next();
        return true;
    }

    fn skipWhitespace(self: *Tokenizer) void {
        while (!self.eof() and isSpace(self.peek()) and self.peek() != '\n') {
            self.next();
        }
    }

    fn skipComments(self: *Tokenizer) void {
        if (self.peek() != '#') {
            return;
        }

        while (!self.eof() and self.peek() != '\n') {
            self.next();
        }

        if (!self.eof()) {
            self.next();
        }
    }

    fn readKeyword(self: *Tokenizer) !bool {
        const old_current = self.current;
        const old_column = self.current_column;
        const old_row = self.current_row;

        while (!self.eof()) : (self.next()) {
            const c = self.peek();
            if (!isAlpha(c)) {
                break;
            }
        }

        if (old_current == self.current) {
            return false;
        }

        const view = self.source[old_current..self.current];

        var keyword_index: usize = Token.keyword_begin;
        while (keyword_index < Token.keyword_end) : (keyword_index += 1) {
            if (std.mem.eql(u8, view, Token.strings[keyword_index])) {
                break;
            }
        }

        if (keyword_index == Token.keyword_end) {
            self.current = old_current;
            self.current_column = old_column;
            self.current_row = old_row;
            return false;
        }

        try self.tokens.append(.{
            .kind = @intToEnum(Token.Kind, keyword_index),
            .value = view,
            .column = old_column,
            .row = old_row,
        });
        return true;
    }

    fn readVariable(self: *Tokenizer) !bool {
        const old_current = self.current;
        const old_column = self.current_column;
        const old_row = self.current_row;
        if (self.peek() != '$') {
            return false;
        }
        self.next();

        var c = self.peek();
        // must begin with a letter
        if (!isAlpha(c)) {
            return false;
        }
        self.next();

        while (!self.eof()) : (self.next()) {
            c = self.peek();
            if (!isAlnum(c) and c != '_') {
                break;
            }
        }

        try self.tokens.append(.{
            .kind = .Variable,
            .value = self.source[old_current..self.current],
            .column = old_column,
            .row = old_row,
        });
        return true;
    }

    fn readIdentifier(self: *Tokenizer) !bool {
        const old_current = self.current;
        const old_column = self.current_column;
        const old_row = self.current_row;

        var c = self.peek();
        // must begin with a letter
        if (!isAlpha(c)) {
            return false;
        }
        self.next();

        while (!self.eof()) : (self.next()) {
            c = self.peek();
            if (!isAlnum(c) and c != '_') {
                break;
            }
        }

        // bad identifier :(
        if (c == '-' or c == '+' or c == '/' or c == '*') {
            self.current = old_current;
            self.current_row = old_row;
            self.current_column = old_column;
            return false;
        }

        // good identifier :)
        try self.tokens.append(.{
            .kind = .Identifier,
            .value = self.source[old_current..self.current],
            .column = old_column,
            .row = old_row,
        });
        return true;
    }

    fn readBareword(self: *Tokenizer) !bool {
        const old_current = self.current;
        const old_column = self.current_column;
        const old_row = self.current_row;

        var c = self.peek();

        while (!self.eof()) : (self.next()) {
            c = self.peek();
            if (isSpace(c) or c == '(' or c == ')') {
                break;
            }
            //TODO: handle forward slashes
            // \n, \t, \( etc...
        }

        try self.tokens.append(.{
            .kind = .Bareword,
            .value = self.source[old_current..self.current],
            .column = old_column,
            .row = old_row,
        });
        return true;
    }

    fn readStringLiteral(self: *Tokenizer) !bool {
        const old_current = self.current;
        const old_column = self.current_column;
        const old_row = self.current_row;

        if (self.peek() != '"') {
            return false;
        }

        self.next();

        while (!self.eof() and self.peek() != '"') {
            if (self.peek() == '\\') {
                self.next();
                if (!self.eof()) {
                    self.next();
                    continue;
                }
            }
            self.next();
        }

        if (self.eof()) {
            //TODO: handle unterminated string literal
            assert(false);
        }

        try self.tokens.append(.{
            .kind = .StringLiteral,
            .value = self.source[old_current + 1 .. self.current],
            .column = old_column,
            .row = old_row,
        });
        self.next();
        return true;
    }

    fn readIntegerLiteral(self: *Tokenizer) !bool {
        // leading negation (-)
        // -1
        // first char
        // - 0 1 2 3 4 5 6 7 8 9
        // if leading negation + not digit
        if (self.peek() == '-' and self.current + 1 < self.end and !isDigit(self.source[self.current + 1])) {
            return false;
        }

        // if not leading negation + not digit
        if (self.peek() != '-' and !isDigit(self.peek())) {
            return false;
        }

        const old_current = self.current;
        const old_column = self.current_column;
        const old_row = self.current_row;

        self.next();

        // all the others
        // 0 1 2 3 4 5 6 7 8 9
        while (!self.eof() and isDigit(self.peek())) {
            self.next();
        }

        try self.tokens.append(.{
            .kind = .IntegerLiteral,
            .value = self.source[old_current..self.current],
            .column = old_column,
            .row = old_row,
        });

        if (self.eof()) {
            return true;
        }

        if (isSpace(self.peek())) {
            return true;
        }

        const upcoming = self.source[self.current .. self.current + 1];
        if (mysh_token.isSymbol(upcoming)) {
            return true;
        }

        _ = self.tokens.pop();
        self.current = old_current;
        self.current_column = old_column;
        self.current_row = old_row;
        return false;
    }

    fn readSymbol(self: *Tokenizer) !bool {
        const old_current = self.current;
        const old_column = self.current_column;
        const old_row = self.current_row;

        const upcoming = self.source[self.current .. self.current + 1];
        var index: usize = Token.symbol_begin;
        while (index < Token.symbol_end) : (index += 1) {
            if (std.mem.eql(u8, upcoming, Token.strings[index])) {
                break;
            }
        }

        if (index == Token.symbol_end) {
            return false;
        }

        self.next();

        switch (@intToEnum(Token.Kind, index)) {
            .Subtract, .Add, .Divide, .Multiply, .Modulo => {
                if (self.eof() or isAlpha(self.peek())) {
                    self.current = old_current;
                    self.current_column = old_column;
                    self.current_row = old_row;
                    return false;
                }

                if (self.peek() == '=') {
                    index = @enumToInt(switch (@intToEnum(Token.Kind, index)) {
                        .Add => Token.Kind.AddAssign,
                        .Subtract => Token.Kind.SubtractAssign,
                        .Multiply => Token.Kind.MultiplyAssign,
                        .Divide => Token.Kind.DivideAssign,
                        .Modulo => Token.Kind.ModuloAssign,
                        else => unreachable,
                    });
                    self.next();
                } else {
                    // save state
                    const k_current = self.current;
                    const k_current_column = self.current_column;
                    const k_current_row = self.current_row;

                    if (!self.isMathCheck()) {
                        self.current = old_current;
                        self.current_column = old_column;
                        self.current_row = old_row;
                        return false;
                    }

                    // rewind
                    self.current = k_current;
                    self.current_column = k_current_column;
                    self.current_row = k_current_row;
                }
            },
            .Assign, .Bang, .Less, .Greater => {
                if (!self.eof() and self.peek() == '=') {
                    index = @enumToInt(switch (@intToEnum(Token.Kind, index)) {
                        .Assign => Token.Kind.Equals,
                        .Bang => Token.Kind.NotEquals,
                        .Less => Token.Kind.LessEquals,
                        .Greater => Token.Kind.GreaterEquals,
                        else => unreachable,
                    });
                    self.next();
                }
            },
            .And => {
                if (!self.eof() and self.peek() == '&') {
                    index = @enumToInt(Token.Kind.LogicalAnd);
                    self.next();
                }
            },
            .Or => {
                if (!self.eof() and self.peek() == '|') {
                    index = @enumToInt(Token.Kind.LogicalOr);
                    self.next();
                }
            },
            .Member => {
                if (!self.member_chain_alive) {
                    self.current = old_current;
                    self.current_column = old_column;
                    self.current_row = old_row;
                    return false;
                }
            },
            else => {},
        }

        try self.tokens.append(.{
            .kind = @intToEnum(Token.Kind, index),
            .value = self.source[old_current..self.current],
            .column = old_column,
            .row = old_row,
        });
        return true;
    }

    fn isMathCheck(self: *Tokenizer) bool {
        self.skipWhitespace();
        while (!self.eof()) {
            const c = self.peek();

            switch (c) {
                '0'...'9', '$' => return true,
                '-' => {},
                else => return false,
            }
            self.next();
            self.skipWhitespace();
        }
        return false;
    }

    tokens: Tokens = undefined,
    source: []const u8 = undefined,
    current: usize = undefined,
    end: usize = undefined,
    current_column: usize = undefined,
    current_row: usize = undefined,
    member_chain_alive: bool = false,
};

const expectEqual = std.testing.expectEqual;
const expectEqualSlices = std.testing.expectEqualSlices;

test "tokenize basic commands" {
    var ally = std.testing.allocator;
    var tokenizer = Tokenizer.init(ally);

    {
        var tokens = try tokenizer.tokenize("ls -l");
        defer ally.free(tokens);

        try expectEqual(tokens.len, 2);
        try expectEqual(tokens[0].kind, .Identifier);
        try expectEqual(tokens[0].column, 1);
        try expectEqual(tokens[0].row, 1);
        try expectEqualSlices(u8, tokens[0].value, "ls");

        try expectEqual(tokens[1].kind, .Bareword);
        try expectEqual(tokens[1].column, 4);
        try expectEqual(tokens[1].row, 1);
        try expectEqualSlices(u8, tokens[1].value, "-l");
    }

    {
        var tokens = try tokenizer.tokenize("echo ");
        defer ally.free(tokens);
        try expectEqual(tokens.len, 1);
        try expectEqual(tokens[0].kind, .Identifier);
        try expectEqualSlices(u8, tokens[0].value, "echo");
    }
}

test "tokenize with double dash" {
    var ally = std.testing.allocator;
    var tokenizer = Tokenizer.init(ally);
    var tokens = try tokenizer.tokenize("ls --color");
    defer ally.free(tokens);
    try expectEqual(tokens.len, 2);
    try expectEqual(tokens[0].kind, .Identifier);
    try expectEqualSlices(u8, tokens[0].value, "ls");
    try expectEqual(tokens[1].kind, .Bareword);
    try expectEqualSlices(u8, tokens[1].value, "--color");
}

test "tokenize subtraction" {
    var ally = std.testing.allocator;
    var tokenizer = Tokenizer.init(ally);
    var tokens = try tokenizer.tokenize("- 1 - - - - - - - 5 - - 0 ");
    defer ally.free(tokens);
    try expectEqual(@as(usize, 13), tokens.len);
    try expectEqual(Token.Kind.Subtract, tokens[0].kind);
    try expectEqualSlices(u8, "-", tokens[0].value);
    try expectEqual(Token.Kind.IntegerLiteral, tokens[1].kind);
    try expectEqualSlices(u8, "1", tokens[1].value);
    try expectEqual(Token.Kind.Subtract, tokens[2].kind);
    try expectEqualSlices(u8, "-", tokens[2].value);
    try expectEqual(Token.Kind.Subtract, tokens[3].kind);
    try expectEqualSlices(u8, "-", tokens[3].value);
    try expectEqual(Token.Kind.Subtract, tokens[4].kind);
    try expectEqualSlices(u8, "-", tokens[4].value);
    try expectEqual(Token.Kind.Subtract, tokens[5].kind);
    try expectEqualSlices(u8, "-", tokens[5].value);
    try expectEqual(Token.Kind.Subtract, tokens[6].kind);
    try expectEqualSlices(u8, "-", tokens[6].value);
    try expectEqual(Token.Kind.Subtract, tokens[7].kind);
    try expectEqualSlices(u8, "-", tokens[7].value);
    try expectEqual(Token.Kind.Subtract, tokens[8].kind);
    try expectEqualSlices(u8, "-", tokens[8].value);
    try expectEqual(Token.Kind.IntegerLiteral, tokens[9].kind);
    try expectEqualSlices(u8, "5", tokens[9].value);
    try expectEqual(Token.Kind.Subtract, tokens[10].kind);
    try expectEqualSlices(u8, "-", tokens[10].value);
    try expectEqual(Token.Kind.Subtract, tokens[11].kind);
    try expectEqualSlices(u8, "-", tokens[11].value);
    try expectEqual(Token.Kind.IntegerLiteral, tokens[12].kind);
    try expectEqualSlices(u8, "0", tokens[12].value);
}

test "tokenize with equals in args" {
    var ally = std.testing.allocator;
    var tokenizer = Tokenizer.init(ally);

    var tokens = try tokenizer.tokenize("ls --color=auto");
    defer ally.free(tokens);
    try expectEqual(tokens.len, 2);
    try expectEqual(tokens[0].kind, .Identifier);
    try expectEqualSlices(u8, tokens[0].value, "ls");
    try expectEqual(tokens[1].kind, .Bareword);
    try expectEqualSlices(u8, tokens[1].value, "--color=auto");
}

test "tokenize with ending slash" {
    var ally = std.testing.allocator;
    var tokenizer = Tokenizer.init(ally);

    var tokens = try tokenizer.tokenize("ls /");
    defer ally.free(tokens);
    try expectEqual(tokens.len, 2);
    try expectEqual(tokens[0].kind, .Identifier);
    try expectEqualSlices(u8, tokens[0].value, "ls");
    try expectEqual(tokens[1].kind, .Bareword);
    try expectEqualSlices(u8, tokens[1].value, "/");
}

test "tokenize unary operator" {
    var ally = std.testing.allocator;
    var tokenizer = Tokenizer.init(ally);

    var tokens = try tokenizer.tokenize("- 5");
    defer ally.free(tokens);
    try expectEqual(tokens.len, 2);
    try expectEqual(tokens[0].kind, .Subtract);
    try expectEqualSlices(u8, tokens[0].value, "-");
    try expectEqual(tokens[1].kind, .IntegerLiteral);
    try expectEqualSlices(u8, tokens[1].value, "5");
}

test "tokenize dotfile" {
    var ally = std.testing.allocator;
    var tokenizer = Tokenizer.init(ally);

    var tokens = try tokenizer.tokenize("cat .hidden");
    defer ally.free(tokens);
    try expectEqual(@as(usize, 2), tokens.len);
    try expectEqual(Token.Kind.Identifier, tokens[0].kind);
    try expectEqualSlices(u8, "cat", tokens[0].value);
    try expectEqual(Token.Kind.Bareword, tokens[1].kind);
    try expectEqualSlices(u8, ".hidden", tokens[1].value);
}

test "tokenize wildcard" {
    var ally = std.testing.allocator;
    var tokenizer = Tokenizer.init(ally);
    var tokens = try tokenizer.tokenize("ls *txt");
    defer ally.free(tokens);
    try expectEqual(@as(usize, 2), tokens.len);
    try expectEqual(Token.Kind.Identifier, tokens[0].kind);
    try expectEqualSlices(u8, "ls", tokens[0].value);
    try expectEqual(Token.Kind.Bareword, tokens[1].kind);
    try expectEqualSlices(u8, "*txt", tokens[1].value);
}

test "tokenize wildcard dot" {
    var ally = std.testing.allocator;
    var tokenizer = Tokenizer.init(ally);
    var tokens = try tokenizer.tokenize("ls *.txt");
    defer ally.free(tokens);
    try expectEqual(@as(usize, 2), tokens.len);
    try expectEqual(Token.Kind.Identifier, tokens[0].kind);
    try expectEqualSlices(u8, "ls", tokens[0].value);
    try expectEqual(Token.Kind.Bareword, tokens[1].kind);
    try expectEqualSlices(u8, "*.txt", tokens[1].value);
}

test "tokenize member access 1" {
    var ally = std.testing.allocator;
    var tokenizer = Tokenizer.init(ally);
    var tokens = try tokenizer.tokenize("$person.age");
    defer ally.free(tokens);
    try expectEqual(@as(usize, 3), tokens.len);
    try expectEqual(Token.Kind.Variable, tokens[0].kind);
    try expectEqualSlices(u8, "$person", tokens[0].value);
    try expectEqual(Token.Kind.Member, tokens[1].kind);
    try expectEqualSlices(u8, ".", tokens[1].value);
    try expectEqual(Token.Kind.Identifier, tokens[2].kind);
    try expectEqualSlices(u8, "age", tokens[2].value);
}

test "tokenize member access deep" {
    var ally = std.testing.allocator;
    var tokenizer = Tokenizer.init(ally);
    var tokens = try tokenizer.tokenize("$person.name.first");
    defer ally.free(tokens);
    try expectEqual(@as(usize, 5), tokens.len);
    try expectEqual(Token.Kind.Variable, tokens[0].kind);
    try expectEqualSlices(u8, "$person", tokens[0].value);
    try expectEqual(Token.Kind.Member, tokens[1].kind);
    try expectEqualSlices(u8, ".", tokens[1].value);
    try expectEqual(Token.Kind.Identifier, tokens[2].kind);
    try expectEqualSlices(u8, "name", tokens[2].value);
    try expectEqual(Token.Kind.Member, tokens[3].kind);
    try expectEqualSlices(u8, ".", tokens[3].value);
    try expectEqual(Token.Kind.Identifier, tokens[4].kind);
    try expectEqualSlices(u8, "first", tokens[4].value);
}

test "tokenize operator assign" {
    var ally = std.testing.allocator;
    var tokenizer = Tokenizer.init(ally);
    var tokens = try tokenizer.tokenize("$i += 1");
    defer ally.free(tokens);
    try expectEqual(@as(usize, 3), tokens.len);
}

//TODO: move various text examples in here
