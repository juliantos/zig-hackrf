const std = @import("std");
const win = std.os.windows;
const usb = @cImport({
    @cInclude("winusb.h");
    @cInclude("usbspec.h");
});
const setup = @cImport({
    @cInclude("windows.h");
    @cInclude("setupapi.h");
    @cInclude("guiddef.h");
});

fn HRESULT_FROM_WIN32(kError: win.Win32Error) win.HRESULT {
    const cError: win.HRESULT = @intFromEnum(kError);
    if (cError <= 0) {
        return cError;
    } else {
        const kInt: u32 = @intFromEnum(kError);
        const fError: win.HRESULT = @bitCast(((kInt & 0x0000FFFF) | (0x00000007 << 16) | 0x80000000));
        return fError;
    }
}

const _DEVICE_DATA = struct {
    HandlesOpen: bool,
    WinusbHandle: usb.WINUSB_INTERFACE_HANDLE,
    Handle: ?*anyopaque,
    DevicePath: std.ArrayList(win.WCHAR),
    InPipes: std.ArrayList(usb.WINUSB_PIPE_INFORMATION_EX),
    OutPipes: std.ArrayList(usb.WINUSB_PIPE_INFORMATION_EX),
};
pub const DEVICE_DATA = _DEVICE_DATA;
pub const PDEVICE_DATA = *_DEVICE_DATA;

const _DEVICE_DESCRIPTOR = packed struct {
    Length: u8,
    DescriptorType: u8,
    USB: u16,
    DeviceClass: u8,
    DeviceSubClass: u8,
    DeviceProtocol: u8,
    MaxPacketSize0: u8,
    IdVendor: u16,
    IdProduct: u16,
    Device: u16,
    Manufacturer: u8,
    Product: u8,
    SerialNumber: u8,
    NumConfigurations: u8,
};
pub const DEVICE_DESCRIPTOR = _DEVICE_DESCRIPTOR;
pub const PDEVICE_DESCRIPTOR = *_DEVICE_DESCRIPTOR;

const _CONFIGURATION_DESCRIPTOR = packed struct {
    Length: u8,
    DescriptorType: u8,
    TotalLength: u16,
    NumInterfaces: u8,
    ConfigurationValue: u8,
    Configuration: u8,
    Attributes: u8,
    MaxPower: u8,
};
pub const CONFIGURATION_DESCRIPTOR = _CONFIGURATION_DESCRIPTOR;
pub const PCONFIGURATION_DESCRIPTOR = *_CONFIGURATION_DESCRIPTOR;

pub const STRING_DESCRIPTOR = usb.USB_STRING_DESCRIPTOR;
pub const PSTRING_DESCRIPTOR = usb.PUSB_STRING_DESCRIPTOR;

pub const GUID_DEVINTERFACE_HACKRF: setup.GUID = .{ .Data1 = 0xa5dcbf10, .Data2 = 0x6530, .Data3 = 0x11d2, .Data4 = .{ 0x90, 0x1f, 0x00, 0xc0, 0x4f, 0xb9, 0x51, 0xed } };
pub const INVALID_HANDLE_VALUE = win.INVALID_HANDLE_VALUE;

pub const ENDPOINT_IN = 0x80;
pub const ENDPOINT_OUT = 0x00;
pub const REQUEST_TYPE_VENDOR = 0x2 << 5;
pub const RECIPIENT_DEVICE = 0x00;

pub const USB_TRANSFER_TYPE = enum(u3) {
    CONTROL = 0,
    ISOCHRONOUS = 1,
    BULK = 2,
    INTERRUPT = 3,
    BULK_STREAM = 4,
};

pub const USB_TRANSFER_STATUS = enum(u3) {
    COMPLETED = 0,
    ERROR = 1,
    TIMED_OUT = 2,
    CANCELLED = 3,
    STALL = 4,
    NO_DEVICE = 5,
    OVERFLOW = 6,
};

pub const usb_transfer_cb_fn = fn (*Transfer) void;

