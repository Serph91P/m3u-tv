import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

enum _SwipeAxis { horizontal, vertical }

/// Suppresses a synthetic swipe-driven key when the OS has just delivered a
/// matching native key event of its own for the same gesture - e.g. a
/// connected Bluetooth game controller's d-pad reporting alongside the Siri
/// Remote, or any other input path UIKit still funnels through the normal
/// key-event pipeline. Ported from the sibling Plezy project's
/// `GamepadDuplicateInputGuard` (lib/services/gamepad_service.dart), trimmed
/// to the directional keys this governor emits.
class _DuplicateInputGuard {
  _DuplicateInputGuard({DateTime Function()? now}) : _now = now ?? DateTime.now;

  static const Duration _suppressionWindow = Duration(milliseconds: 120);

  static final Map<LogicalKeyboardKey, Set<LogicalKeyboardKey>> _nativeAliases =
      {
        LogicalKeyboardKey.arrowUp: {LogicalKeyboardKey.arrowUp},
        LogicalKeyboardKey.arrowDown: {LogicalKeyboardKey.arrowDown},
        LogicalKeyboardKey.arrowLeft: {LogicalKeyboardKey.arrowLeft},
        LogicalKeyboardKey.arrowRight: {LogicalKeyboardKey.arrowRight},
      };

  static final Set<LogicalKeyboardKey> _trackedNativeKeys = _nativeAliases
      .values
      .expand((keys) => keys)
      .toSet();

  final DateTime Function() _now;
  final Map<LogicalKeyboardKey, DateTime> _lastNativeEvents = {};
  final Set<LogicalKeyboardKey> _nativeKeysPressed = {};

  bool handleNativeKeyEvent(KeyEvent event) {
    if (!_trackedNativeKeys.contains(event.logicalKey)) return false;

    final now = _now();
    _lastNativeEvents[event.logicalKey] = now;
    if (event is KeyUpEvent) {
      _nativeKeysPressed.remove(event.logicalKey);
    } else {
      _nativeKeysPressed.add(event.logicalKey);
    }
    _prune(now);
    return false;
  }

  bool shouldSuppressSyntheticKey(LogicalKeyboardKey logicalKey) {
    final now = _now();
    _prune(now);
    for (final key in _nativeAliases[logicalKey] ?? {logicalKey}) {
      if (_nativeKeysPressed.contains(key)) return true;
      final lastNativeEvent = _lastNativeEvents[key];
      if (lastNativeEvent != null &&
          now.difference(lastNativeEvent) <= _suppressionWindow) {
        return true;
      }
    }
    return false;
  }

  void clear() {
    _lastNativeEvents.clear();
    _nativeKeysPressed.clear();
  }

  void _prune(DateTime now) {
    _lastNativeEvents.removeWhere(
      (_, timestamp) => now.difference(timestamp) > _suppressionWindow,
    );
  }
}

const double _axisSwitchDominanceRatio = 1.5;
// Tuned by the sibling Plezy project against the native tvOS focus engine
// (two instrumentation passes on an Apple TV 4K: a UIFocusItem telemetry
// bridge, then a dedicated native probe logging every touch sample, pan
// velocity, and focus step across 101 swipe sessions on 160/230/300pt
// tiles). Ported as-is rather than re-derived - see plezy's
// lib/services/apple_tv_remote_touch_service.dart for the full derivation.
//
// Findings these constants encode:
//  - one focus step prices at the focused item's extent along the swipe axis
//    plus ~155pt of indirect-touch travel (UITouch points - the accelerated
//    space this channel reports): measured 314pt on a 160pt tile, 391pt on a
//    230pt poster, 410pt on a 300pt rail card.
//  - steps repeat at 40-120ms (mode ~80ms) during a committed drag; the 60ms
//    cooldown only floors that cadence, travel does the pricing.
//  - a lift never coasts more than ONE step: sessions with lift velocities
//    up to ~11400pt/s produced 95 zero-coast lifts and 6 single-step coasts
//    landing 4-101ms after the lift. Do not reintroduce a multi-step
//    momentum law.
const Duration _swipeRepeatInterval = Duration(milliseconds: 60);
// Fallback step travel when no usable focus geometry exists (a bare focus
// scope, a screen-sized catch-all surface, a detached node).
const double _swipeStepDistance = 400;
// Travel added to the focused item's extent to price one step.
const double _swipeStepExtraTravel = 155;
// Guards, not tuning: measured extents span 90-345pt; anything outside
// prices within sane bounds instead of extrapolating the affine law.
const double _minSwipeStepTravel = 200;
const double _maxSwipeStepTravel = 700;
const Duration _glideStepInterval = Duration(milliseconds: 70);
const double _glideVelocity = 2000;
const Duration _liftVelocityWindow = Duration(milliseconds: 100);
// A glide only ever extends a sustained drag: the gesture must already have
// emitted this many consecutive steps in the lift direction. The velocity
// estimator runs in the same accelerated space as the step distance, and an
// ordinary discrete flick covers one step's travel at well past
// [_glideVelocity] there - ungated, every deliberate single swipe glided
// into a second step.
const int _glideMinConsecutiveSteps = 2;

