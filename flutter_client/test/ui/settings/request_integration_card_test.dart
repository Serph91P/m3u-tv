import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3u_tv/features/settings/settings_screen.dart';
import 'package:m3u_tv/l10n/app_localizations.dart';
import 'package:m3u_tv/services/auth_notifier.dart';
import 'package:m3u_tv/services/secure_storage.dart';
import 'package:m3u_tv/services/trakt_service.dart';
import 'package:m3u_tv/services/xtream_service.dart';

void main() {
  testWidgets('shows request card only when capability is available', (
    tester,
  ) async {
    await tester.pumpWidget(_app(hasRequests: false));
    await tester.tap(find.text('Integrations'));
    await tester.pumpAndSettle();
    expect(find.text('Content Requests'), findsNothing);

    await tester.pumpWidget(_app(hasRequests: true));
    await tester.tap(find.text('Integrations'));
    await tester.pumpAndSettle();
    expect(find.text('Content Requests'), findsOneWidget);
  });

  testWidgets('request card navigates through supplied route callback', (
    tester,
  ) async {
    var navigated = false;
    await tester.pumpWidget(
      _app(hasRequests: true, onRequestsSelect: () => navigated = true),
    );
    await tester.tap(find.text('Integrations'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Browse requests'));
    await tester.pump();

    expect(navigated, isTrue);
  });
}

Widget _app({required bool hasRequests, VoidCallback? onRequestsSelect}) {
  final notifier = AuthNotifier(
    xtreamService: XtreamService(transport: (_) async => null),
    secureStorage: InMemorySecureStorage(),
  );
  return MaterialApp(
    theme: ThemeData.dark(useMaterial3: true),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: SettingsScreen(
      authNotifier: notifier,
      traktService: TraktService(storage: InMemorySecureStorage()),
      isConfiguredOverride: true,
      hasRequestsFeature: hasRequests,
      onRequestsSelect: onRequestsSelect,
    ),
  );
}
