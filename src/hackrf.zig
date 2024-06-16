const std = @import("std");
const driver = @import("root.zig");

pub const VERSION: [:0]const u8 = "1.0.0";

var Context: ?*anyopaque = null;
var DeviceCount: u8 = 0;
var LastUsbError: i32 = 0;

pub const BYTES_PER_BLOCK = 16384;

pub const FREQ_ONE_MHZ = 1000000;

pub const HACKRF_USB_VID: u16 = 0x1d50;
pub const HACKRF_JAWBREAKER_USB_PID: u16 = 0x604b;
pub const HACKRF_ONE_USB_PID: u16 = 0x06089;
pub const RADIO_USB_PID: u16 = 0xcc15;

pub const TRANSFER_COUNT: usize = 4;
pub const TRANSFER_BUFFER_SIZE: usize = 262144;

pub const USB_CONFIG_STANDARD: i32 = 0x1;

pub const RX_ENDPOINT_ADDRESS = driver.ENDPOINT_IN | 1;
pub const TX_ENDPOINT_ADDRESS = driver.ENDPOINT_OUT | 2;

pub const HACKRF_BOARD_REV_GSG: u8 = 0x80;
pub const HACKRF_PLATFORM_JAWBREAKER: u32 = (1 << 0);
pub const HACKRF_PLATFORM_HACKRF1_OG: u32 = (1 << 1);
pub const HACKRF_PLATFORM_RAD1O: u32 = (1 << 2);
pub const HACKRF_PLATFORM_HACKRF1_R9: u32 = (1 << 3);

pub const HACKRF_OPERACAKE_ADDRESS_INVALID = 0xff;

pub const MAX_SWEEP_RANGES = 10;

pub const HACKRF_STATUS = enum(i16) {
    HACKRF_SUCCESS = 0,
    HACKRF_TRUE = 1,
    HACKRF_ERROR_INVALID_PARAM = -2,
    HACKRF_ERROR_NOT_FOUND = -5,
    HACKRF_ERROR_BUSY = -6,
    HACKRF_ERROR_NO_MEM = -11,
    HACKRF_ERROR_LIBUSB = -1000,
    HACKRF_ERROR_THREAD = -1001,
    HACKRF_ERROR_STREAMING_THREAD_ERR = -1002,
    HACKRF_ERROR_STREAMING_STOPPED = -1003,
    HACKRF_ERROR_STREAMING_EXIT_CALLED = -1004,
    HACKRF_ERROR_USB_API_VERSION = -1005,
    HACKRF_ERROR_NOT_LAST_DEVICE = -2000,
    HACKRF_ERROR_OTHER = -9999,
};

pub const HACKRF_USB_BOARD_ID = enum(u16) {
    USB_BOARD_ID_JAWBREAKER = 0x604B,
    USB_BOARD_ID_HACKRF_ONE = 0x6089,
    USB_BOARD_ID_RADIO = 0xCC15,
    USB_BOARD_ID_INVALID = 0xFFFF,
};

pub const HACKRF_BOARD_ID = enum(u8) {
    BOARD_ID_JELLYBEAN = 0,
    BOARD_ID_JAWBREAKER = 1,
    BOARD_ID_HACKRF1_OG = 2,
    BOARD_ID_RAD1O = 3,
    BOARD_ID_HACKRF1_R9 = 4,
    BOARD_ID_UNRECOGNIZED = 0xFE,
    BOARD_ID_UNDETECTED = 0xFF,
};

pub const HACKRF_BOARD_REV = enum(u8) {
    BOARD_REV_HACKRF1_OLD = 0,
    BOARD_REV_HACKRF1_R6 = 1,
    BOARD_REV_HACKRF1_R7 = 2,
    BOARD_REV_HACKRF1_R8 = 3,
    BOARD_REV_HACKRF1_R9 = 4,
    BOARD_REV_HACKRF1_R10 = 5,
    BOARD_REV_GSG_HACKRF1_R6 = 0x81,
    BOARD_REV_GSG_HACKRF1_R7 = 0x82,
    BOARD_REV_GSG_HACKRF1_R8 = 0x83,
    BOARD_REV_GSG_HACKRF1_R9 = 0x84,
    BOARD_REV_GSG_HACKRF1_R10 = 0x85,
    BOARD_REV_UNRECOGNIZED = 0xFE,
    BOARD_REV_UNDETECTED = 0xFF,
};

pub const HACKRF_VENDOR_REQUEST = enum(u8) {
    HACKRF_VENDOR_REQUEST_SET_TRANSCEIVER_MODE = 1,
    HACKRF_VENDOR_REQUEST_MAX2837_WRITE = 2,
    HACKRF_VENDOR_REQUEST_MAX2837_READ = 3,
    HACKRF_VENDOR_REQUEST_SI5351C_WRITE = 4,
    HACKRF_VENDOR_REQUEST_SI5351C_READ = 5,
    HACKRF_VENDOR_REQUEST_SAMPLE_RATE_SET = 6,
    HACKRF_VENDOR_REQUEST_BASEBAND_FILTER_BANDWIDTH_SET = 7,
    HACKRF_VENDOR_REQUEST_RFFC5071_WRITE = 8,
    HACKRF_VENDOR_REQUEST_RFFC5071_READ = 9,
    HACKRF_VENDOR_REQUEST_SPIFLASH_ERASE = 10,
    HACKRF_VENDOR_REQUEST_SPIFLASH_WRITE = 11,
    HACKRF_VENDOR_REQUEST_SPIFLASH_READ = 12,
    HACKRF_VENDOR_REQUEST_BOARD_ID_READ = 14,
    HACKRF_VENDOR_REQUEST_VERSION_STRING_READ = 15,
    HACKRF_VENDOR_REQUEST_SET_FREQ = 16,
    HACKRF_VENDOR_REQUEST_AMP_ENABLE = 17,
    HACKRF_VENDOR_REQUEST_BOARD_PARTID_SERIALNO_READ = 18,
    HACKRF_VENDOR_REQUEST_SET_LNA_GAIN = 19,
    HACKRF_VENDOR_REQUEST_SET_VGA_GAIN = 20,
    HACKRF_VENDOR_REQUEST_SET_TXVGA_GAIN = 21,
    HACKRF_VENDOR_REQUEST_ANTENNA_ENABLE = 23,
    HACKRF_VENDOR_REQUEST_SET_FREQ_EXPLICIT = 24,
    HACKRF_VENDOR_REQUEST_USB_WCID_VENDOR_REQ = 25,
    HACKRF_VENDOR_REQUEST_INIT_SWEEP = 26,
    HACKRF_VENDOR_REQUEST_OPERACAKE_GET_BOARDS = 27,
    HACKRF_VENDOR_REQUEST_OPERACAKE_SET_PORTS = 28,
    HACKRF_VENDOR_REQUEST_SET_HW_SYNC_MODE = 29,
    HACKRF_VENDOR_REQUEST_RESET = 30,
    HACKRF_VENDOR_REQUEST_OPERACAKE_SET_RANGES = 31,
    HACKRF_VENDOR_REQUEST_CLKOUT_ENABLE = 32,
    HACKRF_VENDOR_REQUEST_SPIFLASH_STATUS = 33,
    HACKRF_VENDOR_REQUEST_SPIFLASH_CLEAR_STATUS = 34,
    HACKRF_VENDOR_REQUEST_OPERACAKE_GPIO_TEST = 35,
    HACKRF_VENDOR_REQUEST_CPLD_CHECKSUM = 36,
    HACKRF_VENDOR_REQUEST_UI_ENABLE = 37,
    HACKRF_VENDOR_REQUEST_OPERACAKE_SET_MODE = 38,
    HACKRF_VENDOR_REQUEST_OPERACAKE_GET_MODE = 39,
    HACKRF_VENDOR_REQUEST_OPERACAKE_SET_DWELL_TIMES = 40,
    HACKRF_VENDOR_REQUEST_GET_M0_STATE = 41,
    HACKRF_VENDOR_REQUEST_SET_TX_UNDERRUN_LIMIT = 42,
    HACKRF_VENDOR_REQUEST_SET_RX_OVERRUN_LIMIT = 43,
    HACKRF_VENDOR_REQUEST_GET_CLKIN_STATUS = 44,
    HACKRF_VENDOR_REQUEST_BOARD_REV_READ = 45,
    HACKRF_VENDOR_REQUEST_SUPPORTED_PLATFORM_READ = 46,
    HACKRF_VENDOR_REQUEST_SET_LEDS = 47,
    HACKRF_VENDOR_REQUEST_SET_USER_BIAS_T_OPTS = 48,
};

