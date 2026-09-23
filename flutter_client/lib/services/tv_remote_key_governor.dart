import 'package:dpad/dpad.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show TraversalDirection;

/// What [TvRemoteKeyGovernor.decide] wants the caller to do with a key event.
enum TvRemoteKeyDecision {
  /// Not a direction key this governor cares about - let it flow normally.
  passThrough,

  /// A direction key this governor is swallowing (over-sensitive repeat, or
  /// a stray swipe immediately after a select press).
  suppress,

  /// A direction key that should still flow through normally *and* trigger
  /// one extra programmatic step, because it is part of a fast, sustained
  /// same-direction burst.
  accelerate,
}

/// Moderates the arrow-key stream that tvOS's native focus engine already
/// synthesizes from Siri Remote swipes (the same stream `dpad`'s
/// `Shortcuts` consumes), without replacing or racing that native
/// translation. Two things:
///
/// - Debounces same-direction repeats that arrive faster than a real,
///   deliberate swipe would (fixes plain over-sensitivity), and swallows the
///   first direction key that arrives immediately after a select press
///   (fixes a stray swipe registering from the click itself).
/// - Detects a fast, sustained same-direction burst and asks the caller to
///   add one extra step per accepted key once the burst is established, so a
///   held swipe feels like it speeds up rather than moving one item per
///   swipe forever.
class TvRemoteKeyGovernor {
  TvRemoteKeyGovernor({DateTime Function()? now}) : _now = now ?? DateTime.now;

  static const Duration _repeatDebounce = Duration(milliseconds: 120);
  static const Duration _postSelectDeadZone = Duration(milliseconds: 180);
  static const Duration _burstWindow = Duration(milliseconds: 350);
  static const int _burstThreshold = 3;

  static final Map<LogicalKeyboardKey, TraversalDirection> _directionKeys = {
    for (final key in DpadKeySet.defaultUp) key: TraversalDirection.up,
    for (final key in DpadKeySet.defaultDown) key: TraversalDirection.down,
    for (final key in DpadKeySet.defaultLeft) key: TraversalDirection.left,
    for (final key in DpadKeySet.defaultRight) key: TraversalDirection.right,
  };

  static final Set<LogicalKeyboardKey> _selectKeys = DpadKeySet.defaultSelect
      .toSet();

  final DateTime Function() _now;

  DateTime? _lastSelectAt;
  final Map<LogicalKeyboardKey, DateTime> _lastAcceptedAt = {};
  LogicalKeyboardKey? _burstKey;
  int _burstCount = 0;
  DateTime? _lastBurstAt;

  /// The direction a key resolves to, for callers that need it after an
  /// [TvRemoteKeyDecision.accelerate] result.
  TraversalDirection? directionOf(LogicalKeyboardKey key) =>
      _directionKeys[key];

  TvRemoteKeyDecision decide(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return TvRemoteKeyDecision.passThrough;
    }

    final key = event.logicalKey;
    final now = _now();

    if (_selectKeys.contains(key)) {
      _lastSelectAt = now;
      return TvRemoteKeyDecision.passThrough;
    }

    final direction = _directionKeys[key];
    if (direction == null) return TvRemoteKeyDecision.passThrough;

    final lastSelectAt = _lastSelectAt;
    if (lastSelectAt != null &&
        now.difference(lastSelectAt) < _postSelectDeadZone) {
      _lastSelectAt = null;
      return TvRemoteKeyDecision.suppress;
    }

    final lastAccepted = _lastAcceptedAt[key];
    if (lastAccepted != null &&
        now.difference(lastAccepted) < _repeatDebounce) {
      return TvRemoteKeyDecision.suppress;
    }
    _lastAcceptedAt[key] = now;

    final lastBurstAt = _lastBurstAt;
    if (_burstKey == key &&
        lastBurstAt != null &&
        now.difference(lastBurstAt) < _burstWindow) {
      _burstCount++;
    } else {
      _burstKey = key;
      _burstCount = 1;
    }
    _lastBurstAt = now;

    return _burstCount >= _burstThreshold
        ? TvRemoteKeyDecision.accelerate
        : TvRemoteKeyDecision.passThrough;
  }
}
