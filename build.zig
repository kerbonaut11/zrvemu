const std = @import("std");
const Build = std.Build;

pub fn build(b: *Build) void {
    if (std.fs.cwd().openDir("tests", .{}) == error.FileNotFound) {
        std.process.execv(b.allocator, &.{}) catch unreachable;
    }

    const exe = b.addExecutable(.{
        .name = "zrvemu",
        .root_module = b.addModule("zremu", .{
            .root_source_file = b.path("src/main.zig"),
            .target = b.standardTargetOptions(.{}),
            .optimize = b.standardOptimizeOption(.{}),
            .link_libc = true,
        }),
    });

    const tui = b.dependency("zigtui", .{});
    exe.root_module.addImport("zigtui", tui.module("zigtui"));
    exe.root_module.addIncludePath(b.path("."));

    b.installArtifact(exe);

    const test_step = b.step("test", "");
    const tests = b.addTest(.{.root_module = exe.root_module});
    test_step.dependOn(&b.addRunArtifact(tests).step);
}

const Target = std.Target.riscv;
const Feature = Target.Feature;
const FeatureSet = std.Target.Cpu.Feature.Set;

const supported_features: [2]Feature = .{.@"32bit", .i, .m};

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
