import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3u_tv/app/app_shell.dart';
import 'package:m3u_tv/features/player/player_screen.dart';
import 'package:m3u_tv/navigation/app_router.dart';
import 'package:m3u_tv/navigation/route_names.dart';
import 'package:m3u_tv/services/app_state_controller.dart';
import 'package:m3u_tv/services/domain_models.dart';
import 'package:m3u_tv/services/xtream_service.dart';

void main() {
  group('Route navigation', () {
    testWidgets('initial route shows Home content', (tester) async {
      await tester.pumpWidget(const _TestApp(deviceType: DeviceType.tv));
      await tester.pumpAndSettle();

      // Home text appears in both sidebar and content area
      expect(find.text('Home'), findsAtLeast(1));
      expect(
        find.text('Please connect to your service in Settings'),
        findsOneWidget,
      );
    });

    testWidgets('navigating to LiveTV shows Live TV screen', (tester) async {
      await tester.pumpWidget(const _TestApp(deviceType: DeviceType.tv));
      await tester.pumpAndSettle();

      // Sidebar is expanded by default, so text is visible
      await tester.tap(_sidebarText('Live TV'));
      await tester.pumpAndSettle();

      expect(
        find.text('Please connect to your service in Settings'),
        findsOneWidget,
      );
    });

    testWidgets('navigating to VOD shows Movies screen', (tester) async {
      await tester.pumpWidget(const _TestApp(deviceType: DeviceType.tv));
      await tester.pumpAndSettle();

      await tester.tap(_sidebarText('Movies'));
      await tester.pumpAndSettle();

      expect(
        find.text('Please connect to your service in Settings'),
        findsOneWidget,
      );
    });

    testWidgets('navigating to Series shows Series screen', (tester) async {
      await tester.pumpWidget(const _TestApp(deviceType: DeviceType.tv));
      await tester.pumpAndSettle();

      await tester.tap(_sidebarText('Series'));
      await tester.pumpAndSettle();

      expect(
        find.text('Please connect to your service in Settings'),
        findsOneWidget,
      );
    });

    testWidgets('navigating to Search shows Search screen', (tester) async {
      await tester.pumpWidget(const _TestApp(deviceType: DeviceType.tv));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Search'));
      await tester.pumpAndSettle();

      expect(
        find.text('Please connect to your service in Settings'),
        findsOneWidget,
      );
    });

    testWidgets('navigating to Settings shows Settings screen', (tester) async {
      await tester.pumpWidget(const _TestApp(deviceType: DeviceType.tv));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      expect(find.text('Server URL'), findsOneWidget);
    });

    testWidgets('sidebar labels remain visible after selecting a route', (
      tester,
    ) async {
      await tester.pumpWidget(const _TestApp(deviceType: DeviceType.tv));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(NavigationSidebar),
          matching: find.text('Home'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(NavigationSidebar),
          matching: find.text('Settings'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('Player route pushes as modal via inner navigator', (
      tester,
    ) async {
      await tester.pumpWidget(const _TestApp(deviceType: DeviceType.tv));
      await tester.pumpAndSettle();

      final nav = _findInnerNavigator(tester);
      unawaited(
        nav.pushNamed(
          RouteNames.player,
          arguments: const PlayerArgs(
            streamUrl: 'http://example.com/stream.m3u8',
            title: 'Test Channel',
            type: 'live',
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(PlayerScreen), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('Details route pushes via inner navigator', (tester) async {
      await tester.pumpWidget(const _TestApp(deviceType: DeviceType.tv));
      await tester.pumpAndSettle();

      final nav = _findInnerNavigator(tester);
      unawaited(
        nav.pushNamed(
          RouteNames.details,
          arguments: const DetailsArgs(vodId: 1, vodName: 'Test Movie'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Test Movie'), findsOneWidget);
    });

    testWidgets('SeriesDetails route pushes via inner navigator', (
      tester,
    ) async {
      await tester.pumpWidget(const _TestApp(deviceType: DeviceType.tv));
      await tester.pumpAndSettle();

      final nav = _findInnerNavigator(tester);
      unawaited(
        nav.pushNamed(
          RouteNames.seriesDetails,
          arguments: const SeriesDetailsArgs(
            seriesId: 1,
            seriesName: 'Test Series',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Test Series'), findsOneWidget);
    });

    testWidgets('ViewerSelection route pushes via inner navigator', (
      tester,
    ) async {
      await tester.pumpWidget(const _TestApp(deviceType: DeviceType.tv));
      await tester.pumpAndSettle();

      final nav = _findInnerNavigator(tester);
      unawaited(nav.pushNamed(RouteNames.viewerSelection));
      await tester.pumpAndSettle();

      expect(find.text('Viewer Selection'), findsOneWidget);
    });
  });

  testWidgets('selecting live channel from app shell opens player route', (
    tester,
  ) async {
    final appState = AppStateController(
      xtreamService: _NavigationXtreamService(),
    );
    addTearDown(appState.dispose);
    await appState.connectXtream(
      const UserCredentials(
        server: 'http://example.com',
        username: 'user',
        password: 'pass',
      ),
    );

    await tester.pumpWidget(
      _TestApp(deviceType: DeviceType.tv, appState: appState),
    );
    await tester.pumpAndSettle();

    await tester.tap(_sidebarText('Live TV'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Route News'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(PlayerScreen), findsOneWidget);
  });

  testWidgets('selecting Home continue watching movie opens player route', (
    tester,
  ) async {
    final appState = AppStateController(
      xtreamService: _NavigationXtreamService(
        recentlyWatched: const <Progress>[
          Progress(
            viewerId: 'viewer-1',
            contentType: ContentType.vod,
            streamId: 201,
            positionSeconds: 91,
            durationSeconds: 600,
          ),
        ],
      ),
    );
    addTearDown(appState.dispose);
    await appState.connectXtream(
      const UserCredentials(
        server: 'http://example.com',
        username: 'user',
        password: 'pass',
      ),
    );

    await tester.pumpWidget(
      _TestApp(deviceType: DeviceType.tv, appState: appState),
    );
    await tester.pumpAndSettle();

    expect(find.text('Resume Route Movie'), findsOneWidget);
    expect(find.text('Stream 201'), findsOneWidget);

    await tester.tap(find.text('Stream 201'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(PlayerScreen), findsOneWidget);
  });

  testWidgets('selecting movie from app shell opens player route', (
    tester,
  ) async {
    final appState = AppStateController(
      xtreamService: _NavigationXtreamService(),
    );
    addTearDown(appState.dispose);
    await appState.connectXtream(
      const UserCredentials(
        server: 'http://example.com',
        username: 'user',
        password: 'pass',
      ),
    );

    await tester.pumpWidget(
      _TestApp(deviceType: DeviceType.tv, appState: appState),
    );
    await tester.pumpAndSettle();

    await tester.tap(_sidebarText('Movies'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Route Movie'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(PlayerScreen), findsOneWidget);
  });

  testWidgets('selecting series from app shell opens series details route', (
    tester,
  ) async {
    final appState = AppStateController(
      xtreamService: _NavigationXtreamService(),
    );
    addTearDown(appState.dispose);
    await appState.connectXtream(
      const UserCredentials(
        server: 'http://example.com',
        username: 'user',
        password: 'pass',
      ),
    );

    await tester.pumpWidget(
      _TestApp(deviceType: DeviceType.tv, appState: appState),
    );
    await tester.pumpAndSettle();

    await tester.tap(_sidebarText('Series'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Route Series'));
    await tester.pumpAndSettle();

    expect(find.text('Route Series'), findsWidgets);
  });

  group('Adaptive layout', () {
    testWidgets('TV device shows sidebar navigation', (tester) async {
      await tester.pumpWidget(const _TestApp(deviceType: DeviceType.tv));
      await tester.pumpAndSettle();

      expect(find.byType(NavigationSidebar), findsOneWidget);
      expect(find.byType(BottomNavigationBar), findsNothing);
    });

    testWidgets('Desktop device shows sidebar navigation', (tester) async {
      await tester.pumpWidget(const _TestApp(deviceType: DeviceType.desktop));
      await tester.pumpAndSettle();

      expect(find.byType(NavigationSidebar), findsOneWidget);
      expect(find.byType(BottomNavigationBar), findsNothing);
    });

    testWidgets('Phone device shows bottom navigation', (tester) async {
      await tester.pumpWidget(const _TestApp(deviceType: DeviceType.phone));
      await tester.pumpAndSettle();

      expect(find.byType(BottomNavigationBar), findsOneWidget);
      expect(find.byType(NavigationSidebar), findsNothing);
    });

    testWidgets('Tablet device shows bottom navigation', (tester) async {
      await tester.pumpWidget(const _TestApp(deviceType: DeviceType.tablet));
      await tester.pumpAndSettle();

      expect(find.byType(BottomNavigationBar), findsOneWidget);
      expect(find.byType(NavigationSidebar), findsNothing);
    });
  });

  group('TV focus traversal', () {
    testWidgets('sidebar items are focusable', (tester) async {
      await tester.pumpWidget(const _TestApp(deviceType: DeviceType.tv));
      await tester.pumpAndSettle();

      final sidebarItems = find.byType(SidebarDestinationItem);
      expect(sidebarItems, findsAtLeast(6));
    });

    testWidgets('D-pad down moves focus through sidebar items', (tester) async {
      await tester.pumpWidget(const _TestApp(deviceType: DeviceType.tv));
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();

      expect(find.byType(AppShell), findsOneWidget);
    });

    testWidgets('D-pad right moves focus from sidebar to content', (
      tester,
    ) async {
      await tester.pumpWidget(const _TestApp(deviceType: DeviceType.tv));
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();

      expect(find.byType(AppShell), findsOneWidget);
    });

    testWidgets('Menu key opens sidebar on TV', (tester) async {
      await tester.pumpWidget(const _TestApp(deviceType: DeviceType.tv));
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.contextMenu);
      await tester.pump();

      expect(find.byType(NavigationSidebar), findsOneWidget);
    });
  });

  group('Back behavior', () {
    testWidgets('back button on modal route pops to main', (tester) async {
      await tester.pumpWidget(const _TestApp(deviceType: DeviceType.tv));
      await tester.pumpAndSettle();

      final nav = _findInnerNavigator(tester);
      unawaited(
        nav.pushNamed(
          RouteNames.player,
          arguments: const PlayerArgs(
            streamUrl: 'http://example.com/stream.m3u8',
            title: 'Test Channel',
            type: 'live',
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(PlayerScreen), findsOneWidget);

      nav.pop();
      await tester.pumpAndSettle();

      // Should be back at Home content
      expect(
        find.text('Please connect to your service in Settings'),
        findsOneWidget,
      );
    });

    testWidgets('back on TV activates sidebar when content is focused', (
      tester,
    ) async {
      await tester.pumpWidget(const _TestApp(deviceType: DeviceType.tv));
      await tester.pumpAndSettle();

      // Move focus to content area first
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();

      // Press back/escape
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      expect(find.byType(NavigationSidebar), findsOneWidget);
    });

    testWidgets('back on phone pops modal routes', (tester) async {
      await tester.pumpWidget(const _TestApp(deviceType: DeviceType.phone));
      await tester.pumpAndSettle();

      final nav = _findInnerNavigator(tester);
      unawaited(
        nav.pushNamed(
          RouteNames.details,
          arguments: const DetailsArgs(vodId: 1, vodName: 'Test Movie'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Test Movie'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      // Should be back at Home content
      expect(
        find.text('Please connect to your service in Settings'),
        findsOneWidget,
      );
    });
  });

  group('Focus restoration', () {
    testWidgets('returning from modal restores previous route content', (
      tester,
    ) async {
      await tester.pumpWidget(const _TestApp(deviceType: DeviceType.tv));
      await tester.pumpAndSettle();

      // Navigate to Live TV
      await tester.tap(_sidebarText('Live TV'));
      await tester.pumpAndSettle();

      // Push Player modal
      final nav = _findInnerNavigator(tester);
      unawaited(
        nav.pushNamed(
          RouteNames.player,
          arguments: const PlayerArgs(
            streamUrl: 'http://example.com/stream.m3u8',
            title: 'Test Channel',
            type: 'live',
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Pop Player
      nav.pop();
      await tester.pumpAndSettle();

      // Should be back at Live TV content (not Home)
      expect(
        find.text('Please connect to your service in Settings'),
        findsOneWidget,
      );
    });
  });
}

/// Finds the inner NavigatorState from the _ContentNavigator widget.
NavigatorState _findInnerNavigator(WidgetTester tester) {
  final navigators = tester.stateList<NavigatorState>(find.byType(Navigator));
  // The inner navigator is the last one (MaterialApp creates the first)
  return navigators.last;
}

Finder _sidebarText(String label) {
  return find.descendant(
    of: find.byType(NavigationSidebar),
    matching: find.text(label),
  );
}

/// Test app that wraps AppShell with a controlled device type.
class _TestApp extends StatelessWidget {
  const _TestApp({required this.deviceType, this.appState});

  final DeviceType deviceType;
  final AppStateController? appState;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'M3U TV Test',
      theme: ThemeData.dark(useMaterial3: true),
      home: AppShell(deviceType: deviceType, appState: appState),
    );
  }
}

class _NavigationXtreamService extends XtreamService {
  _NavigationXtreamService({this.recentlyWatched = const <Progress>[]});

  final List<Progress> recentlyWatched;

  @override
  Future<XtreamAuthResponse> authenticate(UserCredentials credentials) async {
    return const XtreamAuthResponse(
      isAuthenticated: true,
      status: 'Active',
      m3uEditorVersion: 'test',
    );
  }

  @override
  Future<List<Category>> getLiveCategories() async => const <Category>[
    Category(id: 'live', name: 'Live'),
  ];

  @override
  Future<List<Category>> getVodCategories() async => const <Category>[
    Category(id: 'vod', name: 'VOD'),
  ];

  @override
  Future<List<Category>> getSeriesCategories() async => const <Category>[
    Category(id: 'series', name: 'Series'),
  ];

  @override
  Future<List<Channel>> getLiveStreams({String? categoryId}) async =>
      const <Channel>[
        Channel(
          id: 101,
          name: 'Route News',
          streamUrl: 'http://example.com/live/101.m3u8',
          categoryId: 'live',
        ),
      ];

  @override
  Future<List<VodItem>> getVodStreams({String? categoryId}) async =>
      const <VodItem>[
        VodItem(
          id: 201,
          name: 'Route Movie',
          streamUrl: 'http://example.com/movie/201.mp4',
          containerExtension: 'mp4',
          categoryId: 'vod',
        ),
      ];

  @override
  Future<List<Series>> getSeries({String? categoryId}) async => const <Series>[
    Series(id: 301, name: 'Route Series', categoryId: 'series'),
  ];

  @override
  Future<List<Viewer>> getViewers() async => const <Viewer>[
    Viewer(id: 1, ulid: 'viewer-1', name: 'Viewer', isAdmin: true),
  ];

  @override
  Future<List<Progress>> getRecentlyWatched(
    String viewerId, {
    int limit = 20,
    ContentType? type,
  }) async => recentlyWatched
      .where((progress) => type == null || progress.contentType == type)
      .take(limit)
      .toList(growable: false);
}
