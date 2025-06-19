const std = @import("std");

pub const Lexer = @This();

input: []const u8,
position: usize = 0,

pub const TokenType = enum {
    Key,
    Equal,
    Value,
    Comment,
    Newline,
    Eof,
    DoubleQuoted,
    SingleQuoted,
    BacktickQuoted,
};

pub const Token = struct {
    kind: TokenType,
    lexeme: []const u8,
};

pub fn init(input: []const u8) Lexer {
    return .{ .input = input };
}

fn peek(self: *Lexer) ?u8 {
    return if (self.position < self.input.len) self.input[self.position] else null;
}

fn advance(self: *Lexer) ?u8 {
    const c = self.peek() orelse return null;
    self.position += 1;
    return c;
}

fn sliceFrom(self: *Lexer, start: usize) []const u8 {
    return self.input[start..self.position];
}

fn skipWhitespace(self: *Lexer) void {
    while (self.peek()) |c| : (self.position += 1) {
        if (!std.ascii.isWhitespace(c) or c == '\n') return;
    }
}

fn readQuotedValue(self: *Lexer, quote: u8) []const u8 {
    const start = self.position;
    while (self.peek()) |c| : (self.position += 1) {
        if (c == quote) break;
    }
    return self.sliceFrom(start);
}

fn readUnquotedValue(self: *Lexer, start: usize) []const u8 {
    while (self.peek()) |c| : (self.position += 1) {
        if (c == '\n' or c == '#') break;
    }
    return self.sliceFrom(start);
}

fn readKey(self: *Lexer, start: usize) []const u8 {
    while (self.peek()) |c| : (self.position += 1) {
        if (c == '=' or c == '#' or std.ascii.isWhitespace(c)) break;
    }
    return self.sliceFrom(start);
}

fn readValue(self: *Lexer) Token {
    const c = self.peek() orelse return .{ .kind = .Value, .lexeme = "" };

    if (c == '"' or c == '\'' or c == '`') {
        self.position += 1;
        const lexeme = self.readQuotedValue(c);
        return switch (c) {
            '"' => .{ .kind = .DoubleQuoted, .lexeme = lexeme },
            '\'' => .{ .kind = .SingleQuoted, .lexeme = lexeme },
            '`' => .{ .kind = .BacktickQuoted, .lexeme = lexeme },
            else => .{ .kind = .Value, .lexeme = lexeme },
        };
    }

    const start = self.position;
    const lexeme = self.readUnquotedValue(start);
    return .{ .kind = .Value, .lexeme = lexeme };
}

fn skipToEOL(self: *Lexer) []const u8 {
    const start = self.position;
    while (self.peek()) |pc| : (self.position += 1) {
        if (pc == '\n') break;
    }
    return self.sliceFrom(start);
}

pub fn next(self: *Lexer) ?Token {
    self.skipWhitespace();

    const start = self.position;
    return switch (self.advance() orelse return null) {
        '=' => .{ .kind = .Equal, .lexeme = self.sliceFrom(start) },
        '#' => .{ .kind = .Comment, .lexeme = self.skipToEOL() },
        '\n' => .{ .kind = .Newline, .lexeme = "\n" },
        '"', '\'', '`' => self.readValue(),
        else => .{ .kind = .Key, .lexeme = self.readKey(start) },
    };
}

pub fn nextValue(self: *Lexer) Token {
    self.skipWhitespace();

    if (self.position >= self.input.len)
        return .{ .kind = .Value, .lexeme = "" };

    return self.readValue();
}
