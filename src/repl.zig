const std = @import("std");
const globals = @import("globals.zig");
const Tokenizer = @import("tokenizer.zig").Tokenizer;
const ast = @import("ast.zig");
const astprint = @import("astprint.zig");
const Interpreter = @import("interpreter.zig").Interpreter;

const mibu = @import("mibu");
const events = mibu.events;
const term = mibu.term;
const clear = mibu.clear;
const cursor = mibu.cursor;

const stdin = std.io.getStdIn();
const stderr_writer = std.io.getStdErr().writer();
const stdout_writer = std.io.getStdOut().writer();

var ally: std.mem.Allocator = undefined;
var input: std.ArrayList(u8) = undefined;
var input_needle: usize = 0;

const prompt_str = "mysh > ";

pub fn do(the_ally: std.mem.Allocator) !u8 {
    ally = the_ally;
    input = try std.ArrayList(u8).initCapacity(ally, 128);
    defer input.deinit();
    var tokenizer = Tokenizer.init(ally);
    var parser = ast.Parser.init(ally);
    var interpreter = try Interpreter.init(ally);
    defer interpreter.deinit();

    var result = ReadResult.Parse;

    while (true) {
        if (result == .Parse) {
            try printPrompt(false);
        }
        //try stdout_writer.print("{s}", .{prompt_str});

        result = try readLine();
        switch (result) {
            .Parse => {},
            .Ignore => {
                //try stdout_writer.writeByte('\n');
                continue;
            },
            .NoDrawPrompt => {
                continue;
            },
            .Exit => {
                break;
            },
        }
        try stdout_writer.writeByte('\n');

        defer input.clearRetainingCapacity();

        var tokens = try tokenizer.tokenize(input.items);
        defer ally.free(tokens);

        if (globals.verbose) {
            for (tokens) |*token| {
                try stderr_writer.print("{}\n", .{token});
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
        input.clearRetainingCapacity();
    }
    try stderr_writer.print("\nexit\n", .{});
    return 0;
}

const ReadResult = enum {
    Parse,
    Ignore,
    NoDrawPrompt,
    Exit,
};

fn readLine() !ReadResult {
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
                    'l' => {
                        try clearScreen();
                        return .NoDrawPrompt;
                    },
                    'u' => {
                        try clearFromCursorToBeginning();
                        try printPrompt(true);
                        return .Ignore;
                    },
                    else => {},
                },
                .enter => {
                    input_needle = 0;
                    return .Parse;
                },
                .delete => {
                    try deleteCharAtNeedle();
                },
                .up => {},
                .down => {},
                .left => {
                    if (input_needle > 0) {
                        input_needle -= 1;
                        try cursor.goLeft(stdout_writer, 1);
                    }
                },
                .right => {
                    if (input_needle < input.items.len) {
                        input_needle += 1;
                        try cursor.goRight(stdout_writer, 1);
                    }
                },
                else => {},
            },
            else => {},
        }
    }

    unreachable;
}

fn addch(char: u8) !void {
    try stdout_writer.writeByte(char);
    try input.append(char);
    input_needle += 1;
}

fn deleteCharAtNeedle() !void {
    if (input_needle == 0) {
        return;
    }

    input_needle -= 1;
    try clear.entire_line(stdout_writer);
    _ = input.orderedRemove(input_needle);
    const steps = prompt_str.len + input_needle;
    try cursor.goLeft(stdout_writer, steps + 1);
    try printPrompt(true);
    const back_steps = prompt_str.len + input.items.len + 1;
    try cursor.goLeft(stdout_writer, back_steps);
    try cursor.goRight(stdout_writer, steps);
}

fn clearFromCursorToBeginning() !void {
    //try clear.line_to_cursor(stdout_writer);
    //try clear.line_from_cursor(stdout_writer);
    try clear.entire_line(stdout_writer);
    const steps = prompt_str.len + input_needle;
    try cursor.goLeft(stdout_writer, steps);
    const slice = input.items[input_needle..];
    const new_len = input.items.len - input_needle;
    input_needle = 0;
    try input.replaceRange(0, new_len, slice);
    input.shrinkRetainingCapacity(new_len);
}

fn printPrompt(andContents: bool) !void {
    try stdout_writer.print("{s}", .{prompt_str});
    if (andContents) {
        try stdout_writer.print("{s}", .{input.items});
    }
}

fn clearScreen() !void {
    try clear.screenToCursor(stdout_writer);
    try cursor.goTo(stdout_writer, 0, 0);
    try printPrompt(true);
}
