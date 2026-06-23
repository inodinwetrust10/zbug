const std = @import("std");
const zbug = @import("zbug");
const process = zbug.process;
const repl = @import("repl");

pub fn main(init: std.process.Init) void {
    const allocator: std.mem.Allocator = init.gpa;

    const args: []const [:0]const u8 = init.minimal.args.toSlice(allocator) catch |err| {
        std.debug.print("Cannot allocate the slice for args: {s}\n", .{@errorName(err)});
        std.process.exit(1);
    };
    defer allocator.free(args);

    if (args.len < 2) {
        std.debug.print("Usage: zbug <program>\n", .{});
        std.process.exit(1);
    }

    const pid: std.posix.pid_t = process.Attach(args.len, args, init);

    // wait for the child process to receive the stop signal
    var wait_status: u32 = undefined;
    const result: usize = std.os.linux.waitpid(pid, &wait_status, 0);
    if (std.posix.errno(result) != .SUCCESS) {
        std.debug.print("waitpid failed\n", .{});
        std.process.exit(1);
    }

    repl.Repl.run(.{ .allocator = allocator, .prompt = "zbug>> ", .run_fn = runCommand }) catch |err| {
        std.debug.print("Error reading the user input :{any}", .{err});
    };
}
fn runCommand(
    _: ?*anyopaque,
    _: std.mem.Allocator,
    input: []const u8,
    history: *repl.HistoryStore,
) anyerror!bool {
    const effective_input = if (std.mem.eql(u8, input, "") and history.entries.items.len > 0)
        history.entries.items[history.entries.items.len - 1]
    else
        input;

    if (std.mem.eql(u8, effective_input, "quit")) {
        // history has deinit which runs automatically
        return false;
    }

    const out = repl.terminalWriter();
    try out.print("You entered: {s}\n", .{effective_input});
    return true;
}
