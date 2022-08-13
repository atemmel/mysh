const std = @import("std");

const EscapeError = error{
    InvalidEscape,
    NoEscape,
} || std.mem.Allocator.Error;

pub fn maybe(ally: std.mem.Allocator, str: []const u8) EscapeError!?[]const u8 {
    var buffer = std.ArrayList(u8).init(ally);
    errdefer buffer.deinit();
    var i: usize = 0;
    var prev_i = i;
    while (i < str.len) : (i += 1) {
        if (str[i] == '\\') {
            if (i + 1 >= str.len) {
                return EscapeError.NoEscape;
            }

            try buffer.appendSlice(str[prev_i..i]);
            const next = str[i + 1];
            switch (next) {
                '\\' => {
                    try buffer.append('\\');
                },
                'n' => {
                    try buffer.append('\n');
                },
                't' => {
                    try buffer.append('\t');
                },
                else => {
                    return EscapeError.InvalidEscape;
                },
            }
            i += 1;
            prev_i = i + 1;
        }
    }

    if (buffer.items.len == 0) {
        return null;
    }

    try buffer.appendSlice(str[prev_i..]);
    return buffer.toOwnedSlice();
}

test "escape failure" {
    const expect = std.testing.expect;
    var ally = std.testing.allocator;
    var result = try maybe(ally, "abc");
    try expect(result == null);
}

test "escape success" {
    const expectEqualSlices = std.testing.expectEqualSlices;
    var ally = std.testing.allocator;

    {
        var output = (try maybe(ally, "\\n")).?;
        defer ally.free(output);
        try expectEqualSlices(u8, "\n", output);
    }

    {
        var output = (try maybe(ally, "hello\\n")).?;
        defer ally.free(output);
        try expectEqualSlices(u8, "hello\n", output);
    }

    {
        var output = (try maybe(ally, "\\nhello")).?;
        defer ally.free(output);
        try expectEqualSlices(u8, "\nhello", output);
    }

    {
        var output = (try maybe(ally, "hello\\nworld")).?;
        defer ally.free(output);
        try expectEqualSlices(u8, "hello\nworld", output);
    }
}

test "escape error" {
    const expectError = std.testing.expectError;
    var ally = std.testing.allocator;

    {
        var err = maybe(ally, "\\");
        try expectError(EscapeError.NoEscape, err);
    }

    {
        var err = maybe(ally, "\\+");
        try expectError(EscapeError.InvalidEscape, err);
    }
}
