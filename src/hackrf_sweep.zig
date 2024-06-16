const std = @import("std");
const builtin = @import("builtin");
const hackrf = @import("hackrf.zig");
const getopt = @import("getopt");

const fftw = @cImport({
    @cInclude("fftw3.h");
});

const ctime = @cImport({
    @cInclude("time.h");
});

const status = hackrf.HACKRF_STATUS;

const FREQ_MAX_MHZ = 7250;
const DEFAULT_SAMPLE_RATE_HZ = 20000000;
const FFT_MIN_BINS = DEFAULT_SAMPLE_RATE_HZ / 5000000;
const _PRE_1_FFT_MAX_BINS = @divFloor(hackrf.BYTES_PER_BLOCK - 10, 2);
const _PRE_2_FFT_MAX_BINS = _PRE_1_FFT_MAX_BINS - @rem(_PRE_1_FFT_MAX_BINS, 4); //might have to do some odd multiple calcs
const FFT_MAX_BINS = if (@mod(_PRE_2_FFT_MAX_BINS / 4, 2) == 0) _PRE_2_FFT_MAX_BINS - 4 else _PRE_2_FFT_MAX_BINS;

const TUNE_STEP = DEFAULT_SAMPLE_RATE_HZ / hackrf.FREQ_ONE_MHZ;
const OFFSET = 7500000;
const BLOCKS_PER_TRANSFER = 16;

var NumRanges: u32 = 0;
var Frequencies: [hackrf.MAX_SWEEP_RANGES * 2]u16 = std.mem.zeroes([hackrf.MAX_SWEEP_RANGES * 2]u16);
var DoExit: bool = false;
var SweepCount: u64 = 0;
var ByteCount: u64 = 0;

// RX Callback Closure Variables
var FFTSize: u32 = 20;
var StepCount: u16 = undefined;
var SweepStarted: bool = false;
var BinaryOutput: bool = false;
var Antenna: bool = false;
var AntennaEnable: u32 = undefined;
var FiniteMode: bool = false;
var NumSweeps: u32 = 0;
var TimestampNormalized: bool = false;
var OneShot: bool = false;

var OutFile: ?std.fs.File = undefined;

var UsbTranferTime: std.posix.timeval = .{ .tv_usec = 0, .tv_sec = 0 };

// FFT Variables
var FftBinWidth: f64 = undefined;
var IFFTOutput: bool = false;

var FftwIn: ?[*]fftw.fftwf_complex = null;
var FftwOut: ?[*]fftw.fftwf_complex = null;
var FftwPlan: fftw.fftwf_plan = null;
var IfftwIn: ?[*]fftw.fftwf_complex = null;
var IfftwOut: ?[*]fftw.fftwf_complex = null;
var IfftwPlan: fftw.fftwf_plan = null;

var Window: [*]f64 = undefined;
var Pwr: [*]f64 = undefined;

fn parse_u32(S: []const u8, Value: *u32) status {
    if (std.fmt.parseUnsigned(u32, S, 10)) |value| {
        Value.* = value;
        return status.HACKRF_SUCCESS;
    } else |_| {
        return status.HACKRF_ERROR_INVALID_PARAM;
    }
}

fn parse_u32_range(S: []const u8, ValueMin: *u32, ValueMax: *u32) status {
    var splitIter = std.mem.split(u8, S, ":");
    var index: usize = 0;
    var result: status = undefined;
    while (splitIter.next()) |arg| {
        switch (index) {
            0 => result = parse_u32(arg, ValueMin),
            1 => result = parse_u32(arg, ValueMax),
            else => break,
        }

        if (result != status.HACKRF_SUCCESS)
            return result;

        index += 1;
    }

    if (index == 0)
        return status.HACKRF_ERROR_INVALID_PARAM;

    return result;
}

fn get_time_of_day(TimeValue: *std.posix.timeval) void {
    const is_posix = switch (builtin.os.tag) {
        .windows, .uefi, .wasi => false,
        else => true,
    };

    if (is_posix) {
        const time = std.time.Instant.now() catch return;
        TimeValue = time.timestamp;
    } else {
        const time = std.time.nanoTimestamp();
        TimeValue.tv_sec = @truncate(@divFloor(time, std.time.ns_per_s));
        TimeValue.tv_usec = @truncate(@mod(@divFloor(time, std.time.ns_per_us), 1000000));
    }
}

