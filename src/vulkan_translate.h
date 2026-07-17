#ifndef VK_ZIG_TRANSLATE_H_
#define VK_ZIG_TRANSLATE_H_

#define VK_NO_PROTOTYPES 1
#define VK_ENABLE_BETA_EXTENSIONS 1
#include <vulkan/vulkan_core.h>
#include <vulkan/vulkan_beta.h>

#if defined(VK_ZIG_PLATFORM_METAL)
#include <vulkan/vulkan_metal.h>
#endif
#if defined(VK_ZIG_PLATFORM_WIN32)
/* Vulkan's Win32 declarations only need these handle and scalar types. */
typedef void *HANDLE;
typedef struct HINSTANCE__ *HINSTANCE;
typedef struct HWND__ *HWND;
typedef struct HMONITOR__ *HMONITOR;
typedef const uint16_t *LPCWSTR;
typedef uint32_t DWORD;
typedef struct _SECURITY_ATTRIBUTES SECURITY_ATTRIBUTES;
#include <vulkan/vulkan_win32.h>
#endif
#if defined(VK_ZIG_PLATFORM_XLIB)
typedef struct _XDisplay Display;
typedef unsigned long XID;
typedef XID Window;
typedef XID VisualID;
#include <vulkan/vulkan_xlib.h>
#endif
#if defined(VK_ZIG_PLATFORM_XCB)
typedef struct xcb_connection_t xcb_connection_t;
typedef uint32_t xcb_window_t;
typedef uint32_t xcb_visualid_t;
#include <vulkan/vulkan_xcb.h>
#endif
#if defined(VK_ZIG_PLATFORM_WAYLAND)
struct wl_display;
struct wl_surface;
#include <vulkan/vulkan_wayland.h>
#endif
#if defined(VK_ZIG_PLATFORM_ANDROID)
#include <vulkan/vulkan_android.h>
#endif

#endif
