const std = @import("std");
const token = @import("token.zig");
const Token = token.Token;

const assert = std.debug.assert;

const isSpace = std.ascii.isSpace;
const isAlpha = std.ascii.isAlpha;
const isDigit = std.ascii.isDigit;

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
                continue;
            }

            if (isSpace(c) and c != '\n') {
                self.skipWhitespace();
                continue;
            }

            if (c == '#') {
                self.skipComments();
                continue;
            }

            if (try self.readVariable()) {
                continue;
            }
            if (try self.readKeyword()) {
                continue;
            }
            if (try self.readIdentifier()) {
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

    fn eof(self: *Tokenizer) bool {
        return self.current >= self.end;
    }

    fn peek(self: *Tokenizer) u8 {
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
        while (isSpace(self.peek()) and self.peek() != '\n') {
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
            if (isSpace(c)) {
                break;
            }
            //TODO: handle forward slashes
            // \n, \t, etc...
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
            .value = self.source[old_current..self.current],
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
        if (token.isOperator(upcoming)) {
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
        var index: usize = Token.operator_begin;
        while (index < Token.operator_end) : (index += 1) {
            if (std.mem.eql(u8, upcoming, Token.strings[index])) {
                break;
            }
        }

        if (index == Token.operator_end) {
            return false;
        }

        self.next();

        //TODO: handle special cases
        // ==, <=, >=, !=, etc...
        switch (@intToEnum(Token.Kind, index)) {
            .Subtract, .Add, .Divide, .Multiply => {
                if (isAlpha(self.peek())) {
                    self.current = old_current;
                    self.current_column = old_column;
                    self.current_row = old_row;
                    return false;
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

    tokens: Tokens = undefined,
    source: []const u8 = undefined,
    current: usize = undefined,
    end: usize = undefined,
    current_column: usize = undefined,
    current_row: usize = undefined,
};