pub const IsoPacketDescriptor = struct {
    Length: u64,
    ActualLength: u64,
    Status: USB_TRANSFER_STATUS,
};

pub const Transfer = struct {
    DeviceHandle: PDEVICE_DATA,
    Flags: u8,
    Endpoint: u8,
    Type: USB_TRANSFER_TYPE,
    Timeout: u64,
    Status: USB_TRANSFER_STATUS,
    Length: u32,
    ActualLength: u32,
    Callback: ?*const usb_transfer_cb_fn,
    UserData: ?*anyopaque,
    Buffer: [*]u8,
    NumIsoPackets: u32,
    IsoPacketDesc: [0]IsoPacketDescriptor,
};

const ActiveTransfer = struct {
    TransferPtr: *Transfer,
    Overlapped: *usb.OVERLAPPED,
};
var ActiveTransfers: std.ArrayList(ActiveTransfer) = std.ArrayList(ActiveTransfer).init(std.heap.page_allocator);
var TransferMutex: std.Thread.Mutex = .{};

pub fn Init() ?*anyopaque {
    return setup.SetupDiGetClassDevsW(&GUID_DEVINTERFACE_HACKRF, null, null, setup.DIGCF_PRESENT | setup.DIGCF_DEVICEINTERFACE);
}

pub fn Exit(Context: ?*anyopaque) void {
    _ = setup.SetupDiDestroyDeviceInfoList(Context);
}

pub fn OpenDevice(Context: ?*anyopaque, UsbVid: u16, UsbPid: u16) ?PDEVICE_DATA {
    var devices = std.ArrayList(DEVICE_DATA).init(std.heap.page_allocator);
    GetDevices(Context, &devices);

    for (devices.items, 0..) |usbDevice, i| {
        var deviceDescriptor: DEVICE_DESCRIPTOR = undefined;
        if (GetDeviceDescriptor(usbDevice, &deviceDescriptor)) {
            if (deviceDescriptor.IdVendor == UsbVid and deviceDescriptor.IdProduct == UsbPid) {
                const newDevice: PDEVICE_DATA = std.heap.page_allocator.create(DEVICE_DATA) catch return null;
                newDevice.* = devices.swapRemove(i);
                defer devices.deinit();
                return newDevice;
            }
        }
    }

    return null;
}

