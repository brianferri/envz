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
    double_quote,
    single_quote,
    backtick_quote,
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

fn skipWhitespaces(self: *Lexer) void {
    while (self.peek()) |c| : (self.position += 1) {
        // ? newlines are valid tokens, so we break before consuming them
        if (!std.ascii.isWhitespace(c) or c == '\n') return;
    }
}

fn readQuotedValue(self: *Lexer, quote: u8) []const u8 {
    const start = self.position;
    // ! After slicing we consume the trailing quote char
    defer self.position += 1;

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

fn skipToEOL(self: *Lexer) []const u8 {
    const start = self.position;
    while (self.peek()) |pc| : (self.position += 1) {
        if (pc == '\n') break;
    }
    return self.sliceFrom(start);
}

fn readKey(self: *Lexer) []const u8 {
    const start = self.position;
    while (self.peek()) |c| : (self.position += 1) {
        if (c == '=' or c == '#' or std.ascii.isWhitespace(c)) break;
    }
    return self.sliceFrom(start);
}

fn readValue(self: *Lexer) Token {
    return switch (self.advance() orelse
        return .{ .kind = .eof, .lexeme = "" }) {
        '"' => |c| .{ .kind = .double_quote, .lexeme = self.readQuotedValue(c) },
        '\'' => |c| .{ .kind = .single_quote, .lexeme = self.readQuotedValue(c) },
        '`' => |c| .{ .kind = .backtick_quote, .lexeme = self.readQuotedValue(c) },
        else => .{
            .kind = .value,
            .lexeme = out: {
                // ? If we're reading an unquoted value we need to backtrack
                // ? to not skip the first character
                self.position -= 1;
                break :out std.mem.trim(u8, self.readUnquotedValue(), &std.ascii.whitespace);
            },
        },
    };
}

fn readString(self: *Lexer, is_value: bool) ?Token {
    return if (is_value) self.readValue() else .{ .kind = .key, .lexeme = self.readKey() };
}

pub fn next(self: *Lexer, expect: ?TokenType) ?Token {
    // * In `.env` whitespaces between tokens are skipped
    self.skipWhitespaces();
    return switch (self.peek() orelse
        return .{ .kind = .eof, .lexeme = "" }) {
        '#' => .{ .kind = .comment, .lexeme = self.skipToEOL() },
        '=' => |c| .{ .kind = .equal, .lexeme = &.{self.advance() orelse c} },
        '\n' => |c| .{ .kind = .newline, .lexeme = &.{self.advance() orelse c} },
        else => self.readString(
            // ? Scan for `.key`s if not explicitly requested otherwise
            if (expect) |expected| expected == .value else false,
        ),
    };
}
