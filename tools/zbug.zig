const std = @import("std");

const process = @import("../src/process.zig");

fn main(init: std.process.Init) void {
    // juicy main introduced in 0.16 provides the main function with basic io,a gpa,args ,environment variables etc
    const allocator: std.mem.Allocator = init.gpa;
    const args: []const [:0]const u8 = init.minimal.args.toSlice(allocator);

    if (args.len == 1) {
        std.debug.print("No file to debug", .{});
    }

    var pid: std.posix.pid_t = process.Attach(args.len, args, init.io);
}
