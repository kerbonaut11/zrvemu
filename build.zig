const std = @import("std");
const Build = std.Build;

pub fn build(b: *Build) void {
    const exe = b.addExecutable(.{
        .name = "zrvemu",
        .root_module = b.addModule("zremu", .{
            .root_source_file = b.path("src/main.zig"),
            .target = b.standardTargetOptions(.{}),
            .optimize = b.standardOptimizeOption(.{}),
        }),
    });

    const mibu = b.dependency("zigtui", .{});
    exe.root_module.addImport("zigtui", mibu.module("zigtui"));

    b.installArtifact(exe);

    const test_step = b.step("test", "");
    const tests = b.addTest(.{.root_module = exe.root_module});
    test_step.dependOn(compileTest(b, "basic"));
    test_step.dependOn(&b.addRunArtifact(tests).step);
}

const Target = std.Target.riscv;
const Feature = Target.Feature;
const FeatureSet = std.Target.Cpu.Feature.Set;

const supported_features: [2]Feature = .{.@"32bit", .i};

fn getFeatureAddSub() struct{FeatureSet, FeatureSet} {
    @setEvalBranchQuota(10000);

    var support = std.EnumArray(Feature, bool).initFill(false);
    for (supported_features) |feature| support.set(feature, true);

    const total_features = support.values.len;
    var add: [supported_features.len]Feature = undefined;
    var add_i = 0;
    var sub: [total_features-supported_features.len]Feature = undefined;
    var sub_i = 0;

    var iter = support.iterator();
    while (iter.next()) |e| {
        if (e.value.*) {
            add[add_i] = e.key;
            add_i += 1;
        } else {
            sub[sub_i] = e.key;
            sub_i += 1;
        }
    }

    return .{Target.featureSet(&add), Target.featureSet(&sub)};
}

fn compileTest(b: *Build, comptime name: []const u8) *Build.Step {
    const feature_add, const feature_sub = comptime getFeatureAddSub();

    const target = b.resolveTargetQuery(.{
        .cpu_arch = .riscv32,
        .os_tag = .freestanding,
        .cpu_features_sub = feature_sub,
        .cpu_features_add = feature_add,
        .abi = .gnu,
    });

    const exe = b.addExecutable(.{
        .name = name,
        .root_module = b.addModule(name, .{
            .root_source_file = b.path("tests/" ++ name ++ ".zig"),
            .target = target,
            .optimize = .ReleaseSmall,
        })
    });

    exe.addAssemblyFile(b.path("tests/entry.S"));
    exe.setLinkerScript(b.path("tests/link.ld"));

    return &b.addInstallArtifact(exe, .{}).step;
}
