const std = @import("std");
const Parsed = @import("./lexer.zig").Parsed;

const Env = @This();

const KVMap = struct { []const u8, []const u8 };
const EnvMap = std.StaticStringMap([]const u8);

map: EnvMap = undefined,

pub fn loadComptime(comptime file: []const u8) Env {
    return .{
        .map = comptime blk: {
            var kv_map: []KVMap = &.{};
            var file_line_iterator = std.mem.splitScalar(u8, file, '\n');
            while (file_line_iterator.next()) |line| {
                if (Parsed.line(line)) |env_line| {
                    const appended_kv_map = kv_map ++ .{.{
                        env_line.key,
                        env_line.value,
                    }};
                    kv_map = @constCast(appended_kv_map);
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
