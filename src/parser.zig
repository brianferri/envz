const std = @import("std");
const Lexer = @import("./lexer.zig");

const KV = struct { []const u8, []const u8 };

pub fn parse(allocator: std.mem.Allocator, file: []const u8) ![]KV {
    var kv_map: std.ArrayList(KV) = .empty;
    var lexer: Lexer = .init(file);

    while (lexer.next(null)) |token| {
        switch (token.kind) {
            .key => {
                if (lexer.next(null)) |next_token| if (next_token.kind != .equal)
                    @panic(try std.fmt.allocPrint(
                        allocator,
                        "InvalidToken: expected `{s}`, got `{s}`",
                        .{
                            @tagName(Lexer.TokenType.equal),
                            @tagName(next_token.kind),
                        },
                    ));
                if (lexer.next(.value)) |value| {
                    const lexeme = switch (value.kind) {
                        .value,
                        .single_quote,
                        .backtick_quote,
                        => try allocator.dupe(u8, value.lexeme),
                        .double_quote,
                        => try processDoubleQuoteString(value.lexeme, allocator),
                        .comment, .newline, .eof => "",
                        else => @panic(try std.fmt.allocPrint(
                            allocator,
                            "InvalidToken: expected `{s}`, got `{s}`",
                            .{
                                @tagName(Lexer.TokenType.value),
                                @tagName(value.kind),
                            },
                        )),
                    };
                    try kv_map.append(allocator, .{ token.lexeme, lexeme });
                }
            },
            .eof => break,
            .comment, .newline => continue,
            else => @panic(try std.fmt.allocPrint(
                allocator,
                "UnexpectedToken: `{s}`",
                .{@tagName(token.kind)},
            )),
        }
    }

    return try kv_map.toOwnedSlice(allocator);
}

pub fn parseComptime(comptime file: []const u8) std.StaticStringMap([]const u8) {
    return comptime blk: {
        var kv_map: []KV = &.{};
        var lexer: Lexer = .init(file);

        while (lexer.next(null)) |token| {
            switch (token.kind) {
                .key => {
                    if (lexer.next(null)) |next_token| if (next_token.kind != .equal)
                        @compileError(std.fmt.comptimePrint(
                            "InvalidToken: expected `{s}`, got `{s}`",
                            .{
                                @tagName(Lexer.TokenType.equal),
                                @tagName(next_token.kind),
                            },
                        ));
                    if (lexer.next(.value)) |value| {
                        const lexeme = switch (value.kind) {
                            .value,
                            .single_quote,
                            .backtick_quote,
                            => value.lexeme,
                            .double_quote,
                            => processDoubleQuoteStringComptime(value.lexeme),
                            .comment, .newline, .eof => "",
                            else => @compileError(std.fmt.comptimePrint(
                                "InvalidToken: expected `{s}`, got `{s}`",
                                .{
                                    @tagName(Lexer.TokenType.value),
                                    @tagName(value.kind),
                                },
                            )),
                        };
                        kv_map = @constCast(kv_map ++ .{.{ token.lexeme, lexeme }});
                    }
                },
                .eof => break,
                .comment, .newline => continue,
                else => @compileError(std.fmt.comptimePrint(
                    "UnexpectedToken: `{s}`",
                    .{@tagName(token.kind)},
                )),
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

fn processDoubleQuoteString(input: []const u8, allocator: std.mem.Allocator) ![]u8 {
    var out: std.ArrayList(u8) = .empty;

    var i: usize = 0;
    while (i < input.len) : (i += 1) {
        if (input[i] == '\\' and i + 1 < input.len) {
            i += 1;
            const c = input[i];
            try out.append(allocator, escape(c));
        } else try out.append(allocator, input[i]);
    }

    return try out.toOwnedSlice(allocator);
}

fn processDoubleQuoteStringComptime(input: []const u8) []const u8 {
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
