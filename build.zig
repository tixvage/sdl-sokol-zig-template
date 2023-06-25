const std = @import("std");
const sokol = @import("libs/sokol-zig/build.zig");
const zstbi = @import("libs/zstbi/build.zig");
const zsdl = @import("libs/zsdl/build.zig");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zstbi_pkg = zstbi.package(b, target, optimize, .{});
    const sokol_pkg = sokol.package(b, target, optimize, .{ .backend = .gl });
    const zsdl_pkg = zsdl.package(b, target, optimize, .{});

    const exe = b.addExecutable(.{
        .name = "template",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(exe);

    zstbi_pkg.link(exe);
    sokol_pkg.link(exe);
    zsdl_pkg.link(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