pub const HACKRF_TRANSCEIVER_MODE = enum(u8) {
    HACKRF_TRANSCEIVER_MODE_OFF = 0,
    HACKRF_TRANSCEIVER_MODE_RECEIVE = 1,
    HACKRF_TRANSCEIVER_MODE_TRANSMIT = 2,
    HACKRF_TRANSCEIVER_MODE_SS = 3,
    TRANSCEIVER_MODE_CPLD_UPDATE = 4,
    TRANSCEIVER_MODE_RX_SWEEP = 5,
};

pub const SWEEP_STYLE = enum(u1) {
    LINEAR = 0,
    INTERLEAVED = 1,
};

pub const HackrfPartIdSerialNo = struct {
    PartId: [2]u32,
    SerialNo: [4]u32,
};

pub const HACKRF_DEVICE_LIST = struct {
    SerialNumbers: std.ArrayList([]u16),
    UsbBoardIds: std.ArrayList(HACKRF_USB_BOARD_ID),
    UsbDevices: std.ArrayList(driver.DEVICE_DATA),
    UsbDeviceCount: usize,
};

pub const HackrfTransfer = struct {
    Device: *HackrfDevice,
    Buffer: [*]u8,
    BufferLen: u32,
    ValidLength: u32,
    RxCtx: ?*anyopaque,
    TxCtx: ?*anyopaque,
};

pub const hackrf_sample_block_cb_fn = fn (Transfer: *HackrfTransfer) i32;
pub const hackrf_flush_cb_fn = fn (FlushCtx: ?*anyopaque, i32) void;
pub const hackrf_tx_block_completion_cb_fn = fn (Transfer: *HackrfTransfer, i32) void;
pub const HackrfDevice = struct {
    UsbDevice: driver.PDEVICE_DATA,
    UsbTransfers: ?[*]?*driver.Transfer,
    Callback: ?*const hackrf_sample_block_cb_fn,
    TransferThreadStarted: bool,
    TransferThread: std.Thread,
    Streaming: bool,
    RxCtx: ?*anyopaque,
    TxCtx: ?*anyopaque,
    DoExit: bool,
    Buffer: [TRANSFER_COUNT * TRANSFER_BUFFER_SIZE]u8,
    TransfersSetup: bool,
    TransferLock: std.Thread.Mutex,
    ActiveTransfers: usize,
    AllFinishedCv: std.Thread.Condition,
    Flush: bool,
    FlushTransfer: ?*driver.Transfer,
    FlushCallback: ?*const hackrf_flush_cb_fn,
    TxCompletionCallback: ?*const hackrf_tx_block_completion_cb_fn,
    FlushCtx: ?*anyopaque,
};

pub fn hackrf_init() HACKRF_STATUS {
    if (Context != null)
        return HACKRF_STATUS.HACKRF_SUCCESS;

    Context = driver.Init();

    if (Context == driver.INVALID_HANDLE_VALUE) {
        LastUsbError = @intCast(driver.GetLastError());
        return HACKRF_STATUS.HACKRF_ERROR_LIBUSB;
    } else {
        return HACKRF_STATUS.HACKRF_SUCCESS;
    }
}

pub fn hackrf_exit() HACKRF_STATUS {
    if (DeviceCount == 0) {
        if (Context != null) {
            driver.Exit(Context);
            Context = null;
        }

        return HACKRF_STATUS.HACKRF_SUCCESS;
    } else {
        return HACKRF_STATUS.HACKRF_ERROR_NOT_LAST_DEVICE;
    }
}

pub fn hackrf_close(Device: *HackrfDevice) HACKRF_STATUS {
    var result_stop: HACKRF_STATUS = HACKRF_STATUS.HACKRF_SUCCESS;
    var result_thread: HACKRF_STATUS = HACKRF_STATUS.HACKRF_SUCCESS;

    result_stop = hackrf_stop_cmd(Device);

    result_thread = kill_transfer_thread(Device);

    _ = free_transfers(Device);

    _ = driver.ReleaseInterface(Device.UsbDevice, 0);
    driver.CloseDevice(Device.UsbDevice);

    defer std.heap.page_allocator.destroy(Device);

    DeviceCount -= 1;
    if (result_thread != HACKRF_STATUS.HACKRF_SUCCESS) {
        return result_thread;
    }

    return result_stop;
}

pub fn hackrf_error_name(ErrCode: HACKRF_STATUS) [:0]const u8 {
    const out = switch (ErrCode) {
        HACKRF_STATUS.HACKRF_SUCCESS => "HACKRF_SUCCESS",
        HACKRF_STATUS.HACKRF_TRUE => "HACKRF_TRUE",
        HACKRF_STATUS.HACKRF_ERROR_INVALID_PARAM => "invalid parameter(s)",
        HACKRF_STATUS.HACKRF_ERROR_NOT_FOUND => "HackRF not found",
        HACKRF_STATUS.HACKRF_ERROR_BUSY => "HackRF busy",
        HACKRF_STATUS.HACKRF_ERROR_NO_MEM => "insufficient memory",
        HACKRF_STATUS.HACKRF_ERROR_LIBUSB => "USB error",
        HACKRF_STATUS.HACKRF_ERROR_THREAD => "transfer thread error",
        HACKRF_STATUS.HACKRF_ERROR_STREAMING_THREAD_ERR => "streaming thread encountered an error",
        HACKRF_STATUS.HACKRF_ERROR_STREAMING_STOPPED => "streaming stopped",
        HACKRF_STATUS.HACKRF_ERROR_STREAMING_EXIT_CALLED => "streaming terminated",
        HACKRF_STATUS.HACKRF_ERROR_USB_API_VERSION => "feature not supported by installed firmware",
        HACKRF_STATUS.HACKRF_ERROR_NOT_LAST_DEVICE => "one or more HackRFs still in use",
        HACKRF_STATUS.HACKRF_ERROR_OTHER => "unspecified error",
        //else => "unknown error code",
    };

    return out;
}