/// Bridges tvOS touch-surface events (Siri Remote and Apple's iOS Remote
/// app) into the focus-tree key events `dpad` already handles for D-pad
/// navigation, replacing UIKit's own swipe-to-key translation (see
/// `M3uTvFlutterViewController` in tvos/Runner/AppDelegate.swift, which opts
/// the app into raw indirect-touch reporting on this channel).
///
/// Like the native focus engine, one focus step prices by on-screen
/// geometry: the focused control's extent along the swipe axis plus a fixed
/// travel margin, falling back to [swipeThreshold] when no usable geometry
/// exists. Steps repeat on a short cadence during a sustained drag, and a
/// fast lift "glides" at most one further step - never more. A glide only
/// extends a drag that already covered [_glideMinConsecutiveSteps] steps in
/// that direction, so a discrete flick moves exactly one item.
class AppleTvRemoteSwipeGovernor {
  AppleTvRemoteSwipeGovernor({
    void Function(LogicalKeyboardKey logicalKey)? simulateKeyPress,
    DateTime Function()? now,
    this.swipeThreshold = _swipeStepDistance,
    Rect? Function()? focusedItemRect,
  }) : _simulateKeyPress = simulateKeyPress ?? _defaultSimulateKeyPress,
       _now = now ?? DateTime.now,
       _focusedItemRect = focusedItemRect ?? _defaultFocusedItemRect,
       _duplicateInputGuard = _DuplicateInputGuard(now: now);

  static const String _channelName = 'flutter/gamepadtouchevent';

  static final AppleTvRemoteSwipeGovernor instance =
      AppleTvRemoteSwipeGovernor();

  final BasicMessageChannel<dynamic> _channel =
      const BasicMessageChannel<dynamic>(
        _channelName,
        JSONMessageCodec(),
      );
  final void Function(LogicalKeyboardKey logicalKey) _simulateKeyPress;
  final DateTime Function() _now;

  /// Fallback touch travel that prices one focus step when no usable focus
  /// geometry exists.
  final double swipeThreshold;

  /// Global rect of the control that prices a focus step, or null when no
  /// usable geometry exists. Injected so tests can supply fake geometry.
  final Rect? Function() _focusedItemRect;

  bool _listening = false;
  bool _touchActive = false;
  double _anchorX = 0;
  double _anchorY = 0;
  double _startX = 0;
  double _startY = 0;
  _SwipeAxis? _lastSwipeAxis;
  DateTime? _lastSwipeAt;
  LogicalKeyboardKey? _lastSwipeKey;
  int _consecutiveStepCount = 0;
  final List<({DateTime t, double x, double y})> _moveSamples = [];
  Timer? _glideTimer;
  final _DuplicateInputGuard _duplicateInputGuard;
  bool _nativeKeyHandlerRegistered = false;

  void start() {
    if (_listening) return;
    _channel.setMessageHandler(handleMessage);
    _registerNativeKeyHandler();
    _listening = true;
  }

  void stop() {
    if (!_listening) return;
    _channel.setMessageHandler(null);
    _cancelGlide();
    _unregisterNativeKeyHandler();
    _duplicateInputGuard.clear();
    _resetTouch();
    _listening = false;
  }

