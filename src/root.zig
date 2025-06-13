pub const Env = @import("./env.zig");

test {
    const std = @import("std");

    std.testing.refAllDecls(@This());
}