pub fn hackrf_device_list() ?HACKRF_DEVICE_LIST {
    var deviceList: HACKRF_DEVICE_LIST = undefined;
    var bResult: bool = true;

    if (Context != null) {
        deviceList.UsbDevices = std.ArrayList(driver.DEVICE_DATA).init(std.heap.page_allocator);
        driver.GetDevices(Context, &deviceList.UsbDevices);
        deviceList.UsbDeviceCount = deviceList.UsbDevices.items.len;
    }

    deviceList.SerialNumbers = std.ArrayList([]u16).init(std.heap.page_allocator);
    deviceList.UsbBoardIds = std.ArrayList(HACKRF_USB_BOARD_ID).init(std.heap.page_allocator);

    for (deviceList.UsbDevices.items) |usbDevice| {
        var deviceDescriptor: driver.DEVICE_DESCRIPTOR = undefined;
        if (driver.GetDeviceDescriptor(usbDevice, &deviceDescriptor)) {
            if (deviceDescriptor.IdVendor == HACKRF_USB_VID) {
                switch (deviceDescriptor.IdProduct) {
                    HACKRF_JAWBREAKER_USB_PID, HACKRF_ONE_USB_PID, RADIO_USB_PID => {
                        deviceList.UsbBoardIds.append(@enumFromInt(deviceDescriptor.IdProduct)) catch {};

                        const serialDescriptorIndex = deviceDescriptor.SerialNumber;
                        if (serialDescriptorIndex > 0) {
                            var buffer: [256]u8 = std.mem.zeroes([256]u8);
                            var fba = std.heap.FixedBufferAllocator.init(&buffer);
                            const allocator = fba.allocator();

                            const stringDescriptor: driver.PSTRING_DESCRIPTOR = allocator.create(driver.STRING_DESCRIPTOR) catch break;
                            bResult = driver.GetStringDescriptor(usbDevice, serialDescriptorIndex, stringDescriptor);

                            if (bResult == true) {
                                const length = stringDescriptor.*.bLength;
                                var serial = std.ArrayList(u16).init(std.heap.page_allocator);
                                for (@as(*align(1) const [127]u16, @ptrCast(&buffer[@sizeOf(u16)])), 0..) |elem, i| {
                                    if (i >= (length / 2) - 1)
                                        break;
                                    serial.append(elem) catch {};
                                }
                                deviceList.SerialNumbers.append(serial.toOwnedSlice() catch &[_]u16{}) catch {};
                            } else {
                                deviceList.SerialNumbers.append(&[_]u16{}) catch {};
                            }
                            defer allocator.destroy(@as(*driver.STRING_DESCRIPTOR, @ptrCast(stringDescriptor)));
                        }
                    },
                    else => {},
                }
            }
        }
    }

    return deviceList;
}

pub fn hackrf_open_by_serial(DesiredSerialNumber: ?[]const u8, Device: *?*HackrfDevice) HACKRF_STATUS {
    if (DesiredSerialNumber == null)
        return hackrf_open(Device);

    const usbDevice = hackrf_open_usb(DesiredSerialNumber.?);

    if (usbDevice == null)
        return HACKRF_STATUS.HACKRF_ERROR_NOT_FOUND;

    return hackrf_open_setup(usbDevice.?, Device);
}

pub fn hackrf_device_list_open(DeviceList: *HACKRF_DEVICE_LIST, Index: usize, Device: *?*HackrfDevice) HACKRF_STATUS {
    if (Index > DeviceList.UsbDevices.items.len)
        return HACKRF_STATUS.HACKRF_ERROR_INVALID_PARAM;

    return hackrf_open_setup(&DeviceList.UsbDevices.items[Index], Device);
}

pub fn hackrf_open_setup(UsbDevice: driver.PDEVICE_DATA, Device: *?*HackrfDevice) HACKRF_STATUS {
    var result: i16 = undefined;
    const libDevice: *HackrfDevice = std.heap.page_allocator.create(HackrfDevice) catch return HACKRF_STATUS.HACKRF_ERROR_NO_MEM;

    result = @intFromEnum(set_hackrf_configuration(UsbDevice, USB_CONFIG_STANDARD));
    if (result != 0) {
        return HACKRF_STATUS.HACKRF_ERROR_LIBUSB;
    }

    result = @truncate(driver.ClaimInterface(UsbDevice, 0));
    if (result != 0) {
        return HACKRF_STATUS.HACKRF_ERROR_LIBUSB;
    }

    libDevice.UsbDevice = UsbDevice;
    libDevice.UsbTransfers = null;
    libDevice.Callback = null;
    libDevice.TransferThreadStarted = false;
    libDevice.Streaming = false;
    libDevice.DoExit = false;
    libDevice.ActiveTransfers = 0;
    libDevice.Flush = false;
    libDevice.FlushTransfer = null;
    libDevice.FlushCallback = null;
    libDevice.FlushCtx = null;
    libDevice.TxCompletionCallback = null;

    libDevice.TransferLock = std.Thread.Mutex{};
    libDevice.AllFinishedCv = std.Thread.Condition{};

    result = @intFromEnum(allocate_transfers(libDevice));
    if (result != 0) {
        _ = driver.ReleaseInterface(UsbDevice, 0);
        driver.CloseDevice(UsbDevice);
        return HACKRF_STATUS.HACKRF_ERROR_NO_MEM;
    }

    result = @intFromEnum(create_transfer_thread(libDevice));
    if (result != 0) {
        _ = driver.ReleaseInterface(UsbDevice, 0);
        driver.CloseDevice(UsbDevice);
        return @enumFromInt(result);
    }

    Device.* = libDevice;
    DeviceCount += 1;

    return @enumFromInt(result);
}

pub fn hackrf_open(Device: *?*HackrfDevice) HACKRF_STATUS {
    var usbDevice: ?driver.PDEVICE_DATA = driver.OpenDevice(Context, HACKRF_USB_VID, HACKRF_ONE_USB_PID);

    if (usbDevice == null)
        usbDevice = driver.OpenDevice(Context, HACKRF_USB_VID, HACKRF_JAWBREAKER_USB_PID);

    if (usbDevice == null)
        usbDevice = driver.OpenDevice(Context, HACKRF_USB_VID, RADIO_USB_PID);

    if (usbDevice == null)
        return HACKRF_STATUS.HACKRF_ERROR_NOT_FOUND;

    return hackrf_open_setup(usbDevice.?, Device);
}

pub fn hackrf_device_list_free(DeviceList: *HACKRF_DEVICE_LIST) void {
    DeviceList.UsbDeviceCount = 0;
    DeviceList.UsbDevices.deinit();
    DeviceList.SerialNumbers.deinit();
    DeviceList.UsbBoardIds.deinit();
}

