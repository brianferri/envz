const std = @import("std");

pub const Lexer = @This();

input: []const u8,
position: usize = 0,

pub const TokenType = enum {
    key,
    equal,
    value,
    comment,
    newline,
    eof,
    double_quoted,
    single_quoted,
    backtick_quoted,
};

pub const Token = struct {
    kind: TokenType,
    lexeme: []const u8,
};

pub fn init(input: []const u8) Lexer {
    return .{ .input = input };
}

pub fn expect(self: *Lexer, expected_type: TokenType) bool {
    return if (self.next()) |token|
        token.kind == expected_type
    else
        false;
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

fn readUnquotedValue(self: *Lexer) []const u8 {
    const start = self.position;
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
    const c = self.peek() orelse return .{ .kind = .eof, .lexeme = "" };

    self.position += 1;
    const kind: TokenType = switch (c) {
        '"' => .double_quoted,
        '\'' => .single_quoted,
        '`' => .backtick_quoted,
        else => blk: {
            self.position -= 1;
            break :blk .value;
        },
    };

    const lexeme = switch (kind) {
        .double_quoted, .single_quoted, .backtick_quoted => self.readQuotedValue(c),
        else => std.mem.trim(u8, self.readUnquotedValue(), &std.ascii.whitespace),
    };

    return .{
        .kind = kind,
        .lexeme = lexeme,
    };
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
    return switch (self.advance() orelse return .{ .kind = .eof, .lexeme = "" }) {
        '=' => .{ .kind = .equal, .lexeme = "=" },
        '\n' => .{ .kind = .newline, .lexeme = "\n" },
        '"', '\'', '`' => self.readValue(),
        '#' => .{ .kind = .comment, .lexeme = self.skipToEOL() },
        else => .{ .kind = .key, .lexeme = self.readKey(start) },
    };
}

pub fn nextValue(self: *Lexer) Token {
    self.skipWhitespace();
    return self.readValue();
}
