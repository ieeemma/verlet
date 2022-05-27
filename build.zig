const std = @import("std");
const glfw = @import("deps/mach-glfw/build.zig");
const nvg = @import("deps/nanovg-zig/build.zig");

pub fn build(b: *std.build.Builder) void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();

    const exe = b.addExecutable("verlet", "src/main.zig");

    exe.addIncludeDir("include");
    exe.linkSystemLibrary("epoxy");
    exe.addPackagePath("glfw", "deps/mach-glfw/src/main.zig");
    glfw.link(b, exe, .{});
    exe.addPackagePath("zgl", "deps/zgl/zgl.zig");
    nvg.add(b, exe);

    exe.setTarget(target);
    exe.setBuildMode(mode);
    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
