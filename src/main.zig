const std = @import("std");
const glfw = @import("glfw");
const gl = @import("zgl");
const nvg = @import("nanovg");

const physics = @import("physics.zig");
const Vec2 = physics.Vec2;

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
    solver: physics.Solver,
};

var scene: Scene = undefined;

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

const tick = std.time.ns_per_s / 60;

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

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    scene = .{
        .transform = .{ .translate = .{ 400, 300 } },
        .solver = .{
            .objects = std.ArrayList(physics.Object).init(allocator),
        },
    };
    defer scene.solver.objects.deinit();

    try scene.solver.objects.append(.{
        .cur_pos = .{ 200, 0 },
        .old_pos = .{ 0, 0 },
        .acc = .{ 0, 0 },
        .radius = 50,
    });

    var timer = try std.time.Timer.start();

    while (!win.shouldClose()) {

        // Lock to frame rate
        var time = timer.read();
        while (time < tick) {
            std.time.sleep(tick - time);
            time = timer.read();
        }

        // Step simulation, using delta time of current frame
        scene.solver.step(@intToFloat(f32, timer.lap()) / std.time.ns_per_s);

        const size = try win.getSize();
        const fb_size = try win.getFramebufferSize();

        gl.viewport(0, 0, size.width, size.height);
        gl.clearColor(0.16, 0.17, 0.20, 1.00);
        gl.clear(.{ .color = true });

        ctx.beginFrame(
            @intToFloat(f32, size.width),
            @intToFloat(f32, size.height),
            @intToFloat(f32, fb_size.width) / @intToFloat(f32, size.width),
        );

        // Transform by view matrix
        ctx.transform(
            scene.transform.scale,
            0,
            0,
            scene.transform.scale,
            scene.transform.translate[0],
            scene.transform.translate[1],
        );

        // Draw background sphere
        ctx.beginPath();
        ctx.fillColor(nvg.Color.rgba(0x21, 0x25, 0x2b, 0xff));
        ctx.circle(0, 0, 400);
        ctx.fill();

        // Draw solver objects
        ctx.fillColor(nvg.Color.rgba(0x5c, 0xb3, 0xfa, 0xff));
        for (scene.solver.objects.items) |obj| {
            ctx.beginPath();
            ctx.circle(obj.cur_pos[0], obj.cur_pos[1], obj.radius);
            ctx.fill();
        }

        ctx.endFrame();

        try win.swapBuffers();
        try glfw.pollEvents();
    }
}
