const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{ .preferred_optimize_mode = .ReleaseSafe });

    { // backend
        //const step = b.step("backend", "Build the backend");
        const target = b.standardTargetOptions(.{});

        const zap = b.dependency("zap", .{ .target = target, .optimize = optimize }).module("zap");
        const libpq = b.dependency("libpq", .{ .target = target, .optimize = optimize }).artifact("pq");

        const rootsourcefile = b.path("backend/main.zig");

        const exe = b.addExecutable(.{
            .name = "patavinus",
            .root_source_file = rootsourcefile,
            .target = target,
            .optimize = optimize,
        });

        exe.root_module.addImport("zap", zap);
        exe.linkLibrary(libpq);
        b.installArtifact(exe);
    }
    { // frontend
        //const step = b.step("frontend", "Build the frontend");
        const query = std.Target.Query{
            .cpu_arch = .wasm32,
            .os_tag = .freestanding,
            .abi = .musl,
        };
        const target = b.resolveTargetQuery(query);
        const dvui = b.dependency("dvui", .{
            .target = target,
            .optimize = optimize,
            .link_backend = false,
        });
        const rootsourcefile = b.path("frontend/app.zig");
        const exe = b.addExecutable(.{
            .name = "antonius",
            .root_source_file = rootsourcefile,
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        });
        exe.root_module.addImport("dvui", dvui.module("dvui_web"));
        exe.root_module.addImport("dvuiWebBackend", dvui.module("WebBackend"));
        b.installArtifact(exe);
    }

    // { // Run
    //     const run_step = b.step("run", "Run the app");
    //     const run_cmd = b.addRunArtifact(exe);

    //     run_cmd.step.dependOn(b.getInstallStep());
    //     if (b.args) |args| {
    //         run_cmd.addArgs(args);
    //     }
    //     run_step.dependOn(&run_cmd.step);
    // }
    // { // Test
    //     const test_step = b.step("test", "Run unit tests");
    //     const unit_tests = b.addTest(.{
    //         .root_source_file = rootsourcefile,
    //         .target = target,
    //         .optimize = optimize,
    //     });
    //     const run_unit_tests = b.addRunArtifact(unit_tests);

    //     unit_tests.root_module.addImport("zap", zap);
    //     test_step.dependOn(&run_unit_tests.step);
    // }
}
