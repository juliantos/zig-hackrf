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
    Pipes: std.ArrayList(usb.WINUSB_PIPE_INFORMATION_EX),
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

pub fn Init() ?*anyopaque {
    return setup.SetupDiGetClassDevsW(&GUID_DEVINTERFACE_HACKRF, null, null, setup.DIGCF_PRESENT | setup.DIGCF_DEVICEINTERFACE);
}

pub fn Exit(Context: ?*anyopaque) void {
    _ = setup.SetupDiDestroyDeviceInfoList(Context);
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

            if (deviceData.Handle == win.INVALID_HANDLE_VALUE)
                continue;

            bResult = usb.WinUsb_Initialize(deviceData.Handle, &deviceData.WinusbHandle);
            if (bResult == win.FALSE) {
                win.CloseHandle(deviceData.Handle.?);
                bResult = win.TRUE;
                continue;
            }

            deviceData.HandlesOpen = true;
            deviceData.Pipes = std.ArrayList(usb.WINUSB_PIPE_INFORMATION_EX).init(std.heap.page_allocator);

            Devices.append(deviceData) catch {};
        }
    }
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

        DeviceData.Pipes.append(pipe) catch {};
    }

    return hr;
}

pub fn ReleaseInterface(DeviceData: PDEVICE_DATA, InterfaceIndex: usize) win.HRESULT {
    _ = InterfaceIndex;
    DeviceData.Pipes.clearAndFree();
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
    DeviceData.Pipes.deinit();

    return;
}

pub fn ControlTransfer(DeviceData: PDEVICE_DATA, RequestType: u8, Request: u8, Value: u8, Index: u16, Data: *u8, Length: u16, Timeout: usize) win.LONG {
    _ = Timeout;

    var bResult: win.BOOL = undefined;
    const setupPacket: usb.WINUSB_SETUP_PACKET = .{
        .RequestType = RequestType,
        .Request = Request,
        .Value = Value,
        .Index = Index,
    };
    var lengthTransferred: win.ULONG = undefined;

    bResult = usb.WinUsb_ControlTransfer(DeviceData.WinusbHandle, setupPacket, Data, Length, &lengthTransferred, null);
    if (bResult != win.TRUE) {
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

pub fn GetHackRFSpeed(hDeviceHandle: usb.WINUSB_INTERFACE_HANDLE, pDeviceSpeed: ?*win.UCHAR) bool {
    if (pDeviceSpeed == null or hDeviceHandle == win.INVALID_HANDLE_VALUE)
        return false;

    var bResult: win.BOOL = win.TRUE;
    var length: win.ULONG = @sizeOf(win.UCHAR);

    bResult = usb.WinUsb_QueryDeviceInformation(hDeviceHandle, usb.DEVICE_SPEED, &length, pDeviceSpeed);

    return bResult != 0;
}

//pub fn OpenDeviceData(DeviceData: PDEVICE_DATA, FailureDeviceNotFound: *bool) win.HRESULT {
//var hr: win.HRESULT = win.S_OK;
//var bResult: win.BOOL = undefined;

//if (FailureDeviceNotFound != undefined)
//FailureDeviceNotFound.* = false;

//const address = std.unicode.utf8ToUtf16LeStringLiteral("\\\\?\\USB#VID_1D50&PID_6089#000000000000000057b068dc241b3e63#{a5dcbf10-6530-11d2-901f-00c04fb951ed}");
//DeviceData.DevicePath.appendSlice(address) catch {};

//std.debug.print("Address {u}\n", .{address});

//if (hr < 0) {
//return hr;
//}

//DeviceData.Handle = win.kernel32.CreateFileW(address, win.GENERIC_READ | win.GENERIC_WRITE, win.FILE_SHARE_READ | win.FILE_SHARE_WRITE, null, win.OPEN_EXISTING, win.FILE_ATTRIBUTE_NORMAL | win.FILE_FLAG_OVERLAPPED, null);

//if (DeviceData.Handle == win.INVALID_HANDLE_VALUE) {
//hr = HRESULT_FROM_WIN32(win.kernel32.GetLastError());
//return hr;
//}

//bResult = usb.WinUsb_Initialize(DeviceData.Handle, &DeviceData.WinusbHandle);

//if (bResult == win.FALSE) {
//hr = HRESULT_FROM_WIN32(win.kernel32.GetLastError());
//win.CloseHandle(DeviceData.Handle.?);
//return hr;
//}

//DeviceData.HandlesOpen = true;
//return hr;
//}
