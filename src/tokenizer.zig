const std = @import("std");
const token = @import("token.zig");
const Token = token.Token;

const assert = std.debug.assert;

const Tokens = std.ArrayList(Token);

pub const Tokenizer = struct {
    pub fn init(ally: std.mem.Allocator) Tokenizer {
        return Tokenizer{
            .tokens = Tokens.init(ally),
        };
    }

    pub fn tokenize(self: *Tokenizer, src: []const u8) !Tokens {
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

            if (std.ascii.isSpace(c) and c != '\n') {
                self.skipWhitespace();
                continue;
            }

            if (c == '#') {
                self.skipComments();
                continue;
            }

            if (try self.readKeyword()) {
                continue;
            }

            assert(false);
        }

        return self.tokens;
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
        if (prev_token_kind == Token.Kind.Newline) {
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
        while (std.ascii.isSpace(self.peek()) and self.peek() != '\n') {
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
            if (!std.ascii.isAlpha(c)) {
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

    tokens: Tokens = undefined,
    source: []const u8 = undefined,
    current: usize = undefined,
    end: usize = undefined,
    current_column: usize = undefined,
    current_row: usize = undefined,
};