fn timeval_diff(A: *std.posix.timeval, B: *std.posix.timeval) f32 {
    return @as(f32, @floatFromInt(A.tv_sec - B.tv_sec)) + 1e-6 * @as(f32, @floatFromInt(A.tv_usec - B.tv_usec));
}

fn usage() void {
    std.log.err("Usage:\n\t[-h] # this help\n\t[-d serial_number] # Serial number of desired HackRF\n\t[-a amp_enable] # RX RF amplifier 1=Enable, 0=Disable\n\t[-f freq_min:freq_max] # minimum and maximum frequencies in MHz\n\t[-p antenna_enable] # Antenna port power, 1=Enable, 0=Disable\n\t[-l gain_db] # RX LNA (IF) gain, 0-40dB, 8dB steps\n\t[-g gain_db] # RX VGA (baseband) gain, 0-62dB, 2dB steps\n\t[-w bin_width] # FFT bin width (frequency resolution) in Hz, 2445-5000000\n\t[-W wisdom_file] # Use FFTW wisdom file (will be created if necessary)\n\t[-P estimate|measure|patient|exhaustive] # FFTW plan type, default is 'measure'\n\t[-1] # one shot mode\n\t[-N num_sweeps] # Number of sweeps to perform\n\t[-B] # binary output\n\t[-I] # binary inverse FFT output\n\t[-n] # keep the same timestamp within a sweep\n\t-r filename # output file\n\nOutput fields:\n\tdate, time, hz_low, hz_high, hz_bin_width, num_samples, dB, dB, . . .\n", .{});
}

fn sigint_callback_handler(Signum: c_int) callconv(.C) void {
    std.log.info("Caught Signal {}", .{Signum});
    DoExit = true;
}

fn sighandler(Signum: std.os.windows.DWORD) callconv(std.os.windows.WINAPI) std.os.windows.BOOL {
    std.log.info("Caught Signal {}", .{Signum});
    DoExit = true;
    return std.os.windows.TRUE;
}

