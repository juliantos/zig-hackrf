const std = @import("std");
const hackrf = @import("hackrf.zig");

const status = hackrf.HACKRF_STATUS;

fn print_board_rev(BoardRev: hackrf.HACKRF_BOARD_REV) void {
    switch (BoardRev) {
        hackrf.HACKRF_BOARD_REV.BOARD_REV_UNDETECTED, hackrf.HACKRF_BOARD_REV.BOARD_REV_UNRECOGNIZED => {
            std.debug.print("Error: Hardware revision not yet detected by firmware.\n", .{});
            return;
        },
        else => {
            std.debug.print("Hardware Revision: {s}\n", .{hackrf.hackrf_board_rev_name(BoardRev)});
            if (@intFromEnum(BoardRev) > @intFromEnum(hackrf.HACKRF_BOARD_REV.BOARD_REV_HACKRF1_OLD)) {
                if ((@intFromEnum(BoardRev) & hackrf.HACKRF_BOARD_REV_GSG) > 0) {
                    std.debug.print("Hardware appears to have been manufactured by Great Scott Gadgets.\n", .{});
                } else {
                    std.debug.print("Hardware does not appear to have been manufactured by Great Scott Gadgets.\n", .{});
                }
            }
        },
    }
    return;
}

fn print_supported_platform(Platform: u32, BoardId: u8) void {
    std.debug.print("Hardware supported by installed firmware:\n", .{});
    if ((Platform & hackrf.HACKRF_PLATFORM_JAWBREAKER) > 0) {
        std.debug.print("    Jawbreaker\n", .{});
    }
    if ((Platform & hackrf.HACKRF_PLATFORM_RAD1O) > 0) {
        std.debug.print("    rad1o\n", .{});
    }
    if ((Platform & hackrf.HACKRF_PLATFORM_HACKRF1_OG) > 0 or
        (Platform & hackrf.HACKRF_PLATFORM_HACKRF1_R9) > 0)
    {
        std.debug.print("    HackRF One\n", .{});
    }
    const boardId: hackrf.HACKRF_BOARD_ID = @enumFromInt(BoardId);
    switch (boardId) {
        hackrf.HACKRF_BOARD_ID.BOARD_ID_HACKRF1_OG => {
            if ((Platform & hackrf.HACKRF_PLATFORM_HACKRF1_OG) == 0) {
                std.debug.print("Error: Firmware does not support HackRF One revisions older than r9.\n", .{});
            }
        },
        hackrf.HACKRF_BOARD_ID.BOARD_ID_HACKRF1_R9 => {
            if ((Platform & hackrf.HACKRF_PLATFORM_HACKRF1_R9) == 0) {
                std.debug.print("Error: Firmware does not support HackRF One r9.\n", .{});
            }
        },
        hackrf.HACKRF_BOARD_ID.BOARD_ID_JAWBREAKER => {
            if ((Platform & hackrf.HACKRF_PLATFORM_JAWBREAKER) > 0) {} else {
                std.debug.print("Error: Firmware does not support hardware platform.\n", .{});
            }
        },
        hackrf.HACKRF_BOARD_ID.BOARD_ID_RAD1O => {
            if ((Platform & hackrf.HACKRF_PLATFORM_RAD1O) > 0) {} else {
                std.debug.print("Error: Firmware does not support hardware platform.\n", .{});
            }
        },
        else => {},
    }

    return;
}

