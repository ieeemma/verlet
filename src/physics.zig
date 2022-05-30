const std = @import("std");
const nvg = @import("nanovg");

const QuadTree = @import("QuadTree.zig");

pub const Vec2 = std.meta.Vector(2, f32);

const gravity = Vec2{ 0, 1000 };

pub inline fn v(n: f32) Vec2 {
    return .{ n, n };
}

inline fn mag2(a: Vec2) f32 {
    return @reduce(.Add, a * a);
}

pub const Object = struct {
    cur_pos: Vec2,
    old_pos: Vec2,
    acc: Vec2 = Vec2{ 0, 0 },
    radius: f32,
    color: nvg.Color,

    rect: QuadTree.Rect = undefined,

    pub fn step(self: *Object, dt: f32) void {
        const vel = self.cur_pos - self.old_pos;
        self.old_pos = self.cur_pos;
        // Verlet equation
        self.cur_pos += vel + self.acc * v(dt * dt);
        self.acc = .{ 0, 0 };
    }
};

pub const Solver = struct {
    objects: std.ArrayList(Object),
    qt: QuadTree,

    pub fn add(self: *Solver, obj_c: Object) !void {
        var obj = obj_c;
        const r = v(obj.radius);
        obj.rect = .{ obj.cur_pos - r, obj.cur_pos + r };

        const id = @intCast(u32, self.objects.items.len);
        try self.objects.append(obj);
        try self.qt.put(obj.rect, id);
    }

    pub fn step(self: *Solver, dt: f32) !void {
        for (self.objects.items) |*obj| {
            obj.acc += gravity;
        }

        for (self.objects.items) |*obj, j| {
            obj.step(dt);
            const id = @intCast(u32, j);

            std.debug.assert(self.qt.remove(obj.rect, id));

            const r = v(obj.radius);
            const new_rect = QuadTree.Rect{ obj.cur_pos - r, obj.cur_pos + r };
            try self.qt.put(new_rect, id);
            obj.rect = new_rect;
        }

        self.constrain();
        try self.collisions();
    }

    fn constrain(self: *Solver) void {
        const position = Vec2{ 400, 400 };
        const radius = 400;

        for (self.objects.items) |*obj| {
            const to_obj = obj.cur_pos - position;
            const dist2 = mag2(to_obj);
            const radius_diff = radius - obj.radius;

            if (dist2 > radius_diff * radius_diff) {
                const dist = @sqrt(dist2);
                const n = to_obj / v(dist);
                obj.cur_pos = position + n * v(radius_diff);
            }
        }
    }

    fn resolve(a: *Object, b: *Object) void {
        // If the length of the vector between two circles is less than
        // the sum of their radii, move them apart along the axis
        // of intersection.

        const axis = a.cur_pos - b.cur_pos;
        const total_radius = a.radius + b.radius;

        const dist2 = mag2(axis);
        if (dist2 < total_radius * total_radius) {
            const dist = @sqrt(dist2);
            const n = axis / v(dist);
            const delta = total_radius - dist;
            a.cur_pos += v(0.5 * delta) * n;
            b.cur_pos -= v(0.5 * delta) * n;
        }
    }

    fn collisions(self: *Solver) !void {
        var results = std.ArrayList(u32).init(self.objects.allocator);
        defer results.deinit();

        for (self.objects.items) |*obj, id1| {
            try self.qt.get(&results, obj.rect);
            for (results.items) |id2| {
                if (id1 != id2) resolve(obj, &self.objects.items[id2]);
            }
            results.clearRetainingCapacity();
        }
    }
};
