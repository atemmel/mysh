const std = @import("std");
const globals = @import("globals.zig");
const Tokenizer = @import("tokenizer.zig").Tokenizer;
const ast = @import("ast.zig");
const astprint = @import("astprint.zig");
const Interpreter = @import("interpreter.zig").Interpreter;

const stdin = std.io.getStdIn().reader();
const stderr = std.io.getStdErr().writer();

var ally: std.mem.Allocator = undefined;
var buffer: [2048]u8 = undefined;
var input: []const u8 = undefined;

pub fn do(the_ally: std.mem.Allocator) !u8 {
    ally = the_ally;
    var tokenizer = Tokenizer.init(ally);
    var parser = ast.Parser.init(ally);
    var interpreter = try Interpreter.init(ally);
    defer interpreter.deinit();
    //TODO: final step
    //var interpreter = Interpreter.init(ally);

    while (true) {
        try stderr.print("mysh > ", .{});
        //const count = try stdin.read(&buffer);
        //if (count == 0) {
        //break;
        //}
        //const source = buffer[0 .. count - 1];

        switch (readLine()) {
            .Ok => {},
            .Discard => {
                continue;
            },
            .Exit => {
                break;
            },
        }

        var tokens = try tokenizer.tokenize(input);
        defer ally.free(tokens);

        if (globals.verbose) {
            for (tokens) |*token| {
                token.print();
            }
        }
        var maybe_root = try parser.parse(tokens, input, "");
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
    try stderr.print("\nexit\n", .{});
    return 0;
}

const ReadResult = enum {
    Ok,
    Discard,
    Exit,
};

fn readLine() ReadResult {
    var i: usize = 0;

    while (i < buffer.len) {
        const c = stdin.readByte() catch {
            return .Exit;
        };
        stderr.print("HERE\n", .{}) catch unreachable;

        switch (c) {
            0 => {
                return .Exit;
            },
            '\t' => {
                //TODO: handle tab
            },
            8 => {
                //TODO: handle backspace
            },
            '\n' => {
                break;
            },
            else => {
                buffer[i] = c;
                i += 1;
            },
        }
    }

    input = buffer[0..i];

    return .Ok;
}
