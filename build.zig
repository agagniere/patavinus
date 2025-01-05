const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{ .preferred_optimize_mode = .ReleaseSafe });

    const frontend = b.step("frontend", "Build the frontend");
    const web_dir: std.Build.InstallDir = .{ .custom = "web" };
    {
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
        exe.entry = .disabled;
        exe.root_module.addImport("dvui", dvui.module("dvui_web"));
        exe.root_module.addImport("dvuiWebBackend", dvui.module("WebBackend"));
        frontend.dependOn(&b.addInstallArtifact(exe, .{ .dest_dir = .{ .override = web_dir } }).step);
        frontend.dependOn(&b.addInstallFileWithDir(dvui.path("src/backends/WebBackend.js"), web_dir, "WebBackend.js").step);
        frontend.dependOn(&b.addInstallFileWithDir(b.path("frontend/index.html"), web_dir, "index.html").step);
        b.getInstallStep().dependOn(frontend);
    }

    { // backend
        const backend = b.step("backend", "Build the backend");
        const target = b.standardTargetOptions(.{});

        const zap = b.dependency("zap", .{ .target = target, .optimize = optimize }).module("zap");
        const libpq = b.dependency("libpq", .{ .target = target, .optimize = optimize }).artifact("pq");
        const argsParser = b.dependency("args", .{ .target = target, .optimize = optimize }).module("args");

        const rootsourcefile = b.path("backend/main.zig");
        const exe = b.addExecutable(.{
            .name = "patavinus",
            .root_source_file = rootsourcefile,
            .target = target,
            .optimize = optimize,
        });

        exe.root_module.addImport("zap", zap);
        exe.root_module.addImport("args", argsParser);
        exe.linkLibrary(libpq);
        backend.dependOn(&b.addInstallArtifact(exe, .{}).step);
        b.getInstallStep().dependOn(backend);

        { // Run
            const run_step = b.step("run", "Run the app");
            const run_cmd = b.addRunArtifact(exe);

            run_cmd.step.dependOn(b.getInstallStep());
            run_cmd.addArg("--directory");
            run_cmd.addArg(b.getInstallPath(web_dir, ""));
            if (b.args) |args| {
                run_cmd.addArgs(args);
            }
            run_step.dependOn(&run_cmd.step);
        }
        { // Test
            const test_step = b.step("test", "Run unit tests");
            const unit_tests = b.addTest(.{
                .root_source_file = rootsourcefile,
                .target = target,
                .optimize = optimize,
            });
            const run_unit_tests = b.addRunArtifact(unit_tests);

            unit_tests.root_module.addImport("zap", zap);
            test_step.dependOn(&run_unit_tests.step);
        }
    }
}
