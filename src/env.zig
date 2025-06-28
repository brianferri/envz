const std = @import("std");
const Parser = @import("./parser.zig");

const Env = @This();

map: std.StaticStringMap([]const u8) = undefined,
allocator: std.mem.Allocator = undefined,
file_buf: ?[]u8 = null,

pub fn load(allocator: std.mem.Allocator, file: []u8) !Env {
    const kv_slice = try Parser.parse(allocator, file);
    defer allocator.free(kv_slice); 
    return .{
        .map = try .init(kv_slice, allocator),
        .allocator = allocator,
        .file_buf = file,
    };
}

pub fn loadFromPath(allocator: std.mem.Allocator, path: []const u8) !Env {
    const input_file = try std.fs.cwd().openFile(path, .{});
    defer input_file.close();

    const file = try input_file.stat();
    const buf = try input_file.readToEndAlloc(allocator, file.size);
    return try load(allocator, buf);
}

pub fn deinit(self: *Env) void {
    for (self.map.values()) |val|
        self.allocator.free(val);
    self.map.deinit(self.allocator);
    if (self.file_buf) |buf| self.allocator.free(buf);
}

pub fn loadComptime(comptime file: []const u8) Env {
    return .{
        .map = Parser.parseComptime(file),
    };
}

pub fn loadFromPathComptime(comptime path: []const u8) Env {
    return loadComptime(@embedFile(path));
}

pub fn get(self: Env, key: []const u8) ?[]const u8 {
    return self.map.get(key);
}

const testing = std.testing;

//? https://github.com/ziglang/zig/issues/513
// test "invalid env errors" {
//     const env = Env.loadFromPathComptime("env/invalid.env");
//
//     try testing.expectError(Parser.ParserError.InvalidToken, env);
// }

