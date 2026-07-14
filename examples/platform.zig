const std = @import("std");
const vk = @import("vulkan");

pub fn main() !void {
    std.log.info("generated Vulkan platform: {s}", .{@tagName(vk.platform)});
    std.log.info("Khronos registry commit: {s}", .{vk.registry_commit});

    switch (vk.platform) {
        .metal => {
            if (!@hasDecl(vk.raw, "VkMetalSurfaceCreateInfoEXT")) {
                return error.MetalDeclarationsMissing;
            }
        },
        .win32 => {
            if (!@hasDecl(vk.raw, "VkWin32SurfaceCreateInfoKHR")) {
                return error.Win32DeclarationsMissing;
            }
        },
        .xlib => {
            if (!@hasDecl(vk.raw, "VkXlibSurfaceCreateInfoKHR")) {
                return error.XlibDeclarationsMissing;
            }
        },
        .xcb => {
            if (!@hasDecl(vk.raw, "VkXcbSurfaceCreateInfoKHR")) {
                return error.XcbDeclarationsMissing;
            }
        },
        .wayland => {
            if (!@hasDecl(vk.raw, "VkWaylandSurfaceCreateInfoKHR")) {
                return error.WaylandDeclarationsMissing;
            }
        },
        .android => {
            if (!@hasDecl(vk.raw, "VkAndroidSurfaceCreateInfoKHR")) {
                return error.AndroidDeclarationsMissing;
            }
        },
        .none => {},
    }
}
