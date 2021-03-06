const std = @import("std");
const glfw = @import("glfw");
const gl = @import("zgl");
const nvg = @import("nanovg");

const physics = @import("physics.zig");
const Vec2 = physics.Vec2;
const Transform = @import("Transform.zig");
const QuadTree = @import("QuadTree.zig");

const tick = std.time.ns_per_s / 60;

var transform: Transform = .{};

var rand: std.rand.Random = undefined;

fn scrollCallback(win: glfw.Window, scroll_x: f64, scroll_y: f64) void {
    if (win.getKey(.left_control) == .press) {
        const cursor = win.getCursorPos() catch return;
        const pos = Vec2{ @floatCast(f32, cursor.xpos), @floatCast(f32, cursor.ypos) };

        const t = transform;
        const mouse_world = t.invert().apply(pos);
        const to_origin = t.invert().compose(.{ .translate = -mouse_world });
        const from_origin = to_origin.invert();
        const zoom = .{ .scale = 1 - -(@floatCast(f32, scroll_y) / 15) };

        transform = t.compose(to_origin).compose(zoom).compose(from_origin);
    } else {
        const scroll = Vec2{ @floatCast(f32, scroll_x), @floatCast(f32, scroll_y) };
        transform.modify(.{ .translate = scroll * Vec2{ 20, 20 } });
    }
}

const Color = enum(u32) {
    purple = 0xcd74e8ff,
    red = 0xeb6772ff,
    orange = 0xdb9d63ff,
    yellow = 0xe6c07bff,
    green = 0x9acc76ff,
    blue = 0x5cb3faff,
};

fn spawnRandom(solver: *physics.Solver) !void {
    const x = rand.float(f32) * 2 - 1;
    const y = rand.float(f32) * 2 - 1;
    const pos = Vec2{ x, y } * Vec2{ 200, 100 } + Vec2{ 400, 400 };
    try solver.add(.{
        .cur_pos = pos,
        .old_pos = pos,
        .radius = rand.float(f32) * 20 + 5,
        .color = nvg.Color.hex(@enumToInt(rand.enumValue(Color))),
    });
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

    ctx.fontFaceId(ctx.createFont("font", "font.ttf"));

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    transform = .{ .translate = .{ 0, -100 } };

    rand = std.rand.DefaultPrng.init(@intCast(u64, std.time.timestamp())).random();

    var solver = physics.Solver{
        .objects = std.ArrayList(physics.Object).init(allocator),
        .qt = .{
            .allocator = allocator,
            .size = .{ 800, 800 },
        },
    };
    defer solver.objects.deinit();
    defer solver.qt.deinit();

    var timer = try std.time.Timer.start();

    var count: usize = 0;

    while (!win.shouldClose()) : (count += 1) {

        // Lock to frame rate
        var time = timer.read();
        while (time < tick) {
            std.time.sleep(tick - time);
            time = timer.read();
        }

        const t = timer.lap();

        if (count % 15 == 0) try spawnRandom(&solver);

        // Step simulation, using delta time of current frame
        var step: usize = 0;
        while (step < 4) : (step += 1) {
            try solver.step(1.0 / 60.0 / 4.0);
        }

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
            transform.scale,
            0,
            0,
            transform.scale,
            transform.translate[0],
            transform.translate[1],
        );

        // Draw background sphere
        ctx.beginPath();
        ctx.fillColor(nvg.Color.rgba(0x21, 0x25, 0x2b, 0xff));
        ctx.circle(400, 400, 400);
        ctx.fill();

        // Draw solver objects
        for (solver.objects.items) |obj| {
            ctx.fillColor(obj.color);
            ctx.beginPath();
            ctx.circle(obj.cur_pos[0], obj.cur_pos[1], obj.radius);
            ctx.fill();
        }

        // Draw quad tree regions
        try solver.qt.draw(ctx);

        ctx.fillColor(nvg.Color.hex(@enumToInt(Color.purple)));
        ctx.resetTransform();
        const txt = try std.fmt.allocPrint(
            allocator,
            "{} / {}",
            .{ t, solver.objects.items.len },
        );
        defer allocator.free(txt);
        _ = ctx.text(10, 30, txt);

        ctx.endFrame();

        try win.swapBuffers();
        try glfw.pollEvents();
    }
}