pub fn GetDevices(Context: ?*anyopaque, Devices: *std.ArrayList(DEVICE_DATA)) void {
    var interfaceData: setup.SP_DEVICE_INTERFACE_DATA = undefined;
    var detailData: setup.PSP_DEVICE_INTERFACE_DETAIL_DATA_W = null;
    var bResult: win.BOOL = win.TRUE;
    var index: u16 = 0;

    while (bResult != win.FALSE) {
        interfaceData = undefined;
        interfaceData.cbSize = @sizeOf(setup.SP_DEVICE_INTERFACE_DATA);

        bResult = setup.SetupDiEnumDeviceInterfaces(Context, null, &GUID_DEVINTERFACE_HACKRF, index, &interfaceData);
        index += 1;

        if (bResult == win.TRUE) {
            var requiredLength: win.ULONG = 0;

            bResult = setup.SetupDiGetDeviceInterfaceDetailW(Context, &interfaceData, null, 0, &requiredLength, null);
            if (bResult != win.TRUE and win.kernel32.GetLastError() != win.Win32Error.INSUFFICIENT_BUFFER)
                break;

            var buffer: [win.MAX_PATH * 2 + @sizeOf(win.ULONG)]u8 align(16) = std.mem.zeroes([win.MAX_PATH * 2 + @sizeOf(win.ULONG)]u8);
            var fba = std.heap.FixedBufferAllocator.init(&buffer);
            const allocator = fba.allocator();

            detailData = allocator.create(setup.SP_DEVICE_INTERFACE_DETAIL_DATA_W) catch break;
            detailData.*.cbSize = @sizeOf(setup.SP_DEVICE_INTERFACE_DETAIL_DATA_W);
            const length = requiredLength;

            bResult = setup.SetupDiGetDeviceInterfaceDetailW(Context, &interfaceData, detailData, length, &requiredLength, null);
            if (bResult != win.TRUE) {
                std.debug.print("Error {}\n", .{win.kernel32.GetLastError()});
                break;
            }

            var deviceData: DEVICE_DATA = undefined;
            deviceData.DevicePath = std.ArrayList(win.WCHAR).init(std.heap.page_allocator);
            for (@as(*align(1) const [win.MAX_PATH]u16, @ptrCast(&buffer[@sizeOf(win.ULONG)])), 0..) |elem, i| {
                if (i >= (length - @sizeOf(win.ULONG)) / 2 - 1)
                    break;
                deviceData.DevicePath.append(elem) catch {};
            }

            const sentinel = deviceData.DevicePath.toOwnedSliceSentinel(0) catch &[_:0]u16{};
            deviceData.Handle = win.kernel32.CreateFileW(sentinel, win.GENERIC_READ | win.GENERIC_WRITE, win.FILE_SHARE_READ | win.FILE_SHARE_WRITE, null, win.OPEN_EXISTING, win.FILE_ATTRIBUTE_NORMAL | win.FILE_FLAG_OVERLAPPED, null);
            deviceData.DevicePath.appendSlice(sentinel) catch {};

            defer allocator.destroy(@as(*setup.SP_DEVICE_INTERFACE_DETAIL_DATA_W, @ptrCast(detailData)));
            //detailData = null; // previous cast nullifies

            if (deviceData.Handle == win.INVALID_HANDLE_VALUE)
                continue;

            bResult = usb.WinUsb_Initialize(deviceData.Handle, &deviceData.WinusbHandle);
            if (bResult == win.FALSE) {
                win.CloseHandle(deviceData.Handle.?);
                bResult = win.TRUE;
                continue;
            }

            deviceData.HandlesOpen = true;
            deviceData.InPipes = std.ArrayList(usb.WINUSB_PIPE_INFORMATION_EX).init(std.heap.page_allocator);
            deviceData.OutPipes = std.ArrayList(usb.WINUSB_PIPE_INFORMATION_EX).init(std.heap.page_allocator);

            Devices.append(deviceData) catch {};
        }
    }
}

pub fn HandleEventsTimeout(Context: ?*anyopaque, Timeout: u64, Completed: ?*bool) !void {
    _ = Context;
    _ = Completed;
    //_ = Timeout;

    var handles = std.ArrayList(?*anyopaque).initCapacity(std.heap.page_allocator, ActiveTransfers.items.len) catch return error.OutOfMemory;
    defer handles.deinit();

    TransferMutex.lock();
    for (ActiveTransfers.items) |activeTransfer| {
        handles.append(activeTransfer.Overlapped.hEvent) catch {
            TransferMutex.unlock();
            return error.OutOfMemory;
        };
    }
    TransferMutex.unlock();

    const millis = Timeout / std.time.ns_per_ms;
    if (handles.items.len > 0) {
        const val = usb.WaitForMultipleObjectsEx(@intCast(handles.items.len), @ptrCast(handles.items), win.FALSE, @intCast(millis), win.TRUE);
        switch (val) {
            usb.WAIT_OBJECT_0...(usb.WAIT_OBJECT_0 + usb.MAXIMUM_WAIT_OBJECTS) => {
                const index = val - usb.WAIT_OBJECT_0;

                TransferMutex.lock();
                const activeTransfer = ActiveTransfers.swapRemove(index);
                TransferMutex.unlock();
                var bytes: win.DWORD = undefined;
                const result = usb.WinUsb_GetOverlappedResult(activeTransfer.TransferPtr.DeviceHandle.WinusbHandle, activeTransfer.Overlapped, &bytes, win.FALSE);
                if (result != 0) {
                    activeTransfer.TransferPtr.ActualLength = bytes;
                    activeTransfer.TransferPtr.Status = USB_TRANSFER_STATUS.COMPLETED;
                } else {
                    activeTransfer.TransferPtr.Status = USB_TRANSFER_STATUS.ERROR;
                }

                if (activeTransfer.TransferPtr.Callback != null)
                    activeTransfer.TransferPtr.Callback.?(activeTransfer.TransferPtr);
                defer std.heap.page_allocator.destroy(activeTransfer.Overlapped);
            },
            usb.WAIT_ABANDONED_0...(usb.WAIT_ABANDONED_0 + usb.MAXIMUM_WAIT_OBJECTS) => {
                const index = val - usb.WAIT_ABANDONED_0;
                TransferMutex.lock();
                const activeTransfer = ActiveTransfers.swapRemove(index);
                defer std.heap.page_allocator.destroy(activeTransfer.Overlapped);
                TransferMutex.unlock();
            },
            usb.WAIT_TIMEOUT => {
                return error.WaitTimeOut;
            },
            else => return error.WaitFailed,
        }
    } else {
        std.time.sleep(Timeout);
    }
}

