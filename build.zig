const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const repl_dependency = b.dependency("repl", .{
        .target = target,
        .optimize = optimize,
    });
    const zbug_lib = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "zbug",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/zbug.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });

    exe.root_module.addImport("repl", repl_dependency.module("repl"));
    exe.root_module.addImport("zbug", zbug_lib);

    b.installArtifact(exe);
    const run_command = b.addRunArtifact(exe);
    if (b.args) |args| run_command.addArgs(args);
    const run_step = b.step("run", "Run zbug");
    run_step.dependOn(&run_command.step);
}
