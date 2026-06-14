const std = @import("std");

const argsEnv = struct {
    args: [*:null]const ?[*:0]const u8,
    env: [*:null]const ?[*:0]const u8,
};

fn buildArgsandEnv(init: std.process.Init) argsEnv {
    const gpa: std.mem.Allocator = init.gpa;
}

pub fn Attach(len: usize, args: []const [:0]const u8, io: std.process.Init.io) std.posix.pid_t {
    var pid: std.posix.pid_t = 0;
    //attaching to a process using process_id(pid)
    if (len == 3 and std.mem.eql(u8, args[1], "-p")) {
        pid = std.fmt.parseInt(std.posix.pid_t, args[2], 10) catch |err| {
            std.debug.print("Error parsing the process_id(Make sure it is an integer): {s}", .{err});
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
            var buff: [std.fs.max_path_bytes]u8 = undefined;
            _ = std.Io.Dir.cwd().realPath(fileName, io, &buff) catch |err| {
                std.debug.print("Could not resolve the path for the file : {s}", .{err});
                std.os.linux.exit(1);
            };
            // now convert the args and env into null terminated array of pointers to null terminated strings

            result = std.os.linux.execve(buff, null, null);
        }
    }
    return pid;
}
