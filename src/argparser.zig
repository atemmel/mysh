const std = @import("std");

pub const ArgParser = struct {
    pub fn init(ally: std.mem.Allocator, flags: []const Flag) ArgParser {
        return .{
            .flags = flags,
            .other_args = std.ArrayList([]const u8).init(ally),
        };
    }

    pub fn boolean(ptr: *bool, name: []const u8, help: []const u8) Flag {
        return Flag.init(.Boolean, @ptrCast(*anyopaque, ptr), name, help);
    }

    pub fn parse(self: *ArgParser, args: [][]const u8) ![][]const u8 {
        try self.checkHelp(args);

        var i: usize = 1;
        while (i < args.len) : (i += 1) {
            const find = self.flagIndex(args[i]);
            if (find) |index| {
                self.handleFlag(index);
            } else {
                try self.other_args.append(args[i]);
            }
        }

        return self.other_args.toOwnedSlice();
    }

    fn flagIndex(self: *ArgParser, arg: []const u8) ?usize {
        var i: usize = 1;
        while (i < self.flags.len) : (i += 1) {
            const flag = self.flags[i];
            if (std.mem.eql(u8, flag.flag_name, arg)) {
                return i;
            }
        }
        return null;
    }

    fn handleFlag(self: *ArgParser, index: usize) void {
        var flag = &self.flags[index];

        switch (flag.kind) {
            .Boolean => {
                var ptr = @ptrCast(*bool, flag.ptr);
                ptr.* = true;
            },
        }
    }

    fn checkHelp(self: *ArgParser, args: [][]const u8) !void {
        const helps = [_][]const u8{
            "--help",
            "-help",
            "help",
            "-h",
        };

        var i: usize = 1;
        while (i < args.len) : (i += 1) {
            for (helps) |help| {
                if (std.mem.eql(u8, args[i], help)) {
                    try self.printHelp(args);
                    std.os.exit(0);
                }
            }
        }
    }

    fn printHelp(self: *ArgParser, args: [][]const u8) !void {
        const exe_name = args[0];
        const stdout = std.io.getStdOut().writer();
        try stdout.print("{s} usage:\n", .{exe_name});
        for (self.flags) |flag| {
            try stdout.print("  {s}", .{flag.flag_name});
            switch (flag.kind) {
                .Boolean => try stdout.print(": bool", .{}),
            }

            try stdout.print("  {s}\n", .{flag.help_text});
        }
    }

    pub const Flag = struct {
        fn init(kind: Kind, ptr: *anyopaque, name: []const u8, help: []const u8) Flag {
            return .{
                .kind = kind,
                .ptr = @ptrCast(*anyopaque, ptr),
                .flag_name = name,
                .help_text = help,
            };
        }

        const Kind = enum {
            Boolean,
        };
        kind: Kind,
        ptr: *anyopaque,
        flag_name: []const u8,
        help_text: []const u8,
    };

    flags: []const Flag = undefined,
    other_args: std.ArrayList([]const u8) = undefined,
};