test "comptime env: basic parsing" {
    @setEvalBranchQuota(10000);
    const env = Env.loadFromPathComptime("env/.env");

    try testing.expectEqualStrings("basic", env.get("BASIC").?);
    try testing.expectEqualStrings("after_line", env.get("AFTER_LINE").?);

    try testing.expectEqualStrings("", env.get("EMPTY").?);
    try testing.expectEqualStrings("", env.get("EMPTY_SINGLE_QUOTES").?);
    try testing.expectEqualStrings("", env.get("EMPTY_DOUBLE_QUOTES").?);
    try testing.expectEqualStrings("", env.get("EMPTY_BACKTICKS").?);

    try testing.expectEqualStrings("single_quotes", env.get("SINGLE_QUOTES").?);
    try testing.expectEqualStrings("    single quotes    ", env.get("SINGLE_QUOTES_SPACED").?);
    try testing.expectEqualStrings("double_quotes", env.get("DOUBLE_QUOTES").?);
    try testing.expectEqualStrings("    double quotes    ", env.get("DOUBLE_QUOTES_SPACED").?);

    try testing.expectEqualStrings("double \"quotes\" work inside single quotes", env.get("DOUBLE_QUOTES_INSIDE_SINGLE").?);
    try testing.expectEqualStrings("{ port: $MONGOLAB_PORT}", env.get("DOUBLE_QUOTES_WITH_NO_SPACE_BRACKET").?);
    try testing.expectEqualStrings("single 'quotes' work inside double quotes", env.get("SINGLE_QUOTES_INSIDE_DOUBLE").?);

    try testing.expectEqualStrings("`backticks` work inside single quotes", env.get("BACKTICKS_INSIDE_SINGLE").?);
    try testing.expectEqualStrings("`backticks` work inside double quotes", env.get("BACKTICKS_INSIDE_DOUBLE").?);
    try testing.expectEqualStrings("backticks", env.get("BACKTICKS").?);
    try testing.expectEqualStrings("    backticks    ", env.get("BACKTICKS_SPACED").?);
    try testing.expectEqualStrings("double \"quotes\" work inside backticks", env.get("DOUBLE_QUOTES_INSIDE_BACKTICKS").?);
    try testing.expectEqualStrings("single 'quotes' work inside backticks", env.get("SINGLE_QUOTES_INSIDE_BACKTICKS").?);
    try testing.expectEqualStrings("double \"quotes\" and single 'quotes' work inside backticks", env.get("DOUBLE_AND_SINGLE_QUOTES_INSIDE_BACKTICKS").?);

    try testing.expectEqualStrings("expand\nnew\nlines", env.get("EXPAND_NEWLINES").?);
    try testing.expectEqualStrings("dontexpand\\nnew\\nline", env.get("DONT_EXPAND_DOUBLE_ESCAPE").?);
    try testing.expectEqualStrings("dontexpand\\nnewlines", env.get("DONT_EXPAND_UNQUOTED").?);
    try testing.expectEqualStrings("dontexpand\\nnewlines", env.get("DONT_EXPAND_SQUOTED").?);

    try testing.expectEqualStrings("inline comments", env.get("INLINE_COMMENTS").?);
    try testing.expectEqualStrings("inline comments outside of #singlequotes", env.get("INLINE_COMMENTS_SINGLE_QUOTES").?);
    try testing.expectEqualStrings("inline comments outside of #doublequotes", env.get("INLINE_COMMENTS_DOUBLE_QUOTES").?);
    try testing.expectEqualStrings("inline comments outside of #backticks", env.get("INLINE_COMMENTS_BACKTICKS").?);
    try testing.expectEqualStrings("inline comments start with a", env.get("INLINE_COMMENTS_SPACE").?);

    try testing.expectEqualStrings("equals==", env.get("EQUAL_SIGNS").?);
    try testing.expectEqualStrings("{\"foo\": \"bar\"}", env.get("RETAIN_INNER_QUOTES").?);
    try testing.expectEqualStrings("{\"foo\": \"bar\"}", env.get("RETAIN_INNER_QUOTES_AS_STRING").?);
    try testing.expectEqualStrings("{\"foo\": \"bar's\"}", env.get("RETAIN_INNER_QUOTES_AS_BACKTICKS").?);
    try testing.expectEqualStrings("some spaced out string", env.get("TRIM_SPACE_FROM_UNQUOTED").?);
    try testing.expectEqualStrings("therealnerdybeast@example.tld", env.get("USERNAME").?);
    try testing.expectEqualStrings("parsed", env.get("SPACED_KEY").?);
}

test "comptime env: multiline parsing" {
    @setEvalBranchQuota(10000);
    const env = Env.loadFromPathComptime("env/multiline.env");

    try testing.expectEqualStrings("basic", env.get("BASIC").?);
    try testing.expectEqualStrings("after_line", env.get("AFTER_LINE").?);
    try testing.expectEqualStrings("", env.get("EMPTY").?);
    try testing.expectEqualStrings("single_quotes", env.get("SINGLE_QUOTES").?);
    try testing.expectEqualStrings("    single quotes    ", env.get("SINGLE_QUOTES_SPACED").?);
    try testing.expectEqualStrings("double_quotes", env.get("DOUBLE_QUOTES").?);
    try testing.expectEqualStrings("    double quotes    ", env.get("DOUBLE_QUOTES_SPACED").?);
    try testing.expectEqualStrings("expand\nnew\nlines", env.get("EXPAND_NEWLINES").?);
    try testing.expectEqualStrings("dontexpand\\nnewlines", env.get("DONT_EXPAND_UNQUOTED").?);
    try testing.expectEqualStrings("dontexpand\\nnewlines", env.get("DONT_EXPAND_SQUOTED").?);
    try testing.expectEqualStrings("equals==", env.get("EQUAL_SIGNS").?);
    try testing.expectEqualStrings("{\"foo\": \"bar\"}", env.get("RETAIN_INNER_QUOTES").?);
    try testing.expectEqualStrings("{\"foo\": \"bar\"}", env.get("RETAIN_INNER_QUOTES_AS_STRING").?);
    try testing.expectEqualStrings("some spaced out string", env.get("TRIM_SPACE_FROM_UNQUOTED").?);
    try testing.expectEqualStrings("therealnerdybeast@example.tld", env.get("USERNAME").?);
    try testing.expectEqualStrings("parsed", env.get("SPACED_KEY").?);

    try testing.expectEqualStrings(
        \\THIS
        \\IS
        \\A
        \\MULTILINE
        \\STRING
    , env.get("MULTI_DOUBLE_QUOTED").?);

    try testing.expectEqualStrings(
        \\THIS
        \\IS
        \\A
        \\MULTILINE
        \\STRING
    , env.get("MULTI_SINGLE_QUOTED").?);

    try testing.expectEqualStrings(
        \\THIS
        \\IS
        \\A
        \\"MULTILINE'S"
        \\STRING
    , env.get("MULTI_BACKTICKED").?);

    try testing.expectEqualStrings(env.get("MULTI_PEM_DOUBLE_QUOTED").?[0..26], "-----BEGIN PUBLIC KEY-----");
}

