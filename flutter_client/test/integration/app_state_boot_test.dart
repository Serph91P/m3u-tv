import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3u_tv/app/app_shell.dart';
import 'package:m3u_tv/services/app_state_controller.dart';
import 'package:m3u_tv/services/cache_service.dart';
import 'package:m3u_tv/services/domain_models.dart';
import 'package:m3u_tv/services/favorites_service.dart';
import 'package:m3u_tv/services/resume_service.dart';
import 'package:m3u_tv/services/secure_storage.dart';
import 'package:m3u_tv/services/viewer_service.dart';
import 'package:m3u_tv/services/xtream_service.dart';

void main() {
  group('app state boot', () {
    testWidgets(
      'saved_source boots connected app state without constructor fixtures',
      (WidgetTester tester) async {
        final storage = InMemorySecureStorage();
        final localMemory = <String, Object?>{};
        await storage.write(
          'm3ue_tv_credentials',
          jsonEncode(<String, String>{
            'server': 'https://fixture.example',
            'username': 'fixture-user',
            'password': 'fixture-password',
          }),
        );
        await storage.write(
          'm3ue_tv_source',
          jsonEncode(<String, String>{'type': 'xtream'}),
        );
        final resumeService = ResumeService(memory: localMemory);
        await FavoritesService(memory: localMemory).add(101);
        await resumeService.save(
          const Progress(
            viewerId: 'viewer-admin',
            contentType: ContentType.vod,
            streamId: 201,
            positionSeconds: 91,
            durationSeconds: 600,
          ),
        );

        final controller = _controller(
          storage: storage,
          localMemory: localMemory,
          transport: _FakeXtreamTransport.success().call,
        );

        await tester.pumpWidget(_TestApp(controller: controller));
        await _pumpAppState(tester);

        expect(find.text('Connected source: Xtream'), findsOneWidget);
        expect(find.text('BBC One'), findsOneWidget);
        expect(find.text('Big Buck Bunny'), findsOneWidget);
        expect(find.text('Fixture Show'), findsOneWidget);
        expect(find.text('Stream 201'), findsOneWidget);
        expect(await controller.favoritesService.isFavorite(101), isTrue);

        await _tapSidebarDestination(tester, 'Live TV');
        await _pumpAppState(tester);
        expect(find.text('All Channels'), findsOneWidget);
        expect(find.text('BBC One'), findsWidgets);

        await _tapSidebarDestination(tester, 'Movies');
        await _pumpAppState(tester);
        expect(find.text('All Movies'), findsOneWidget);
        expect(find.text('Big Buck Bunny'), findsWidgets);

        await _tapSidebarDestination(tester, 'Series');
        await _pumpAppState(tester);
        expect(find.text('All Series'), findsOneWidget);
        expect(find.text('Fixture Show'), findsWidgets);

        await _tapSidebarDestination(tester, 'Settings');
        await _pumpAppState(tester);
        expect(find.text('Connection Status'), findsOneWidget);
        expect(find.text('Source'), findsOneWidget);
        expect(find.text('Xtream'), findsOneWidget);
        expect(_visibleText(tester), isNot(contains('fixture-password')));
        expect(_visibleText(tester), isNot(contains('fixture-user')));

        final restarted = _controller(
          storage: storage,
          localMemory: localMemory,
          transport: _FakeXtreamTransport.success().call,
        );
        await restarted.boot();

        expect(restarted.channels.single.name, 'BBC One');
        expect(await restarted.favoritesService.isFavorite(101), isTrue);
        expect(restarted.progressList.single.streamId, 201);
        expect(restarted.progressList.single.positionSeconds, 91);
        expect(restarted.error, isNot(contains('fixture-password')));
      },
    );

    testWidgets(
      'source switch failure path preserves prior cache and redacts credentials',
      (WidgetTester tester) async {
        final storage = InMemorySecureStorage();
        final cacheMemory = <String, Object?>{};
        final localMemory = <String, Object?>{};
        final controller = _controller(
          storage: storage,
          cacheMemory: cacheMemory,
          localMemory: localMemory,
          transport: _FakeXtreamTransport.success().call,
        );

        final connected = await controller.connectXtream(
          const UserCredentials(
            server: 'https://fixture.example',
            username: 'fixture-user',
            password: 'fixture-password',
          ),
        );
        expect(connected, isTrue);
        expect(controller.channels.single.name, 'BBC One');

        final cachedXtreamChannels = await controller.cacheService
            .get<List<Channel>>('liveStreams');
        expect(cachedXtreamChannels?.data.single.name, 'BBC One');

        final switched = await controller.switchToM3u(
          playlistText:
              '#EXTM3U\n#EXTINF:-1 group-title="News",BBC One HD\nhttps://streams.example/live/bbc-one.m3u8',
        );
        expect(switched, isTrue);
        expect(controller.sourceType, AppSourceType.m3u);
        expect(controller.channels.single.name, 'BBC One HD');
        expect(
          (await controller.cacheService.get<List<Channel>>(
            'liveStreams',
          ))?.data.single.name,
          'BBC One HD',
        );

        final failed = await controller.switchToM3u(
          playlistText: 'fixture-password is not a playlist',
        );
        expect(failed, isFalse);
        expect(controller.error, contains('M3U parse error'));
        expect(controller.error, isNot(contains('fixture-password')));
        expect(controller.channels.single.name, 'BBC One HD');
        expect(
          (await controller.cacheService.get<List<Channel>>(
            'liveStreams',
          ))?.data.single.name,
          'BBC One HD',
        );

        await tester.pumpWidget(_TestApp(controller: controller));
        await _pumpAppState(tester);
        await _tapSidebarDestination(tester, 'Settings');
        await _pumpAppState(tester);

        expect(find.text('Last source error'), findsOneWidget);
        expect(_visibleText(tester), contains('M3U parse error'));
        expect(_visibleText(tester), isNot(contains('fixture-password')));
        expect(_visibleText(tester), isNot(contains('fixture-user')));
      },
    );
  });
}