pub fn hackrf_open_usb(DesiredSerialNumber: []const u8) ?driver.PDEVICE_DATA {
    var usbDevices = std.ArrayList(driver.DEVICE_DATA).init(std.heap.page_allocator);
    var matchLen: usize = undefined;

    driver.GetDevices(Context, &usbDevices);

    matchLen = DesiredSerialNumber.len;
    if (matchLen > 32) return null;

    for (usbDevices.items) |usbDevice| {
        var deviceDescriptor: driver.DEVICE_DESCRIPTOR = undefined;
        if (driver.GetDeviceDescriptor(usbDevice, &deviceDescriptor)) {
            if (deviceDescriptor.IdVendor == HACKRF_USB_VID) {
                switch (deviceDescriptor.IdProduct) {
                    HACKRF_JAWBREAKER_USB_PID, HACKRF_ONE_USB_PID, RADIO_USB_PID => {
                        const serialDescriptorIndex = deviceDescriptor.SerialNumber;
                        if (serialDescriptorIndex > 0) {
                            var buffer: [256]u8 = std.mem.zeroes([256]u8);
                            var fba = std.heap.FixedBufferAllocator.init(&buffer);
                            const allocator = fba.allocator();

                            const stringDescriptor: driver.PSTRING_DESCRIPTOR = allocator.create(driver.STRING_DESCRIPTOR) catch break;
                            const bResult = driver.GetStringDescriptor(usbDevice, serialDescriptorIndex, stringDescriptor);

                            if (bResult == true) {
                                const length = stringDescriptor.*.bLength;
                                var serial = std.ArrayList(u16).init(std.heap.page_allocator);
                                for (@as(*align(1) const [127]u16, @ptrCast(&buffer[@sizeOf(u16)])), 0..) |elem, i| {
                                    if (i >= (length / 2) - 1)
                                        break;
                                    serial.append(elem) catch {};
                                }
                                const serialNumber = std.unicode.utf16leToUtf8Alloc(std.heap.page_allocator, serial.toOwnedSlice() catch &[_]u16{}) catch null;

                                if (serialNumber != null and serialNumber.?.len > 0) {
                                    if (std.mem.eql(u8, serialNumber.?[serialNumber.?.len - matchLen ..], DesiredSerialNumber)) {
                                        defer usbDevices.deinit();
                                        return driver.OpenDevice(Context, deviceDescriptor.IdVendor, deviceDescriptor.IdProduct);
                                    }
                                }
                            }

                            defer usbDevices.deinit();
                        }
                    },
                    else => {},
                }
            }
        }
    }

    return null;
}

pub fn hackrf_board_id_read(Device: *const HackrfDevice, value: *u8) HACKRF_STATUS {
    const iResult = driver.ControlTransfer(Device.UsbDevice, driver.ENDPOINT_IN | driver.REQUEST_TYPE_VENDOR | driver.RECIPIENT_DEVICE | 0x0, @intFromEnum(HACKRF_VENDOR_REQUEST.HACKRF_VENDOR_REQUEST_BOARD_ID_READ), 0, 0, value, 1, 0);

    if (iResult < 1) {
        LastUsbError = @intCast(driver.GetLastError());
        return HACKRF_STATUS.HACKRF_ERROR_LIBUSB;
    }

    return HACKRF_STATUS.HACKRF_SUCCESS;
}

pub fn hackrf_board_id_name(BoardId: HACKRF_BOARD_ID) [:0]const u8 {
    const id = switch (BoardId) {
        HACKRF_BOARD_ID.BOARD_ID_JELLYBEAN => "Jellybean",
        HACKRF_BOARD_ID.BOARD_ID_JAWBREAKER => "Jawbreaker",
        HACKRF_BOARD_ID.BOARD_ID_HACKRF1_OG => "HackRF One OG",
        HACKRF_BOARD_ID.BOARD_ID_RAD1O => "rad1o",
        HACKRF_BOARD_ID.BOARD_ID_HACKRF1_R9 => "HackRF One R9",
        HACKRF_BOARD_ID.BOARD_ID_UNRECOGNIZED => "unrecognized",
        HACKRF_BOARD_ID.BOARD_ID_UNDETECTED => "undetected",
        //else => "unknown",
    };

    return id;
}

pub fn hackrf_version_string_read(Device: *const HackrfDevice, Version: *u8, Length: *u16) HACKRF_STATUS {
    const iResult = driver.ControlTransfer(Device.UsbDevice, driver.ENDPOINT_IN | driver.REQUEST_TYPE_VENDOR | driver.RECIPIENT_DEVICE, @intFromEnum(HACKRF_VENDOR_REQUEST.HACKRF_VENDOR_REQUEST_VERSION_STRING_READ), 0, 0, Version, Length.*, 0);

    if (iResult < 0) {
        LastUsbError = @intCast(driver.GetLastError());
        return HACKRF_STATUS.HACKRF_ERROR_LIBUSB;
    }

    Length.* = @intCast(iResult);
    return HACKRF_STATUS.HACKRF_SUCCESS;
}

pub fn hackrf_usb_api_version_read(Device: *const HackrfDevice, version: *u16) HACKRF_STATUS {
    var deviceDescriptor: driver.DEVICE_DESCRIPTOR = undefined;

    const result = driver.GetDeviceDescriptor(Device.UsbDevice.*, &deviceDescriptor);
    if (result == false) {
        LastUsbError = @intCast(driver.GetLastError());
        return HACKRF_STATUS.HACKRF_ERROR_LIBUSB;
    }

    version.* = deviceDescriptor.Device;
    return HACKRF_STATUS.HACKRF_SUCCESS;
}

pub fn hackrf_board_partid_serialno_read(Device: *const HackrfDevice, PartIdSerialNo: *HackrfPartIdSerialNo) HACKRF_STATUS {
    const iResult = driver.ControlTransfer(Device.UsbDevice, driver.ENDPOINT_IN | driver.REQUEST_TYPE_VENDOR | driver.RECIPIENT_DEVICE, @intFromEnum(HACKRF_VENDOR_REQUEST.HACKRF_VENDOR_REQUEST_BOARD_PARTID_SERIALNO_READ), 0, 0, @ptrCast(std.mem.asBytes(PartIdSerialNo)), @sizeOf(HackrfPartIdSerialNo), 0);

    if (iResult < 0) {
        LastUsbError = @intCast(driver.GetLastError());
        return HACKRF_STATUS.HACKRF_ERROR_LIBUSB;
    }

    // FIXME Bytes Swap for BE Systems
    //PartIdSerialNo.PartId[0] = @byteSwap(PartIdSerialNo.PartId[0]);
    //PartIdSerialNo.PartId[1] = @byteSwap(PartIdSerialNo.PartId[1]);
    //PartIdSerialNo.PartId[0] = @byteSwap(PartIdSerialNo.SerialNo[0]);
    //PartIdSerialNo.PartId[1] = @byteSwap(PartIdSerialNo.SerialNo[1]);
    //PartIdSerialNo.PartId[2] = @byteSwap(PartIdSerialNo.SerialNo[2]);
    //PartIdSerialNo.PartId[3] = @byteSwap(PartIdSerialNo.SerialNo[3]);
    return HACKRF_STATUS.HACKRF_SUCCESS;
}

