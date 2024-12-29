const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{ .preferred_optimize_mode = .ReleaseSafe });

    const zap = b.dependency("zap", .{ .target = target, .optimize = optimize }).module("zap");
    const libpq = b.dependency("libpq", .{ .target = target, .optimize = optimize }).artifact("pq");

    const exe = b.addExecutable(.{
        .name = "inventaire",
        .root_source_file = b.path("main.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe.root_module.addImport("zap", zap);
    exe.linkLibrary(libpq);
    b.installArtifact(exe);

    { // Run
        const run_step = b.step("run", "Run the app");
        const run_cmd = b.addRunArtifact(exe);

        run_cmd.step.dependOn(b.getInstallStep());
        if (b.args) |args| {
            run_cmd.addArgs(args);
        }
        run_step.dependOn(&run_cmd.step);
    }
    { // Test
        const test_step = b.step("test", "Run unit tests");
        const unit_tests = b.addTest(.{
            .root_source_file = b.path("main.zig"),
            .target = target,
            .optimize = optimize,
        });
        const run_unit_tests = b.addRunArtifact(unit_tests);

        unit_tests.root_module.addImport("zap", zap);
        test_step.dependOn(&run_unit_tests.step);
    }
}