pub fn InterruptEventHandler(Context: ?*anyopaque) win.HRESULT {
    _ = Context;

    TransferMutex.lock();
    for (ActiveTransfers.items) |activeTransfer| {
        _ = usb.CloseHandle(activeTransfer.Overlapped.hEvent);
        var bytes: win.DWORD = undefined;
        const result = usb.WinUsb_GetOverlappedResult(activeTransfer.TransferPtr.DeviceHandle.WinusbHandle, activeTransfer.Overlapped, &bytes, win.FALSE);
        if (result != 0) {
            activeTransfer.TransferPtr.ActualLength = bytes;
            activeTransfer.TransferPtr.Status = USB_TRANSFER_STATUS.COMPLETED;
        } else {
            activeTransfer.TransferPtr.Status = USB_TRANSFER_STATUS.ERROR;
        }

        if (activeTransfer.TransferPtr.Callback != null)
            activeTransfer.TransferPtr.Callback.?(activeTransfer.TransferPtr);
    }
    ActiveTransfers.clearAndFree();

    TransferMutex.unlock();

    return win.S_OK;
}

pub fn ClaimInterface(DeviceData: PDEVICE_DATA, InterfaceIndex: usize) win.HRESULT {
    _ = InterfaceIndex;
    if (DeviceData.HandlesOpen == false or DeviceData.WinusbHandle == win.INVALID_HANDLE_VALUE)
        return win.S_FALSE;
    var bResult: win.BOOL = win.TRUE;
    var usbInterface: usb.USB_INTERFACE_DESCRIPTOR = undefined;
    var pipe: usb.WINUSB_PIPE_INFORMATION_EX = undefined;
    var hr: win.HRESULT = win.S_OK;

    bResult = usb.WinUsb_QueryInterfaceSettings(DeviceData.WinusbHandle, 0, &usbInterface);
    if (bResult == win.FALSE) {
        hr = HRESULT_FROM_WIN32(win.kernel32.GetLastError());
        return hr;
    }

    for (0..usbInterface.bNumEndpoints) |index| {
        bResult = usb.WinUsb_QueryPipeEx(DeviceData.WinusbHandle, 0, @intCast(index), &pipe);
        if (bResult == win.FALSE) {
            hr = HRESULT_FROM_WIN32(win.kernel32.GetLastError());
            return hr;
        }

        if (pipe.PipeId & 0x80 > 0) {
            DeviceData.OutPipes.append(pipe) catch {};
        } else {
            DeviceData.InPipes.append(pipe) catch {};
        }
    }

    return hr;
}

pub fn ReleaseInterface(DeviceData: PDEVICE_DATA, InterfaceIndex: usize) win.HRESULT {
    _ = InterfaceIndex;
    DeviceData.OutPipes.clearAndFree();
    DeviceData.InPipes.clearAndFree();
    return win.S_OK;
}

