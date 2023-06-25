const std = @import("std");
const sdl = @import("zsdl");
const sokol = @import("sokol");
const sg = sokol.gfx;
const sgp = sokol.gp;
const sdtx = sokol.debugtext;

const WINDOW_WIDTH = 1280;
const WINDOW_HEIGHT = 720;

const log = std.log.scoped(.template);

pub fn main() !void {
    try sdl.init(sdl.InitFlags.everything);
    defer sdl.quit();

    try sdl.gl.setAttribute(.context_profile_mask, @enumToInt(sdl.gl.Profile.core));
    try sdl.gl.setAttribute(.context_major_version, 3);
    try sdl.gl.setAttribute(.context_minor_version, 3);

    const window = try sdl.Window.create(
        "sdl + sokol",
        sdl.Window.pos_undefined,
        sdl.Window.pos_undefined,
        1280,
        720,
        .{ .opengl = true, .allow_highdpi = true, .resizable = true },
    );
    defer window.destroy();

    const gl_context = try sdl.gl.createContext(window);
    defer sdl.gl.deleteContext(gl_context);

    try sdl.gl.makeCurrent(window, gl_context);
    try sdl.gl.setSwapInterval(1);

    sg.setup(.{});
    defer sg.shutdown();
    sgp.setup(.{});
    defer sgp.shutdown();
    var sdtx_desc: sdtx.Desc = .{};
    sdtx_desc.fonts[0] = sdtx.fontKc854();
    sdtx.setup(sdtx_desc);
    defer sdtx.shutdown();

    main_loop: while (true) {
        var width: i32 = 0;
        var height: i32 = 0;
        try window.getSize(&width, &height);
        const ratio = @min(@intToFloat(f32, width) / @intToFloat(f32, WINDOW_WIDTH), @intToFloat(f32, height) / @intToFloat(f32, WINDOW_HEIGHT));

        var event: sdl.Event = undefined;
        while (sdl.pollEvent(&event)) {
            if (event.type == .quit) {
                break :main_loop;
            } else if (event.type == .keydown) {
                if (event.key.keysym.sym == .escape) break :main_loop;
            }
        }

        sgp.begin(width, height);
        sgp.viewport(
            @floatToInt(i32, @divFloor((@intToFloat(f32, width) - WINDOW_WIDTH * ratio), 2)),
            @floatToInt(i32, @divFloor((@intToFloat(f32, height) - WINDOW_HEIGHT * ratio), 2)),
            @floatToInt(i32, WINDOW_WIDTH * ratio),
            @floatToInt(i32, WINDOW_HEIGHT * ratio),
        );
        sgp.project(0, WINDOW_WIDTH, 0, WINDOW_HEIGHT);
        sgp.setColor(0.1, 0.1, 0.1, 1.0);
        sgp.clear();

        sdtx.canvas(WINDOW_WIDTH * 0.5, WINDOW_HEIGHT * 0.5);
        sdtx.origin(0.0, 2.0);
        sdtx.home();

        sdtx.font(0);
        sdtx.color3b(0xf4, 0x43, 0x36);

        var pass_action: sg.PassAction = .{};
        pass_action.colors[0] = .{ .load_action = .CLEAR, .clear_value = .{ .r = 0, .g = 0, .b = 0, .a = 1 } };
        sg.beginDefaultPass(pass_action, width, height);
        sgp.flush();
        sgp.end();
        sdtx.draw();
        sg.endPass();
        sg.commit();

        sdl.gl.swapWindow(window);
    }
}
