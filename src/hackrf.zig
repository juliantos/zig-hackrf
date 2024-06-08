const std = @import("std");
const driver = @import("root.zig");

pub const VERSION: [:0]const u8 = "1.0.0";

var Context: ?*anyopaque = null;
var DeviceCount: u8 = 0;
var LastUsbError: i32 = 0;

pub const HACKRF_USB_VID: u16 = 0x1d50;
pub const HACKRF_JAWBREAKER_USB_PID: u16 = 0x604b;
pub const HACKRF_ONE_USB_PID: u16 = 0x06089;
pub const RADIO_USB_PID: u16 = 0xcc15;

pub const TRANSFER_COUNT: usize = 4;
pub const TRANSFER_BUFFER_SIZE: usize = 262144;

pub const USB_CONFIG_STANDARD: i32 = 0x1;

pub const HACKRF_BOARD_REV_GSG: u8 = 0x80;
pub const HACKRF_PLATFORM_JAWBREAKER: u32 = (1 << 0);
pub const HACKRF_PLATFORM_HACKRF1_OG: u32 = (1 << 1);
pub const HACKRF_PLATFORM_RAD1O: u32 = (1 << 2);
pub const HACKRF_PLATFORM_HACKRF1_R9: u32 = (1 << 3);

pub const HACKRF_OPERACAKE_ADDRESS_INVALID = 0xff;

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
    Buffer: *u8,
    BufferLen: usize,
    ValidLength: usize,
    RxCtx: ?*anyopaque,
    TxCtx: ?*anyopaque,
};

pub const hackrf_sample_block_cb_fn = fn (Transfer: *HackrfTransfer) i32;
pub const hackrf_flush_cb_fn = fn (FlushCtx: ?*anyopaque, i32) void;
pub const hackrf_tx_block_completion_cb_fn = fn (Transfer: *HackrfTransfer, i32) void;
pub const HackrfDevice = struct {
    UsbDevice: driver.PDEVICE_DATA,
    UsbTransfers: ?**anyopaque, // Not sure what the libusb_transfer type is
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
    FlushTransfer: ?*anyopaque, // Not sure what the libusbtransfer type isize
    FlushCallback: ?*const hackrf_flush_cb_fn,
    TxCompletionCallback: ?*const hackrf_tx_block_completion_cb_fn,
    FlushCtx: ?*anyopaque,
};

pub fn hackrf_init() HACKRF_STATUS {
    if (Context != null)
        return HACKRF_STATUS.HACKRF_SUCCESS;

    Context = driver.Init();

    if (Context == driver.INVALID_HANDLE_VALUE) {
        LastUsbError = -1; //FIXME: should match libusb
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

    // FIXME kill concurrency

    _ = driver.ReleaseInterface(Device.UsbDevice, 0);
    driver.CloseDevice(Device.UsbDevice);

    DeviceCount -= 1;
    if (result_thread != HACKRF_STATUS.HACKRF_SUCCESS) {
        return result_thread;
    }

    return result_stop;
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
                        }
                    },
                    else => {},
                }
            }
        }
    }

    return deviceList;
}

pub fn hackrf_device_list_open(DeviceList: *HACKRF_DEVICE_LIST, Index: usize, Device: *?*HackrfDevice) HACKRF_STATUS {
    if (Index > DeviceList.UsbDevices.items.len)
        return HACKRF_STATUS.HACKRF_ERROR_INVALID_PARAM;

    return hackrf_open_setup(&DeviceList.UsbDevices.items[Index], Device);
}

pub fn hackrf_open_setup(UsbDevice: driver.PDEVICE_DATA, Device: *?*HackrfDevice) HACKRF_STATUS {
    var result: i16 = undefined;
    var libDevice: HackrfDevice = undefined;

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

    result = @intFromEnum(allocate_transfers(&libDevice));
    if (result != 0) {
        _ = driver.ReleaseInterface(UsbDevice, 0);
        driver.CloseDevice(UsbDevice);
        return HACKRF_STATUS.HACKRF_ERROR_NO_MEM;
    }

    result = @intFromEnum(create_transfer_thread(&libDevice));
    if (result != 0) {
        _ = driver.ReleaseInterface(UsbDevice, 0);
        driver.CloseDevice(UsbDevice);
        return @enumFromInt(result);
    }

    Device.* = &libDevice;
    DeviceCount += 1;

    return @enumFromInt(result);
}

pub fn hackrf_device_list_free(DeviceList: *HACKRF_DEVICE_LIST) void {
    DeviceList.UsbDeviceCount = 0;
    DeviceList.UsbDevices.deinit();
    DeviceList.SerialNumbers.deinit();
    DeviceList.UsbBoardIds.deinit();
}

