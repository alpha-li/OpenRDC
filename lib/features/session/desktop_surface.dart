/// Renders the remote desktop and turns local input into RDP input.
///
/// The desktop is letterboxed into whatever space is available, so every
/// pointer position has to be mapped from widget space into remote-desktop
/// space. Keyboard events go out as scancodes so the *host's* layout decides
/// what each key produces, which is what a hardware KVM does and what makes
/// remote typing match the remote keyboard indicator.
library;

import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../engine/rdc_engine.dart';
import 'scancode_map.dart';

/// Keyboard shortcuts the client handles itself instead of forwarding.
///
/// Both require Ctrl+Alt, which is not a combination Windows or any common
/// application claims, so hijacking it costs the remote session nothing.
enum RemoteShortcut {
  /// Ctrl+Alt+Home — reveal the connection bar when nothing else is visible.
  connectionBar,

  /// Ctrl+Alt+Enter — switch between full screen and a window.
  ///
  /// The Windows App uses Ctrl+Alt+Pause for this, and Pause is deliberately
  /// not used here: its PS/2 encoding is the multi-byte sequence E1 1D 45
  /// rather than a single scancode, and Flutter's Windows key mapping does not
  /// produce a physical key for it, so the shortcut would silently never fire.
  /// Enter is unambiguous and reaches the application reliably.
  fullScreen,
}

class DesktopSurface extends StatefulWidget {
  const DesktopSurface({
    super.key,
    required this.engine,
    required this.textureId,
    required this.desktopSize,
    this.swapMouseButtons = false,
    this.fitToWindow = true,
    this.cursor,
    this.onFocusLost,
    this.onLocalShortcut,
  });

  final RdcEngine engine;

  /// Engine texture to draw, or -1 when registration failed.
  final int textureId;

  /// Remote desktop geometry, or null before the host reports it.
  final RdcDesktopSize? desktopSize;

  /// The remote machine's pointer, or null before it has sent one. Anything but
  /// the ordinary arrow is a picture, which is drawn here at the pointer's
  /// position: the local pointer is hidden over the desktop in that case, so
  /// that what the user sees is the host's pointer and not two of them.
  final RdcCursorShape? cursor;

  /// Sends button 2 where button 1 was pressed and vice versa. Some left-handed
  /// users configure this per connection rather than at the OS level.
  final bool swapMouseButtons;

  /// Scale the desktop to fill the window. When false it is drawn at its own
  /// size and scrolled if it does not fit.
  final bool fitToWindow;

  /// Called when the local window loses focus, so held keys can be released
  /// rather than left stuck down on the remote side.
  final VoidCallback? onFocusLost;

  /// Invoked for keyboard shortcuts that belong to the client rather than the
  /// remote session. Returning true consumes the key so it is not forwarded.
  ///
  /// These exist because the client needs an escape hatch that still works when
  /// the session owns the whole screen: the connection bar is hidden and there
  /// is no chrome left to click.
  final bool Function(RemoteShortcut shortcut)? onLocalShortcut;

  @override
  State<DesktopSurface> createState() => _DesktopSurfaceState();
}

class _DesktopSurfaceState extends State<DesktopSurface> {
  final FocusNode _focusNode = FocusNode(debugLabel: 'remote-desktop');

  /// Bitmask of the buttons the remote has been told are down. Tracked so a
  /// release is never sent for a button whose press was not delivered, which
  /// the server treats as a protocol error.
  int _buttonsDown = 0;

  /// Whether Ctrl and Alt are currently held, tracked so the client's own
  /// shortcuts can be recognised and withheld from the remote session.
  bool _ctrlDown = false;
  bool _altDown = false;

  /// Used only when the desktop is shown at its own size and does not fit;
  /// [ScrollController.hasClients] is false otherwise, which is how the
  /// coordinate mapping knows there is no offset to apply.
  final ScrollController _horizontalScroll = ScrollController();
  final ScrollController _verticalScroll = ScrollController();

  /// Where the pointer is inside this widget, or null when it is elsewhere.
  /// The remote cursor is drawn here, since the platform cannot be asked to
  /// draw a picture as a cursor.
  Offset? _pointer;

  /// The remote cursor decoded for painting, and the generation it came from,
  /// so a decode that finishes after a newer shape arrived can be dropped
  /// rather than painted over it.
  ui.Image? _cursorImage;
  int _cursorGeneration = 0;

