// Window control on Linux, through GTK.
//
// The handle the plugin hands over is the application's own GtkWindow, not an
// X11 id. GTK in turn asks the compositor, which is the only thing that can
// answer under Wayland -- and the same call works under X11, so one path covers
// both instead of an Xlib one that would be dead on half the desktops.
//
// This is why the core links GTK here: on Windows it links the windowing system
// directly, and GTK is the equivalent on this platform.

#include "platform/platform.h"

#include <gtk/gtk.h>

#include "rdc_api.h"
#include "rdc_core.h"

namespace rdc {
namespace {

/// The top-level window the plugin registered. Null until it does, and again
/// after it clears it, which is what makes every command a no-op rather than a
/// crash when there is no window to act on.
GtkWindow* g_window = nullptr;

GtkWindow* Window() {
  return (g_window != nullptr && GTK_IS_WINDOW(g_window)) ? g_window : nullptr;
}

bool IsFullScreen(GtkWindow* window) {
  GdkWindow* gdk_window = gtk_widget_get_window(GTK_WIDGET(window));
  return gdk_window != nullptr &&
         (gdk_window_get_state(gdk_window) & GDK_WINDOW_STATE_FULLSCREEN) != 0;
}

void SetFullScreen(GtkWindow* window, bool full_screen) {
  if (full_screen) {
    gtk_window_fullscreen(window);
  } else {
    gtk_window_unfullscreen(window);
  }
}

}  // namespace

void SetMainWindow(void* native_window_handle) {
  g_window = native_window_handle != nullptr ? GTK_WINDOW(native_window_handle) : nullptr;
}

void RunWindowCommand(int32_t command) {
  GtkWindow* window = Window();
  if (window == nullptr) {
    return;
  }

  switch (command) {
    case RDC_WINDOW_MINIMIZE:
      gtk_window_iconify(window);
      break;
    case RDC_WINDOW_RESTORE:
      gtk_window_deiconify(window);
      gtk_window_present(window);
      break;
    case RDC_WINDOW_TOGGLE_FULLSCREEN:
      SetFullScreen(window, !IsFullScreen(window));
      break;
    case RDC_WINDOW_ENTER_FULLSCREEN:
      SetFullScreen(window, true);
      break;
    case RDC_WINDOW_LEAVE_FULLSCREEN:
      SetFullScreen(window, false);
      break;
    default:
      break;
  }
}

bool IsWindowFullScreen() {
  GtkWindow* window = Window();
  return window != nullptr && IsFullScreen(window);
}

}  // namespace rdc
