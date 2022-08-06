const std = @import("std");
const Interpreter = @import("interpreter.zig").Interpreter;
const Value = @import("symtable.zig").Value;
const ValueArray = @import("symtable.zig").ValueArray;

const assert = std.debug.assert;

pub const Signature = fn (interp: *Interpreter, args: []const Value) anyerror!?Value;

pub fn print(interp: *Interpreter, args: []const Value) !?Value {
    const stdout = std.io.getStdOut().writer();

    _ = interp;
    for (args) |*arg, idx| {
        try stdout.print("{}", .{arg.*});
        if (idx != args.len - 1) {
            try stdout.print(" ", .{});
        }
    }

    // trailing newline check
    if (args.len > 0) {
        const last_arg = args[args.len - 1];
        switch (last_arg.inner) {
            .string => |string| {
                if (string.len > 0) {
                    const last_byte = string[string.len - 1];
                    if (last_byte == '\n') {
                        return null;
                    }
                }
            },
            else => {},
        }
    }
    try stdout.print("\n", .{});
    return null;
}

pub fn append(interp: *Interpreter, args: []const Value) !?Value {
    assert(args.len >= 2);
    assert(@as(Value.Kind, args[0].inner) == .array);

    var original_array = &args[0].inner.array;
    const total_new_length = original_array.items.len + args.len - 1;
    var modified_array = try ValueArray.initCapacity(interp.ally, total_new_length);

    // clone prior members
    for (original_array.items) |*element| {
        try modified_array.append(try element.clone(interp.ally));
    }

    // append args
    var idx: usize = 1;
    while (idx < args.len) : (idx += 1) {
        const element = &args[idx];
        try modified_array.append(try element.clone(interp.ally));
    }
    return Value{
        .inner = .{
            .array = modified_array,
        },
    };
}