  /// Exposed for tests: feeds a native key event through the duplicate-input
  /// guard exactly like the [HardwareKeyboard] handler registered by
  /// [start] would.
  @visibleForTesting
  bool handleNativeKeyEvent(KeyEvent event) =>
      _duplicateInputGuard.handleNativeKeyEvent(event);

  void _registerNativeKeyHandler() {
    if (_nativeKeyHandlerRegistered) return;
    HardwareKeyboard.instance.addHandler(handleNativeKeyEvent);
    _nativeKeyHandlerRegistered = true;
  }

  void _unregisterNativeKeyHandler() {
    if (!_nativeKeyHandlerRegistered) return;
    HardwareKeyboard.instance.removeHandler(handleNativeKeyEvent);
    _nativeKeyHandlerRegistered = false;
  }

  Future<void> handleMessage(dynamic arguments) async {
    if (arguments is! Map) return;

    final type = arguments['type'];
    if (type is! String) return;

    switch (type) {
      case 'started':
        final position = _positionFrom(arguments);
        if (position == null) return;
        _startTouch(position.$1, position.$2);
      case 'move':
        final position = _positionFrom(arguments);
        if (position == null) return;
        _moveTouch(position.$1, position.$2);
      case 'ended':
        // Drop the lift frame position: it is unreliable on the Siri Remote
        // - a natural finger pivot during lift can register enough delta
        // from the post-last-swipe anchor to fire a stray opposite-direction
        // swipe. The gesture's recorded move samples still price a
        // post-lift glide.
        _endTouch();
      case 'cancelled':
        _resetTouch();
      default:
        break;
    }
  }

  (double, double)? _positionFrom(Map<dynamic, dynamic> arguments) {
    final x = _toDouble(arguments['x']);
    final y = _toDouble(arguments['y']);
    if (x == null || y == null) return null;
    return (x, y);
  }

  double? _toDouble(Object? value) => value is num ? value.toDouble() : null;

  void _startTouch(double x, double y) {
    _cancelGlide();
    _touchActive = true;
    _startX = x;
    _startY = y;
    _anchorX = x;
    _anchorY = y;
    _lastSwipeAxis = null;
    _lastSwipeAt = null;
    _lastSwipeKey = null;
    _consecutiveStepCount = 0;
    _moveSamples
      ..clear()
      ..add((t: _now(), x: x, y: y));
  }

  void _moveTouch(double x, double y) {
    if (!_touchActive) return;

    final deltaX = _anchorX - x;
    final deltaY = _anchorY - y;

    final now = _now();
    _recordMoveSample(now, x, y);
    final lastSwipeAt = _lastSwipeAt;
    if (lastSwipeAt != null &&
        now.difference(lastSwipeAt) < _swipeRepeatInterval) {
      // Travel during the repeat cooldown never counts toward the next step:
      // re-anchor on every frame so a fast flick's deceleration tail is
      // discarded instead of banked. Without this, the first post-cooldown
      // move frame - even a stationary or lift-drift one - released the
      // banked delta as a second focus step for a single intentional swipe.
      _anchorX = x;
      _anchorY = y;
      return;
    }

    final thresholds = _stepThresholds();
    final axis = _resolveSwipeAxis(
      x: x,
      y: y,
      deltaX: deltaX,
      deltaY: deltaY,
      thresholds: thresholds,
    );
    if (axis == null) return;

    final logicalKey = axis == _SwipeAxis.horizontal
        ? (deltaX >= 0
              ? LogicalKeyboardKey.arrowLeft
              : LogicalKeyboardKey.arrowRight)
        : (deltaY >= 0
              ? LogicalKeyboardKey.arrowUp
              : LogicalKeyboardKey.arrowDown);

    _emitKey(logicalKey);
    _anchorX = x;
    _anchorY = y;
    _lastSwipeAxis = axis;
    _lastSwipeAt = now;
    _consecutiveStepCount = logicalKey == _lastSwipeKey
        ? _consecutiveStepCount + 1
        : 1;
    _lastSwipeKey = logicalKey;
  }

