const std = @import("std");

const upstream_url = "https://github.com/KhronosGroup/Vulkan-Headers.git";

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const platform = b.option(
        Platform,
        "platform",
        "Platform surface declarations (none, metal, win32, xlib, xcb, wayland, android)",
    ) orelse Platform.default(target.result.os.tag);

    platform.validate(target.result.os.tag);

    const cleaner = addBindingCleaner(b);
    const command_generator = addCommandGenerator(b);
    const type_generator = addTypeGenerator(b);
    const translate_c = addTranslateC(
        b,
        target,
        optimize,
        b.path("vendor/include"),
        platform,
    );
    const bindings = cleanBindings(b, cleaner, translate_c.getOutput(), "vulkan_raw.zig");

    const vulkan_raw = b.addModule("vulkan-raw", .{
        .root_source_file = bindings,
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    const commands = generateCommands(
        b,
        command_generator,
        bindings,
        b.path("vendor/registry/vk.xml"),
        "vulkan_commands.zig",
    );
    const vulkan_commands = b.addModule("vulkan-commands", .{
        .root_source_file = commands,
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "vulkan_raw", .module = vulkan_raw }},
    });
    const types = generateTypes(
        b,
        type_generator,
        bindings,
        b.path("vendor/registry/vk.xml"),
        "vulkan_types.zig",
    );
    const vulkan_types = b.addModule("vulkan-types", .{
        .root_source_file = types,
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "vulkan_raw", .module = vulkan_raw }},
    });

    const build_options = b.addOptions();
    build_options.addOption(Platform, "platform", platform);
    build_options.addOption([]const u8, "registry_commit", registryCommit());

    const vulkan = b.addModule("vulkan", .{
        .root_source_file = b.path("src/vulkan.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .imports = &.{
            .{ .name = "vulkan_raw", .module = vulkan_raw },
            .{ .name = "vulkan_commands", .module = vulkan_commands },
            .{ .name = "vulkan_types", .module = vulkan_types },
            .{ .name = "vulkan_build_options", .module = build_options.createModule() },
        },
    });
    configureLoaderLibraries(vulkan, target.result.os.tag);

    addBindingsStep(b, bindings, commands, types);
    addTestStep(b, target, optimize, vulkan);
    addExampleSteps(b, target, optimize, vulkan);
    addUpdateStep(
        b,
        cleaner,
        command_generator,
        type_generator,
        target,
        optimize,
        platform,
    );
}

const Platform = enum {
    none,
    metal,
    win32,
    xlib,
    xcb,
    wayland,
    android,

    fn default(os_tag: std.Target.Os.Tag) Platform {
        return switch (os_tag) {
            .macos, .ios, .tvos, .visionos => .metal,
            .windows => .win32,
            else => .none,
        };
    }

    fn validate(platform: Platform, os_tag: std.Target.Os.Tag) void {
        switch (platform) {
            .metal => switch (os_tag) {
                .macos, .ios, .tvos, .visionos => {},
                else => @panic("the metal Vulkan platform requires an Apple target"),
            },
            .win32 => if (os_tag != .windows) {
                @panic("the win32 Vulkan platform requires a Windows target");
            },
            .android => if (os_tag != .linux) {
                @panic("the Android Vulkan platform requires an Android target");
            },
            else => {},
        }
    }
};

fn registryCommit() []const u8 {
    return std.mem.trim(
        u8,
        @embedFile("vendor/VULKAN_HEADERS_COMMIT"),
        " \t\r\n",
    );
}

fn addTranslateC(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    include_path: std.Build.LazyPath,
    platform: Platform,
) *std.Build.Step.TranslateC {
    const translate_c = b.addTranslateC(.{
        .root_source_file = b.path("src/vulkan_translate.h"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    translate_c.addIncludePath(include_path);
    switch (platform) {
        .none => {},
        .metal => translate_c.defineCMacro("VK_ZIG_PLATFORM_METAL", null),
        .win32 => translate_c.defineCMacro("VK_ZIG_PLATFORM_WIN32", null),
        .xlib => translate_c.defineCMacro("VK_ZIG_PLATFORM_XLIB", null),
        .xcb => translate_c.defineCMacro("VK_ZIG_PLATFORM_XCB", null),
        .wayland => translate_c.defineCMacro("VK_ZIG_PLATFORM_WAYLAND", null),
        .android => translate_c.defineCMacro("VK_ZIG_PLATFORM_ANDROID", null),
    }
    return translate_c;
}

fn addBindingCleaner(b: *std.Build) *std.Build.Step.Compile {
    return b.addExecutable(.{
        .name = "clean-vulkan-bindings",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/clean_bindings.zig"),
            .target = b.graph.host,
            .optimize = .ReleaseSafe,
        }),
    });
}

fn addCommandGenerator(b: *std.Build) *std.Build.Step.Compile {
    return b.addExecutable(.{
        .name = "generate-vulkan-commands",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/generate_commands.zig"),
            .target = b.graph.host,
            .optimize = .ReleaseSafe,
        }),
    });
}

