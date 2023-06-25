const std = @import("std");
const builtin = @import("builtin");
const Builder = std.build.Builder;
const LibExeObjStep = std.build.LibExeObjStep;
const CrossTarget = std.zig.CrossTarget;
const Mode = std.builtin.Mode;

pub const Package = struct {
    sokol: *std.Build.Module,
    sokol_c: *std.Build.CompileStep,

    pub fn link(pkg: Package, exe: *std.Build.CompileStep) void {
        exe.linkLibrary(pkg.sokol_c);
        exe.addModule("sokol", pkg.sokol);
    }
};

pub fn package(
    b: *std.Build,
    target: std.zig.CrossTarget,
    mode: std.builtin.Mode,
    config: Config,
) Package {
    const sokol = b.createModule(.{ .source_file = .{ .path = thisDir() ++ "/src/sokol/sokol.zig" } });
    const lib = b.addStaticLibrary(.{
        .name = "sokol",
        .target = target,
        .optimize = mode,
    });

    const sokol_path = thisDir() ++ "/src/sokol/c/";
    const csources = [_][]const u8{
        "sokol.c",
        //    "sokol_log.c",
        //    "sokol_app.c",
        //    "sokol_gfx.c",
        //    "sokol_time.c",
        //    "sokol_audio.c",
        //    "sokol_gl.c",
        //    "sokol_debugtext.c",
        //    "sokol_shape.c",
        //    "sokol_gp.c",
    };

    lib.linkLibC();

    var _backend = config.backend;
    if (_backend == .auto) {
        if (lib.target.isDarwin()) {
            _backend = .metal;
        } else if (lib.target.isWindows()) {
            _backend = .d3d11;
        } else {
            _backend = .gl;
        }
    }
    const backend_option = switch (_backend) {
        .d3d11 => "-DSOKOL_D3D11",
        .metal => "-DSOKOL_METAL",
        .gl => "-DSOKOL_GLCORE33",
        .gles2 => "-DSOKOL_GLES2",
        .gles3 => "-DSOKOL_GLES3",
        .wgpu => "-DSOKOL_WGPU",
        else => unreachable,
    };

    if (lib.target.isDarwin()) {
        inline for (csources) |csrc| {
            lib.addCSourceFile(sokol_path ++ csrc, &[_][]const u8{ "-ObjC", "-DIMPL", backend_option });
        }
        lib.linkFramework("Cocoa");
        lib.linkFramework("QuartzCore");
        lib.linkFramework("AudioToolbox");
        if (.metal == _backend) {
            lib.linkFramework("MetalKit");
            lib.linkFramework("Metal");
        } else {
            lib.linkFramework("OpenGL");
        }
    } else {
        var egl_flag = if (config.force_egl) "-DSOKOL_FORCE_EGL " else "";
        var x11_flag = if (!config.enable_x11) "-DSOKOL_DISABLE_X11 " else "";
        var wayland_flag = if (!config.enable_wayland) "-DSOKOL_DISABLE_WAYLAND" else "";

        inline for (csources) |csrc| {
            lib.addCSourceFile(sokol_path ++ csrc, &[_][]const u8{ "-DIMPL", backend_option, egl_flag, x11_flag, wayland_flag });
        }

        if (lib.target.isLinux()) {
            var link_egl = config.force_egl or config.enable_wayland;
            var egl_ensured = (config.force_egl and config.enable_x11) or config.enable_wayland;

            lib.linkSystemLibrary("asound");

            if (.gles2 == _backend) {
                lib.linkSystemLibrary("glesv2");
                if (!egl_ensured) {
                    @panic("GLES2 in Linux only available with Config.force_egl and/or Wayland");
                }
            } else {
                lib.linkSystemLibrary("GL");
            }
            if (config.enable_x11) {
                lib.linkSystemLibrary("X11");
                lib.linkSystemLibrary("Xi");
                lib.linkSystemLibrary("Xcursor");
            }
            if (config.enable_wayland) {
                lib.linkSystemLibrary("wayland-client");
                lib.linkSystemLibrary("wayland-cursor");
                lib.linkSystemLibrary("wayland-egl");
                lib.linkSystemLibrary("xkbcommon");
            }
            if (link_egl) {
                lib.linkSystemLibrary("egl");
            }
        } else if (lib.target.isWindows()) {
            lib.linkSystemLibraryName("kernel32");
            lib.linkSystemLibraryName("user32");
            lib.linkSystemLibraryName("gdi32");
            lib.linkSystemLibraryName("ole32");
            if (.d3d11 == _backend) {
                lib.linkSystemLibraryName("d3d11");
                lib.linkSystemLibraryName("dxgi");
            }
        }
    }

    return .{
        .sokol = sokol,
        .sokol_c = lib,
    };
}

pub const Backend = enum {
    auto, // Windows: D3D11, macOS/iOS: Metal, otherwise: GL
    d3d11,
    metal,
    gl,
    gles2,
    gles3,
    wgpu,
};

pub const Config = struct {
    backend: Backend = .auto,
    force_egl: bool = false,
    enable_x11: bool = true,
    enable_wayland: bool = false,
};

inline fn thisDir() []const u8 {
    return comptime std.fs.path.dirname(@src().file) orelse ".";
}
