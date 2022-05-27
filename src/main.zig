const std = @import("std");
const glfw = @import("glfw");
const gl = @import("zgl");
const nvg = @import("nanovg");

const Vec2 = std.meta.Vector(2, f32);

const Transform = struct {
    translate: Vec2 = Vec2{ 0.0, 0.0 },
    scale: f32 = 1.0,

    fn compose(a: Transform, b: Transform) Transform {
        return .{
            .translate = a.translate * Vec2{ b.scale, b.scale } + b.translate,
            .scale = a.scale * b.scale,
        };
    }

    fn modify(a: *Transform, b: Transform) void {
        a.* = a.compose(b);
    }

    fn invert(self: Transform) Transform {
        return .{
            .translate = -self.translate / @splat(2, self.scale),
            .scale = 1.0 / self.scale,
        };
    }

    fn apply(self: Transform, vec: Vec2) Vec2 {
        return vec * Vec2{ self.scale, self.scale } + self.translate;
    }
};

const Scene = struct {
    transform: Transform,
};

var scene: Scene = .{ .transform = .{} };

fn scrollCallback(win: glfw.Window, scroll_x: f64, scroll_y: f64) void {
    if (win.getKey(.left_control) == .press) {
        const cursor = win.getCursorPos() catch return;
        const pos = Vec2{ @floatCast(f32, cursor.xpos), @floatCast(f32, cursor.ypos) };

        const t = scene.transform;
        const mouse_world = t.invert().apply(pos);
        const to_origin = t.invert().compose(.{ .translate = -mouse_world });
        const from_origin = to_origin.invert();
        const zoom = .{ .scale = 1 - -(@floatCast(f32, scroll_y) / 15) };

        scene.transform = t.compose(to_origin).compose(zoom).compose(from_origin);
    } else {
        const scroll = Vec2{ @floatCast(f32, scroll_x), @floatCast(f32, scroll_y) };
        scene.transform.modify(.{ .translate = scroll * Vec2{ 20, 20 } });
    }
}

pub fn main() !void {
    try glfw.init(.{});
    defer glfw.terminate();
    const win = try glfw.Window.create(800, 600, "", null, null, .{});
    defer win.destroy();

    try glfw.makeContextCurrent(win);
    try glfw.swapInterval(0);

    const ctx = nvg.Context.createGl3(.{});
    defer ctx.deleteGl3();

    win.setScrollCallback(scrollCallback);

    while (!win.shouldClose()) {
        const size = try win.getSize();
        const fb_size = try win.getFramebufferSize();

        gl.viewport(0, 0, size.width, size.height);
        gl.clearColor(0, 0, 0, 0);
        gl.clear(.{ .color = true });

        ctx.beginFrame(
            @intToFloat(f32, size.width),
            @intToFloat(f32, size.height),
            @intToFloat(f32, fb_size.width) / @intToFloat(f32, size.width),
        );

        ctx.transform(
            scene.transform.scale,
            0,
            0,
            scene.transform.scale,
            scene.transform.translate[0],
            scene.transform.translate[1],
        );

        ctx.beginPath();
        ctx.rect(50, 100, 200, 400);
        ctx.fillColor(nvg.Color.hex(0xff00ffff));
        ctx.fill();

        ctx.strokeColor(nvg.Color.rgba(0x66, 0x66, 0x66, 0xff));
        ctx.beginPath();
        ctx.moveTo(256, -100000);
        ctx.lineTo(256, 100000);
        ctx.stroke();

        ctx.beginPath();
        ctx.moveTo(-100000, 256);
        ctx.lineTo(100000, 256);
        ctx.stroke();

        ctx.endFrame();

        try win.swapBuffers();
        try glfw.waitEvents();
    }
}
