const std = @import("std");
const globals = @import("globals.zig");
const Tokenizer = @import("tokenizer.zig").Tokenizer;
const ast = @import("ast.zig");
const astprint = @import("astprint.zig");
const Interpreter = @import("interpreter.zig").Interpreter;

const mibu = @import("mibu");
const events = mibu.events;
const term = mibu.term;

const stdin = std.io.getStdIn();
const stderr_writer = std.io.getStdErr().writer();

var ally: std.mem.Allocator = undefined;
var input: std.ArrayList(u8) = undefined;

pub fn do(the_ally: std.mem.Allocator) !u8 {
    ally = the_ally;
    input = try std.ArrayList(u8).initCapacity(ally, 128);
    defer input.deinit();
    var tokenizer = Tokenizer.init(ally);
    var parser = ast.Parser.init(ally);
    var interpreter = try Interpreter.init(ally);
    defer interpreter.deinit();

    while (true) {
        try stderr_writer.print("mysh > ", .{});
        //const count = try stdin.read(&buffer);
        //if (count == 0) {
        //break;
        //}
        //const source = buffer[0 .. count - 1];

        switch (try readLine()) {
            .Ok => {},
            .Discard => {
                try stderr_writer.writeByte('\n');
                continue;
            },
            .Exit => {
                break;
            },
        }
        try stderr_writer.writeByte('\n');

        var tokens = try tokenizer.tokenize(input.items);
        defer ally.free(tokens);

        if (globals.verbose) {
            for (tokens) |*token| {
                token.print();
            }
        }
        var maybe_root = try parser.parse(tokens, input.items, "");
        if (maybe_root == null) {
            if (parser.encounteredError()) {
                parser.dumpError();
            }
            continue;
        }

        var root = maybe_root.?;
        defer root.deinit();

        if (globals.verbose) {
            astprint.print(&root);
        }

        interpreter.interpret(&root) catch {
            interpreter.reportError();
        };
    }
    try stderr_writer.print("\nexit\n", .{});
    return 0;
}

const ReadResult = enum {
    Ok,
    Discard,
    Exit,
};

fn readLine() !ReadResult {
    input.clearRetainingCapacity();

    var raw_term = try term.enableRawMode(stdin.handle, .blocking);
    defer raw_term.disableRawMode() catch {};

    while (true) {
        const event = try events.next(stdin);
        //try stderr_writer.print("event: {s}\n\r", .{event});
        switch (event) {
            .key => |k| switch (k) {
                .char => |c| {
                    try addch(@intCast(u8, c & 0xff));
                    if (c > 0xff) {
                        try addch(@intCast(u8, c & 0xff00));
                    }
                    if (c > 0xff00) {
                        try addch(@intCast(u8, c & 0x1f0000));
                    }
                },
                .ctrl => |c| switch (c) {
                    'd' => return .Exit,
                    else => {},
                },
                .enter => break,
                .up => {},
                .down => {},
                .left => {},
                .right => {},
                else => {},
            },
            .none => return .Exit,
            else => {},
        }
    }

    return .Ok;
}

fn addch(char: u8) !void {
    try stderr_writer.writeByte(char);
    try input.append(char);
}
