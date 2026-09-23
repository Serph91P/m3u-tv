import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show TraversalDirection;
import 'package:flutter_test/flutter_test.dart';
import 'package:m3u_tv/services/tv_remote_key_governor.dart';

void main() {
  group('TvRemoteKeyGovernor', () {
    test('a non-direction, non-select key always passes through', () {
      final harness = _Harness();

      expect(
        harness.decide(LogicalKeyboardKey.escape),
        TvRemoteKeyDecision.passThrough,
      );
    });

    test('select keys always pass through and are never suppressed', () {
      final harness = _Harness();

      expect(
        harness.decide(LogicalKeyboardKey.select),
        TvRemoteKeyDecision.passThrough,
      );
      harness.advance(const Duration(milliseconds: 1));
      expect(
        harness.decide(LogicalKeyboardKey.select),
        TvRemoteKeyDecision.passThrough,
      );
    });

    test('a single deliberate swipe passes through', () {
      final harness = _Harness();

      expect(
        harness.decide(LogicalKeyboardKey.arrowRight),
        TvRemoteKeyDecision.passThrough,
      );
    });

    test(
      'a same-direction repeat faster than the debounce window is suppressed',
      () {
        final harness = _Harness();

        expect(
          harness.decide(LogicalKeyboardKey.arrowRight),
          TvRemoteKeyDecision.passThrough,
        );
        harness.advance(const Duration(milliseconds: 50));
        expect(
          harness.decide(LogicalKeyboardKey.arrowRight),
          TvRemoteKeyDecision.suppress,
        );
      },
    );

    test(
      'a same-direction repeat slower than the debounce window passes through',
      () {
        final harness = _Harness();

        expect(
          harness.decide(LogicalKeyboardKey.arrowRight),
          TvRemoteKeyDecision.passThrough,
        );
        harness.advance(const Duration(milliseconds: 130));
        expect(
          harness.decide(LogicalKeyboardKey.arrowRight),
          TvRemoteKeyDecision.passThrough,
        );
      },
    );

    test('debounce is tracked independently per direction', () {
      final harness = _Harness();

      expect(
        harness.decide(LogicalKeyboardKey.arrowRight),
        TvRemoteKeyDecision.passThrough,
      );
      harness.advance(const Duration(milliseconds: 10));
      expect(
        harness.decide(LogicalKeyboardKey.arrowDown),
        TvRemoteKeyDecision.passThrough,
      );
    });

    test('a direction key immediately after select is suppressed once', () {
      final harness = _Harness()
        ..decide(LogicalKeyboardKey.select)
        ..advance(const Duration(milliseconds: 20));
      expect(
        harness.decide(LogicalKeyboardKey.arrowRight),
        TvRemoteKeyDecision.suppress,
      );

      // The dead zone only fires once: a second, later swipe is a
      // deliberate move and must go through (past the debounce window too).
      harness.advance(const Duration(milliseconds: 200));
      expect(
        harness.decide(LogicalKeyboardKey.arrowRight),
        TvRemoteKeyDecision.passThrough,
      );
    });

    test('a direction key well after select is unaffected', () {
      final harness = _Harness()
        ..decide(LogicalKeyboardKey.select)
        ..advance(const Duration(milliseconds: 500));
      expect(
        harness.decide(LogicalKeyboardKey.arrowRight),
        TvRemoteKeyDecision.passThrough,
      );
    });

    test(
      'a fast sustained burst crosses into acceleration at the threshold',
      () {
        final harness = _Harness();

        expect(
          harness.decide(LogicalKeyboardKey.arrowRight),
          TvRemoteKeyDecision.passThrough,
        );
        harness.advance(const Duration(milliseconds: 130));
        expect(
          harness.decide(LogicalKeyboardKey.arrowRight),
          TvRemoteKeyDecision.passThrough,
        );
        harness.advance(const Duration(milliseconds: 130));
        expect(
          harness.decide(LogicalKeyboardKey.arrowRight),
          TvRemoteKeyDecision.accelerate,
        );
        // Stays accelerated on further sustained repeats.
        harness.advance(const Duration(milliseconds: 130));
        expect(
          harness.decide(LogicalKeyboardKey.arrowRight),
          TvRemoteKeyDecision.accelerate,
        );
      },
    );

    test('a gap longer than the burst window resets the burst', () {
      final harness = _Harness()
        ..decide(LogicalKeyboardKey.arrowRight)
        ..advance(const Duration(milliseconds: 130))
        ..decide(LogicalKeyboardKey.arrowRight)
        ..advance(const Duration(milliseconds: 130));
      expect(
        harness.decide(LogicalKeyboardKey.arrowRight),
        TvRemoteKeyDecision.accelerate,
      );

      harness.advance(const Duration(milliseconds: 400));
      expect(
        harness.decide(LogicalKeyboardKey.arrowRight),
        TvRemoteKeyDecision.passThrough,
      );
    });

    test('switching direction resets the burst', () {
      final harness = _Harness()
        ..decide(LogicalKeyboardKey.arrowRight)
        ..advance(const Duration(milliseconds: 130))
        ..decide(LogicalKeyboardKey.arrowRight)
        ..advance(const Duration(milliseconds: 130));
      expect(
        harness.decide(LogicalKeyboardKey.arrowRight),
        TvRemoteKeyDecision.accelerate,
      );

      harness.advance(const Duration(milliseconds: 130));
      expect(
        harness.decide(LogicalKeyboardKey.arrowDown),
        TvRemoteKeyDecision.passThrough,
      );
    });

    test('directionOf resolves the accelerated key back to a direction', () {
      final governor = TvRemoteKeyGovernor();

      expect(
        governor.directionOf(LogicalKeyboardKey.arrowRight),
        TraversalDirection.right,
      );
      expect(
        governor.directionOf(LogicalKeyboardKey.arrowUp),
        TraversalDirection.up,
      );
      expect(governor.directionOf(LogicalKeyboardKey.select), isNull);
    });
  });
}

class _Harness {
  _Harness();

  DateTime now = DateTime(2026, 5, 5, 12);
  late final TvRemoteKeyGovernor _governor = TvRemoteKeyGovernor(
    now: () => now,
  );

  TvRemoteKeyDecision decide(LogicalKeyboardKey key) {
    return _governor.decide(_keyDown(key));
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