test "env: basic parsing" {
    var env = try Env.loadFromPath(testing.allocator, "./src/env/.env");
    defer env.deinit();

    try testing.expectEqualStrings("basic", env.get("BASIC").?);
    try testing.expectEqualStrings("after_line", env.get("AFTER_LINE").?);

    try testing.expectEqualStrings("", env.get("EMPTY").?);
    try testing.expectEqualStrings("", env.get("EMPTY_SINGLE_QUOTES").?);
    try testing.expectEqualStrings("", env.get("EMPTY_DOUBLE_QUOTES").?);
    try testing.expectEqualStrings("", env.get("EMPTY_BACKTICKS").?);

    try testing.expectEqualStrings("single_quotes", env.get("SINGLE_QUOTES").?);
    try testing.expectEqualStrings("    single quotes    ", env.get("SINGLE_QUOTES_SPACED").?);
    try testing.expectEqualStrings("double_quotes", env.get("DOUBLE_QUOTES").?);
    try testing.expectEqualStrings("    double quotes    ", env.get("DOUBLE_QUOTES_SPACED").?);

    try testing.expectEqualStrings("double \"quotes\" work inside single quotes", env.get("DOUBLE_QUOTES_INSIDE_SINGLE").?);
    try testing.expectEqualStrings("{ port: $MONGOLAB_PORT}", env.get("DOUBLE_QUOTES_WITH_NO_SPACE_BRACKET").?);
    try testing.expectEqualStrings("single 'quotes' work inside double quotes", env.get("SINGLE_QUOTES_INSIDE_DOUBLE").?);

    try testing.expectEqualStrings("`backticks` work inside single quotes", env.get("BACKTICKS_INSIDE_SINGLE").?);
    try testing.expectEqualStrings("`backticks` work inside double quotes", env.get("BACKTICKS_INSIDE_DOUBLE").?);
    try testing.expectEqualStrings("backticks", env.get("BACKTICKS").?);
    try testing.expectEqualStrings("    backticks    ", env.get("BACKTICKS_SPACED").?);
    try testing.expectEqualStrings("double \"quotes\" work inside backticks", env.get("DOUBLE_QUOTES_INSIDE_BACKTICKS").?);
    try testing.expectEqualStrings("single 'quotes' work inside backticks", env.get("SINGLE_QUOTES_INSIDE_BACKTICKS").?);
    try testing.expectEqualStrings("double \"quotes\" and single 'quotes' work inside backticks", env.get("DOUBLE_AND_SINGLE_QUOTES_INSIDE_BACKTICKS").?);

    try testing.expectEqualStrings("expand\nnew\nlines", env.get("EXPAND_NEWLINES").?);
    try testing.expectEqualStrings("dontexpand\\nnew\\nline", env.get("DONT_EXPAND_DOUBLE_ESCAPE").?);
    try testing.expectEqualStrings("dontexpand\\nnewlines", env.get("DONT_EXPAND_UNQUOTED").?);
    try testing.expectEqualStrings("dontexpand\\nnewlines", env.get("DONT_EXPAND_SQUOTED").?);

    try testing.expectEqualStrings("inline comments", env.get("INLINE_COMMENTS").?);
    try testing.expectEqualStrings("inline comments outside of #singlequotes", env.get("INLINE_COMMENTS_SINGLE_QUOTES").?);
    try testing.expectEqualStrings("inline comments outside of #doublequotes", env.get("INLINE_COMMENTS_DOUBLE_QUOTES").?);
    try testing.expectEqualStrings("inline comments outside of #backticks", env.get("INLINE_COMMENTS_BACKTICKS").?);
    try testing.expectEqualStrings("inline comments start with a", env.get("INLINE_COMMENTS_SPACE").?);

    try testing.expectEqualStrings("equals==", env.get("EQUAL_SIGNS").?);
    try testing.expectEqualStrings("{\"foo\": \"bar\"}", env.get("RETAIN_INNER_QUOTES").?);
    try testing.expectEqualStrings("{\"foo\": \"bar\"}", env.get("RETAIN_INNER_QUOTES_AS_STRING").?);
    try testing.expectEqualStrings("{\"foo\": \"bar's\"}", env.get("RETAIN_INNER_QUOTES_AS_BACKTICKS").?);
    try testing.expectEqualStrings("some spaced out string", env.get("TRIM_SPACE_FROM_UNQUOTED").?);
    try testing.expectEqualStrings("therealnerdybeast@example.tld", env.get("USERNAME").?);
    try testing.expectEqualStrings("parsed", env.get("SPACED_KEY").?);
}

