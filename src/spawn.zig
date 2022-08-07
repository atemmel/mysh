const std = @import("std");

pub const SpawnCommandOptions = struct {
    capture_stdout: bool = false,
    stdin_slice: ?[]const u8 = null,
};

pub const SpawnCommandOutput = struct {
    term: std.ChildProcess.Term = undefined,
    stdout: ?[]u8 = undefined,
};

pub fn cmd(ally: std.mem.Allocator, args: []const []const u8, opts: SpawnCommandOptions) !SpawnCommandOutput {
    var proc = std.ChildProcess.init(args, ally);

    var captured_stdout: []u8 = &.{};
    errdefer ally.free(captured_stdout);

    // stdout prep
    if (opts.capture_stdout) {
        proc.stdout_behavior = .Pipe;
    } else {
        proc.stdout_behavior = .Ignore;
    }

    // stdin prep
    if (opts.stdin_slice != null) {
        proc.stdin_behavior = .Pipe;
    } else {
        proc.stdin_behavior = .Ignore;
    }

    try proc.spawn();

    // stdin check
    if (opts.stdin_slice) |stdin_slice| {
        try proc.stdin.?.writer().writeAll(stdin_slice);
        proc.stdin.?.close();
        proc.stdin = null;
    }

    // stdout check
    if (opts.capture_stdout) {
        captured_stdout = try proc.stdout.?.reader().readAllAlloc(ally, 50 * 1024 * 1024);
    }

    // wait
    const term = try proc.wait();

    if (captured_stdout.len > 0) {
        return SpawnCommandOutput{
            .term = term,
            .stdout = captured_stdout,
        };
    }

    return SpawnCommandOutput{
        .term = term,
        .stdout = null,
    };
}

test "stdout capture test" {
    const Term = std.ChildProcess.Term;
    var ally = std.testing.allocator;

    const args = [_][]const u8{
        "echo",
        "test",
    };

    const opts = SpawnCommandOptions{
        .capture_stdout = true,
        .stdin_slice = null,
    };

    const expected_term = Term{ .Exited = 0 };
    const expected_stdout = "test\n";

    const result = try cmd(ally, &args, opts);
    defer {
        if (result.stdout) |stdout| {
            ally.free(stdout);
        }
    }

    try std.testing.expectEqual(result.term, expected_term);
    try std.testing.expect(result.stdout != null);
    try std.testing.expectEqualSlices(u8, result.stdout.?, expected_stdout);
}

test "stdin input test" {
    const Term = std.ChildProcess.Term;
    var ally = std.testing.allocator;

    const args = [_][]const u8{
        "wc",
        "-w",
    };

    const opts = SpawnCommandOptions{
        .capture_stdout = true,
        .stdin_slice = "a b c d e",
    };

    const expected_term = Term{ .Exited = 0 };
    const expected_stdout = "5\n";

    const result = try cmd(ally, &args, opts);
    defer {
        if (result.stdout) |stdout| {
            ally.free(stdout);
        }
    }

    try std.testing.expectEqual(result.term, expected_term);
    try std.testing.expect(result.stdout != null);
    try std.testing.expectEqualSlices(u8, result.stdout.?, expected_stdout);
}
