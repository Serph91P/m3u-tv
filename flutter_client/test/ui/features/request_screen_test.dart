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
    final completer = Completer<RequestSearchPage>();
    final controller = RequestController.forTest(
      onSearch: (_, _, {page = 1, perPage = 20}) => completer.future,
    );
    await tester.pumpWidget(_app(controller));

    await tester.enterText(find.byType(TextField), 'missing');
    await tester.tap(find.text('Search'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsWidgets);

    completer.complete(
      const RequestSearchPage(
        results: [],
        currentPage: 1,
        perPage: 20,
        total: 0,
        lastPage: 1,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No matching titles found.'), findsOneWidget);

    controller.onSearch = (_, _, {page = 1, perPage = 20}) =>
        throw Exception('Search unavailable');
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
      onSearch: (_, _, {page = 1, perPage = 20}) async =>
          const RequestSearchPage(
            results: [_result],
            currentPage: 1,
            perPage: 20,
            total: 1,
            lastPage: 1,
          ),
      onSubmit: (result, {seasons = const <int>[]}) async {
        submitted = true;
        return _submission;
      },
      onLoadHistory: ({page = 1, perPage = 20}) async => historyLoads++ == 0
          ? const RequestHistoryPage(
              requests: [],
              currentPage: 1,
              perPage: 20,
              total: 0,
              lastPage: 1,
            )
          : RequestHistoryPage(
              requests: [_historyItem],
              currentPage: 1,
              perPage: 20,
              total: 1,
              lastPage: 1,
            ),
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

  testWidgets('selects series seasons and shows successful submission', (
    tester,
  ) async {
    List<int>? submittedSeasons;
    var historyLoads = 0;
    final controller = RequestController.forTest(
      onSearch: (_, _, {page = 1, perPage = 20}) async =>
          const RequestSearchPage(
            results: [_seriesResult],
            currentPage: 1,
            perPage: 20,
            total: 1,
            lastPage: 1,
          ),
      onSubmit: (result, {seasons = const <int>[]}) async {
        submittedSeasons = seasons;
        return _seriesSubmission;
      },
      onLoadHistory: ({page = 1, perPage = 20}) async {
        historyLoads++;
        return const RequestHistoryPage(
          requests: [],
          currentPage: 1,
          perPage: 20,
          total: 0,
          lastPage: 1,
        );
      },
    );
    await tester.pumpWidget(_app(controller));

    await tester.enterText(find.byType(TextField), 'game of thrones');
    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.ancestor(
        of: find.text('Game of Thrones'),
        matching: find.byType(DpadInkWell),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Select seasons to request'), findsOneWidget);
    expect(
      find.text('Use D-pad to select, press OK to confirm'),
      findsOneWidget,
    );
    expect(submittedSeasons, isNull);

    await tester.tap(find.text('Season 0'));
    await tester.tap(find.text('Season 2'));
    await tester.pump();
    final dialog = find.byType(AlertDialog);
    await tester.tap(
      find.descendant(of: dialog, matching: find.text('Request series')),
    );
    await tester.pumpAndSettle();

    expect(submittedSeasons, [0, 2]);
    expect(historyLoads, 2);
    expect(find.text('Pending approval'), findsOneWidget);
  });

  testWidgets('requests all series seasons with an empty selection', (
    tester,
  ) async {
    List<int>? submittedSeasons;
    final controller = RequestController.forTest(
      onSearch: (_, _, {page = 1, perPage = 20}) async =>
          const RequestSearchPage(
            results: [_seriesResult],
            currentPage: 1,
            perPage: 20,
            total: 1,
            lastPage: 1,
          ),
      onSubmit: (result, {seasons = const <int>[]}) async {
        submittedSeasons = seasons;
        return _seriesSubmission;
      },
    );
    await tester.pumpWidget(_app(controller));

    await tester.enterText(find.byType(TextField), 'game of thrones');
    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.ancestor(
        of: find.text('Game of Thrones'),
        matching: find.byType(DpadInkWell),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('All seasons'));
    await tester.pumpAndSettle();

    expect(submittedSeasons, isEmpty);
    expect(find.text('Pending approval'), findsOneWidget);
  });

  testWidgets('requests series without season options directly', (
    tester,
  ) async {
    List<int>? submittedSeasons;
    final controller = RequestController.forTest(
      onSearch: (_, _, {page = 1, perPage = 20}) async =>
          const RequestSearchPage(
            results: [_seriesWithoutSeasons],
            currentPage: 1,
            perPage: 20,
            total: 1,
            lastPage: 1,
          ),
      onSubmit: (result, {seasons = const <int>[]}) async {
        submittedSeasons = seasons;
        return _seriesSubmission;
      },
    );
    await tester.pumpWidget(_app(controller));

    await tester.enterText(find.byType(TextField), 'the last of us');
    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.ancestor(
        of: find.text('The Last of Us'),
        matching: find.byType(DpadInkWell),
      ),
    );
    await tester.pumpAndSettle();

    expect(submittedSeasons, isEmpty);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Pending approval'), findsOneWidget);
  });

  testWidgets('shows already available result as unavailable action', (
    tester,
  ) async {
    final controller = RequestController.forTest(
      onSearch: (_, _, {page = 1, perPage = 20}) async =>
          const RequestSearchPage(
            results: [
              RequestSearchResult(
                type: RequestMediaType.movie,
                externalId: '1',
                integrationId: '7',
                integrationName: 'Radarr',
                title: 'Existing Movie',
                alreadyAvailable: true,
              ),
            ],
            currentPage: 1,
            perPage: 20,
            total: 1,
            lastPage: 1,
          ),
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
      onSearch: (_, _, {page = 1, perPage = 20}) async =>
          const RequestSearchPage(
            results: [_result],
            currentPage: 1,
            perPage: 20,
            total: 1,
            lastPage: 1,
          ),
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
      onLoadHistory: ({page = 1, perPage = 20}) async =>
          const RequestHistoryPage(
            requests: [_dismissableItem],
            currentPage: 1,
            perPage: 20,
            total: 1,
            lastPage: 1,
          ),
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

const _seriesResult = RequestSearchResult(
  type: RequestMediaType.series,
  externalId: '1399',
  integrationId: '7',
  integrationName: 'Sonarr',
  title: 'Game of Thrones',
  year: 2011,
  seasons: [0, 1, 2],
);

const _seriesWithoutSeasons = RequestSearchResult(
  type: RequestMediaType.series,
  externalId: '100088',
  integrationId: '7',
  integrationName: 'Sonarr',
  title: 'The Last of Us',
  year: 2023,
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

const _seriesSubmission = RequestSubmission(
  status: RequestStatus.pendingApproval,
  request: RequestHistoryItem(
    id: '43',
    type: RequestMediaType.series,
    externalId: '1399',
    title: 'Game of Thrones',
    status: RequestStatus.pendingApproval,
    integrationId: '7',
    integrationName: 'Sonarr',
  ),
  selectedSeasons: [0, 2],
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