pub fn hackrf_board_rev_read(Device: *const HackrfDevice, Value: *u8) HACKRF_STATUS {
    var usbVersion: u16 = undefined;
    var status: HACKRF_STATUS = undefined;

    status = hackrf_usb_api_version_read(Device, &usbVersion);
    if (status != HACKRF_STATUS.HACKRF_SUCCESS)
        return status;

    if (usbVersion < 0x0106)
        return HACKRF_STATUS.HACKRF_ERROR_USB_API_VERSION;

    const iResult = driver.ControlTransfer(Device.UsbDevice, driver.ENDPOINT_IN | driver.REQUEST_TYPE_VENDOR | driver.RECIPIENT_DEVICE, @intFromEnum(HACKRF_VENDOR_REQUEST.HACKRF_VENDOR_REQUEST_BOARD_REV_READ), 0, 0, Value, 1, 0);
    if (iResult < 0) {
        LastUsbError = @intCast(driver.GetLastError());
        return HACKRF_STATUS.HACKRF_ERROR_LIBUSB;
    }

    return HACKRF_STATUS.HACKRF_SUCCESS;
}

pub fn hackrf_board_rev_name(BoardRev: HACKRF_BOARD_REV) [:0]const u8 {
    const name = switch (BoardRev) {
        HACKRF_BOARD_REV.BOARD_REV_HACKRF1_OLD => "older than r6",
        HACKRF_BOARD_REV.BOARD_REV_HACKRF1_R6, HACKRF_BOARD_REV.BOARD_REV_GSG_HACKRF1_R6 => "r6",
        HACKRF_BOARD_REV.BOARD_REV_HACKRF1_R7, HACKRF_BOARD_REV.BOARD_REV_GSG_HACKRF1_R7 => "r7",
        HACKRF_BOARD_REV.BOARD_REV_HACKRF1_R8, HACKRF_BOARD_REV.BOARD_REV_GSG_HACKRF1_R8 => "r8",
        HACKRF_BOARD_REV.BOARD_REV_HACKRF1_R9, HACKRF_BOARD_REV.BOARD_REV_GSG_HACKRF1_R9 => "r9",
        HACKRF_BOARD_REV.BOARD_REV_HACKRF1_R10, HACKRF_BOARD_REV.BOARD_REV_GSG_HACKRF1_R10 => "r10",
        HACKRF_BOARD_REV.BOARD_REV_UNRECOGNIZED => "unrecognized",
        HACKRF_BOARD_REV.BOARD_REV_UNDETECTED => "undetected",
        //else => "unknown",
    };

    return name;
}

pub fn hackrf_supported_platform_read(Device: *const HackrfDevice, Value: *u32) HACKRF_STATUS {
    var usbVersion: u16 = undefined;
    var status: HACKRF_STATUS = undefined;

    status = hackrf_usb_api_version_read(Device, &usbVersion);
    if (status != HACKRF_STATUS.HACKRF_SUCCESS)
        return status;

    if (usbVersion < 0x0106)
        return HACKRF_STATUS.HACKRF_ERROR_USB_API_VERSION;

    var data: [4]u8 = undefined;
    const iResult = driver.ControlTransfer(Device.UsbDevice, driver.ENDPOINT_IN | driver.REQUEST_TYPE_VENDOR | driver.RECIPIENT_DEVICE, @intFromEnum(HACKRF_VENDOR_REQUEST.HACKRF_VENDOR_REQUEST_SUPPORTED_PLATFORM_READ), 0, 0, @as(*u8, @ptrCast(&data)), 4, 0);
    if (iResult < 0) {
        LastUsbError = @intCast(driver.GetLastError());
        return HACKRF_STATUS.HACKRF_ERROR_LIBUSB;
    }

    Value.* = @as(u32, data[0]) << 24 | @as(u32, data[1]) << 16 | @as(u32, data[2]) << 8 | @as(u32, data[3]);
    return HACKRF_STATUS.HACKRF_SUCCESS;
}

pub fn hackrf_get_operacacke_boards(Device: *const HackrfDevice, Boards: *[8]u8) HACKRF_STATUS {
    var usbVersion: u16 = undefined;
    var status: HACKRF_STATUS = undefined;

    status = hackrf_usb_api_version_read(Device, &usbVersion);
    if (status != HACKRF_STATUS.HACKRF_SUCCESS)
        return status;

    if (usbVersion < 0x0105)
        return HACKRF_STATUS.HACKRF_ERROR_USB_API_VERSION;

    const iResult = driver.ControlTransfer(Device.UsbDevice, driver.ENDPOINT_IN | driver.REQUEST_TYPE_VENDOR | driver.RECIPIENT_DEVICE, @intFromEnum(HACKRF_VENDOR_REQUEST.HACKRF_VENDOR_REQUEST_OPERACAKE_GET_BOARDS), 0, 0, @as(*u8, @ptrCast(Boards)), 8, 0);
    if (iResult < 0) {
        LastUsbError = @intCast(driver.GetLastError());
        return HACKRF_STATUS.HACKRF_ERROR_LIBUSB;
    }

    return HACKRF_STATUS.HACKRF_SUCCESS;
}

pub fn hackrf_set_sample_rate_manual(Device: *HackrfDevice, FreqHz: u32, Divider: u32) HACKRF_STATUS {
    const set_fracrate_params_t = struct { FreqHz: u32, Divider: u32 };
    var set_fracrate_params: set_fracrate_params_t = undefined;
    const length = @sizeOf(set_fracrate_params_t);

    // FIXME: Make this to little endian;
    set_fracrate_params.FreqHz = FreqHz;
    set_fracrate_params.Divider = Divider;

    const lengthReturned = driver.ControlTransfer(Device.UsbDevice, driver.ENDPOINT_OUT | driver.REQUEST_TYPE_VENDOR | driver.RECIPIENT_DEVICE | 0x0, @intFromEnum(HACKRF_VENDOR_REQUEST.HACKRF_VENDOR_REQUEST_SAMPLE_RATE_SET), 0, 0, @ptrCast(std.mem.asBytes(&set_fracrate_params)), length, 0);
    if (lengthReturned < length) {
        LastUsbError = @intCast(driver.GetLastError());
        return HACKRF_STATUS.HACKRF_ERROR_LIBUSB;
    } else {
        const basebandFilterBW = hackrf_compute_baseband_filter_bw(@as(u32, @intFromFloat(0.75 * @as(f32, @floatFromInt(FreqHz)) / @as(f32, @floatFromInt(Divider)))));
        return hackrf_set_baseband_filter_bandwidth(Device, basebandFilterBW);
    }
}

