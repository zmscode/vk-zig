#ifndef VK_ZIG_TRANSLATE_H_
#define VK_ZIG_TRANSLATE_H_

#define VK_NO_PROTOTYPES 1
#include <vulkan/vulkan_core.h>

#if defined(VK_ZIG_PLATFORM_METAL)
#include <vulkan/vulkan_metal.h>
#elif defined(VK_ZIG_PLATFORM_WIN32)
#include <windows.h>
#include <vulkan/vulkan_win32.h>
#elif defined(VK_ZIG_PLATFORM_XLIB)
#include <X11/Xlib.h>
#include <vulkan/vulkan_xlib.h>
#elif defined(VK_ZIG_PLATFORM_XCB)
#include <xcb/xcb.h>
#include <vulkan/vulkan_xcb.h>
#elif defined(VK_ZIG_PLATFORM_WAYLAND)
#include <wayland-client.h>
#include <vulkan/vulkan_wayland.h>
#endif

#endif
