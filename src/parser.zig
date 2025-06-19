const std = @import("std");
const Lexer = @import("./lexer.zig").Lexer;

const KV = struct { []const u8, []const u8 };

/// Parses a `.env` file in to a `Static String Map`
pub fn parse(comptime file: []const u8) std.StaticStringMap([]const u8) {
    return comptime blk: {
        var kv_map: []KV = &.{};
        var lexer: Lexer = .init(file);

        while (true) {
            const token = lexer.next() orelse break;

            switch (token.kind) {
                .Key => {
                    const eq_token = lexer.next() orelse break;
                    if (eq_token.kind != .Equal) continue;

                    const value_token = lexer.nextValue();

                    const appended = kv_map ++ .{.{ token.lexeme, value_token.lexeme }};
                    kv_map = @constCast(appended);
                },
                .Eof => break,
                .Newline, .Comment => continue,
                else => continue,
            }
        }

        break :blk .initComptime(kv_map);
    };
}