pub fn hackrf_set_vga_gain(Device: *HackrfDevice, Value: u32) HACKRF_STATUS {
    if (Value > 62)
        return HACKRF_STATUS.HACKRF_ERROR_INVALID_PARAM;

    const not: u32 = 0x01;
    const nValue = Value & ~not;
    var ret: u8 = undefined;
    const iResult = driver.ControlTransfer(Device.UsbDevice, driver.ENDPOINT_IN | driver.REQUEST_TYPE_VENDOR | driver.RECIPIENT_DEVICE, @intFromEnum(HACKRF_VENDOR_REQUEST.HACKRF_VENDOR_REQUEST_SET_VGA_GAIN), 0, @truncate(nValue), &ret, 1, 0);
    if (iResult != 1 or ret == 0) {
        return HACKRF_STATUS.HACKRF_ERROR_INVALID_PARAM;
    } else {
        return HACKRF_STATUS.HACKRF_SUCCESS;
    }
}

pub fn hackrf_set_lna_gain(Device: *HackrfDevice, Value: u32) HACKRF_STATUS {
    if (Value > 40)
        return HACKRF_STATUS.HACKRF_ERROR_INVALID_PARAM;

    const not: u32 = 0x07;
    const nValue = Value & ~not;
    var ret: u8 = undefined;
    const iResult = driver.ControlTransfer(Device.UsbDevice, driver.ENDPOINT_IN | driver.REQUEST_TYPE_VENDOR | driver.RECIPIENT_DEVICE, @intFromEnum(HACKRF_VENDOR_REQUEST.HACKRF_VENDOR_REQUEST_SET_LNA_GAIN), 0, @truncate(nValue), &ret, 1, 0);
    if (iResult != 1 or ret == 0) {
        return HACKRF_STATUS.HACKRF_ERROR_INVALID_PARAM;
    } else {
        return HACKRF_STATUS.HACKRF_SUCCESS;
    }
}

pub fn hackrf_set_amp_enable(Device: *HackrfDevice, Value: u8) HACKRF_STATUS {
    var empty: u8 = undefined;
    const iResult = driver.ControlTransfer(Device.UsbDevice, driver.ENDPOINT_OUT | driver.REQUEST_TYPE_VENDOR | driver.RECIPIENT_DEVICE, @intFromEnum(HACKRF_VENDOR_REQUEST.HACKRF_VENDOR_REQUEST_AMP_ENABLE), Value, 0, &empty, 0, 0);
    if (iResult < 0) {
        LastUsbError = @intCast(driver.GetLastError());
        return HACKRF_STATUS.HACKRF_ERROR_LIBUSB;
    }

    return HACKRF_STATUS.HACKRF_SUCCESS;
}

pub fn hackrf_set_antenna_enable(Device: *HackrfDevice, Value: u8) HACKRF_STATUS {
    var empty: u8 = undefined;
    const iResult = driver.ControlTransfer(Device.UsbDevice, driver.ENDPOINT_OUT | driver.REQUEST_TYPE_VENDOR | driver.RECIPIENT_DEVICE, @intFromEnum(HACKRF_VENDOR_REQUEST.HACKRF_VENDOR_REQUEST_ANTENNA_ENABLE), Value, 0, &empty, 0, 0);
    if (iResult < 0) {
        LastUsbError = @intCast(driver.GetLastError());
        return HACKRF_STATUS.HACKRF_ERROR_LIBUSB;
    }

    return HACKRF_STATUS.HACKRF_SUCCESS;
}

pub fn hackrf_set_transceiver_mode(Device: *HackrfDevice, Value: HACKRF_TRANSCEIVER_MODE) HACKRF_STATUS {
    var empty: u8 = undefined;
    const iResult = driver.ControlTransfer(Device.UsbDevice, driver.ENDPOINT_OUT | driver.REQUEST_TYPE_VENDOR | driver.RECIPIENT_DEVICE, @intFromEnum(HACKRF_VENDOR_REQUEST.HACKRF_VENDOR_REQUEST_SET_TRANSCEIVER_MODE), @intFromEnum(Value), 0, &empty, 0, 0);
    if (iResult < 0) {
        LastUsbError = @intCast(driver.GetLastError());
        return HACKRF_STATUS.HACKRF_ERROR_LIBUSB;
    }

    return HACKRF_STATUS.HACKRF_SUCCESS;
}

pub fn hackrf_set_baseband_filter_bandwidth(Device: *HackrfDevice, BandwidthHz: u32) HACKRF_STATUS {
    var empty: u8 = undefined;
    const iResult = driver.ControlTransfer(Device.UsbDevice, driver.ENDPOINT_OUT | driver.REQUEST_TYPE_VENDOR | driver.RECIPIENT_DEVICE, @intFromEnum(HACKRF_VENDOR_REQUEST.HACKRF_VENDOR_REQUEST_BASEBAND_FILTER_BANDWIDTH_SET), @as(u8, @truncate(BandwidthHz & 0xFFFF)), @as(u16, @truncate(BandwidthHz >> 16)), &empty, 0, 0);
    if (iResult < 0) {
        LastUsbError = @intCast(driver.GetLastError());
        return HACKRF_STATUS.HACKRF_ERROR_LIBUSB;
    }

    return HACKRF_STATUS.HACKRF_SUCCESS;
}

pub fn set_hackrf_configuration(UsbDevice: driver.PDEVICE_DATA, Config: i32) HACKRF_STATUS {
    var configurationDescriptor: driver.CONFIGURATION_DESCRIPTOR = undefined;

    var result = driver.GetConfigurationDescriptor(UsbDevice.*, &configurationDescriptor);
    if (result == false) {
        LastUsbError = @intCast(driver.GetLastError());
        return HACKRF_STATUS.HACKRF_ERROR_LIBUSB;
    }

    if (configurationDescriptor.ConfigurationValue != Config) {
        configurationDescriptor.ConfigurationValue = @intCast(Config);
        result = driver.SetConfigurationDescriptor(UsbDevice.*, configurationDescriptor);
        if (result == false) {
            LastUsbError = @intCast(driver.GetLastError());
            return HACKRF_STATUS.HACKRF_ERROR_LIBUSB;
        }
    }

    return HACKRF_STATUS.HACKRF_SUCCESS;
}

