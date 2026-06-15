const std = @import("std");

const ExecveParams = struct {
    argv: [*:null]const ?[*:0]const u8,
    envp: [*:null]const ?[*:0]const u8,

    argv_strings: []const [:0]const u8,
    argv_storage: [:null]?[*:0]const u8,

    pub fn deinit(self: *const @This(), allocator: std.mem.Allocator) void {
        allocator.free(self.argv_storage);
        allocator.free(self.argv_strings);
    }
};

fn buildArgsAndEnv(init: std.process.Init) !ExecveParams {
    const allocator = init.gpa;

    const argv_strings = try init.minimal.args.toSlice(allocator);

    const argv_storage = try allocator.allocSentinel(
        ?[*:0]const u8,
        argv_strings.len,
        null,
    );

    for (argv_strings, 0..) |arg, i| {
        argv_storage[i] = arg.ptr;
    }

    return .{
        .argv = argv_storage.ptr,
        .envp = init.minimal.environ.block.slice.ptr,

        .argv_strings = argv_strings,
        .argv_storage = argv_storage,
    };
}

pub fn Attach(len: usize, args: []const [:0]const u8, init: std.process.Init) std.posix.pid_t {
    var pid: std.posix.pid_t = 0;
    //attaching to a process using process_id(pid)
    if (len == 3 and std.mem.eql(u8, args[1], "-p")) {
        pid = std.fmt.parseInt(std.posix.pid_t, args[2], 10) catch |err| {
            std.debug.print("Error parsing the process_id(Make sure it is an integer): {}", .{err});
            return -1;
        };
        const result = std.os.linux.ptrace(std.os.linux.PTRACE.ATTACH, pid, 0, 0, 0);
        if (std.posix.errno(result) != .SUCCESS) {
            std.debug.print("Could not attach ", .{});
            return -1;
        }
    } else {
        const fileName: [:0]const u8 = args[1];

        var result: usize = std.os.linux.fork();

        if (std.posix.errno(result) != .SUCCESS) {
            std.debug.print("Failed to fork the process ", .{});
            return -1;
        }
        pid = @intCast(result);

        if (pid == 0) {
            // child process
            result = std.os.linux.ptrace(std.os.linux.PTRACE.TRACEME, 0, 0, 0, 0);
            // error checking(only for syscalls / C interlop)
            if (std.posix.errno(result) != .SUCCESS) {
                std.debug.print("Tracing failed ", .{});
                std.os.linux.exit(1); // we dont want to return anything from child process...we must exit
            }
            var buff: [std.fs.max_path_bytes + 1]u8 = undefined;
            const resolvedLength = std.Io.Dir.cwd().realPath(fileName, init.io, &buff) catch |err| {
                std.debug.print("Could not resolve the path for the file : {}", .{err});
                std.os.linux.exit(1);
            };
            // resolvedLength is the number of bytes written into the buff and the index will be the first empty space
            buff[resolvedLength] = 0;
            const path: [:0]const u8 = buff[0..resolvedLength :0];
            var args_env = buildArgsAndEnv(init) catch |err| {
                std.debug.print("failed : {}\n", .{err});
                std.os.linux.exit(1);
            };
            defer args_env.deinit(init.gpa);

            result = std.os.linux.execve(
                path.ptr,
                args_env.argv,
                args_env.envp,
            );
            const err = std.posix.errno(result);
            switch (err) {
                .NOENT => std.debug.print("Executable not found\n", .{}),
                .ACCES => std.debug.print("Permission denied\n", .{}),
                .NOEXEC => std.debug.print("Invalid executable format\n", .{}),
                else => std.debug.print("execve failed: {}\n", .{err}),
            }
            std.os.linux.exit(1);
        }
    }
    return pid;
}
