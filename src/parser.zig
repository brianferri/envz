const std = @import("std");

const Parser = @This();

pub const Parsed = struct {
    key: []const u8,
    value: []const u8,

    pub fn line(env_line: []const u8) ?Parsed {
        const comment = std.mem.indexOfScalar(u8, env_line, '#');

        if (std.mem.indexOfScalar(u8, env_line, '=')) |e_index| {
            if (comment) |c_index| if (c_index < e_index) return null;
            return .{
                .key = std.mem.trim(u8, env_line[0..e_index], " "),
                .value = std.mem.trim(u8, env_line[e_index + 1 .. comment orelse env_line.len], " "),
            };
        }

        return null;
    }
};

const testing = std.testing;

test "basic key-value" {
    const env = Parsed.line("BASIC=basic").?;
    try testing.expectEqualStrings("BASIC", env.key);
    try testing.expectEqualStrings("basic", env.value);
}
