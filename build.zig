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

    const lib = b.addStaticLibrary(.{
        .name = "zig-hackrf",
        // In this case the main source file is merely a path, however, in more
        // complicated build scripts, this could be a generated file.
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    lib.linkLibC();
    lib.linkSystemLibrary("WinUsb");
    lib.linkSystemLibrary("SetupApi");

    // This declares intent for the library to be installed into the standard
    // location when the user invokes the "install" step (the default step when
    // running `zig build`).
    b.installArtifact(lib);

    const exe = b.addExecutable(.{
        .name = "zig-hackrf",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe.linkLibC();
    exe.linkSystemLibrary("WinUsb");
    exe.linkSystemLibrary("SetupApi");

    // This declares intent for the executable to be installed into the
    // standard location when the user invokes the "install" step (the default
    // step when running `zig build`).
    b.installArtifact(exe);

    const hackrf_info = b.addExecutable(.{
        .name = "zig-hackrf-info",
        .root_source_file = b.path("src/hackrf_info.zig"),
        .target = target,
        .optimize = optimize,
    });

    hackrf_info.linkLibC();
    hackrf_info.linkSystemLibrary("WinUsb");
    hackrf_info.linkSystemLibrary("SetupApi");

    b.installArtifact(hackrf_info);

    const getopt = b.dependency("getopt", .{
        .target = target,
        .optimize = optimize,
    });

    const hackrf_sweep = b.addExecutable(.{
        .name = "zig-hackrf-sweep",
        .root_source_file = b.path("src/hackrf_sweep.zig"),
        .target = target,
        .optimize = optimize,
    });

    hackrf_sweep.root_module.addImport("getopt", getopt.module("getopt"));
    hackrf_sweep.addIncludePath(b.path("fftw/include"));

    hackrf_sweep.linkLibC();
    hackrf_sweep.linkSystemLibrary("WinUsb");
    hackrf_sweep.linkSystemLibrary("SetupApi");

    hackrf_sweep.addLibraryPath(b.path("fftw/lib"));
    hackrf_sweep.linkSystemLibrary("libfftw3f-3");
    hackrf_sweep.linkSystemLibrary("libfftw3-3");
    hackrf_sweep.addRPath(b.path("fftw/lib"));

    b.installArtifact(hackrf_sweep);

    // This *creates* a Run step in the build graph, to be executed when another
    // step is evaluated that depends on it. The next line below will establish
    // such a dependency.
    const run_cmd = b.addRunArtifact(exe);

    const info_cmd = b.addRunArtifact(hackrf_info);

    const sweep_cmd = b.addRunArtifact(hackrf_sweep);

    // By making the run step depend on the install step, it will be run from the
    // installation directory rather than directly from within the cache directory.
    // This is not necessary, however, if the application depends on other installed
    // files, this ensures they will be present and in the expected location.
    run_cmd.step.dependOn(b.getInstallStep());

    info_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build run`
    // This will evaluate the `run` step rather than the default, which is "install".
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const info_step = b.step("info", "Run zig-hackrf-info");
    info_step.dependOn(&info_cmd.step);

    const sweep_step = b.step("sweep", "Run zig-hackrf-sweep");
    sweep_step.dependOn(&sweep_cmd.step);
}