  @override
  void initState() {
    super.initState();
    _decodeCursor();
    // The desktop wants the keyboard as soon as it appears; requiring a click
    // first would make every session start with a dead keyboard.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void didUpdateWidget(DesktopSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The engine hands over a fresh buffer for every shape, so identity is what
    // says "this is a different pointer" rather than the values inside it.
    if (!identical(widget.cursor?.pixels, oldWidget.cursor?.pixels) ||
        widget.cursor?.kind != oldWidget.cursor?.kind) {
      _decodeCursor();
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _horizontalScroll.dispose();
    _verticalScroll.dispose();
    _cursorImage?.dispose();
    super.dispose();
  }

  /// Turns the remote pointer's pixels into something that can be painted.
  ///
  /// Decoding is asynchronous, so anything that is still in flight when the
  /// shape changes again is dropped: painting it would put the wrong pointer on
  /// screen for a frame, which is exactly what a fast-moving pointer produces.
  void _decodeCursor() {
    final shape = widget.cursor;
    final pixels = shape?.pixels;
    final generation = ++_cursorGeneration;

    if (shape == null || shape.kind != RdcCursorKind.image || pixels == null) {
      if (_cursorImage != null) {
        _cursorImage!.dispose();
        _cursorImage = null;
      }
      return;
    }

    ui.decodeImageFromPixels(
      pixels,
      shape.width,
      shape.height,
      ui.PixelFormat.rgba8888,
      (image) {
        if (!mounted || generation != _cursorGeneration) {
          image.dispose();
          return;
        }
        setState(() {
          _cursorImage?.dispose();
          _cursorImage = image;
        });
      },
    );
  }

  /// What the platform should draw for the pointer over the desktop.
  ///
  /// The host's pointer is drawn here instead whenever it is a picture, so the
  /// platform's own must not also appear. That swap waits until the picture has
  /// been decoded, otherwise there would be a frame with no pointer at all.
  MouseCursor get _platformCursor {
    final shape = widget.cursor;
    if (shape == null) {
      return SystemMouseCursors.basic;
    }
    return switch (shape.kind) {
      RdcCursorKind.hidden => SystemMouseCursors.none,
      RdcCursorKind.image => _cursorImage == null
          ? SystemMouseCursors.basic
          : SystemMouseCursors.none,
      RdcCursorKind.defaultArrow => SystemMouseCursors.basic,
    };
  }

  /// The host's pointer, positioned so that its hotspot sits under the pointer.
  Widget? _buildRemoteCursor() {
    final image = _cursorImage;
    final shape = widget.cursor;
    final pointer = _pointer;
    if (image == null || shape == null || pointer == null) {
      return null;
    }

    return Positioned(
      left: pointer.dx - shape.hotspotX,
      top: pointer.dy - shape.hotspotY,
      child: RawImage(
        image: image,
        width: shape.width.toDouble(),
        height: shape.height.toDouble(),
        // Pixels are pixels: smoothing a cursor would make it a blur at the one
        // size it was drawn for.
        filterQuality: FilterQuality.none,
      ),
    );
  }

  /// How far the desktop is scrolled behind the viewport, in logical pixels.
  ///
  /// Zero in the fitted case, where nothing scrolls, and zero in the natural
  /// case for whichever axis actually fits.
  Offset get _scrollOffset => Offset(
    _horizontalScroll.hasClients ? _horizontalScroll.offset : 0,
    _verticalScroll.hasClients ? _verticalScroll.offset : 0,
  );

  /// The rectangle the desktop occupies inside [box].
  ///
  /// When fitting to the window it is letterboxed, preserving the aspect ratio:
  /// the remote resolution is left alone and the picture is scaled to whatever
  /// room there is. Otherwise the desktop is drawn at its own size in logical
  /// pixels, so one remote pixel lands on one local pixel -- which is what makes
  /// text crisp -- and anything that does not fit is reachable by scrolling.
  /// Where the desktop sits inside [box]: how big it is drawn, and the corner it
  /// is drawn at.
  ///
  /// Both are returned together on purpose. The layout and the pointer mapping
  /// each need this geometry, and if the two ever disagree -- because one of
  /// them forgot the centring, or the scroll offset, or the device pixel ratio
  /// -- clicks land somewhere other than where they were aimed. Sharing one
  /// calculation is what keeps them honest.
  ({Size size, Offset origin}) _layout(Size box, double devicePixelRatio) {
    final desktop = widget.desktopSize;
    if (desktop == null) {
      return (size: box, origin: Offset.zero);
    }

    final Size content;
    if (widget.fitToWindow) {
      final aspect = desktop.aspectRatio;
      final boxAspect = box.width / box.height;
      content = boxAspect > aspect
          ? Size(box.height * aspect, box.height)
          : Size(box.width, box.width / aspect);
    } else {
      // Expressed in logical pixels, which is the unit the layout works in and
      // the unit the engine scales to physical pixels on the way out.
      content = Size(
        desktop.width / devicePixelRatio,
        desktop.height / devicePixelRatio,
      );
    }

    // Overflowing axes scroll and therefore start at the viewport's corner;
    // axes that fit are centred.
    final origin = Offset(
      content.width > box.width ? 0 : (box.width - content.width) / 2,
      content.height > box.height ? 0 : (box.height - content.height) / 2,
    );
    return (size: content, origin: origin);
  }

  /// Widget-space position -> remote-desktop pixel coordinates.
  (int, int)? _toRemote(Offset local, Size box) {
    final desktop = widget.desktopSize;
    if (desktop == null || desktop.width == 0 || desktop.height == 0) {
      return null;
    }
    final geometry = _layout(box, MediaQuery.devicePixelRatioOf(context));
    if (geometry.size.width <= 0 || geometry.size.height <= 0) {
      return null;
    }

    // Pointer positions arrive in viewport coordinates, so the scroll offset
    // has to come back out before scaling. Without this, clicking a scrolled
    // desktop would land the remote pointer somewhere above and to the left of
    // where it was aimed.
    final position = local - geometry.origin + _scrollOffset;

    final scaleX = desktop.width / geometry.size.width;
    final scaleY = desktop.height / geometry.size.height;
    // Clamped rather than rejected: dragging slightly past the edge should
    // pin the pointer to the edge, as it does on a real desktop, instead of
    // dropping the event and leaving the pointer behind.
    final x = (position.dx * scaleX).round().clamp(0, desktop.width - 1);
    final y = (position.dy * scaleY).round().clamp(0, desktop.height - 1);
    return (x, y);
  }

  int _mapButton(int button) {
    if (!widget.swapMouseButtons) {
      return button;
    }
    if (button == kPrimaryMouseButton) {
      return kSecondaryMouseButton;
    }
    if (button == kSecondaryMouseButton) {
      return kPrimaryMouseButton;
    }
    return button;
  }

  /// Translates a button bitmask into the press and release actions.
  ///
  /// Works from the bitmask rather than the pointer event's own button, because
  /// Flutter's pointer events do not expose a single-button accessor and the
  /// `buttons` field means "currently held", which on a release no longer
  /// includes the button that went up. Diffing against what the remote has
  /// already been told is correct either way.
  static (int down, int up)? _actionsFor(int button) => switch (button) {
    kPrimaryMouseButton => (RdcMouseAction.leftDown, RdcMouseAction.leftUp),
    kSecondaryMouseButton => (RdcMouseAction.rightDown, RdcMouseAction.rightUp),
    kMiddleMouseButton => (RdcMouseAction.middleDown, RdcMouseAction.middleUp),
    _ => null,
  };

  void _handlePointerDown(PointerDownEvent event, Size box) {
    final position = _toRemote(event.localPosition, box);
    if (position == null) {
      return;
    }
    _focusNode.requestFocus();

    final pressed = event.buttons & ~_buttonsDown;
    _buttonsDown |= pressed;
    for (final button in _buttonBits(pressed)) {
      final actions = _actionsFor(_mapButton(button));
      if (actions != null) {
        widget.engine.sendMouse(actions.$1, position.$1, position.$2);
      }
    }
  }

  void _handlePointerUp(PointerUpEvent event, Size box) {
    final position = _toRemote(event.localPosition, box);
    if (position == null) {
      return;
    }

    // When the last button goes up, `buttons` is zero, so every button still
    // recorded as down is one that has just been released. Sending those
    // releases is what stops the remote side from believing a button is stuck.
    final released = _buttonsDown & ~event.buttons;
    _buttonsDown &= ~released;
    for (final button in _buttonBits(released)) {
      final actions = _actionsFor(_mapButton(button));
      if (actions != null) {
        widget.engine.sendMouse(actions.$2, position.$1, position.$2);
      }
    }
  }

  /// Splits a button bitmask into the individual button constants.
  static Iterable<int> _buttonBits(int mask) sync* {
    for (final button in const [
      kPrimaryMouseButton,
      kSecondaryMouseButton,
      kMiddleMouseButton,
    ]) {
      if (mask & button != 0) {
        yield button;
      }
    }
  }

  /// Sends a pointer position to the session.
  ///
  /// Takes any pointer event because both kinds carry one: Flutter reports a
  /// movement with a button held as a move and one without as a hover, and the
  /// host needs both. Only forwarding the moves means the remote machine learns
  /// where the pointer is the moment it is clicked and not before, so hovering
  /// a remote menu, link or title bar does nothing at all.
  void _handlePointerMove(PointerEvent event, Size box) {
    final position = _toRemote(event.localPosition, box);
    if (position == null) {
      return;
    }
    widget.engine.sendMouse(RdcMouseAction.move, position.$1, position.$2);
  }

  void _handleScroll(PointerScrollEvent event, Size box) {
    final position = _toRemote(event.localPosition, box);
    if (position == null) {
      return;
    }
    // Flutter reports scroll in logical pixels; RDP wants notches. One notch
    // per 120 logical pixels is close enough to feel right at any zoom, and
    // the sign flip matches "scroll up moves the view up".
    final notches = (-event.scrollDelta.dy / 120).round();
    if (notches == 0) {
      return;
    }
    widget.engine.sendMouse(
      RdcMouseAction.wheel,
      position.$1,
      position.$2,
      wheelDelta: notches * 120,
    );
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    final physical = event.physicalKey;

    // A repeat is delivered as a fresh down event, which is exactly what the
    // protocol expects, so no special handling is needed.
    final down = event is! KeyUpEvent;

    // Modifier state is tracked locally because the client's own shortcuts have
    // to be recognised before the key is forwarded, and the remote session's
    // view of which modifiers are held is not available here.
    if (physical == PhysicalKeyboardKey.controlLeft ||
        physical == PhysicalKeyboardKey.controlRight) {
      _ctrlDown = down;
    } else if (physical == PhysicalKeyboardKey.altLeft ||
        physical == PhysicalKeyboardKey.altRight) {
      _altDown = down;
    }

    if (down && _ctrlDown && _altDown) {
      final shortcut = switch (physical) {
        PhysicalKeyboardKey.home => RemoteShortcut.connectionBar,
        PhysicalKeyboardKey.enter => RemoteShortcut.fullScreen,
        _ => null,
      };
      if (shortcut != null &&
          (widget.onLocalShortcut?.call(shortcut) ?? false)) {
        // Consumed: not forwarded, so the remote machine never sees it.
        return KeyEventResult.handled;
      }
    }

    final mapped = scancodeFor(physical);
    if (mapped != null) {
      widget.engine.sendKey(
        scancode: mapped.scancode,
        down: down,
        extended: mapped.extended,
      );
      return KeyEventResult.handled;
    }

    // Keys with no scancode — media keys, and anything from a layout the
    // scancode table cannot express — go through as text where possible.
    if (down && event is KeyDownEvent) {
      final character = event.character;
      if (character != null && character.isNotEmpty) {
        widget.engine.sendText(character);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  /// Remembers where the pointer is, which is where the remote cursor is drawn.
  void _trackPointer(Offset position) {
    if (_pointer == position) {
      return;
    }
    // A frame is dropped rather than a whole rebuild: the pointer moves far more
    // often than anything else on this screen.
    setState(() => _pointer = position);
  }

  void _handleFocusChange(bool hasFocus) {
    if (!hasFocus) {
      widget.onFocusLost?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final box = Size(constraints.maxWidth, constraints.maxHeight);
        final geometry = _layout(box, devicePixelRatio);
        final textureId = widget.textureId;

        final desktop = SizedBox.fromSize(
          size: geometry.size,
          child: textureId >= 0
              ? Texture(textureId: textureId, filterQuality: FilterQuality.low)
              : const ColoredBox(color: Color(0xFF1A1A1A)),
        );

        // Scroll only in the dimensions that actually overflow. Wrapping
        // unconditionally would make the desktop jump to the top-left corner as
        // soon as it is smaller than the window, which it usually is.
        Widget content = desktop;
        if (geometry.size.width > box.width) {
          content = SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            controller: _horizontalScroll,
            child: content,
          );
        }
        if (geometry.size.height > box.height) {
          content = SingleChildScrollView(
            scrollDirection: Axis.vertical,
            controller: _verticalScroll,
            child: content,
          );
        }

        final desktopArea = Center(child: content);

        return Focus(
          focusNode: _focusNode,
          onKeyEvent: _handleKey,
          onFocusChange: _handleFocusChange,
          child: MouseRegion(
            cursor: _platformCursor,
            // The remote pointer is drawn where the local one is, so the two
            // would otherwise both be visible. Nothing to track once it is out
            // of the desktop either: the platform's own pointer comes back.
            onExit: (_) {
              if (_pointer != null) {
                setState(() => _pointer = null);
              }
            },
            // Outside the scroll views, so pointer positions arrive in viewport
            // coordinates and _toRemote adds the scroll offset itself.
            child: Listener(
              onPointerDown: (event) => _handlePointerDown(event, box),
              onPointerUp: (event) => _handlePointerUp(event, box),
              onPointerMove: (event) {
                _trackPointer(event.localPosition);
                _handlePointerMove(event, box);
              },
              onPointerHover: (event) {
                _trackPointer(event.localPosition);
                _handlePointerMove(event, box);
              },
              onPointerSignal: (event) {
                if (event is PointerScrollEvent) {
                  _handleScroll(event, box);
                }
              },
              child: Stack(
                children: [desktopArea, ?_buildRemoteCursor()],
              ),
            ),
          ),
        );
      },
    );
  }
}
