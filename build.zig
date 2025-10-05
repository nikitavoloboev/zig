const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const default_version = "0.1.0";
    const version_override = b.option([]const u8, "flow-version", "Override the Flow CLI version string") orelse default_version;

    const flow_options = b.addOptions();
    flow_options.addOption([]const u8, "version", version_override);

    const flow_mod = b.createModule(.{
        .root_source_file = b.path("cli/flow/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    flow_mod.addOptions("build_options", flow_options);

    const flow_exe = b.addExecutable(.{
        .name = "flow",
        .root_module = flow_mod,
    });

    b.installArtifact(flow_exe);

    const run_cmd = b.addRunArtifact(flow_exe);
    if (b.args) |args| run_cmd.addArgs(args);

    const flow_step = b.step("flow", "Run the Flow CLI");
    flow_step.dependOn(&run_cmd.step);
}