  /// Resolves which axis, if any, covered a full step, with hysteresis so
  /// incidental drift does not zig-zag an established swipe.
  ///
  /// Distances are normalized by the per-axis thresholds so that, like the
  /// native focus engine, a wide-flat control steps vertically once the
  /// finger covers its height even while the raw horizontal delta is
  /// larger.
  _SwipeAxis? _resolveSwipeAxis({
    required double x,
    required double y,
    required double deltaX,
    required double deltaY,
    required ({double horizontal, double vertical}) thresholds,
  }) {
    final progressX = deltaX.abs() / thresholds.horizontal;
    final progressY = deltaY.abs() / thresholds.vertical;
    if (progressX < 1 && progressY < 1) return null;

    final candidate = progressX >= progressY
        ? _SwipeAxis.horizontal
        : _SwipeAxis.vertical;
    final lastAxis = _lastSwipeAxis;
    if (lastAxis == null || candidate == lastAxis) return candidate;

    final totalProgressX = (_startX - x).abs() / thresholds.horizontal;
    final totalProgressY = (_startY - y).abs() / thresholds.vertical;
    final candidateTotal = _axisValue(
      candidate,
      totalProgressX,
      totalProgressY,
    );
    final lastAxisTotal = _axisValue(lastAxis, totalProgressX, totalProgressY);
    final candidateSegment = _axisValue(candidate, progressX, progressY);
    final lastAxisSegment = _axisValue(lastAxis, progressX, progressY);
    if (candidateTotal >= lastAxisTotal * _axisSwitchDominanceRatio &&
        candidateSegment >= lastAxisSegment * _axisSwitchDominanceRatio) {
      return candidate;
    }

    return lastAxisSegment >= 1 ? lastAxis : null;
  }

  double _axisValue(_SwipeAxis axis, double horizontal, double vertical) =>
      axis == _SwipeAxis.horizontal ? horizontal : vertical;

  ({double horizontal, double vertical}) _stepThresholds() {
    final rect = _focusedItemRect();
    if (rect == null) {
      return (horizontal: swipeThreshold, vertical: swipeThreshold);
    }
    return (
      horizontal: _thresholdForExtent(rect.width),
      vertical: _thresholdForExtent(rect.height),
    );
  }

  double _thresholdForExtent(double extent) {
    if (!extent.isFinite || extent <= 0) return swipeThreshold;
    return (extent + _swipeStepExtraTravel).clamp(
      _minSwipeStepTravel,
      _maxSwipeStepTravel,
    );
  }

  /// Reads the primary focus geometry, rejecting nodes whose rect cannot
  /// meaningfully price a step: a bare scope (nothing real is focused yet)
  /// and a detached or unlaid-out node have no usable rect.
  static Rect? _defaultFocusedItemRect() {
    final node = FocusManager.instance.primaryFocus;
    if (node == null || node is FocusScopeNode) return null;
    final context = node.context;
    if (context == null) return null;
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox ||
        !renderObject.attached ||
        !renderObject.hasSize) {
      return null;
    }
    final rect = node.rect;
    if (!rect.isFinite || rect.isEmpty) return null;
    return rect;
  }

  void _recordMoveSample(DateTime now, double x, double y) {
    _moveSamples.add((t: now, x: x, y: y));
    final cutoff = now.subtract(_liftVelocityWindow);
    while (_moveSamples.isNotEmpty && _moveSamples.first.t.isBefore(cutoff)) {
      _moveSamples.removeAt(0);
    }
  }

  void _endTouch() {
    final glideKey = _lastSwipeKey;
    final shouldGlide = _liftShouldGlide();
    _resetTouch();
    if (glideKey != null && shouldGlide) _startGlide(glideKey);
  }

  /// Decides whether the lift glides one - and only one - further step,
  /// from the finger's velocity over the last [_liftVelocityWindow] of the
  /// gesture, measured along the established swipe axis. Only a sustained
  /// drag glides: the gesture must already have emitted
  /// [_glideMinConsecutiveSteps] consecutive steps in the lift direction, so
  /// a discrete one-step flick never overshoots its target. A gesture that
  /// never produced a step has no established direction and never glides;
  /// neither does a lift moving against the last step (a reversal pivot).
  bool _liftShouldGlide() {
    final key = _lastSwipeKey;
    final axis = _lastSwipeAxis;
    if (key == null || axis == null || _moveSamples.length < 2) return false;
    if (_consecutiveStepCount < _glideMinConsecutiveSteps) return false;
    final first = _moveSamples.first;
    final last = _moveSamples.last;
    final dt =
        last.t.difference(first.t).inMicroseconds /
        Duration.microsecondsPerSecond;
    if (dt <= 0) return false;
    final velocity = axis == _SwipeAxis.horizontal
        ? (last.x - first.x) / dt
        : (last.y - first.y) / dt;
    final towardKey = axis == _SwipeAxis.horizontal
        ? (velocity < 0
              ? LogicalKeyboardKey.arrowLeft
              : LogicalKeyboardKey.arrowRight)
        : (velocity < 0
              ? LogicalKeyboardKey.arrowUp
              : LogicalKeyboardKey.arrowDown);
    if (towardKey != key) return false;
    return velocity.abs() >= _glideVelocity;
  }

  void _startGlide(LogicalKeyboardKey key) {
    _cancelGlide();
    _glideTimer = Timer(_glideStepInterval, () {
      _glideTimer = null;
      _emitKey(key);
    });
  }

  void _cancelGlide() {
    _glideTimer?.cancel();
    _glideTimer = null;
  }

  bool _emitKey(LogicalKeyboardKey logicalKey) {
    if (_duplicateInputGuard.shouldSuppressSyntheticKey(logicalKey)) {
      return false;
    }
    _scheduleFrameIfIdle();
    _simulateKeyPress(logicalKey);
    return true;
  }

  void _resetTouch() {
    _touchActive = false;
    _lastSwipeAxis = null;
    _lastSwipeAt = null;
    _lastSwipeKey = null;
    _consecutiveStepCount = 0;
    _moveSamples.clear();
  }
}

