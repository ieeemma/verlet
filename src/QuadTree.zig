const std = @import("std");
const nvg = @import("nanovg");

const physics = @import("physics.zig");

const QuadTree = @This();

const threshold = 8;

allocator: std.mem.Allocator,
size: physics.Vec2,
root: Node = .{},

pub const Rect = [2]physics.Vec2;

const Object = struct {
    value: u32,
    box: Rect,
};

const Node = struct {
    children: ?[4]*Node = null,
    objects: std.ArrayListUnmanaged(Object) = .{},

    fn deinit(self: *Node, allocator: std.mem.Allocator) void {
        self.objects.deinit(allocator);
        if (self.children) |children| {
            for (children) |child| {
                child.deinit(allocator);
                allocator.destroy(child);
            }
        }
    }

    fn get(self: Node, results: *std.ArrayList(u32), box: Rect, node_box: Rect) std.mem.Allocator.Error!void {
        if (!collide(box, node_box)) return;

        for (self.objects.items) |obj| {
            if (collide(box, obj.box)) {
                try results.append(obj.value);
            } else {
                dummy();
            }
        }

        if (self.children) |children| {
            for (children) |child, i| {
                try child.get(results, box, childBox(node_box, i));
            }
        }
    }
    fn dummy() void {}

    fn put(root: *Node, allocator: std.mem.Allocator, obj: Object, root_box: Rect) std.mem.Allocator.Error!void {
        var node = root;
        var node_box = root_box;
        while (node.children) |children| {
            for (children) |child, i| {
                const child_box = childBox(node_box, i);
                if (contains(child_box, obj.box)) {
                    node = child;
                    node_box = child_box;
                    break;
                }
            } else {
                try node.objects.append(allocator, obj);
                return;
            }
        }

        if (node.objects.items.len > threshold) {
            node.children = [_]*Node{undefined} ** 4;
            for (node.children.?) |*child| {
                child.* = try allocator.create(Node);
                child.*.* = .{};
            }

            const objects = node.objects.toOwnedSlice(allocator);
            defer allocator.free(objects);

            for (objects) |object| {
                try node.put(allocator, object, node_box);
            }
            try node.put(allocator, obj, node_box);
        } else {
            try node.objects.append(allocator, obj);
        }
    }

    noinline fn remove(root: *Node, obj: Object, root_box: Rect) bool {
        var node = root;
        var node_box = root_box;
        while (node.children) |children| {
            for (children) |child, i| {
                const child_box = childBox(node_box, i);
                if (contains(child_box, obj.box)) {
                    node = child;
                    node_box = child_box;
                    break;
                }
            } else {
                break;
            }
        }
        for (node.objects.items) |obj2, i| {
            if (obj.value == obj2.value) {
                _ = node.objects.swapRemove(i);
                return true;
            }
        }
        return false;
    }

    fn draw(self: Node, allocator: std.mem.Allocator, ctx: *nvg.Context, node_box: Rect) std.mem.Allocator.Error!void {
        if (self.children) |children| {
            for (children) |child, i| {
                try child.draw(allocator, ctx, childBox(node_box, i));
            }
        } else {
            ctx.beginPath();
            ctx.rect(
                node_box[0][0],
                node_box[0][1],
                node_box[1][0] - node_box[0][0],
                node_box[1][1] - node_box[0][1],
            );
            ctx.strokeColor(nvg.Color.rgba(0xff, 0xff, 0xff, 0x10));
            ctx.stroke();

            const txt = try std.fmt.allocPrint(allocator, "{}", .{self.objects.items.len});
            defer allocator.free(txt);
            ctx.fillColor(nvg.Color.rgba(0xff, 0xff, 0xff, 0x99));
            _ = ctx.text(node_box[0][0], node_box[1][1], txt);
        }
    }

    fn childBox(parent: Rect, i: usize) Rect {
        const coord = physics.Vec2{
            @intToFloat(f32, i & 1),
            @intToFloat(f32, (i >> 1) & 1),
        };
        const dim = physics.v(0.5) * (parent[1] - parent[0]);
        const child_pos = parent[0] + coord * dim;
        return Rect{ child_pos, child_pos + dim };
    }

    fn collide(a: Rect, b: Rect) bool {
        return !(a[1][0] < b[0][0] or // a left of b
            b[1][0] < a[0][0] or // b left of a
            a[1][1] < b[0][1] or // a above b
            b[1][1] < a[0][1]); // b above a
    }

    fn contains(a: Rect, b: Rect) bool {
        return @reduce(.And, a[0] <= b[0]) and @reduce(.And, a[1] >= b[1]);
    }
};

pub fn deinit(self: *QuadTree) void {
    self.root.deinit(self.allocator);
}

pub fn get(self: QuadTree, results: *std.ArrayList(u32), box: Rect) !void {
    return self.root.get(results, box, .{ .{ 0, 0 }, self.size });
}

pub fn put(self: *QuadTree, box: Rect, value: u32) !void {
    return self.root.put(
        self.allocator,
        .{ .value = value, .box = box },
        .{ .{ 0, 0 }, self.size },
    );
}

pub fn remove(self: *QuadTree, box: Rect, value: u32) bool {
    return self.root.remove(
        .{ .value = value, .box = box },
        .{ .{ 0, 0 }, self.size },
    );
}

pub fn draw(self: QuadTree, ctx: *nvg.Context) !void {
    return self.root.draw(self.allocator, ctx, .{ .{ 0, 0 }, self.size });
}
