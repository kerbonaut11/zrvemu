const std = @import("std");
const Build = std.Build;

pub fn build(b: *Build) void {
    const target = b.standardTargetOptions(.{});

    if (std.fs.cwd().openDir("tests", .{}) == error.FileNotFound) {
        std.process.execv(b.allocator, &.{}) catch unreachable;
    }

    const exe = b.addExecutable(.{
        .name = "zrvemu",
        .root_module = b.addModule("zremu", .{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = b.standardOptimizeOption(.{}),
            .link_libc = true,
        }),
    });

    const softfloat_build_dir = switch (target.result.os.tag) {
        .linux => switch (target.result.cpu.arch) {
            .x86_64 => "berkeley-softfloat-3/build/Linux-x86_64-GCC/",
            else => @panic("unsupported arch"),
        },

        else => @panic("unsupported os"),
    };

    var make_proc = std.process.Child.init(&.{"make", "-C",  softfloat_build_dir}, b.allocator);
    make_proc.stdout_behavior = .Ignore;
    _ = make_proc.spawnAndWait() catch unreachable;


    exe.root_module.addIncludePath(b.path("berkeley-softfloat-3/source/include/"));
    exe.root_module.addLibraryPath(b.path(softfloat_build_dir));
    //exe.root_module.linkSystemLibrary("softfloat", .{b.});
    const softfloat_lib_path = std.fmt.allocPrint(b.allocator, "{s}/softfloat.a", .{softfloat_build_dir}) catch unreachable;
    exe.root_module.addObjectFile(b.path(softfloat_lib_path));

    const tui = b.dependency("zigtui", .{});
    exe.root_module.addImport("zigtui", tui.module("zigtui"));

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