pub fn main() u8 {
    var result = status.HACKRF_SUCCESS;
    var device: ?*hackrf.HackrfDevice = null;
    var version: [255]u8 = std.mem.zeroes([255]u8);
    var usbVersion: u16 = undefined;
    var partIdSerialNo: hackrf.HackrfPartIdSerialNo = undefined;
    var boardId = hackrf.HACKRF_BOARD_ID.BOARD_ID_UNDETECTED;
    var boardRev = hackrf.HACKRF_BOARD_REV.BOARD_REV_UNDETECTED;
    var supportedPlatform: u32 = undefined;
    var operaCakes: [8]u8 = std.mem.zeroes([8]u8);

    var version_fba = std.heap.FixedBufferAllocator.init(&version);
    const version_mem: *u8 = version_fba.allocator().create(u8) catch return 0xFF;

    result = hackrf.hackrf_init();
    if (result != status.HACKRF_SUCCESS) {
        std.debug.print("hackrf_init() failed: {}\n", .{status});
        return 0xFF;
    }

    std.debug.print("hackrf_info version: [zig {s}]\n", .{hackrf.VERSION});

    var list = hackrf.hackrf_device_list();

    if (list == null or list.?.UsbDeviceCount < 1) {
        std.debug.print("No HackRF boards found.\n", .{});
        return 0xFF;
    }

    for (list.?.UsbDevices.items, list.?.SerialNumbers.items, 0..) |_, serialNumber, i| {
        if (i > 0)
            std.debug.print("\n", .{});

        std.debug.print("Found HackRF\nIndex {}\n", .{i});

        if (serialNumber.len != 0) {
            const utf8SerialNumber = std.unicode.utf16leToUtf8Alloc(std.heap.page_allocator, serialNumber) catch &[_]u8{};
            std.debug.print("Serial number: {s}\n", .{utf8SerialNumber});
        }

        device = null;
        result = hackrf.hackrf_device_list_open(&list.?, i, &device);
        if (result != status.HACKRF_SUCCESS) {
            std.log.err("hackrf_open() failed ({})\n", .{result});
            if (result == status.HACKRF_ERROR_LIBUSB) {
                continue;
            }
            return 0xFF;
        }

        result = hackrf.hackrf_board_id_read(device.?, @ptrCast(&boardId));
        if (result != status.HACKRF_SUCCESS) {
            std.log.err("hackrf_board_id_read() failed ({})\n", .{result});
            return 0xFF;
        }
        std.debug.print("Board ID Number: {} ({s})\n", .{ @intFromEnum(boardId), hackrf.hackrf_board_id_name(boardId) });

        var versionLength: u16 = 255;
        result = hackrf.hackrf_version_string_read(device.?, version_mem, &versionLength);
        if (result != status.HACKRF_SUCCESS) {
            std.log.err("hackrf_version_string_read() failed ({})\n", .{result});
            return 0xFF;
        }

        result = hackrf.hackrf_usb_api_version_read(device.?, &usbVersion);
        if (result != status.HACKRF_SUCCESS) {
            std.log.err("hackrf_usb_api_version_read() failed ({})\n", .{result});
            return 0xFF;
        }
        std.debug.print("Firmware Version: {s} (API:{x}.{x:0>2})\n", .{ version[0..versionLength], (usbVersion >> 8) & 0xFF, usbVersion & 0xFF });

        result = hackrf.hackrf_board_partid_serialno_read(device.?, &partIdSerialNo);
        if (result != status.HACKRF_SUCCESS) {
            std.log.err("hackrf_board_partid_serialno_read() failed ({})\n", .{result});
            return 0xFF;
        }
        std.debug.print("Part ID Number: 0x{x:0>8} 0x{x:0>8}\n", .{ partIdSerialNo.PartId[0], partIdSerialNo.PartId[1] });

        if ((usbVersion >= 0x0106) and ((boardId == hackrf.HACKRF_BOARD_ID.BOARD_ID_HACKRF1_OG) or (boardId == hackrf.HACKRF_BOARD_ID.BOARD_ID_HACKRF1_R9))) {
            result = hackrf.hackrf_board_rev_read(device.?, @ptrCast(&boardRev));
            if (result != status.HACKRF_SUCCESS) {
                std.log.err("hackrf_board_rev_read() failed ({})\n", .{result});
                return 0xFF;
            }

            print_board_rev(boardRev);
        }

        if (usbVersion >= 0x0106) {
            result = hackrf.hackrf_supported_platform_read(device.?, &supportedPlatform);
            if (result != status.HACKRF_SUCCESS) {
                std.log.err("hackrf_supported_platform_read() failed ({})\n", .{result});
                return 0xFF;
            }

            print_supported_platform(supportedPlatform, @intFromEnum(boardId));
        }

        result = hackrf.hackrf_get_operacacke_boards(device.?, &operaCakes);
        if (result != status.HACKRF_SUCCESS and result != status.HACKRF_ERROR_USB_API_VERSION) {
            std.log.err("hackrf_get_operacake_boards() failed ({})\n", .{result});
            return 0xFF;
        }
        if (result == status.HACKRF_SUCCESS) {
            for (operaCakes) |operaCake| {
                if (operaCake == hackrf.HACKRF_OPERACAKE_ADDRESS_INVALID)
                    break;
                std.debug.print("Opera Cake found, address: {}\n", .{operaCake});
            }
        }

        result = hackrf.hackrf_close(device.?);
        if (result != status.HACKRF_SUCCESS) {
            std.log.err("hackrf_close() failed ({})\n", .{result});
            return 0xFF;
        }
    }

    hackrf.hackrf_device_list_free(&list.?);
    return @truncate(@as(u16, @intCast(@intFromEnum(hackrf.hackrf_exit()))));
}