pub fn CloseDevice(DeviceData: PDEVICE_DATA) void {
    if (DeviceData.HandlesOpen == false) {
        return;
    }

    _ = usb.WinUsb_Free(DeviceData.WinusbHandle);
    win.CloseHandle(DeviceData.Handle.?);
    DeviceData.HandlesOpen = false;
    DeviceData.WinusbHandle = null;
    DeviceData.Handle = null;
    DeviceData.DevicePath.deinit();
    DeviceData.InPipes.deinit();
    DeviceData.OutPipes.deinit();

    return;
}

pub fn ControlTransfer(DeviceData: PDEVICE_DATA, RequestType: u8, Request: u8, Value: u16, Index: u16, Data: *u8, Length: u16, Timeout: usize) win.LONG {
    _ = Timeout;

    var bResult: win.BOOL = undefined;
    const setupPacket: usb.WINUSB_SETUP_PACKET = .{
        .RequestType = RequestType,
        .Request = Request,
        .Value = Value,
        .Index = Index,
    };
    var lengthTransferred: win.ULONG = undefined;

    //std.debug.print("RT 0x{b:0>8}, R 0x{x:0>2}, V {d:>5}, I {d:>5}, D {x:0>2}, L {d:>5}\n", .{ RequestType, Request, Value, Index, Data.*, Length });

    bResult = usb.WinUsb_ControlTransfer(DeviceData.WinusbHandle, setupPacket, Data, Length, &lengthTransferred, null);
    if (bResult != win.TRUE) {
        std.log.err("WinUsb CT error ({})\n", .{@intFromEnum(win.kernel32.GetLastError())});
        return -1;
    }

    return @intCast(lengthTransferred);
}

pub fn GetDeviceDescriptor(DeviceData: DEVICE_DATA, pDeviceDescriptor: ?PDEVICE_DESCRIPTOR) bool {
    if (pDeviceDescriptor == null or DeviceData.HandlesOpen == false or DeviceData.WinusbHandle == win.INVALID_HANDLE_VALUE)
        return false;

    var bResult: win.BOOL = win.TRUE;
    var lengthOut: win.ULONG = 0;

    bResult = usb.WinUsb_GetDescriptor(DeviceData.WinusbHandle, usb.USB_DEVICE_DESCRIPTOR_TYPE, 0, 0, std.mem.asBytes(pDeviceDescriptor.?), 18, &lengthOut);

    return bResult != 0;
}

pub fn GetConfigurationDescriptor(DeviceData: DEVICE_DATA, pConfigurationDescriptor: ?PCONFIGURATION_DESCRIPTOR) bool {
    if (pConfigurationDescriptor == null or DeviceData.HandlesOpen == false or DeviceData.WinusbHandle == win.INVALID_HANDLE_VALUE)
        return false;

    var bResult: win.BOOL = win.TRUE;
    var lengthOut: win.ULONG = 0;

    bResult = usb.WinUsb_GetDescriptor(DeviceData.WinusbHandle, usb.USB_CONFIGURATION_DESCRIPTOR_TYPE, 0, 0, std.mem.asBytes(pConfigurationDescriptor.?), 9, &lengthOut);

    return bResult != 0;
}

pub fn GetStringDescriptor(DeviceData: DEVICE_DATA, index: u8, pStringDescriptor: usb.PUSB_STRING_DESCRIPTOR) bool {
    if (pStringDescriptor == null or DeviceData.HandlesOpen == false or DeviceData.WinusbHandle == win.INVALID_HANDLE_VALUE)
        return false;

    var bResult: win.BOOL = win.TRUE;
    var lengthOut: win.ULONG = 255;

    bResult = usb.WinUsb_GetDescriptor(DeviceData.WinusbHandle, usb.USB_STRING_DESCRIPTOR_TYPE, index, 0, std.mem.asBytes(pStringDescriptor), 256, &lengthOut);

    return bResult != 0;
}

pub fn GetLastError() usize {
    return @intFromEnum(win.kernel32.GetLastError());
}

