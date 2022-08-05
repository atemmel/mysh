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
    var proc = try std.ChildProcess.init(args, ally);
    defer proc.deinit();

    var stdout_buffer = std.ArrayList(u8).init(ally);
    errdefer stdout_buffer.deinit();

    var me_read: std.os.fd_t = undefined;
    var you_write: std.os.fd_t = undefined;
    var you_read: std.os.fd_t = undefined;
    var me_write: std.os.fd_t = undefined;
    var captured_stdout: []u8 = &.{};

    // stdout prep
    if (opts.capture_stdout) {
        try stdout_buffer.ensureTotalCapacity(512);
        proc.stdout_behavior = .Pipe;
        //TODO: set fd?
        const pipe_fd = try std.os.pipe();
        me_read = pipe_fd[0];
        you_write = pipe_fd[1];
    } else {
        proc.stdout_behavior = .Ignore;
    }

    // stdin prep
    if (opts.stdin_slice != null) {
        proc.stdin_behavior = .Pipe;
        //TODO: set fd?
        const pipe_fd = try std.os.pipe();
        you_read = pipe_fd[0];
        me_write = pipe_fd[1];
    } else {
        proc.stdin_behavior = .Ignore;
    }

    try proc.spawn();

    // stdin check
    if (opts.stdin_slice) |stdin_slice| {
        std.os.close(you_read);
        _ = try std.os.write(me_write, stdin_slice);
        std.os.close(me_write);
    }

    // stdout check
    if (opts.capture_stdout) {
        //TODO: handle me_read, you_write, etc...
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

test "ls test" {
    var ally = std.testing.allocator;

    const args = [_][]const u8{
        "ls",
    };

    const opts = SpawnCommandOptions{
        .capture_stdout = true,
        .stdin_slice = null,
    };

    const result = try cmd(ally, &args, opts);
    std.debug.print("{}\n", .{result});
    if (result.stdout) |stdout| {
        ally.free(stdout);
    }
}
