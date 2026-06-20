const std = @import("std");
const zbug = @import("zbug");
const process = zbug.process;

pub fn main(init: std.process.Init) void {
    const allocator: std.mem.Allocator = init.gpa;

    const args: []const [:0]const u8 = init.minimal.args.toSlice(allocator) catch |err| {
        std.debug.print("Cannot allocate the slice for args: {s}\n", .{@errorName(err)});
        std.process.exit(1);
    };

    if (args.len < 2) {
        std.debug.print("Usage: zbug <program>\n", .{});
        std.process.exit(1);
    }

    const pid: std.posix.pid_t = process.Attach(args.len, args, init);

    var wait_status: u32 = undefined;
    const result: usize = std.os.linux.waitpid(pid, &wait_status, 0);
    if (std.posix.errno(result) != .SUCCESS) {
        std.debug.print("waitpid failed\n", .{});
        std.process.exit(1);
    }
}