void _scheduleFrameIfIdle() {
  if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.idle) {
    SchedulerBinding.instance.scheduleFrame();
  }
}

/// Simulates a full key press (down and up) on the currently focused node,
/// walking [FocusNode.onKeyEvent] up the tree exactly like a real hardware
/// key event would - this flows straight through `dpad`'s `Shortcuts`
/// widget (itself just a [FocusNode] with `onKeyEvent`), so no `dpad` fork
/// is needed.
void _defaultSimulateKeyPress(LogicalKeyboardKey logicalKey) {
  // Post-frame dispatch lets focus settle, and schedules a frame when the
  // engine is otherwise idle so external input wakes the app up.
  _scheduleFrameIfIdle();
  SchedulerBinding.instance.addPostFrameCallback((_) {
    final focusNode = FocusManager.instance.primaryFocus;
    if (focusNode == null) return;
    final physicalKey = _physicalKeyFor(logicalKey);
    final timeStamp = Duration(
      milliseconds: DateTime.now().millisecondsSinceEpoch,
    );
    _dispatchKeyEvent(
      focusNode,
      KeyDownEvent(
        physicalKey: physicalKey,
        logicalKey: logicalKey,
        timeStamp: timeStamp,
        deviceType: ui.KeyEventDeviceType.directionalPad,
      ),
    );
    _dispatchKeyEvent(
      focusNode,
      KeyUpEvent(
        physicalKey: physicalKey,
        logicalKey: logicalKey,
        timeStamp: timeStamp,
        deviceType: ui.KeyEventDeviceType.directionalPad,
      ),
    );
  });
}

void _dispatchKeyEvent(FocusNode focusNode, KeyEvent event) {
  FocusNode? node = focusNode;
  while (node != null) {
    if (node.onKeyEvent != null) {
      final result = node.onKeyEvent!(node, event);
      if (result != KeyEventResult.ignored) break;
    }
    node = node.parent;
  }
}

PhysicalKeyboardKey _physicalKeyFor(LogicalKeyboardKey logicalKey) {
  if (logicalKey == LogicalKeyboardKey.arrowUp) {
    return PhysicalKeyboardKey.arrowUp;
  }
  if (logicalKey == LogicalKeyboardKey.arrowDown) {
    return PhysicalKeyboardKey.arrowDown;
  }
  if (logicalKey == LogicalKeyboardKey.arrowLeft) {
    return PhysicalKeyboardKey.arrowLeft;
  }
  return PhysicalKeyboardKey.arrowRight;
}
