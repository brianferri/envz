const std = @import("std");
const Lexer = @import("./lexer.zig").Lexer;

const KV = struct { []const u8, []const u8 };

/// Parses a `.env` file in to a `Static String Map`
pub fn parse(comptime file: []const u8) std.StaticStringMap([]const u8) {
    return comptime blk: {
        var kv_map: []KV = &.{};
        var lexer: Lexer = .init(file);

        while (lexer.next()) |token| {
            switch (token.kind) {
                .Key => {
                    if (lexer.next()) |eq| if (eq.kind != .Equal) continue;
                    var value_token = lexer.nextValue();

                    if (value_token.kind == .DoubleQuoted) {
                        value_token.lexeme = processEscapes(value_token.lexeme);
                    }

                    const appended = kv_map ++ .{.{ token.lexeme, value_token.lexeme }};
                    kv_map = @constCast(appended);
                },
                .Eof => break,
                else => continue,
            }
        }

        break :blk .initComptime(kv_map);
    };
}

fn processEscapes(input: []const u8) []const u8 {
    var out: []u8 = &.{};

    var i: usize = 0;
    while (i < input.len) : (i += 1) {
        if (input[i] == '\\' and i + 1 < input.len) {
            i += 1;
            const c = input[i];
            out = @constCast(switch (c) {
                'n' => out ++ "\n",
                'r' => out ++ "\r",
                't' => out ++ "\t",
                '"' => out ++ "\"",
                '\\' => out ++ "\\",
                else => out ++ &[_]u8{c},
            });
        } else {
            out = @constCast(out ++ &[_]u8{input[i]});
        }
    }

    return @constCast(out);
}