AppStateController _controller({
  required InMemorySecureStorage storage,
  required XtreamTransport transport,
  Map<String, Object?>? cacheMemory,
  Map<String, Object?>? localMemory,
}) {
  final sharedLocalMemory = localMemory ?? <String, Object?>{};
  return AppStateController(
    xtreamService: XtreamService(
      transport: transport,
      cache: CacheService(memory: cacheMemory ?? <String, Object?>{}),
    ),
    secureStorage: storage,
    cacheService: CacheService(memory: cacheMemory ?? <String, Object?>{}),
    favoritesService: FavoritesService(memory: sharedLocalMemory),
    resumeService: ResumeService(memory: sharedLocalMemory),
    viewerService: ViewerService(memory: sharedLocalMemory),
  );
}

String _visibleText(WidgetTester tester) {
  return tester
      .widgetList<Text>(find.byType(Text))
      .map((Text text) => text.data ?? '')
      .join('\n');
}

Future<void> _pumpAppState(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
  await tester.pump();
}

Finder _sidebarDestination(String label) {
  return find.descendant(
    of: find.byType(NavigationSidebar),
    matching: find.text(label),
  );
}

Future<void> _tapSidebarDestination(WidgetTester tester, String label) async {
  if (_sidebarDestination(label).evaluate().isEmpty) {
    await tester.sendKeyEvent(LogicalKeyboardKey.contextMenu);
    await _pumpAppState(tester);
  }
  await tester.tap(_sidebarDestination(label));
}

class _TestApp extends StatelessWidget {
  const _TestApp({required this.controller});

  final AppStateController controller;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.dark(useMaterial3: true),
      home: AppShell(deviceType: DeviceType.tv, appState: controller),
    );
  }
}

class _FakeXtreamTransport {
  _FakeXtreamTransport(this.responses);

  factory _FakeXtreamTransport.success() =>
      _FakeXtreamTransport(<String, Object?>{
        'auth': <String, Object?>{
          'user_info': <String, Object?>{'auth': 1, 'status': 'Active'},
          'm3u_editor': <String, Object?>{'version': '0.10.0'},
        },
        'get_live_categories': <Map<String, Object?>>[
          <String, Object?>{'category_id': '10', 'category_name': 'News'},
        ],
        'get_vod_categories': <Map<String, Object?>>[
          <String, Object?>{'category_id': '20', 'category_name': 'Movies'},
        ],
        'get_series_categories': <Map<String, Object?>>[
          <String, Object?>{'category_id': '30', 'category_name': 'Series'},
        ],
        'get_live_streams': <Map<String, Object?>>[
          <String, Object?>{
            'stream_id': 101,
            'name': 'BBC One',
            'category_id': '10',
            'epg_channel_id': 'bbc.one',
          },
        ],
        'get_vod_streams': <Map<String, Object?>>[
          <String, Object?>{
            'stream_id': 201,
            'name': 'Big Buck Bunny',
            'category_id': '20',
            'container_extension': 'mp4',
          },
        ],
        'get_series': <Map<String, Object?>>[
          <String, Object?>{
            'series_id': 301,
            'name': 'Fixture Show',
            'category_id': '30',
          },
        ],
        'get_viewers': <Map<String, Object?>>[
          <String, Object?>{
            'id': 1,
            'ulid': 'viewer-admin',
            'name': 'Admin',
            'is_admin': true,
          },
        ],
        'get_recently_watched': <Map<String, Object?>>[],
      });

  final Map<String, Object?> responses;

  Future<Object?> call(XtreamRequest request) async {
    final action = request.action ?? 'auth';
    final response = responses[action];
    if (response == null) {
      throw StateError('No fixture for ${jsonEncode(request.toDebugMap())}');
    }
    return response;
  }
}
