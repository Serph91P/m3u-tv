import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3u_tv/services/apple_tv_remote_swipe_governor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppleTvRemoteSwipeGovernor', () {
    test('a single fast flick emits exactly one swipe', () async {
      final harness = _Harness();

      await harness.send('started', x: 500, y: 500);
      await harness.send('move', x: 380, y: 490);
      await harness.send('move', x: 260, y: 490);

      expect(harness.keys, [LogicalKeyboardKey.arrowLeft]);

      // The flick's tail travel landed inside the repeat cooldown and must
      // be discarded: a near-stationary frame after the cooldown expires
      // must not release it as a second focus step.
      harness.advance(const Duration(milliseconds: 61));
      await harness.send('move', x: 259, y: 490);

      expect(harness.keys, [LogicalKeyboardKey.arrowLeft]);
    });

    test(
      'sub-threshold cooldown travel plus lift drift does not fire a second swipe',
      () async {
        final harness = _Harness();

        await harness.send('started', x: 500, y: 500);
        await harness.send('move', x: 390, y: 500);
        // 80pt tail inside the cooldown: below threshold, but banked it would
        // combine with the 70pt lift drift below to cross the 100pt threshold.
        await harness.send('move', x: 310, y: 500);

        harness.advance(const Duration(milliseconds: 61));
        await harness.send('move', x: 240, y: 500);

        expect(harness.keys, [LogicalKeyboardKey.arrowLeft]);
      },
    );

    test(
      'a sustained drag keeps repeating after each repeat interval',
      () async {
        final harness = _Harness();

        await harness.send('started', x: 900, y: 500);
        await harness.send('move', x: 780, y: 500);

        expect(harness.keys, [LogicalKeyboardKey.arrowLeft]);

        harness.advance(const Duration(milliseconds: 30));
        await harness.send('move', x: 700, y: 500);

        // A full fresh threshold is covered after the cooldown expires.
        harness.advance(const Duration(milliseconds: 31));
        await harness.send('move', x: 580, y: 500);

        expect(harness.keys, [
          LogicalKeyboardKey.arrowLeft,
          LogicalKeyboardKey.arrowLeft,
        ]);
      },
    );

    test('uses the dominant vertical axis for swipes', () async {
      final harness = _Harness();

      await harness.send('started', x: 500, y: 500);
      await harness.send('move', x: 540, y: 380);

      expect(harness.keys, [LogicalKeyboardKey.arrowUp]);
    });

    test(
      'prices a step by the focused item extent plus the travel margin',
      () async {
        final harness = _Harness()
          ..focusedRect = const Rect.fromLTWH(0, 0, 245, 10);

        // Horizontal: 245pt extent + 155pt margin = 400pt per step.
        await harness.send('started', x: 500, y: 500);
        await harness.send('move', x: 101, y: 500);
        expect(harness.keys, isEmpty);
        await harness.send('move', x: 100, y: 500);
        expect(harness.keys, [LogicalKeyboardKey.arrowLeft]);

        // Vertical: 10pt extent prices at the 200pt floor, not at 165pt.
        harness.advance(const Duration(milliseconds: 61));
        await harness.send('started', x: 500, y: 500);
        await harness.send('move', x: 500, y: 301);
        expect(harness.keys, [LogicalKeyboardKey.arrowLeft]);
        await harness.send('move', x: 500, y: 300);
        expect(harness.keys, [
          LogicalKeyboardKey.arrowLeft,
          LogicalKeyboardKey.arrowUp,
        ]);
      },
    );

    test(
      'a wide-flat control steps vertically once the finger covers its height',
      () async {
        final harness = _Harness()
          ..focusedRect = const Rect.fromLTWH(0, 0, 900, 45);

        // Width prices at the 700pt cap; height at 45+155 = 200pt. A larger raw
        // horizontal delta still resolves vertical because axis progress is
        // normalized by the per-axis thresholds, like the native engine.
        await harness.send('started', x: 500, y: 500);
        await harness.send('move', x: 250, y: 290);
        expect(harness.keys, [LogicalKeyboardKey.arrowUp]);
      },
    );

    test('keeps horizontal axis through non-decisive vertical drift', () async {
      final harness = _Harness();

      await harness.send('started', x: 500, y: 500);
      await harness.send('move', x: 380, y: 500);

      harness.advance(const Duration(milliseconds: 61));
      await harness.send('move', x: 380, y: 370);

      expect(harness.keys, [LogicalKeyboardKey.arrowLeft]);
    });

    test(
      'continues horizontal swipes when drift is slightly vertical-dominant',
      () async {
        final harness = _Harness();

        await harness.send('started', x: 500, y: 500);
        await harness.send('move', x: 380, y: 500);

        harness.advance(const Duration(milliseconds: 61));
        await harness.send('move', x: 260, y: 370);

        expect(harness.keys, [
          LogicalKeyboardKey.arrowLeft,
          LogicalKeyboardKey.arrowLeft,
        ]);
      },
    );

    test(
      'switches axis when the new direction clearly dominates the gesture',
      () async {
        final harness = _Harness();

        await harness.send('started', x: 500, y: 500);
        await harness.send('move', x: 380, y: 500);

        harness.advance(const Duration(milliseconds: 61));
        await harness.send('move', x: 380, y: 300);

        expect(harness.keys, [
          LogicalKeyboardKey.arrowLeft,
          LogicalKeyboardKey.arrowUp,
        ]);
      },
    );

    test('resets swipe axis hysteresis between touches', () async {
      final harness = _Harness();

      await harness.send('started', x: 500, y: 500);
      await harness.send('move', x: 380, y: 500);
      await harness.send('ended', x: 380, y: 500);
      await harness.send('started', x: 500, y: 500);
      await harness.send('move', x: 500, y: 380);

      expect(harness.keys, [
        LogicalKeyboardKey.arrowLeft,
        LogicalKeyboardKey.arrowUp,
      ]);
    });

    test('a short touch with no move emits nothing', () async {
      final harness = _Harness();

      await harness.send('started', x: 500, y: 500);
      await harness.send('ended', x: 512, y: 504);

      expect(harness.keys, isEmpty);
    });

    test('swipe end does not fire an extra key', () async {
      final harness = _Harness();

      await harness.send('started', x: 500, y: 500);
      await harness.send('move', x: 380, y: 500);
      await harness.send('ended', x: 380, y: 500);

      expect(harness.keys, [LogicalKeyboardKey.arrowLeft]);
    });

    test(
      'ended position past threshold opposite of the last move does not fire a reverse swipe',
      () async {
        final harness = _Harness();

        // User swipes left, then releases the finger. The final lift position
        // registers past the swipe threshold from the post-swipe anchor in the
        // *opposite* direction - a natural finger pivot during a lift. If the
        // 'ended' payload's position were fed through the move logic, this
        // would re-fire a stray arrowRight.
        await harness.send('started', x: 500, y: 500);
        await harness.send('move', x: 380, y: 500);
        await harness.send('ended', x: 600, y: 500);

        expect(harness.keys, [LogicalKeyboardKey.arrowLeft]);
      },
    );

    test(
      'cancelled touch does not emit anything on a later ended message',
      () async {
        final harness = _Harness();

        await harness.send('started', x: 500, y: 500);
        await harness.send('cancelled');
        await harness.send('ended', x: 500, y: 500);

        expect(harness.keys, isEmpty);
      },
    );

    test('a native key event suppresses a matching synthetic swipe', () async {
      final harness = _Harness();

      harness.governor.handleNativeKeyEvent(
        _keyDown(LogicalKeyboardKey.arrowLeft),
      );
      await harness.send('started', x: 500, y: 500);
      await harness.send('move', x: 380, y: 500);

      expect(harness.keys, isEmpty);
    });

    test('a fast single-step flick does not glide', () {
      fakeAsync((async) {
        final harness = _Harness()
          ..sendSync('started', x: 500, y: 500)
          ..advance(const Duration(milliseconds: 8))
          // 120pt in 8ms = 15000pt/s: far past both glide velocities, but the
          // gesture emitted only one step. Ungated, every deliberate single
          // swipe would glide into a second step.
          ..sendSync('move', x: 380, y: 500)
          ..sendSync('ended', x: 380, y: 500);

        async.elapse(const Duration(milliseconds: 500));
        expect(harness.keys, [LogicalKeyboardKey.arrowLeft]);
      });
    });

    test('a fast lift after a sustained drag glides one extra step', () {
      fakeAsync((async) {
        final harness = _Harness()
          ..sendSync('started', x: 500, y: 500)
          ..advance(const Duration(milliseconds: 50))
          ..sendSync('move', x: 380, y: 500)
          ..advance(const Duration(milliseconds: 60))
          ..sendSync('move', x: 260, y: 500);

        expect(harness.keys, List.filled(2, LogicalKeyboardKey.arrowLeft));

        // 120pt in the last 8ms: ~3500pt/s over the velocity window - past
        // the glide velocity, below the double-step velocity.
        harness
          ..advance(const Duration(milliseconds: 8))
          ..sendSync('move', x: 140, y: 500)
          ..sendSync('ended', x: 140, y: 500);

        expect(harness.keys, List.filled(2, LogicalKeyboardKey.arrowLeft));

        async.elapse(const Duration(milliseconds: 70));
        expect(harness.keys, List.filled(3, LogicalKeyboardKey.arrowLeft));

        async.elapse(const Duration(milliseconds: 300));
        expect(harness.keys, List.filled(3, LogicalKeyboardKey.arrowLeft));
      });
    });

    test('a slow lift after a sustained drag does not glide', () {
      fakeAsync((async) {
        final harness = _Harness()
          ..sendSync('started', x: 500, y: 500)
          ..advance(const Duration(milliseconds: 60))
          ..sendSync('move', x: 400, y: 500)
          ..advance(const Duration(milliseconds: 60))
          ..sendSync('move', x: 300, y: 500);

        expect(harness.keys, List.filled(2, LogicalKeyboardKey.arrowLeft));

        // Sub-threshold 90pt in 60ms = 1500pt/s at lift: the drag satisfies
        // the glide gate, but the lift stays below the glide velocity.
        harness
          ..advance(const Duration(milliseconds: 60))
          ..sendSync('move', x: 210, y: 500)
          ..sendSync('ended', x: 210, y: 500);

        async.elapse(const Duration(milliseconds: 500));
        expect(harness.keys, List.filled(2, LogicalKeyboardKey.arrowLeft));
      });
    });

    test('a new touch cancels a pending glide', () {
      fakeAsync((async) {
        final harness = _Harness()
          ..sendSync('started', x: 500, y: 500)
          ..advance(const Duration(milliseconds: 50))
          ..sendSync('move', x: 380, y: 500)
          ..advance(const Duration(milliseconds: 60))
          ..sendSync('move', x: 260, y: 500)
          ..advance(const Duration(milliseconds: 8))
          ..sendSync('move', x: 140, y: 500)
          ..sendSync('ended', x: 140, y: 500)
          ..sendSync('started', x: 500, y: 500);

        async.elapse(const Duration(milliseconds: 500));
        expect(harness.keys, List.filled(2, LogicalKeyboardKey.arrowLeft));
      });
    });

    test('a gesture that never produced a step does not glide', () {
      fakeAsync((async) {
        final harness = _Harness()
          ..sendSync('started', x: 500, y: 500)
          ..advance(const Duration(milliseconds: 8))
          // Fast but sub-threshold: no step, so no established direction.
          ..sendSync('move', x: 420, y: 500)
          ..sendSync('ended', x: 420, y: 500);

        async.elapse(const Duration(milliseconds: 500));
        expect(harness.keys, isEmpty);
      });
    });

    test('a lift moving against the last step does not glide', () {
      fakeAsync((async) {
        final harness = _Harness()
          ..sendSync('started', x: 500, y: 500)
          ..advance(const Duration(milliseconds: 50))
          ..sendSync('move', x: 380, y: 500)
          ..advance(const Duration(milliseconds: 60))
          ..sendSync('move', x: 260, y: 500);

        expect(harness.keys, List.filled(2, LogicalKeyboardKey.arrowLeft));

        // Reversal pivot inside the cooldown: net window velocity points
        // right, against the emitted arrowLeft.
        harness
          ..advance(const Duration(milliseconds: 8))
          ..sendSync('move', x: 500, y: 500)
          ..sendSync('ended', x: 500, y: 500);

        async.elapse(const Duration(milliseconds: 500));
        expect(harness.keys, List.filled(2, LogicalKeyboardKey.arrowLeft));
      });
    });
  });
}

class _Harness {
  _Harness();

  DateTime now = DateTime(2026, 5, 5, 12);
  Rect? focusedRect;
  final List<LogicalKeyboardKey> keys = [];

  late final AppleTvRemoteSwipeGovernor governor = AppleTvRemoteSwipeGovernor(
    simulateKeyPress: keys.add,
    now: () => now,
    swipeThreshold: 100,
    focusedItemRect: () => focusedRect,
  );

  Future<void> send(String type, {double x = 0, double y = 0}) {
    return governor.handleMessage({'type': type, 'x': x, 'y': y});
  }

  /// Fire-and-forget variant for [fakeAsync] bodies, where awaiting would
  /// need manual microtask flushing; the handler body is synchronous.
  void sendSync(String type, {double x = 0, double y = 0}) {
    unawaited(governor.handleMessage({'type': type, 'x': x, 'y': y}));
  }

  void advance(Duration duration) {
    now = now.add(duration);
  }
}

KeyDownEvent _keyDown(LogicalKeyboardKey logicalKey) {
  return KeyDownEvent(
    physicalKey: PhysicalKeyboardKey.arrowLeft,
    logicalKey: logicalKey,
    timeStamp: Duration.zero,
  );
}