pub fn hackrf_init_sweep(Device: *HackrfDevice, FrequencyList: []const u16, NumRanges: u32, NumBytes: u32, StepWidth: u32, Offset: u32, Style: SWEEP_STYLE) HACKRF_STATUS {
    var usbVersion: u16 = undefined;
    var status: HACKRF_STATUS = undefined;

    status = hackrf_usb_api_version_read(Device, &usbVersion);
    if (status != HACKRF_STATUS.HACKRF_SUCCESS)
        return status;

    if (usbVersion < 0x0102)
        return HACKRF_STATUS.HACKRF_ERROR_USB_API_VERSION;

    var data = std.mem.zeroes([9 + MAX_SWEEP_RANGES * 2 * @sizeOf(u16)]u8);
    const size = 9 + NumRanges * 2 * @sizeOf(u16);

    if (NumRanges < 1 or NumRanges > MAX_SWEEP_RANGES)
        return HACKRF_STATUS.HACKRF_ERROR_INVALID_PARAM;

    if (@mod(NumBytes, BYTES_PER_BLOCK) != 0)
        return HACKRF_STATUS.HACKRF_ERROR_INVALID_PARAM;

    if (BYTES_PER_BLOCK > NumBytes)
        return HACKRF_STATUS.HACKRF_ERROR_INVALID_PARAM;

    if (StepWidth < 1)
        return HACKRF_STATUS.HACKRF_ERROR_INVALID_PARAM;

    data[0] = @intCast(StepWidth & 0xFF);
    data[1] = @intCast((StepWidth >> 8) & 0xFF);
    data[2] = @intCast((StepWidth >> 16) & 0xFF);
    data[3] = @intCast((StepWidth >> 24) & 0xFF);
    data[4] = @intCast(Offset & 0xFF);
    data[5] = @intCast((Offset >> 8) & 0xFF);
    data[6] = @intCast((Offset >> 16) & 0xFF);
    data[7] = @intCast((Offset >> 24) & 0xFF);
    data[8] = @intFromEnum(Style);
    for (0..NumRanges * 2) |i| {
        data[9 + i * 2] = @truncate(FrequencyList[i] & 0xFF);
        data[10 + i * 2] = @truncate((FrequencyList[i] >> 8) & 0xFF);
    }

    const Value: u16 = @truncate(NumBytes & 0xFFFF);
    const Index: u16 = @truncate((NumBytes >> 16) & 0xFFFF);

    const iResult = driver.ControlTransfer(Device.UsbDevice, driver.ENDPOINT_OUT | driver.REQUEST_TYPE_VENDOR | driver.RECIPIENT_DEVICE, @intFromEnum(HACKRF_VENDOR_REQUEST.HACKRF_VENDOR_REQUEST_INIT_SWEEP), Value, Index, @as(*u8, @ptrCast(&data)), @truncate(size), 0);
    if (iResult < size) {
        LastUsbError = @intCast(driver.GetLastError());
        return HACKRF_STATUS.HACKRF_ERROR_LIBUSB;
    } else {
        return HACKRF_STATUS.HACKRF_SUCCESS;
    }
}

pub fn hackrf_start_rx_sweep(Device: *HackrfDevice, Callback: hackrf_sample_block_cb_fn, RxCtx: ?*anyopaque) HACKRF_STATUS {
    var usbVersion: u16 = undefined;
    var status: HACKRF_STATUS = undefined;

    status = hackrf_usb_api_version_read(Device, &usbVersion);
    if (status != HACKRF_STATUS.HACKRF_SUCCESS)
        return status;

    if (usbVersion < 0x0104)
        return HACKRF_STATUS.HACKRF_ERROR_USB_API_VERSION;

    status = hackrf_set_transceiver_mode(Device, HACKRF_TRANSCEIVER_MODE.TRANSCEIVER_MODE_RX_SWEEP);
    if (status == HACKRF_STATUS.HACKRF_SUCCESS) {
        Device.RxCtx = RxCtx;
        status = prepare_setup_transfers(Device, RX_ENDPOINT_ADDRESS, Callback);
    }

    return status;
}

pub fn hackrf_stop_cmd(Device: *HackrfDevice) HACKRF_STATUS {
    return hackrf_set_transceiver_mode(Device, HACKRF_TRANSCEIVER_MODE.HACKRF_TRANSCEIVER_MODE_OFF);
}

pub fn allocate_transfers(Device: *HackrfDevice) HACKRF_STATUS {
    if (Device.UsbTransfers == null) {
        Device.UsbTransfers = @as([*]?*driver.Transfer, @ptrCast(std.heap.page_allocator.alloc(?*driver.Transfer, TRANSFER_COUNT) catch return HACKRF_STATUS.HACKRF_ERROR_NO_MEM));

        Device.Buffer = std.mem.zeroes([TRANSFER_COUNT * TRANSFER_BUFFER_SIZE]u8);

        for (0..TRANSFER_COUNT) |transferIndex| {
            // TODO device Metho to create a transfer!
            Device.UsbTransfers.?[transferIndex] = std.heap.page_allocator.create(driver.Transfer) catch return HACKRF_STATUS.HACKRF_ERROR_NO_MEM;
            driver.SetupBulkTransfer(Device.UsbTransfers.?[transferIndex].?, Device.UsbDevice, 0, &Device.Buffer[transferIndex * TRANSFER_BUFFER_SIZE], TRANSFER_BUFFER_SIZE, null, Device, 0);
        }

        return HACKRF_STATUS.HACKRF_SUCCESS;
    } else {
        return HACKRF_STATUS.HACKRF_ERROR_BUSY;
    }
}

pub fn prepare_transfers(Device: *HackrfDevice, EndpointAddress: u8, Callback: driver.usb_transfer_cb_fn) HACKRF_STATUS {
    var result: bool = false;
    var readyTransfers: u8 = 0;

    if (Device.UsbTransfers == null)
        return HACKRF_STATUS.HACKRF_ERROR_OTHER;

    switch (EndpointAddress) {
        TX_ENDPOINT_ADDRESS => {
            for (0..TRANSFER_COUNT) |transferIndex| {
                if (Device.UsbTransfers.?[transferIndex] == null)
                    continue;
                var transfer: HackrfTransfer = .{
                    .Device = Device,
                    .Buffer = Device.UsbTransfers.?[transferIndex].?.Buffer,
                    .BufferLen = TRANSFER_BUFFER_SIZE,
                    .ValidLength = TRANSFER_BUFFER_SIZE,
                    .RxCtx = Device.RxCtx,
                    .TxCtx = Device.TxCtx,
                };

                if (Device.Callback != null and Device.Callback.?(&transfer) == 0 and transfer.ValidLength > 0) {
                    Device.UsbTransfers.?[transferIndex].?.Length = transfer.ValidLength;
                    readyTransfers += 1;
                }
            }
        },
        else => readyTransfers = TRANSFER_COUNT,
    }

    Device.TransferLock.lock();

    for (0..readyTransfers) |transferIndex| {
        if (Device.UsbTransfers.?[transferIndex] == null)
            continue;
        const transfer = Device.UsbTransfers.?[transferIndex].?;

        transfer.Endpoint = EndpointAddress;
        transfer.Callback = Callback;

        if (EndpointAddress == TX_ENDPOINT_ADDRESS) {
            while (@mod(transfer.Length, 512) != 0) {
                transfer.Buffer[transfer.Length] = 0;
                transfer.Length += 1;
            }
        }

        result = driver.SubmitTransfer(transfer);
        if (!result) {
            LastUsbError = @intCast(driver.GetLastError());
            break;
        }
        Device.ActiveTransfers += 1;
    }

    if (result) {
        Device.Streaming = (readyTransfers == TRANSFER_COUNT);
        Device.TransfersSetup = true;

        if (!Device.Streaming and Device.Flush and Device.FlushTransfer != null) {
            result = driver.SubmitTransfer(Device.FlushTransfer.?);
            if (!result)
                LastUsbError = @intCast(driver.GetLastError());
        }
    }

    Device.TransferLock.unlock();

    if (result) {
        return HACKRF_STATUS.HACKRF_SUCCESS;
    } else {
        return HACKRF_STATUS.HACKRF_ERROR_LIBUSB;
    }
}

