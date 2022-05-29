const std = @import("std");
const nvg = @import("nanovg");

pub const Vec2 = std.meta.Vector(2, f32);

const gravity = Vec2{ 0, 1000 };

const substeps = 4;

inline fn v(n: f32) Vec2 {
    return .{ n, n };
}

inline fn mag2(a: Vec2) f32 {
    return @reduce(.Add, a * a);
}

pub const Object = struct {
    cur_pos: Vec2,
    old_pos: Vec2,
    acc: Vec2,
    radius: f32,
    color: nvg.Color,

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

    pub fn step(self: *Solver, dt: f32) void {
        const sub_dt = dt / substeps;

        var i: usize = 0;
        while (i < substeps) : (i += 1) {
            for (self.objects.items) |*obj| {
                obj.acc += gravity;
            }

            self.constrain();

            self.collisions();

            for (self.objects.items) |*obj| {
                obj.step(sub_dt);
            }
        }
    }

    fn constrain(self: *Solver) void {
        const position = Vec2{ 0, 0 };
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

    fn collisions(self: *Solver) void {
        // O(n^2) brute force, for now. This is slow!
        for (self.objects.items) |*obj1| {
            for (self.objects.items) |*obj2| {
                if (obj1 == obj2) continue;

                // If the length of the vector between two circles is less than
                // the sum of their radii, move them apart along the axis
                // of intersection.

                const axis = obj1.cur_pos - obj2.cur_pos;
                const total_radius = obj1.radius + obj2.radius;

                const dist2 = mag2(axis);
                if (dist2 < total_radius * total_radius) {
                    const dist = @sqrt(dist2);
                    const n = axis / v(dist);
                    const delta = total_radius - dist;
                    obj1.cur_pos += v(0.5 * delta) * n;
                    obj2.cur_pos -= v(0.5 * delta) * n;
                }
            }
        }
    }
};
