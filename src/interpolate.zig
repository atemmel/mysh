const std = @import("std");
const SymTable = @import("symtable.zig").SymTable;
const Value = @import("symtable.zig").Value;

const InterpolationError = error{
    SymbolNotFound,
    EndBraceNotFound,
    EmptySymbol,
} || std.mem.Allocator.Error;

pub fn maybe(ally: std.mem.Allocator, str: []const u8, sym_table: *const SymTable) InterpolationError!?[]const u8 {
    var buffer = std.ArrayList(u8).init(ally);
    errdefer buffer.deinit();
    var i: usize = 0;
    var prev_i = i;
    var writer = buffer.writer();

    while (i < str.len) : (i += 1) {
        const c = str[i];
        switch (c) {
            '{' => {
                // found lbrace
                try buffer.appendSlice(str[prev_i..i]);
                if (i + 1 < str.len and str[i + 1] == '{') {
                    // escaped lbrace, skip ahead
                    try buffer.append('{');
                    i += 1;
                    prev_i = i + 1;
                } else {
                    // to be interpolated
                    if (std.mem.indexOfScalarPos(u8, str, i + 1, '}')) |rbrace_idx| {
                        // found right brace
                        const name = str[i + 1 .. rbrace_idx];

                        if (name.len == 0) {
                            //TODO: this is an error, empty interpolation attempt
                            return InterpolationError.EmptySymbol;
                        }

                        if (sym_table.get(name)) |value| {
                            // found symbol in table
                            try writer.print("{}", .{value});
                            i = rbrace_idx;
                            prev_i = i + 1;
                        } else {
                            //TODO: this is an error, could not find symbol
                            return InterpolationError.SymbolNotFound;
                        }
                    } else {
                        //TODO: this is an error, could not find ending brace
                        return InterpolationError.EndBraceNotFound;
                    }
                }
            },
            '}' => {
                // found rbrace
                if (i + 1 < str.len and str[i + 1] == '}') {
                    // escaped rbrace, skip ahead
                    try buffer.appendSlice(str[prev_i..i]);
                    try buffer.append('}');
                    i += 1;
                    prev_i = i + 1;
                } else {
                    // should never reach unescaped braces (handled by '{' in switch)
                    unreachable;
                }
            },
            '$' => {
                // found dollar
                try buffer.appendSlice(str[prev_i..i]);
                if (i + 1 < str.len and str[i + 1] == '$') {
                    // escaped dollar, skip ahead
                    try buffer.append('$');
                    i += 1;
                    prev_i = i + 1;
                } else {
                    // to be interpolated
                    const find_these: []const u8 = "${} ";
                    const end = std.mem.indexOfAnyPos(u8, str, i + 1, find_these) orelse str.len;
                    const name = str[i + 1 .. end];

                    if (name.len == 0) {
                        //TODO: this is an error, empty interpolation attempt
                        return InterpolationError.EmptySymbol;
                    }

                    if (sym_table.get(name)) |value| {
                        try writer.print("{}", .{value});
                        i = end - 1;
                        prev_i = end;
                    } else {

                        //TODO: this is an error, could not find symbol
                        return InterpolationError.SymbolNotFound;
                    }
                }
            },
            else => {},
        }
    }

    if (buffer.items.len == 0) {
        // nothing was escaped
        return null;
    }

    try buffer.appendSlice(str[prev_i..]);
    return buffer.toOwnedSlice();
}

const expectEqual = std.testing.expectEqual;
const expectEqualSlices = std.testing.expectEqualSlices;
const expectError = std.testing.expectError;

fn makeSymTable(ally: std.mem.Allocator, comptime pairs: anytype) !SymTable {
    var sym_table = SymTable.init(ally);
    try sym_table.addScope();

    inline for (pairs) |pair| {
        const name = pair[0];
        const value = &pair[1];
        try sym_table.put(name, value);
    }

    return sym_table;
}

test "interpolation fail: no interpolation" {
    var ally = std.testing.allocator;
    var sym_table = try makeSymTable(ally, .{});
    defer sym_table.deinit();
    const result = try maybe(ally, "hello", &sym_table);
    try expectEqual(@as(?[]const u8, null), result);
}