pub fn main() !u8 {
    var result: status = status.HACKRF_SUCCESS;
    var serialNumber: ?[]const u8 = null;
    var device: ?*hackrf.HackrfDevice = null;

    var freqMin: u32 = 0;
    var freqMax: u32 = 6000;
    var lnaGain: u32 = 16;
    var vgaGain: u32 = 20;
    var requestedFFTBinWidth: u32 = undefined;
    var fftwWisdomPath: ?[]const u8 = null;

    var path: ?[]const u8 = null;
    var fftwPlanType: u32 = fftw.FFTW_MEASURE;

    var amp: bool = false;
    var ampEnable: u32 = undefined;

    // Timing
    var timeNow: std.posix.timeval = undefined;
    var timePrev: std.posix.timeval = undefined;

    var opts: getopt.OptionsIterator = getopt.getopt("a:f:p:l:g:d:N:w:W:P:n1BIr:h?");
    while (opts.next() catch |err| {
        std.log.err("argument error: {} '-{c}'\n", .{ err, opts.optopt });
        return 0xFF;
    }) |opt| {
        switch (opt.opt) {
            'd' => serialNumber = opt.arg.?,
            'a' => {
                amp = true;
                result = parse_u32(opt.arg.?, &ampEnable);
            },
            'f' => {
                result = parse_u32_range(opt.arg.?, &freqMin, &freqMax);
                if (freqMin >= freqMax) {
                    std.log.err("argument error: freq_max must be greater than freq_min.", .{});
                    usage();
                    return 0xFF;
                }
                if (FREQ_MAX_MHZ < freqMax) {
                    std.log.err("argument error: freq_max may not be higher than {}.", .{FREQ_MAX_MHZ});
                    usage();
                    return 0xFF;
                }
                if (hackrf.MAX_SWEEP_RANGES <= NumRanges) {
                    std.log.err("argument error: specify a maximum of {} frequency ranges.", .{hackrf.MAX_SWEEP_RANGES});
                    usage();
                    return 0xFF;
                }
                Frequencies[2 * NumRanges] = @truncate(freqMin);
                Frequencies[2 * NumRanges + 1] = @truncate(freqMax);
                NumRanges += 1;
            },
            'p' => {
                Antenna = true;
                result = parse_u32(opt.arg.?, &AntennaEnable);
            },
            'l' => result = parse_u32(opt.arg.?, &lnaGain),
            'g' => result = parse_u32(opt.arg.?, &vgaGain),
            'N' => {
                FiniteMode = true;
                result = parse_u32(opt.arg.?, &NumSweeps);
            },
            'w' => {
                result = parse_u32(opt.arg.?, &requestedFFTBinWidth);
                FFTSize = DEFAULT_SAMPLE_RATE_HZ / requestedFFTBinWidth;
            },
            'W' => fftwWisdomPath = opt.arg,
            'P' => {
                if (std.mem.eql(u8, opt.arg.?, "estimate")) {
                    fftwPlanType = fftw.FFTW_ESTIMATE;
                } else if (std.mem.eql(u8, opt.arg.?, "measure")) {
                    fftwPlanType = fftw.FFTW_MEASURE;
                } else if (std.mem.eql(u8, opt.arg.?, "patient")) {
                    fftwPlanType = fftw.FFTW_PATIENT;
                } else if (std.mem.eql(u8, opt.arg.?, "exhaustive")) {
                    fftwPlanType = fftw.FFTW_EXHAUSTIVE;
                } else {
                    std.log.err("Unknown FFTW plan type '{?s}'\n", .{opt.arg});
                    return 0xFF;
                }
            },
            'n' => TimestampNormalized = true,
            '1' => OneShot = true,
            'B' => BinaryOutput = true,
            'I' => IFFTOutput = true,
            'r' => path = opt.arg.?,
            'h', '?' => {
                usage();
                return 0xFF;
            },
            else => {
                std.log.err("argument error: '-{c} {?s}'\n", .{
                    opt.opt,
                    opt.arg,
                });
                return 0xFF;
            },
        }

        if (result != status.HACKRF_SUCCESS) {
            std.log.err("argument error '-{c} {?s}' {s} ({})", .{ opt.opt, opt.arg, hackrf.hackrf_error_name(result), @intFromEnum(result) });
            return 0xFF;
        }
    }

    if (fftwWisdomPath != null) {
        _ = fftw.fftw_import_wisdom_from_filename(@ptrCast(fftwWisdomPath));
    } else {
        _ = fftw.fftw_import_system_wisdom();
    }

    if ((lnaGain % 8) != 0)
        std.log.warn("lna_gain (-l) must be a multiple of 8.", .{});

    if ((vgaGain % 2) != 0)
        std.log.warn("vga_gain (-g) must be a multiple of 2.", .{});

    if (Antenna) {
        if (AntennaEnable > 0) {
            std.log.err("argument error: antenna_enable shall be 0 or 1.", .{});
            usage();
            return 0xFF;
        }
    }

    if (NumRanges == 0) {
        Frequencies[0] = @truncate(freqMin);
        Frequencies[1] = @truncate(freqMax);
        NumRanges += 1;
    }

    if (BinaryOutput and IFFTOutput) {
        std.log.err("argument error: binary output (-B) and IFFT output (-I) are mutually exclusive.", .{});
        return 0xFF;
    }

    if (IFFTOutput and (1 < NumRanges)) {
        std.log.err("argument error: only one frequency range is supported in IFFT output (-I) mode.", .{});
        return 0xFF;
    }

    if (FFTSize < 4) { // FIXME get match that FFTSize is smaller than a quarter of the sample rate
        std.log.err("argument error: FFT bin width (-w) must be no more than 5000000", .{});
        return 0xFF;
    }

    if (FFTSize > FFT_MAX_BINS) {
        std.log.err("argument error: FFT bin width (-w) must be no more than 2445", .{});
        return 0xFF;
    }

    while (((FFTSize + 4) % 8) != 0) {
        FFTSize += 1;
    }

    FftBinWidth = @floatFromInt(DEFAULT_SAMPLE_RATE_HZ / FFTSize);

    var fftwInBuffer: [FFT_MAX_BINS * @sizeOf(fftw.fftwf_complex)]u8 = std.mem.zeroes([FFT_MAX_BINS * @sizeOf(fftw.fftwf_complex)]u8);
    var fftwInFBA = std.heap.FixedBufferAllocator.init(&fftwInBuffer);
    const fftwInPtr = fftwInFBA.allocator().create(fftw.fftwf_complex) catch {
        std.log.err("Out of Memory\n", .{});
        return 0xFF;
    };
    FftwIn = @ptrCast(fftwInPtr);
    defer fftwInFBA.allocator().destroy(fftwInPtr);
    var fftwOutBuffer: [FFT_MAX_BINS * @sizeOf(fftw.fftwf_complex)]u8 = std.mem.zeroes([FFT_MAX_BINS * @sizeOf(fftw.fftwf_complex)]u8);
    var fftwOutFBA = std.heap.FixedBufferAllocator.init(&fftwOutBuffer);
    const fftwOutPtr = fftwOutFBA.allocator().create(fftw.fftwf_complex) catch {
        std.log.err("Out of Memory\n", .{});
        return 0xFF;
    };
    FftwOut = @ptrCast(fftwOutPtr);
    defer fftwOutFBA.allocator().destroy(fftwOutPtr);
    FftwPlan = fftw.fftwf_plan_dft_1d(@intCast(FFTSize), FftwIn, FftwOut, fftw.FFTW_FORWARD, fftwPlanType);
    var pwrBuffer: [FFT_MAX_BINS * @sizeOf(f64)]u8 = std.mem.zeroes([FFT_MAX_BINS * @sizeOf(f64)]u8);
    var pwrFBA = std.heap.FixedBufferAllocator.init(&pwrBuffer);
    const pwrPtr: *f64 = pwrFBA.allocator().create(f64) catch {
        std.log.err("Out of Memory\n", .{});
        return 0xFF;
    };
    Pwr = @ptrCast(pwrPtr);
    defer pwrFBA.allocator().destroy(pwrPtr);
    var windowBuffer: [FFT_MAX_BINS * @sizeOf(f64)]u8 = std.mem.zeroes([FFT_MAX_BINS * @sizeOf(f64)]u8);
    var windowFBA = std.heap.FixedBufferAllocator.init(&windowBuffer);
    const windowPtr: *f64 = windowFBA.allocator().create(f64) catch {
        std.log.err("Out of Memory\n", .{});
        return 0xFF;
    };
    Window = @ptrCast(windowPtr);
    defer windowFBA.allocator().destroy(windowPtr);
    for (0..FFTSize) |i| {
        Window[i] = 0.5 * (1.0 - @cos(2.0 * std.math.pi * @as(f64, @floatFromInt(i)) / (@as(f64, @floatFromInt(FFTSize)) - 1.0)));
    }

    fftw.fftwf_execute(FftwPlan);

    result = hackrf.hackrf_init();
    if (result != status.HACKRF_SUCCESS) {
        std.log.err("hackrf_init() failed: {s} ({})", .{ hackrf.hackrf_error_name(result), @intFromEnum(result) });
        usage();
        return 0xFF;
    }

    result = hackrf.hackrf_open_by_serial(serialNumber, &device);
    if (result != status.HACKRF_SUCCESS) {
        std.log.err("hackrf_open() failed: {s} ({})", .{ hackrf.hackrf_error_name(result), @intFromEnum(result) });
        usage();
        return 0xFF;
    }

    if (path == null or std.mem.eql(u8, path.?, &[_]u8{'-'})) {
        OutFile = std.io.getStdOut();
    } else {
        OutFile = std.fs.cwd().openFile(path.?, .{ .mode = .write_only }) catch |err| switch (err) {
            error.FileNotFound => file: {
                break :file std.fs.cwd().createFile(path.?, .{}) catch |errC| switch (errC) {
                    else => ret: {
                        std.log.err("Error: {any}", .{errC});
                        break :ret std.io.getStdOut();
                    },
                };
            },
            else => std.io.getStdOut(),
        };
    }

    switch (builtin.os.tag) {
        .windows => {
            const handler_routine = struct {
                fn handler_routine(dwCtrlType: std.os.windows.DWORD) callconv(std.os.windows.WINAPI) std.os.windows.BOOL {
                    switch (dwCtrlType) {
                        std.os.windows.CTRL_C_EVENT, std.os.windows.CTRL_BREAK_EVENT, std.os.windows.CTRL_CLOSE_EVENT => {
                            return sighandler(dwCtrlType);
                        },
                        else => {
                            return std.os.windows.FALSE;
                        },
                    }
                }
            }.handler_routine;
            try std.os.windows.SetConsoleCtrlHandler(handler_routine, true);
        },
        else => {
            const SIG = std.os.linux.SIG;
            const internal_handler = struct {
                fn internal_handler(sig: c_int) callconv(.C) void {
                    switch (sig) {
                        SIG.INT, SIG.ILL, SIG.FPE, SIG.SEGV, SIG.TERM, SIG.ABRT => {
                            std.debug.assert(true);
                        },
                        else => std.debug.assert(false),
                    }
                    return sigint_callback_handler(sig);
                }
            }.internal_handler;
            const action = std.os.linux.Sigaction{
                .handler = .{ .handler = internal_handler },
                .mask = std.os.linux.empty_sigset,
                .flags = 0,
            };
            try std.os.linux.sigaction(SIG.INT, action, null);
            try std.os.linux.sigaction(SIG.ILL, action, null);
            try std.os.linux.sigaction(SIG.FPE, action, null);
            try std.os.linux.sigaction(SIG.SEGV, action, null);
            try std.os.linux.sigaction(SIG.TERM, action, null);
            try std.os.linux.sigaction(SIG.ABRT, action, null);
        },
    }

    std.log.info("call hackrf_sample_rate_set({:.03} MHz)", .{@as(f32, @floatFromInt(DEFAULT_SAMPLE_RATE_HZ)) / @as(f32, @floatFromInt(hackrf.FREQ_ONE_MHZ))});
    result = hackrf.hackrf_set_sample_rate_manual(device.?, DEFAULT_SAMPLE_RATE_HZ, 1);
    if (result != status.HACKRF_SUCCESS) {
        std.log.err("hackrf_baseband_filter_bandwidth_set() failed: {s} ({})", .{ hackrf.hackrf_error_name(result), @intFromEnum(result) });
        usage();
        return 0xFF;
    }

    result = hackrf.hackrf_set_vga_gain(device.?, vgaGain);
    if (result != status.HACKRF_SUCCESS) {
        std.log.err("hackrf_set_vga_gain() failed: {s} ({})", .{ hackrf.hackrf_error_name(result), @intFromEnum(result) });
        usage();
        return 0xFF;
    }

    result = hackrf.hackrf_set_lna_gain(device.?, lnaGain);
    if (result != status.HACKRF_SUCCESS) {
        std.log.err("hackrf_set_lna_gain() failed: {s} ({})", .{ hackrf.hackrf_error_name(result), @intFromEnum(result) });
        usage();
        return 0xFF;
    }

    for (0..NumRanges) |i| {
        StepCount = 1 + (Frequencies[2 * i + 1] - Frequencies[2 * i] - 1) / TUNE_STEP;
        Frequencies[2 * i + 1] = Frequencies[2 * i] + StepCount * TUNE_STEP;
        std.log.info("Sweeping from {} MHz to {} MHz", .{ Frequencies[2 * i], Frequencies[2 * i + 1] });
    }

    if (IFFTOutput) {
        const ifftwInPtr = std.heap.page_allocator.alloc(fftw.fftwf_complex, FFTSize * StepCount) catch {
            std.log.err("Out of Memory\n", .{});
            return 0xFF;
        };
        IfftwIn = @ptrCast(ifftwInPtr);
        const ifftwOutPtr = std.heap.page_allocator.alloc(fftw.fftwf_complex, FFTSize * StepCount) catch {
            std.log.err("Out of Memory\n", .{});
            return 0xFF;
        };
        IfftwOut = @ptrCast(ifftwOutPtr);

        IfftwPlan = fftw.fftwf_plan_dft_1d(@intCast(FFTSize * StepCount), IfftwIn, IfftwOut, fftw.FFTW_BACKWARD, fftwPlanType);
        fftw.fftwf_execute(IfftwPlan);
        std.log.info("Setup IFFTs", .{});
    }

    result = hackrf.hackrf_init_sweep(device.?, &Frequencies, NumRanges, hackrf.BYTES_PER_BLOCK, TUNE_STEP * hackrf.FREQ_ONE_MHZ, OFFSET, hackrf.SWEEP_STYLE.INTERLEAVED);
    if (result != status.HACKRF_SUCCESS) {
        std.log.err("hackrf_init_sweep() failed: {s} ({})", .{ hackrf.hackrf_error_name(result), @intFromEnum(result) });
        usage();
        return 0xFF;
    }

    result = hackrf.hackrf_start_rx_sweep(device.?, rx_callback, null);
    if (result != status.HACKRF_SUCCESS) {
        std.log.err("hackrf_start_rx_sweep() failed: {s} ({})", .{ hackrf.hackrf_error_name(result), @intFromEnum(result) });
        usage();
        return 0xFF;
    }

    if (amp) {
        std.log.info("call hackrf_set_amp_enable({})\n", .{ampEnable});
        result = hackrf.hackrf_set_amp_enable(device.?, @intCast(ampEnable));
        if (result != status.HACKRF_SUCCESS) {
            std.log.err("hackrf_set_amp_enable() failed: {s} ({})", .{ hackrf.hackrf_error_name(result), @intFromEnum(result) });
            usage();
            return 0xFF;
        }
    }

    if (Antenna) {
        std.log.info("call hackrf_set_amp_enable({})\n", .{ampEnable});
        result = hackrf.hackrf_set_antenna_enable(device.?, @intCast(AntennaEnable));
        if (result != status.HACKRF_SUCCESS) {
            std.log.err("hackrf_set_antenna_enable() failed: {s} ({})", .{ hackrf.hackrf_error_name(result), @intFromEnum(result) });
            usage();
            return 0xFF;
        }
    }

    var timeStart: std.posix.timeval = undefined;
    get_time_of_day(&timeStart);
    timePrev = timeStart;

    std.log.info("Stop with Ctrl-C", .{});
    while (hackrf.hackrf_is_streaming(device.?) == status.HACKRF_TRUE and !DoExit) {
        std.time.sleep(std.time.ns_per_ms * 50);

        get_time_of_day(&timeNow);
        const timeDifference = timeval_diff(&timeNow, &timeStart);
        if (timeDifference > 1.0) {
            const sweepRate = @as(f32, @floatFromInt(SweepCount)) / timeDifference;
            std.log.info("{} total sweeps completed, {:.2} sweeps/second", .{ SweepCount, sweepRate });
            if (ByteCount == 0) {
                std.log.err("Couldnt transfer any data for one second.", .{});
                break;
            }
            ByteCount = 0;
            timePrev = timeNow;
        }
    }

    result = hackrf.hackrf_is_streaming(device.?);
    if (DoExit) {
        std.log.info("Exiting...", .{});
    } else {
        std.log.err("Exiting.. hackrf_is_streaming() result: {s} ({})", .{ hackrf.hackrf_error_name(result), result });
    }

    if (device != null) {
        result = hackrf.hackrf_close(device.?);
        if (result != status.HACKRF_SUCCESS) {
            std.log.err("hackrf_close() failed: {s} ({})", .{ hackrf.hackrf_error_name(result), @intFromEnum(result) });
        } else {
            std.log.info("hackrf_close() done", .{});
        }
        _ = hackrf.hackrf_exit();
        std.log.info("hackrf_exit() done", .{});
    }

    get_time_of_day(&timeNow);
    const timeDiff = timeval_diff(&timeNow, &timeStart);
    const sweepRate = @as(f32, @floatFromInt(SweepCount)) / timeDiff;
    std.log.info("Total sweeps: {} in {:.5} seconds ({:.2} sweeps/second)", .{ SweepCount, timeDiff, sweepRate });

    if (OutFile != null) {
        OutFile.?.close();
        OutFile = null;
        std.log.info("close() done", .{});
    }

    if (IFFTOutput) {
        std.heap.page_allocator.free(@as(*fftw.fftwf_complex, @ptrCast(IfftwIn)));
        std.heap.page_allocator.free(@as(*fftw.fftwf_complex, @ptrCast(IfftwOut)));
    }
    if (fftwWisdomPath != null) {
        _ = fftw.fftwf_export_wisdom_to_filename(@ptrCast(fftwWisdomPath.?));
    }
    std.log.info("exit", .{});
    return 0;
}