pub fn hackrf_board_id_read(Device: *const HackrfDevice, value: *u8) HACKRF_STATUS {
    const iResult = driver.ControlTransfer(Device.UsbDevice, 0x80 | 0x2 << 5 | 0x0, @intFromEnum(HACKRF_VENDOR_REQUEST.HACKRF_VENDOR_REQUEST_BOARD_ID_READ), 0, 0, value, 1, 0);

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
    const iResult = driver.ControlTransfer(Device.UsbDevice, 0x80 | 0x2 << 5, @intFromEnum(HACKRF_VENDOR_REQUEST.HACKRF_VENDOR_REQUEST_VERSION_STRING_READ), 0, 0, Version, Length.*, 0);

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
    const iResult = driver.ControlTransfer(Device.UsbDevice, 0x80 | 0x2 << 5, @intFromEnum(HACKRF_VENDOR_REQUEST.HACKRF_VENDOR_REQUEST_BOARD_PARTID_SERIALNO_READ), 0, 0, @ptrCast(std.mem.asBytes(PartIdSerialNo)), @sizeOf(HackrfPartIdSerialNo), 0);

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

    const iResult = driver.ControlTransfer(Device.UsbDevice, 0x80 | 0x2 << 5, @intFromEnum(HACKRF_VENDOR_REQUEST.HACKRF_VENDOR_REQUEST_BOARD_REV_READ), 0, 0, Value, 1, 0);
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
    const iResult = driver.ControlTransfer(Device.UsbDevice, 0x80 | 0x2 << 5, @intFromEnum(HACKRF_VENDOR_REQUEST.HACKRF_VENDOR_REQUEST_SUPPORTED_PLATFORM_READ), 0, 0, @as(*u8, @ptrCast(&data)), 4, 0);
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

    const iResult = driver.ControlTransfer(Device.UsbDevice, 0x80 | 0x2 << 5, @intFromEnum(HACKRF_VENDOR_REQUEST.HACKRF_VENDOR_REQUEST_OPERACAKE_GET_BOARDS), 0, 0, @as(*u8, @ptrCast(Boards)), 8, 0);
    if (iResult < 0) {
        LastUsbError = @intCast(driver.GetLastError());
        return HACKRF_STATUS.HACKRF_ERROR_LIBUSB;
    }

    return HACKRF_STATUS.HACKRF_SUCCESS;
}

pub fn hackrf_set_transceiver_mode(Device: *HackrfDevice, Value: HACKRF_TRANSCEIVER_MODE) HACKRF_STATUS {
    var empty: u8 = undefined;
    const iResult = driver.ControlTransfer(Device.UsbDevice, 0x00 | 0x2 << 5, @intFromEnum(HACKRF_VENDOR_REQUEST.HACKRF_VENDOR_REQUEST_SET_TRANSCEIVER_MODE), @intFromEnum(Value), 0, &empty, 0, 0);
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

pub fn hackrf_stop_cmd(Device: *HackrfDevice) HACKRF_STATUS {
    return hackrf_set_transceiver_mode(Device, HACKRF_TRANSCEIVER_MODE.HACKRF_TRANSCEIVER_MODE_OFF);
}

// FIXME: Allocate Transfers
pub fn allocate_transfers(Device: *HackrfDevice) HACKRF_STATUS {
    if (Device.UsbTransfers == null) {
        //var transferIndex: u32 = undefined;
        //Device.UsbTransfers =
        return HACKRF_STATUS.HACKRF_SUCCESS;
    } else {
        return HACKRF_STATUS.HACKRF_ERROR_BUSY;
    }
}

// FIXME: Cancel Transfers
pub fn cancel_transfers(Device: *HackrfDevice) HACKRF_STATUS {
    _ = Device;

    return HACKRF_STATUS.HACKRF_SUCCESS;
}

// FIXME: Free Transfers
pub fn free_transfers(Device: *HackrfDevice) HACKRF_STATUS {
    Device.UsbTransfers = null;

    return HACKRF_STATUS.HACKRF_SUCCESS;
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

pub fn kill_transfer_thread(Device: *HackrfDevice) HACKRF_STATUS {
    if (Device.TransferThreadStarted == true) {
        _ = cancel_transfers(Device);

        Device.DoExit = true;

        //FIXME: interupt event handler

        Device.TransferThread.join();
        Device.TransferThreadStarted = false;
    }

    Device.DoExit = true;

    return HACKRF_STATUS.HACKRF_SUCCESS;
}

pub fn transfer_threadproc(arg: *anyopaque) void {
    var device: *HackrfDevice = @alignCast(@ptrCast(arg));
    const deviceError: i32 = 1;

    while (device.DoExit == false) {
        //FIXME: Handle timeouts PIPE POLICY?

        if (deviceError != 0) {
            device.Streaming = false;
        }
    }

    return;
}