fn addTypeGenerator(b: *std.Build) *std.Build.Step.Compile {
    return b.addExecutable(.{
        .name = "generate-vulkan-types",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/generate_types.zig"),
            .target = b.graph.host,
            .optimize = .ReleaseSafe,
        }),
    });
}

fn cleanBindings(
    b: *std.Build,
    cleaner: *std.Build.Step.Compile,
    input: std.Build.LazyPath,
    output_name: []const u8,
) std.Build.LazyPath {
    const run_cleaner = b.addRunArtifact(cleaner);
    run_cleaner.addFileArg(input);
    return run_cleaner.addOutputFileArg(output_name);
}

fn generateCommands(
    b: *std.Build,
    generator: *std.Build.Step.Compile,
    bindings: std.Build.LazyPath,
    registry: std.Build.LazyPath,
    output_name: []const u8,
) std.Build.LazyPath {
    const run_generator = b.addRunArtifact(generator);
    run_generator.addFileArg(bindings);
    run_generator.addFileArg(registry);
    run_generator.addFileArg(b.path("src/vulkan.zig"));
    return run_generator.addOutputFileArg(output_name);
}

fn generateTypes(
    b: *std.Build,
    generator: *std.Build.Step.Compile,
    bindings: std.Build.LazyPath,
    registry: std.Build.LazyPath,
    output_name: []const u8,
) std.Build.LazyPath {
    const run_generator = b.addRunArtifact(generator);
    run_generator.addFileArg(bindings);
    run_generator.addFileArg(registry);
    return run_generator.addOutputFileArg(output_name);
}

fn configureLoaderLibraries(module: *std.Build.Module, os_tag: std.Target.Os.Tag) void {
    switch (os_tag) {
        .linux, .freebsd, .netbsd, .openbsd, .dragonfly => {
            module.linkSystemLibrary("dl", .{});
        },
        .windows => module.linkSystemLibrary("kernel32", .{}),
        else => {},
    }
}

fn addBindingsStep(
    b: *std.Build,
    bindings: std.Build.LazyPath,
    commands: std.Build.LazyPath,
    types: std.Build.LazyPath,
) void {
    const install_bindings = b.addInstallFile(bindings, "bindings/vulkan.zig");
    const install_commands = b.addInstallFile(commands, "bindings/commands.zig");
    const install_types = b.addInstallFile(types, "bindings/types.zig");
    const bindings_step = b.step(
        "bindings",
        "Generate target-specific Vulkan bindings in zig-out/bindings",
    );
    bindings_step.dependOn(&install_bindings.step);
    bindings_step.dependOn(&install_commands.step);
    bindings_step.dependOn(&install_types.step);
    b.getInstallStep().dependOn(&install_bindings.step);
    b.getInstallStep().dependOn(&install_commands.step);
    b.getInstallStep().dependOn(&install_types.step);
}

fn addTestStep(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    vulkan: *std.Build.Module,
) void {
    const unit_tests = b.addTest(.{ .root_module = vulkan });
    const run_unit_tests = b.addRunArtifact(unit_tests);

    const tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/vulkan.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{.{ .name = "vulkan", .module = vulkan }},
        }),
    });
    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Build and run the Vulkan binding tests");
    test_step.dependOn(&run_unit_tests.step);
    test_step.dependOn(&run_tests.step);

    const invalid_function = addCompileFailureTest(
        b,
        target,
        optimize,
        vulkan,
        "tests/compile_fail/invalid_command_function.zig",
        "expected an optional Vulkan PFN function-pointer type",
    );
    test_step.dependOn(&invalid_function.step);

    const wrong_scope = addCompileFailureTest(
        b,
        target,
        optimize,
        vulkan,
        "tests/compile_fail/wrong_command_scope.zig",
        "Vulkan command descriptor has the wrong dispatch scope",
    );
    test_step.dependOn(&wrong_scope.step);
}

fn addCompileFailureTest(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    vulkan: *std.Build.Module,
    source: []const u8,
    expected_error: []const u8,
) *std.Build.Step.Compile {
    const compile = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path(source),
            .target = target,
            .optimize = optimize,
            .imports = &.{.{ .name = "vulkan", .module = vulkan }},
        }),
    });
    compile.expect_errors = .{ .contains = expected_error };
    return compile;
}