fn log_power(In: fftw.fftwf_complex, Scale: f64) f64 {
    const re = In[0] * Scale;
    const im = In[1] * Scale;
    const magsq = re * re + im * im;
    return @log2(magsq) * 10.0 / @log2(10.0);
}

fn rx_callback(Transfer: *hackrf.HackrfTransfer) i32 {
    var frequency: u64 = undefined;
    var timeString: [50]u8 = undefined;
    var bandEdge: u64 = undefined;
    var recordLength: u64 = undefined;

    if (OutFile == null)
        return -1;

    if (DoExit)
        return 0;

    if (UsbTranferTime.tv_sec == 0 and UsbTranferTime.tv_usec == 0 or TimestampNormalized == false)
        get_time_of_day(&UsbTranferTime);

    ByteCount += Transfer.ValidLength;
    var iBuf: [*]i8 = @ptrCast(Transfer.Buffer);
    const iFFTBins = FFTSize * StepCount;
    for (0..BLOCKS_PER_TRANSFER) |_| {
        const uBuf: [*]u8 = @ptrCast(iBuf);
        if (uBuf[0] == 0x7F and uBuf[1] == 0x7F) {
            frequency = ((@as(u64, uBuf[9]) << 56) |
                (@as(u64, uBuf[8]) << 48) |
                (@as(u64, uBuf[7]) << 40) |
                (@as(u64, uBuf[6]) << 32) |
                (@as(u64, uBuf[5]) << 24) |
                (@as(u64, uBuf[4]) << 16) |
                (@as(u64, uBuf[3]) << 8) |
                (@as(u64, uBuf[2])));
        } else {
            iBuf += hackrf.BYTES_PER_BLOCK;
            continue;
        }

        if (frequency == (hackrf.FREQ_ONE_MHZ * @as(u64, Frequencies[0]))) {
            if (SweepStarted) {
                if (IFFTOutput) {
                    fftw.fftwf_execute(IfftwPlan);
                    for (0..iFFTBins) |j| {
                        IfftwOut.?[j][0] *= 1.0 / @as(f32, @floatFromInt(iFFTBins));
                        IfftwOut.?[j][1] *= 1.0 / @as(f32, @floatFromInt(iFFTBins));
                        _ = OutFile.?.write(@as(*align(1) const [4]u8, @ptrCast(&IfftwOut.?[j][0]))) catch 0;
                        _ = OutFile.?.write(@as(*align(1) const [4]u8, @ptrCast(&IfftwOut.?[j][1]))) catch 0;
                    }
                }
                SweepCount += 1;

                if (TimestampNormalized)
                    get_time_of_day(&UsbTranferTime);
                if (OneShot) {
                    DoExit = true;
                } else if (FiniteMode and SweepCount == NumSweeps) {
                    DoExit = true;
                }
            }
            SweepStarted = true;
        }
        if (DoExit)
            return 0;
        if (!SweepStarted) {
            iBuf += hackrf.BYTES_PER_BLOCK;
            continue;
        }
        if (FREQ_MAX_MHZ * hackrf.FREQ_ONE_MHZ < frequency) {
            iBuf += hackrf.BYTES_PER_BLOCK;
            continue;
        }
        iBuf += hackrf.BYTES_PER_BLOCK - (FFTSize * 2);
        for (0..FFTSize) |j| {
            FftwIn.?[j][0] = @floatCast(@as(f64, @floatFromInt(iBuf[j * 2])) * Window[j] * 1.0 / 128.0);
            FftwIn.?[j][1] = @floatCast(@as(f64, @floatFromInt(iBuf[j * 2 + 1])) * Window[j] * 1.0 / 128.0);
        }
        iBuf += FFTSize * 2;
        fftw.fftwf_execute(FftwPlan);
        for (0..FFTSize) |j| {
            Pwr[j] = log_power(FftwOut.?[j], 1.0 / @as(f64, @floatFromInt(FFTSize)));
        }

        if (BinaryOutput) {
            recordLength = 2 * @sizeOf(@TypeOf(bandEdge)) + (FFTSize / 4) * @sizeOf(f32);
            _ = OutFile.?.write(&std.mem.toBytes(recordLength)) catch 0;
            bandEdge = frequency;
            _ = OutFile.?.write(&std.mem.toBytes(bandEdge)) catch 0;
            bandEdge = frequency + DEFAULT_SAMPLE_RATE_HZ / 4;
            _ = OutFile.?.write(&std.mem.toBytes(bandEdge)) catch 0;
            _ = OutFile.?.write(&std.mem.toBytes(&Pwr[1 + (FFTSize * 5) / 8])) catch 0;
            _ = OutFile.?.write(&std.mem.toBytes(recordLength)) catch 0;
            bandEdge = frequency + DEFAULT_SAMPLE_RATE_HZ / 2;
            _ = OutFile.?.write(&std.mem.toBytes(bandEdge)) catch 0;
            bandEdge = frequency + (DEFAULT_SAMPLE_RATE_HZ * 3) / 4;
            _ = OutFile.?.write(&std.mem.toBytes(bandEdge)) catch 0;
            _ = OutFile.?.write(&std.mem.toBytes(&Pwr[1 + FFTSize / 8])) catch 0;
        } else if (IFFTOutput) {
            var iFFTIndex: usize = @intFromFloat(@round(@as(f64, @floatFromInt(frequency - (hackrf.FREQ_ONE_MHZ * @as(u32, Frequencies[0])))) / FftBinWidth));
            iFFTIndex = @mod((iFFTIndex + iFFTBins / 2), iFFTBins);
            for (0..(FFTSize / 4)) |j| {
                IfftwIn.?[iFFTIndex + j][0] = FftwOut.?[j + 1 + (FFTSize * 5) / 8][0];
                IfftwIn.?[iFFTIndex + j][1] = FftwOut.?[j + 1 + (FFTSize * 5) / 8][1];
            }
            iFFTIndex += FFTSize / 2;
            iFFTIndex = @mod(iFFTIndex, iFFTBins);
            for (0..(FFTSize / 4)) |j| {
                IfftwIn.?[iFFTIndex + j][0] = FftwOut.?[j + 1 + FFTSize / 8][0];
                IfftwIn.?[iFFTIndex + j][0] = FftwOut.?[j + 1 + FFTSize / 8][1];
            }
        } else {
            const timeStampSeconds = @as(i64, UsbTranferTime.tv_sec);
            const fftTime = ctime.localtime(@alignCast(&timeStampSeconds));
            const len = ctime.strftime(@ptrCast(&timeString), 50, "%Y-%m-%d, %H:%M:%S", fftTime);
            const writer = OutFile.?.writer();
            std.fmt.format(writer, "{s}.{}, {:>10}, {:>10}, {:.2}, {}", .{ timeString[0..len], UsbTranferTime.tv_usec, frequency, (frequency + DEFAULT_SAMPLE_RATE_HZ / 4), FftBinWidth, FFTSize }) catch {};
            for (0..(FFTSize / 4)) |j| {
                std.fmt.format(writer, ", {:.2}", .{Pwr[j + 1 + (FFTSize * 5) / 8]}) catch {};
            }
            std.fmt.format(writer, "\n", .{}) catch {};
            std.fmt.format(writer, "{s}.{}, {:>10}, {:>10}, {:.2}, {}", .{ timeString[0..len], UsbTranferTime.tv_usec, (frequency + DEFAULT_SAMPLE_RATE_HZ / 2), (frequency + (DEFAULT_SAMPLE_RATE_HZ * 3) / 4), FftBinWidth, FFTSize }) catch {};
            for (0..(FFTSize / 4)) |j| {
                std.fmt.format(writer, ", {:.2}", .{Pwr[j + 1 + FFTSize / 8]}) catch {};
            }
            std.fmt.format(writer, "\n", .{}) catch {};
        }
    }

    return 0;
}
