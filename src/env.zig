const std = @import("std");
const Lexer = @import("./lexer.zig").Lexer;

const Env = @This();

const KVMap = struct { []const u8, []const u8 };
const EnvMap = std.StaticStringMap([]const u8);

map: EnvMap = undefined,

pub fn loadComptime(comptime file: []const u8) Env {
    return .{
        .map = comptime blk: {
            var kv_map: []KVMap = &.{};
            var lexer = Lexer.init(file);

            while (true) {
                const token = lexer.next() orelse break;

                switch (token.kind) {
                    .Eof => break,
                    .Newline, .Comment => continue,
                    .Key => {
                        const eq_token = lexer.next() orelse break;
                        if (eq_token.kind != .Equal) continue;

                        const value_token = lexer.nextValue();

                        const appended = kv_map ++ .{.{ token.lexeme, value_token.lexeme }};
                        kv_map = @constCast(appended);
                    },
                    else => continue,
                }
            }

            break :blk .initComptime(kv_map);
        },
    };
}

pub fn loadFromPathComptime(comptime path: []const u8) Env {
    return loadComptime(@embedFile(path));
}

pub fn get(self: Env, key: []const u8) ?[]const u8 {
    return self.map.get(key);
}

pub fn print(self: Env) void {
    const kv_map = self.map.kvs;
    for (0..kv_map.len) |i| {
        std.debug.print("{s}: {s}\n", .{ kv_map.keys[i], kv_map.values[i] });
    }
}

test "load comptime" {
    const file: []const u8 = @embedFile("env/.env");
    @setEvalBranchQuota(100000);

    const env: Env = .loadComptime(file);
    env.print();
}

test "load from path comptime" {
    const env: Env = .loadFromPathComptime("env/.env");
    env.print();
}

test "load multiline" {
    @setEvalBranchQuota(100000);
    const env: Env = .loadFromPathComptime("env/multiline.env");
    env.print();
}