test "env: multiline parsing" {
    var env = try Env.loadFromPath(testing.allocator, "./src/env/multiline.env");
    defer env.deinit();

    try testing.expectEqualStrings("basic", env.get("BASIC").?);
    try testing.expectEqualStrings("after_line", env.get("AFTER_LINE").?);
    try testing.expectEqualStrings("", env.get("EMPTY").?);
    try testing.expectEqualStrings("single_quotes", env.get("SINGLE_QUOTES").?);
    try testing.expectEqualStrings("    single quotes    ", env.get("SINGLE_QUOTES_SPACED").?);
    try testing.expectEqualStrings("double_quotes", env.get("DOUBLE_QUOTES").?);
    try testing.expectEqualStrings("    double quotes    ", env.get("DOUBLE_QUOTES_SPACED").?);
    try testing.expectEqualStrings("expand\nnew\nlines", env.get("EXPAND_NEWLINES").?);
    try testing.expectEqualStrings("dontexpand\\nnewlines", env.get("DONT_EXPAND_UNQUOTED").?);
    try testing.expectEqualStrings("dontexpand\\nnewlines", env.get("DONT_EXPAND_SQUOTED").?);
    try testing.expectEqualStrings("equals==", env.get("EQUAL_SIGNS").?);
    try testing.expectEqualStrings("{\"foo\": \"bar\"}", env.get("RETAIN_INNER_QUOTES").?);
    try testing.expectEqualStrings("{\"foo\": \"bar\"}", env.get("RETAIN_INNER_QUOTES_AS_STRING").?);
    try testing.expectEqualStrings("some spaced out string", env.get("TRIM_SPACE_FROM_UNQUOTED").?);
    try testing.expectEqualStrings("therealnerdybeast@example.tld", env.get("USERNAME").?);
    try testing.expectEqualStrings("parsed", env.get("SPACED_KEY").?);

    try testing.expectEqualStrings(
        \\THIS
        \\IS
        \\A
        \\MULTILINE
        \\STRING
    , env.get("MULTI_DOUBLE_QUOTED").?);

    try testing.expectEqualStrings(
        \\THIS
        \\IS
        \\A
        \\MULTILINE
        \\STRING
    , env.get("MULTI_SINGLE_QUOTED").?);

    try testing.expectEqualStrings(
        \\THIS
        \\IS
        \\A
        \\"MULTILINE'S"
        \\STRING
    , env.get("MULTI_BACKTICKED").?);

    try testing.expectEqualStrings(env.get("MULTI_PEM_DOUBLE_QUOTED").?[0..26], "-----BEGIN PUBLIC KEY-----");
}
