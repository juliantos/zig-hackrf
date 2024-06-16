const std = @import("std");
const root = @import("root.zig");
const hackrf = @import("hackrf.zig");

pub fn main() !void {
    //var deviceData: root.DEVICE_DATA = undefined;
    //var noDevice: bool = undefined;
    //var hResult: std.os.windows.HRESULT = std.math.minInt(i32);

    const context = root.Init();

    std.debug.print("Context: {any}\n", .{context});

    const devicePtr: ?root.PDEVICE_DATA = root.OpenDevice(context, hackrf.HACKRF_USB_VID, hackrf.HACKRF_ONE_USB_PID);

    std.debug.print("Data Device {?any}\n", .{devicePtr});

    //hResult = root.OpenDevice(&deviceData, &noDevice);

    //var alloc = std.heap.page_allocator;
    //const path = try std.unicode.utf16leToUtf8Alloc(alloc, deviceData.DevicePath.items[0..97]);

    //alloc.free(path);

    //var hackRFSpeed: u8 = 0;
    //const gotSpeed = root.GetHackRFSpeed(context.WinusbHandle, &hackRFSpeed);

    //std.debug.print("HackRF Speed {} {}\n", .{ gotSpeed, hackRFSpeed });

    //root.CloseDevice(&deviceData);

    return;
}
