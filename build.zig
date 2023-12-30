const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    comptime var counter: usize = 1;
    inline while (counter <= 22) : (counter += 1) {
        build_day(b, target, optimize, counter);
    }
}

fn build_day(b: *std.Build, target: std.zig.CrossTarget, optimize: std.builtin.OptimizeMode, day: u32) void {
    const day_name = b.fmt("day{:0>2}", .{day});
    const day_src = b.fmt("{s}/main.zig", .{day_name});
    const exe = b.addExecutable(.{
        .name = b.fmt("advent-of-code-2023-{s}", .{day_name}),
        .root_source_file = .{ .path = day_src },
        .target = target,
        .optimize = optimize,
    });
    exe.addIncludePath(.{ .cwd_relative = "lib/regez" });

    b.installArtifact(exe);
    const install_step = b.step(day_name, "Build specified day");
    install_step.dependOn(&exe.step);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(&exe.step);
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step(b.fmt("run_{s}", .{day_name}), "Run specified day");
    run_step.dependOn(&run_cmd.step);

    const exe_unit_tests = b.addTest(.{
        .root_source_file = .{ .path = day_src },
        .target = target,
        .optimize = optimize,
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    const test_step = b.step(b.fmt("test_{s}", .{day_name}), "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
}
