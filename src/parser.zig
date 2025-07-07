const std = @import("std");
const Lexer = @import("./lexer.zig");

const KV = struct { []const u8, []const u8 };

pub fn parse(allocator: std.mem.Allocator, file: []const u8) ![]KV {
    var kv_map: std.ArrayList(KV) = .init(allocator);
    var lexer: Lexer = .init(file);

    while (lexer.next()) |token| {
        switch (token.kind) {
            .Key => {
                if (!lexer.expect(.Equal))
                    @panic("InvalidToken: expected `" ++ @tagName(Lexer.TokenType.Equal) ++ "`");

                var value_token = lexer.nextValue();
                value_token.lexeme = if (value_token.kind == .DoubleQuoted)
                    try processDoubleQuotedString(value_token.lexeme, allocator)
                else
                    try allocator.dupe(u8, value_token.lexeme);

                try kv_map.append(.{ token.lexeme, value_token.lexeme });
            },
            .Eof => break,
            else => continue,
        }
    }

    return try kv_map.toOwnedSlice();
}

pub fn parseComptime(comptime file: []const u8) std.StaticStringMap([]const u8) {
    return comptime blk: {
        var kv_map: []KV = &.{};
        var lexer: Lexer = .init(file);

        while (lexer.next()) |token| {
            switch (token.kind) {
                .Key => {
                    if (!lexer.expect(.Equal))
                        @compileError("InvalidToken: expected `" ++ @tagName(Lexer.TokenType.Equal) ++ "`");

                    var value_token = lexer.nextValue();
                    if (value_token.kind == .DoubleQuoted)
                        value_token.lexeme = processDoubleQuotedStringComptime(value_token.lexeme);

                    kv_map = @constCast(kv_map ++ .{.{ token.lexeme, value_token.lexeme }});
                },
                .Eof => break,
                else => continue,
            }
        }

        break :blk .initComptime(kv_map);
    };
}

fn escape(c: u8) u8 {
    return switch (c) {
        'n' => '\n',
        'r' => '\r',
        't' => '\t',
        else => c,
    };
}

fn processDoubleQuotedString(input: []const u8, allocator: std.mem.Allocator) ![]u8 {
    var out: std.ArrayList(u8) = .init(allocator);

    var i: usize = 0;
    while (i < input.len) : (i += 1) {
        if (input[i] == '\\' and i + 1 < input.len) {
            i += 1;
            const c = input[i];
            try out.append(escape(c));
        } else try out.append(input[i]);
    }

    return try out.toOwnedSlice();
}

fn processDoubleQuotedStringComptime(input: []const u8) []const u8 {
    var out: []const u8 = &.{};

    var i: usize = 0;
    while (i < input.len) : (i += 1) {
        if (input[i] == '\\' and i + 1 < input.len) {
            i += 1;
            const c = input[i];
            out = out ++ &[1]u8{escape(c)};
        } else out = out ++ &[1]u8{input[i]};
    }

    return out;
}