fn addExampleSteps(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    vulkan: *std.Build.Module,
) void {
    const examples_step = b.step("examples", "Build every Vulkan example");
    const checker = b.addExecutable(.{
        .name = "check-vulkan-examples",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/check_examples.zig"),
            .target = b.graph.host,
            .optimize = .ReleaseSafe,
        }),
    });
    const check_examples = b.addRunArtifact(checker);
    check_examples.addFileArg(b.path("examples/support.zig"));
    for (examples) |example| {
        if (!std.mem.eql(u8, example.name, "raw-create-info")) {
            check_examples.addFileArg(b.path(example.path));
        }
        const executable = b.addExecutable(.{
            .name = b.fmt("vulkan-{s}", .{example.name}),
            .root_module = b.createModule(.{
                .root_source_file = b.path(example.path),
                .target = target,
                .optimize = optimize,
                .imports = &.{.{ .name = "vulkan", .module = vulkan }},
            }),
        });
        const install = b.addInstallArtifact(executable, .{});
        examples_step.dependOn(&install.step);

        const run = b.addRunArtifact(executable);
        const run_step = b.step(
            b.fmt("run-{s}", .{example.name}),
            b.fmt("Run the {s} Vulkan example", .{example.name}),
        );
        run_step.dependOn(&run.step);

        if (std.mem.eql(u8, example.name, "info")) {
            const example_step = b.step("example", "Build the Vulkan loader example");
            example_step.dependOn(&install.step);
            const run_example_step = b.step(
                "run-example",
                "Run the Vulkan loader example",
            );
            run_example_step.dependOn(&run.step);
        }
    }
    examples_step.dependOn(&check_examples.step);
}

const Example = struct {
    name: []const u8,
    path: []const u8,
};

const examples = [_]Example{
    .{ .name = "info", .path = "examples/info.zig" },
    .{ .name = "instance-extensions", .path = "examples/instance_extensions.zig" },
    .{ .name = "instance-layers", .path = "examples/instance_layers.zig" },
    .{ .name = "physical-devices", .path = "examples/physical_devices.zig" },
    .{ .name = "queue-families", .path = "examples/queue_families.zig" },
    .{ .name = "memory-properties", .path = "examples/memory_properties.zig" },
    .{ .name = "device-features", .path = "examples/device_features.zig" },
    .{ .name = "device-extensions", .path = "examples/device_extensions.zig" },
    .{ .name = "logical-device", .path = "examples/logical_device.zig" },
    .{ .name = "raw-create-info", .path = "examples/raw_create_info.zig" },
    .{ .name = "platform", .path = "examples/platform.zig" },
    .{ .name = "capabilities", .path = "examples/capabilities.zig" },
    .{ .name = "format-queries", .path = "examples/format_queries.zig" },
    .{ .name = "debug-utils", .path = "examples/debug_utils.zig" },
    .{ .name = "frame-resources", .path = "examples/frame_resources.zig" },
    .{ .name = "legacy-render-pass", .path = "examples/legacy_render_pass.zig" },
    .{ .name = "timeline-submit", .path = "examples/timeline_submit.zig" },
    .{ .name = "buffer-setup", .path = "examples/buffer_setup.zig" },
    .{ .name = "compute-dispatch", .path = "examples/compute_dispatch.zig" },
    .{ .name = "resize-triangle", .path = "examples/resize_triangle.zig" },
    .{ .name = "textured-triangle", .path = "examples/textured_triangle.zig" },
    .{ .name = "swapchain-recreation", .path = "examples/swapchain_recreation.zig" },
};

