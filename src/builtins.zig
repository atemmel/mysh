const std = @import("std");
const Token = @import("token.zig").Token;
const Interpreter = @import("interpreter.zig").Interpreter;
const Value = @import("value.zig").Value;
const ValueArray = @import("value.zig").ValueArray;

const assert = std.debug.assert;

pub const Signature = fn (interp: *Interpreter, args: []Value, token: *const Token) anyerror!?Value;

pub fn print(interp: *Interpreter, args: []Value, token: *const Token) !?Value {
    if (interp.is_piping) {
        var buffer = try std.ArrayList(u8).initCapacity(interp.ally, 64);
        defer buffer.deinit();
        try printWithWriter(buffer.writer(), args);
        //TODO: this copy is not needed
        return try Value.init(interp.ally, buffer, token);
    }

    const stdout = std.io.getStdOut().writer();
    try printWithWriter(stdout, args);
    return null;
}

fn printWithWriter(writer: anytype, args: []Value) @TypeOf(writer).Error!void {
    for (args) |*arg, idx| {
        try writer.print("{}", .{arg.*});
        if (idx != args.len - 1) {
            try writer.writeByte(' ');
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
                        return;
                    }
                }
            },
            else => {},
        }
    }
    try writer.writeByte('\n');
}

pub fn append(interp: *Interpreter, args: []const Value, token: *const Token) !?Value {
    //TODO: proper error
    assert(args.len >= 2);
    try interp.assertExpectedType(&args[0], .array, interp.calling_token);

    const original_array = &args[0].holder.inner.array;
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

    //TODO: prevent copy here
    return try Value.initArray(interp.ally, modified_array, token);
}

pub fn filter(interp: *Interpreter, args: []Value, token: *const Token) !?Value {
    //TODO: proper error handling
    assert(args.len == 2);
    try interp.assertExpectedType(&args[0], .array, interp.calling_token);
    //TODO: this should be some sort of function/lambda type
    try interp.assertExpectedType(&args[1], .string, interp.calling_token);

    const original_array = &args[0].holder.inner.array;
    const fn_name = args[1].holder.inner.string;
    var modified_array = try ValueArray.initCapacity(interp.ally, original_array.items.len / 2);

    for (original_array.items) |*element| {
        const fn_args: []Value = &[_]Value{element.*};
        const fn_result = try interp.executeFunction(fn_name, fn_args, false, true, token);
        assert(fn_result != null);
        assert(fn_result.?.getKind() == .boolean);

        if (fn_result.?.holder.inner.boolean) {
            try modified_array.append(try element.clone(interp.ally));
        }
    }

    //TODO: prevent copy here
    return try Value.initArray(interp.ally, modified_array, token);
}

pub fn len(interp: *Interpreter, args: []Value, token: *const Token) !?Value {
    _ = interp;
    assert(args.len >= 1);

    var length_sum: i64 = 0;

    for (args) |*arg| {
        switch (arg.inner) {
            .boolean, .integer => {
                assert(false);
            },
            .string => |string| {
                length_sum += @intCast(i64, string.len);
            },
            .array => |*array| {
                length_sum += @intCast(i64, array.items.len);
            },
            .table => |*table| {
                length_sum += @intCast(i64, table.count());
            },
        }
    }

    return try Value.init(interp.ally, length_sum, token);
}
