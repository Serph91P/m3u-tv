import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3u_tv/services/tv_notification_service.dart';
import 'package:m3u_tv/shared/notification_toast.dart';

void main() {
  const item = TvNotificationItem(
    id: 'toast-1',
    channel: 'general',
    title: 'Hello',
    status: 'info',
  );

  Future<void> pump(WidgetTester tester, {required bool swipeToDismiss}) {
    return tester.pumpWidget(
      MaterialApp(
        home: NotificationToastOverlay(
          swipeToDismiss: swipeToDismiss,
          child: const SizedBox.expand(),
        ),
      ),
    );
  }

  testWidgets('swiping the toast dismisses it when swipeToDismiss is true', (
    tester,
  ) async {
    await pump(tester, swipeToDismiss: true);
    final key =
        find.byType(NotificationToastOverlay).evaluate().single.widget
            as NotificationToastOverlay;
    tester
        .state<NotificationToastOverlayState>(
          find.byWidget(key),
        )
        .enqueue(item);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Hello'), findsOneWidget);

    await tester.drag(find.text('Hello'), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(find.text('Hello'), findsNothing);
  });

  testWidgets('swipe does not dismiss when swipeToDismiss is false', (
    tester,
  ) async {
    await pump(tester, swipeToDismiss: false);
    final key =
        find.byType(NotificationToastOverlay).evaluate().single.widget
            as NotificationToastOverlay;
    tester
        .state<NotificationToastOverlayState>(
          find.byWidget(key),
        )
        .enqueue(item);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.drag(find.text('Hello'), const Offset(-500, 0));
    await tester.pump();

    expect(find.text('Hello'), findsOneWidget);
  });
}