test "interpolation success: braces" {
    var ally = std.testing.allocator;
    var sym_table = try makeSymTable(ally, .{
        .{ "my_var", Value{ .inner = .{ .integer = 42 } } },
        .{ "type", Value{ .inner = .{ .string = "Camel" }, .may_free = false } },
    });
    defer sym_table.deinit();

    const life_output: []const u8 = "the meaning of life is 42";

    var life_result = (try maybe(
        ally,
        "the meaning of life is {my_var}",
        &sym_table,
    )).?;
    defer ally.free(life_result);

    try expectEqualSlices(u8, life_output, life_result);

    {
        const case_output: []const u8 = "Camelcase";
        const case_result = (try maybe(ally, "{type}case", &sym_table)).?;
        defer ally.free(case_result);

        try expectEqualSlices(u8, case_output, case_result);
    }

    {
        const case_output: []const u8 = "Camel case";
        const case_result = (try maybe(ally, "{type} case", &sym_table)).?;
        defer ally.free(case_result);

        try expectEqualSlices(u8, case_output, case_result);
    }

    {
        const case_output: []const u8 = "caseCamel";
        const case_result = (try maybe(ally, "case{type}", &sym_table)).?;
        defer ally.free(case_result);

        try expectEqualSlices(u8, case_output, case_result);
    }

    {
        const case_output: []const u8 = "{Camel}case";
        const case_result = (try maybe(ally, "{{{type}}}case", &sym_table)).?;
        defer ally.free(case_result);

        try expectEqualSlices(u8, case_output, case_result);
    }

    {
        const case_output: []const u8 = "case{Camel}";
        const case_result = (try maybe(ally, "case{{{type}}}", &sym_table)).?;
        defer ally.free(case_result);

        try expectEqualSlices(u8, case_output, case_result);
    }

    {
        const case_output: []const u8 = "case{Camel}case";
        const case_result = (try maybe(ally, "case{{{type}}}case", &sym_table)).?;
        defer ally.free(case_result);

        try expectEqualSlices(u8, case_output, case_result);
    }
}

test "interpolation sucess: dollar" {
    var ally = std.testing.allocator;
    var sym_table = try makeSymTable(ally, .{
        .{ "name", Value{ .inner = .{ .string = "James" }, .may_free = false } },
        .{ "surname", Value{ .inner = .{ .string = "Bond" }, .may_free = false } },
        .{ "a", Value{ .inner = .{ .string = "tic" }, .may_free = false } },
        .{ "b", Value{ .inner = .{ .string = "tac" }, .may_free = false } },
        .{ "c", Value{ .inner = .{ .string = "toe" }, .may_free = false } },
    });
    defer sym_table.deinit();

    {
        const expected: []const u8 = "James";
        const output = (try maybe(ally, "$name", &sym_table)).?;
        defer ally.free(output);
        try expectEqualSlices(u8, expected, output);
    }

    {
        const expected: []const u8 = "James The Guy";
        const output = (try maybe(ally, "$name The Guy", &sym_table)).?;
        defer ally.free(output);
        try expectEqualSlices(u8, expected, output);
    }

    {
        const expected: []const u8 = "Little James";
        const output = (try maybe(ally, "Little $name", &sym_table)).?;
        defer ally.free(output);
        try expectEqualSlices(u8, expected, output);
    }

    {
        const expected: []const u8 = "James Bond";
        const output = (try maybe(ally, "$name $surname", &sym_table)).?;
        defer ally.free(output);
        try expectEqualSlices(u8, expected, output);
    }

    {
        const expected: []const u8 = "tictactoe";
        const output = (try maybe(ally, "$a$b$c", &sym_table)).?;
        defer ally.free(output);
        try expectEqualSlices(u8, expected, output);
    }
}

test "interpolation error: braces" {
    var ally = std.testing.allocator;
    var sym_table = try makeSymTable(ally, .{});
    defer sym_table.deinit();

    {
        const expected = InterpolationError.SymbolNotFound;
        const output = maybe(ally, "{xyz}", &sym_table);
        try expectError(expected, output);
    }

    {
        const expected = InterpolationError.EndBraceNotFound;
        const output = maybe(ally, "{", &sym_table);
        try expectError(expected, output);
    }

    {
        const expected = InterpolationError.EndBraceNotFound;
        const output = maybe(ally, "{xyz", &sym_table);
        try expectError(expected, output);
    }

    {
        const expected = InterpolationError.EmptySymbol;
        const output = maybe(ally, "{}", &sym_table);
        try expectError(expected, output);
    }
}

test "interpolation error: dollar" {
    var ally = std.testing.allocator;
    var sym_table = try makeSymTable(ally, .{});
    defer sym_table.deinit();

    {
        const expected = InterpolationError.SymbolNotFound;
        const output = maybe(ally, "$xyz", &sym_table);
        try expectError(expected, output);
    }

    {
        const expected = InterpolationError.EmptySymbol;
        const output = maybe(ally, "$ hello", &sym_table);
        try expectError(expected, output);
    }
}
