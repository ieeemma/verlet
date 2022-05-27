const std = @import("std");

pub const Vec2 = std.meta.Vector(2, f32);

const gravity = Vec2{ 0, 1000 };

inline fn v(n: f32) Vec2 {
    return .{ n, n };
}

inline fn length(a: Vec2) f32 {
    return @sqrt(@reduce(.Add, a * a));
}

pub const Object = struct {
    cur_pos: Vec2,
    old_pos: Vec2,
    acc: Vec2,
    radius: f32,

    pub fn step(self: *Object, dt: f32) void {
        const vel = self.cur_pos - self.old_pos;
        self.old_pos = self.cur_pos;
        self.cur_pos += vel + self.acc * v(dt * dt);
        self.acc = .{ 0, 0 };
    }
};

pub const Solver = struct {
    objects: std.ArrayList(Object),

    pub fn step(self: *Solver, dt: f32) void {

        // Apply gravity

        for (self.objects.items) |*obj| {
            obj.acc += gravity;
        }

        // Constrain to a circle

        const position = Vec2{ 0, 0 };
        const radius = 400;

        for (self.objects.items) |*obj| {
            const to_obj = obj.cur_pos - position;
            const dist = length(to_obj);

            if (dist > radius - obj.radius) {
                const n = to_obj / v(dist);
                obj.cur_pos = position + n * v(radius - obj.radius);
            }
        }

        // Step each object

        for (self.objects.items) |*obj| {
            obj.step(dt);
        }
    }
};