fn addUpdateStep(
    b: *std.Build,
    cleaner: *std.Build.Step.Compile,
    command_generator: *std.Build.Step.Compile,
    type_generator: *std.Build.Step.Compile,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    platform: Platform,
) void {
    const upstream_ref = b.option(
        []const u8,
        "vulkan-ref",
        "Vulkan-Headers Git branch or tag to vendor (default: main)",
    ) orelse "main";

    const clone = b.addSystemCommand(&.{
        "git",
        "clone",
        "--quiet",
        "--depth",
        "1",
        "--branch",
        upstream_ref,
        upstream_url,
    });
    const checkout = clone.addOutputDirectoryArg("vulkan-headers");

    const revision = b.addSystemCommand(&.{ "git", "-C" });
    revision.addDirectoryArg(checkout);
    revision.addArgs(&.{ "rev-parse", "HEAD" });
    const revision_file = revision.captureStdOut(.{});

    const verify_translate = addTranslateC(
        b,
        target,
        optimize,
        checkout.path(b, "include"),
        platform,
    );
    const verified_bindings = cleanBindings(
        b,
        cleaner,
        verify_translate.getOutput(),
        "updated_vulkan_raw.zig",
    );
    const verify = b.addCheckFile(verified_bindings, .{
        .expected_matches = &.{
            "pub const VkInstance =",
            "pub const PFN_vkCreateInstance =",
            "pub const VK_API_VERSION_1_0 =",
        },
    });
    const verified_commands = generateCommands(
        b,
        command_generator,
        verified_bindings,
        checkout.path(b, "registry/vk.xml"),
        "updated_vulkan_commands.zig",
    );
    const verify_commands = b.addCheckFile(verified_commands, .{
        .expected_matches = &.{
            "pub const create_instance =",
            "pub const get_physical_device_surface_support_khr =",
            "pub const queue_submit =",
        },
    });
    const verified_types = generateTypes(
        b,
        type_generator,
        verified_bindings,
        checkout.path(b, "registry/vk.xml"),
        "updated_vulkan_types.zig",
    );
    const verify_types = b.addCheckFile(verified_types, .{
        .expected_matches = &.{
            "pub const Format = enum",
            "pub const ImageUsageFlags =",
            "pub const Extent2D = struct",
        },
    });

    const update_files = b.addUpdateSourceFiles();
    for (vendored_files) |file_path| {
        update_files.addCopyFileToSource(
            checkout.path(b, file_path),
            b.fmt("vendor/{s}", .{file_path}),
        );
    }
    update_files.addCopyFileToSource(
        checkout.path(b, "LICENSE.md"),
        "vendor/LICENSE.md",
    );
    update_files.addCopyFileToSource(
        checkout.path(b, "registry/vk.xml"),
        "vendor/registry/vk.xml",
    );
    update_files.addCopyFileToSource(
        checkout.path(b, "registry/video.xml"),
        "vendor/registry/video.xml",
    );
    update_files.addCopyFileToSource(revision_file, "vendor/VULKAN_HEADERS_COMMIT");
    update_files.step.dependOn(&verify.step);
    update_files.step.dependOn(&verify_commands.step);
    update_files.step.dependOn(&verify_types.step);

    const update_step = b.step(
        "update",
        "Pull Vulkan-Headers, verify translation, and refresh vendored registry files",
    );
    update_step.dependOn(&update_files.step);
}

const vendored_files = [_][]const u8{
    "include/vulkan/vk_icd.h",
    "include/vulkan/vk_layer.h",
    "include/vulkan/vk_platform.h",
    "include/vulkan/vulkan.h",
    "include/vulkan/vulkan_android.h",
    "include/vulkan/vulkan_beta.h",
    "include/vulkan/vulkan_core.h",
    "include/vulkan/vulkan_directfb.h",
    "include/vulkan/vulkan_fuchsia.h",
    "include/vulkan/vulkan_ggp.h",
    "include/vulkan/vulkan_ios.h",
    "include/vulkan/vulkan_macos.h",
    "include/vulkan/vulkan_metal.h",
    "include/vulkan/vulkan_ohos.h",
    "include/vulkan/vulkan_screen.h",
    "include/vulkan/vulkan_ubm.h",
    "include/vulkan/vulkan_vi.h",
    "include/vulkan/vulkan_wayland.h",
    "include/vulkan/vulkan_win32.h",
    "include/vulkan/vulkan_xcb.h",
    "include/vulkan/vulkan_xlib.h",
    "include/vulkan/vulkan_xlib_xrandr.h",
    "include/vk_video/vulkan_video_codec_av1std.h",
    "include/vk_video/vulkan_video_codec_av1std_decode.h",
    "include/vk_video/vulkan_video_codec_av1std_encode.h",
    "include/vk_video/vulkan_video_codec_h264std.h",
    "include/vk_video/vulkan_video_codec_h264std_decode.h",
    "include/vk_video/vulkan_video_codec_h264std_encode.h",
    "include/vk_video/vulkan_video_codec_h265std.h",
    "include/vk_video/vulkan_video_codec_h265std_decode.h",
    "include/vk_video/vulkan_video_codec_h265std_encode.h",
    "include/vk_video/vulkan_video_codec_vp9std.h",
    "include/vk_video/vulkan_video_codec_vp9std_decode.h",
    "include/vk_video/vulkan_video_codecs_common.h",
};
