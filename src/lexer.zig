const std = @import("std");

pub const TokenType = enum {
    Key,
    Equal,
    Value,
    Comment,
    Newline,
    Eof,
};

pub const Token = struct {
    kind: TokenType,
    lexeme: []const u8,
};

pub const Lexer = struct {
    input: []const u8,
    position: usize = 0,

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

    fn skipWhitespace(self: *Lexer) void {
        while (self.advance()) |c| {
            if (!std.ascii.isWhitespace(c)) {
                self.position -= 1;
                break;
            }
        }
    }

    fn readQuotedValue(self: *Lexer, quote: u8, start_pos: usize) []const u8 {
        while (self.peek()) |c| {
            _ = self.advance();
            if (c == quote) {
                break;
            }
        }
        return self.input[start_pos..self.position];
    }

    pub fn next(self: *Lexer) ?Token {
        self.skipWhitespace();

        if (self.position >= self.input.len)
            return .{ .kind = .Eof, .lexeme = "" };

        const start = self.position;
        const c = self.advance() orelse return null;

        switch (c) {
            '=' => return .{ .kind = .Equal, .lexeme = self.input[start..self.position] },

            '#' => {
                while (self.peek()) |pc| : (_ = self.advance()) {
                    if (pc == '\n') break;
                }
                return .{ .kind = .Comment, .lexeme = self.input[start..self.position] };
            },

            '\n' => return .{ .kind = .Newline, .lexeme = "\n" },

            '"', '\'', '`' => {
                const value = self.readQuotedValue(c, start);
                return .{ .kind = .Value, .lexeme = value };
            },

            else => {
                while (self.peek()) |pc| : (_ = self.advance()) {
                    if (pc == '=' or pc == '\n' or pc == '#' or pc == ' ' or pc == '\t')
                        break;
                }
                return .{ .kind = .Key, .lexeme = self.input[start..self.position] };
            },
        }
    }
};

pub const Parsed = struct {
    key: []const u8,
    value: []const u8,

    pub fn line(env_line: []const u8) ?Parsed {
        var lexer = Lexer.init(env_line);

        const key_token = lexer.next() orelse return null;
        if (key_token.kind != .Key) return null;

        const eq_token = lexer.next() orelse return null;
        if (eq_token.kind != .Equal) return null;

        const val_token = lexer.next() orelse return .{ .key = std.mem.trim(u8, key_token.lexeme, " "), .value = "" };
        if (val_token.kind != .Value and val_token.kind != .Key)
            return .{ .key = std.mem.trim(u8, key_token.lexeme, " "), .value = "" };

        var value = std.mem.trim(u8, val_token.lexeme, " \t");

        // Strip enclosing quotes if present
        if ((value.len >= 2) and ((value[0] == '"' and value[value.len - 1] == '"') or
            (value[0] == '\'' and value[value.len - 1] == '\'') or
            (value[0] == '`' and value[value.len - 1] == '`')))
        {
            value = value[1 .. value.len - 1];
        }

        return .{ .key = std.mem.trim(u8, key_token.lexeme, " \t"), .value = value };
    }
};