pub fn SetConfigurationDescriptor(DeviceData: DEVICE_DATA, ConfigurationDescriptor: CONFIGURATION_DESCRIPTOR) bool {
    // TODO: Windows doesn't support Configuration Changes with WinUSB
    _ = DeviceData;
    _ = ConfigurationDescriptor;

    return true;
}

pub fn SetupBulkTransfer(TransferPtr: *Transfer, UsbDevice: PDEVICE_DATA, Endpoint: u8, Buffer: *u8, BufferLen: u32, Callback: ?*const usb_transfer_cb_fn, UserData: ?*anyopaque, Timeout: usize) void {
    TransferPtr.DeviceHandle = UsbDevice;
    TransferPtr.Flags = 0;
    TransferPtr.Endpoint = Endpoint;
    TransferPtr.Type = USB_TRANSFER_TYPE.BULK;
    TransferPtr.Timeout = Timeout;
    TransferPtr.Status = USB_TRANSFER_STATUS.COMPLETED;
    TransferPtr.Length = BufferLen;
    TransferPtr.ActualLength = 0;
    TransferPtr.Callback = Callback;
    TransferPtr.UserData = UserData;
    TransferPtr.Buffer = @ptrCast(Buffer);
    TransferPtr.NumIsoPackets = 0;

    return;
}

pub fn SubmitTransfer(TransferPtr: *Transfer) bool {
    var activeTransfer: ActiveTransfer = undefined;
    activeTransfer.Overlapped = std.heap.page_allocator.create(usb.OVERLAPPED) catch return false;
    activeTransfer.Overlapped.hEvent = usb.CreateEventA(null, win.TRUE, win.TRUE, null);
    activeTransfer.Overlapped.unnamed_0.unnamed_0.Offset = 0;
    activeTransfer.Overlapped.unnamed_0.unnamed_0.OffsetHigh = 0;
    activeTransfer.TransferPtr = TransferPtr;

    var iReturn: win.BOOL = win.FALSE;
    if (TransferPtr.Endpoint & ENDPOINT_IN > 0) {
        iReturn = usb.WinUsb_ReadPipe(TransferPtr.DeviceHandle.WinusbHandle, TransferPtr.Endpoint, TransferPtr.Buffer, TransferPtr.Length, &TransferPtr.ActualLength, activeTransfer.Overlapped);
    } else {
        iReturn = usb.WinUsb_WritePipe(TransferPtr.DeviceHandle.WinusbHandle, TransferPtr.Endpoint, TransferPtr.Buffer, TransferPtr.Length, &TransferPtr.ActualLength, activeTransfer.Overlapped);
    }

    TransferMutex.lock();
    ActiveTransfers.append(activeTransfer) catch {
        TransferMutex.unlock();
        return false;
    };
    TransferMutex.unlock();
    return iReturn == win.FALSE and GetLastError() == usb.ERROR_IO_PENDING;
}

pub fn Abort(TransferPtr: *Transfer) bool {
    for (TransferPtr.DeviceHandle.OutPipes.items) |pipe| {
        if (pipe.PipeId == TransferPtr.Endpoint) {
            const abort = usb.WinUsb_AbortPipe(TransferPtr.DeviceHandle, pipe.PipeId);
            const flush = usb.WinUsb_FlushPipe(TransferPtr.DeviceHandle, pipe.PipeId);

            TransferMutex.lock();
            for (ActiveTransfers.items) |activeTransfer| {
                if (TransferPtr.Endpoint == activeTransfer.TransferPtr.Endpoint) {
                    _ = usb.SetEvent(activeTransfer.Overlapped.hEvent);
                }
            }
            TransferMutex.unlock();
            return abort == win.TRUE and flush == win.TRUE;
        }
    }
    return false;
}

pub fn FreeTransfer(TransferPtr: ?*Transfer) bool {
    if (TransferPtr != null) {
        TransferPtr.?.Callback = null;
        TransferPtr.?.UserData = null;

        defer std.heap.page_allocator.destroy(TransferPtr.?);
    }

    return true;
}
