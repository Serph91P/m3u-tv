import 'dart:async';

import 'package:dpad/dpad.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3u_tv/features/requests/request_controller.dart';
import 'package:m3u_tv/features/requests/request_screen.dart';
import 'package:m3u_tv/l10n/app_localizations.dart';
import 'package:m3u_tv/providers/app_providers.dart';
import 'package:m3u_tv/services/request_models.dart';
import 'package:m3u_tv/shared/dpad_ink_well.dart';

void main() {
  testWidgets('shows validation before searching', (tester) async {
    final controller = RequestController.forTest();
    await tester.pumpWidget(_app(controller));

    await tester.enterText(find.byType(TextField), 'a');
    await tester.tap(find.text('Search'));
    await tester.pump();

    expect(find.text('Enter at least 2 characters.'), findsOneWidget);
  });

  testWidgets('shows search loading, empty, and API error states', (
    tester,
  ) async {
    final completer = Completer<List<RequestSearchResult>>();
    final controller = RequestController.forTest(
      onSearch: (_, _) => completer.future,
    );
    await tester.pumpWidget(_app(controller));

    await tester.enterText(find.byType(TextField), 'missing');
    await tester.tap(find.text('Search'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsWidgets);

    completer.complete(const []);
    await tester.pumpAndSettle();
    expect(find.text('No matching titles found.'), findsOneWidget);

    controller.onSearch = (_, _) => throw Exception('Search unavailable');
    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Search unavailable'), findsOneWidget);
  });

  testWidgets('requests focused result with select and refreshes history', (
    tester,
  ) async {
    var submitted = false;
    var historyLoads = 0;
    final controller = RequestController.forTest(
      onSearch: (_, _) async => const [_result],
      onSubmit: (_) async {
        submitted = true;
        return _submission;
      },
      onLoadHistory: () async => historyLoads++ == 0 ? [] : [_historyItem],
    );
    await tester.pumpWidget(_app(controller));

    await tester.enterText(find.byType(TextField), 'fight club');
    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();
    expect(find.text('Fight Club'), findsOneWidget);
    expect(find.text('Request movie'), findsOneWidget);

    final card = find.ancestor(
      of: find.text('Fight Club'),
      matching: find.byType(DpadInkWell),
    );
    final focusable = find.descendant(
      of: card,
      matching: find.byType(DpadFocusable),
    );
    tester.widget<DpadFocusable>(focusable).focusNode!.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();

    expect(submitted, isTrue);
    expect(find.text('Pending approval'), findsWidgets);
    expect(find.text('My requests'), findsOneWidget);
  });

  testWidgets('shows already available result as unavailable action', (
    tester,
  ) async {
    final controller = RequestController.forTest(
      onSearch: (_, _) async => const [
        RequestSearchResult(
          type: RequestMediaType.movie,
          externalId: '1',
          integrationId: '7',
          integrationName: 'Radarr',
          title: 'Existing Movie',
          alreadyAvailable: true,
        ),
      ],
    );
    await tester.pumpWidget(_app(controller));

    await tester.enterText(find.byType(TextField), 'existing');
    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();

    expect(find.text('Already available'), findsOneWidget);
  });

  testWidgets('left edge invokes sidebar activation', (tester) async {
    var activated = false;
    final controller = RequestController.forTest(
      onSearch: (_, _) async => const [_result],
    );
    await tester.pumpWidget(
      _app(controller, onSidebarActivate: () => activated = true),
    );

    await tester.enterText(find.byType(TextField), 'fight club');
    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();
    final focusable = find.descendant(
      of: find.ancestor(
        of: find.text('Fight Club'),
        matching: find.byType(DpadInkWell),
      ),
      matching: find.byType(DpadFocusable),
    );
    tester.widget<DpadFocusable>(focusable).focusNode!.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();

    expect(activated, isTrue);
  });

  testWidgets('dismissible history item shows dismiss button', (tester) async {
    final controller = RequestController.forTest(
      onLoadHistory: () async => [_dismissableItem],
    );
    await tester.pumpWidget(_app(controller));
    await tester.pumpAndSettle();

    expect(find.text('Alien'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);
  });
}

const _result = RequestSearchResult(
  type: RequestMediaType.movie,
  externalId: '550',
  integrationId: '7',
  integrationName: 'Radarr',
  title: 'Fight Club',
  year: 1999,
);

final _historyItem = RequestHistoryItem(
  id: '42',
  type: RequestMediaType.movie,
  externalId: '550',
  title: 'Fight Club',
  status: RequestStatus.pendingApproval,
  integrationId: '7',
  integrationName: 'Radarr',
  requestedAt: DateTime.utc(2026, 7, 11),
);

const _dismissableItem = RequestHistoryItem(
  id: '99',
  type: RequestMediaType.movie,
  externalId: '348',
  title: 'Alien',
  status: RequestStatus.completed,
  integrationId: '1',
  integrationName: 'Radarr',
  canDismiss: true,
);

final _submission = RequestSubmission(
  status: RequestStatus.pendingApproval,
  request: _historyItem,
);

Widget _app(RequestController controller, {VoidCallback? onSidebarActivate}) =>
    ProviderScope(
      overrides: [
        isConfiguredProvider.overrideWith((_) => true),
        requestControllerProvider.overrideWith((_) => controller),
      ],
      child: MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: RequestScreen(
          onSearch: controller.search,
          onSubmit: controller.submit,
          onLoadHistory: controller.loadHistory,
          onRefreshItem: controller.refreshItem,
          onDismiss: controller.dismiss,
          onSidebarActivate: onSidebarActivate,
        ),
      ),
    );
