const Vec2 = @import("physics.zig").Vec2;

const Transform = @This();

translate: Vec2 = Vec2{ 0.0, 0.0 },
scale: f32 = 1.0,

pub fn compose(a: Transform, b: Transform) Transform {
    return .{
        .translate = a.translate * Vec2{ b.scale, b.scale } + b.translate,
        .scale = a.scale * b.scale,
    };
}

pub fn modify(a: *Transform, b: Transform) void {
    a.* = a.compose(b);
}

pub fn invert(self: Transform) Transform {
    return .{
        .translate = -self.translate / @splat(2, self.scale),
        .scale = 1.0 / self.scale,
    };
}

pub fn apply(self: Transform, vec: Vec2) Vec2 {
    return vec * Vec2{ self.scale, self.scale } + self.translate;
}