pub fn cancel_transfers(Device: *HackrfDevice) HACKRF_STATUS {
    Device.Streaming = false;

    if (transfers_check_setup(Device) == true) {
        Device.TransferLock.lock();

        for (0..TRANSFER_COUNT) |transferIndex| {
            if (Device.UsbTransfers.?[transferIndex] != null) {
                const transfer = Device.UsbTransfers.?[transferIndex].?;
                _ = driver.Abort(transfer);
            }
        }

        if (Device.FlushTransfer != null)
            _ = driver.Abort(Device.FlushTransfer.?);

        Device.TransfersSetup = false;
        Device.Flush = false;

        defer Device.TransferLock.unlock();
        while (Device.ActiveTransfers > 0) {
            Device.AllFinishedCv.wait(&Device.TransferLock);
        }

        return HACKRF_STATUS.HACKRF_SUCCESS;
    }

    return HACKRF_STATUS.HACKRF_ERROR_OTHER;
}

// FIXME: Free Transfers
pub fn free_transfers(Device: *HackrfDevice) HACKRF_STATUS {
    if (Device.UsbTransfers != null) {
        for (0..TRANSFER_COUNT) |transferIndex| {
            if (Device.UsbTransfers.?[transferIndex] != null)
                _ = driver.FreeTransfer(Device.UsbTransfers.?[transferIndex]);
            Device.UsbTransfers.?[transferIndex] = null;
        }

        Device.UsbTransfers = null;
    }

    if (Device.FlushTransfer != null) {
        _ = driver.FreeTransfer(Device.FlushTransfer);
        Device.FlushTransfer = null;
    }

    return HACKRF_STATUS.HACKRF_SUCCESS;
}

pub fn prepare_setup_transfers(Device: *HackrfDevice, EndpointAddress: u8, Callback: hackrf_sample_block_cb_fn) HACKRF_STATUS {
    if (Device.TransfersSetup == true)
        return HACKRF_STATUS.HACKRF_ERROR_BUSY;

    Device.Callback = Callback;
    return prepare_transfers(Device, EndpointAddress, hackrf_libusb_transfer_callback);
}

pub fn create_transfer_thread(Device: *HackrfDevice) HACKRF_STATUS {
    if (Device.TransferThreadStarted == false) {
        Device.Streaming = false;
        Device.DoExit = false;

        if (std.Thread.spawn(.{}, transfer_threadproc, .{Device})) |thread| {
            Device.TransferThread = thread;
            Device.TransferThreadStarted = true;
        } else |_| {}
    } else {
        return HACKRF_STATUS.HACKRF_ERROR_BUSY;
    }

    return HACKRF_STATUS.HACKRF_SUCCESS;
}

pub fn hackrf_is_streaming(Device: *HackrfDevice) HACKRF_STATUS {
    if (Device.TransferThreadStarted and Device.Streaming and !Device.DoExit) {
        return HACKRF_STATUS.HACKRF_TRUE;
    } else {
        if (!Device.TransferThreadStarted)
            return HACKRF_STATUS.HACKRF_ERROR_STREAMING_THREAD_ERR;

        if (!Device.Streaming)
            return HACKRF_STATUS.HACKRF_ERROR_STREAMING_STOPPED;

        return HACKRF_STATUS.HACKRF_ERROR_STREAMING_EXIT_CALLED;
    }
}

pub fn kill_transfer_thread(Device: *HackrfDevice) HACKRF_STATUS {
    if (Device.TransferThreadStarted == true) {
        _ = cancel_transfers(Device);

        Device.DoExit = true;

        _ = driver.InterruptEventHandler(Context);

        Device.TransferThread.join();
        Device.TransferThreadStarted = false;
    }

    Device.DoExit = false;

    return HACKRF_STATUS.HACKRF_SUCCESS;
}

pub fn transfer_threadproc(arg: *anyopaque) void {
    var device: *HackrfDevice = @alignCast(@ptrCast(arg));
    const timeout: u64 = 500000;

    while (device.DoExit == false) {
        driver.HandleEventsTimeout(Context, timeout, null) catch |err| switch (err) {
            error.WaitTimeOut => {},
            error.OutOfMemory => break,
            else => device.Streaming = false,
        };
    }

    return;
}

pub fn transfers_check_setup(Device: *HackrfDevice) bool {
    if (Device.UsbTransfers != null and Device.TransfersSetup == true)
        return true;
    return false;
}

const max2837_ft: [17]u32 = .{ 1750000, 2500000, 3500000, 5000000, 5500000, 6000000, 7000000, 8000000, 9000000, 10000000, 12000000, 14000000, 15000000, 20000000, 24000000, 28000000, 0 };

pub fn hackrf_compute_baseband_filter_bw(BandwidthHz: u32) u32 {
    var index: usize = 0;
    for (max2837_ft, 0..) |bandwidthHz, i| {
        if (bandwidthHz >= BandwidthHz) {
            index = i;
            break;
        }
    }

    if (index != 0) {
        if (max2837_ft[index] > BandwidthHz)
            index -= 1;
    }

    return max2837_ft[index];
}

pub fn hackrf_libusb_transfer_callback(UsbTransfer: *driver.Transfer) void {
    const device: *HackrfDevice = @alignCast(@ptrCast(UsbTransfer.UserData));
    const success = UsbTransfer.Status == driver.USB_TRANSFER_STATUS.COMPLETED;
    var result: bool = false;
    var resubmit: bool = false;

    var transfer: HackrfTransfer = .{
        .Device = device,
        .RxCtx = device.RxCtx,
        .TxCtx = device.TxCtx,
        .Buffer = UsbTransfer.Buffer,
        .BufferLen = TRANSFER_BUFFER_SIZE,
        .ValidLength = UsbTransfer.ActualLength,
    };

    if (device.TxCompletionCallback != null) {
        device.TxCompletionCallback.?(&transfer, @intFromBool(success));
    }

    device.TransferLock.lock();

    if (success) {
        const cbRet = device.Callback.?(&transfer);
        if (device.Streaming and cbRet == 0 and transfer.ValidLength > 0) {
            resubmit = device.TransfersSetup;
            if (resubmit) {
                if (UsbTransfer.Endpoint == TX_ENDPOINT_ADDRESS) {
                    UsbTransfer.Length = transfer.ValidLength;
                    while (UsbTransfer.Length % 512 != 0) {
                        UsbTransfer.Buffer[UsbTransfer.Length] = 0;
                        UsbTransfer.Length += 1;
                    }
                }
                result = driver.SubmitTransfer(UsbTransfer);
            }
        } else if (device.Flush and device.FlushTransfer != null) {
            result = driver.SubmitTransfer(device.FlushTransfer.?);
            if (!result) {
                device.Streaming = false;
                device.Flush = false;
            }
        }
    } else {
        device.Streaming = false;
        device.Flush = false;
    }

    if (!resubmit or !result) {
        device.Streaming = false;
        if (device.ActiveTransfers == 1) {
            if (!device.Flush) {
                device.ActiveTransfers = 0;
                device.AllFinishedCv.broadcast();
            }
        } else {
            device.ActiveTransfers -= 1;
        }
    }

    device.TransferLock.unlock();

    return;
}
