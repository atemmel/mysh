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
        const count = try stdin.read(&buffer);
        if (count == 0) {
            break;
        }
        const source = buffer[0 .. count - 1];
        var tokens = try tokenizer.tokenize(source);
        defer ally.free(tokens);

        if (globals.verbose) {
            for (tokens) |*token| {
                token.print();
            }
        }
        var maybe_root = try parser.parse(tokens, source, "");
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
