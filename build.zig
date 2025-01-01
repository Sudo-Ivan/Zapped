const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zap = b.dependency("zap", .{
        .target = target,
        .optimize = optimize,
        .openssl = false,
    });

    const exe = b.addExecutable(.{
        .name = "zapped-starter",
        .root_source_file = .{ .cwd_relative = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    exe.root_module.addImport("zap", zap.module("zap"));
    b.installArtifact(exe);

    // Install all static files from public directory
    const static_files = b.addInstallDirectory(.{
        .source_dir = .{ .cwd_relative = "public" },
        .install_dir = .bin,
        .install_subdir = "public",
    });

    // Install configuration files
    const config_files = b.addInstallDirectory(.{
        .source_dir = .{ .cwd_relative = "config" },
        .install_dir = .bin,
        .install_subdir = "config",
    });

    // Add dependencies to install step
    b.getInstallStep().dependOn(&static_files.step);
    b.getInstallStep().dependOn(&config_files.step);

    // Run command
    const run_cmd = b.addRunArtifact(exe);
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // Add run step
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Production build step
    const prod_step = b.step("prod", "Build for production");
    prod_step.dependOn(b.getInstallStep());

    // Optional: Add test step
    const unit_tests = b.addTest(.{
        .root_source_file = .{ .cwd_relative = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    unit_tests.root_module.addImport("zap", zap.module("zap"));

    const run_unit_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);
}
