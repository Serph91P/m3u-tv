import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3u_tv/features/vod/vod_details_screen.dart';
import 'package:m3u_tv/navigation/app_router.dart';
import 'package:m3u_tv/navigation/route_names.dart';
import 'package:m3u_tv/services/domain_models.dart';
import 'package:m3u_tv/services/xtream_service.dart';

void main() {
  group('VodDetailsScreen', () {
    testWidgets('fetches and renders real VOD metadata', (tester) async {
      await tester.pumpWidget(
        _TestApp(
          service: _VodDetailsXtreamService(
            info: const VodInfo(
              id: 201,
              name: 'Big Buck Bunny',
              plot: 'A rabbit gets serious about defending his meadow.',
              genre: 'Animation',
              director: 'Sacha Goedegebure',
              cast: 'Bunny, Frank, Rinky',
              year: '2008',
              duration: '9m',
              rating: 4.5,
              coverUrl: 'https://img.example/bunny.jpg',
              containerExtension: 'mkv',
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Big Buck Bunny'), findsWidgets);
      expect(
        find.text('A rabbit gets serious about defending his meadow.'),
        findsOneWidget,
      );
      expect(find.text('Animation'), findsOneWidget);
      expect(find.text('2008'), findsOneWidget);
      expect(find.text('9m'), findsOneWidget);
      expect(find.text('★ 4.5'), findsOneWidget);
      expect(find.text('MKV'), findsOneWidget);
      expect(find.text('Movie details'), findsNothing);
      expect(find.text('Ready to play in-app.'), findsNothing);
      expect(find.text('Play movie'), findsOneWidget);
    });

    testWidgets('keeps play action in app with metadata fallback', (
      tester,
    ) async {
      PlayerArgs? playerArgs;
      await tester.pumpWidget(
        _TestApp(
          service: _VodDetailsXtreamService(
            info: const VodInfo(
              id: 201,
              name: '',
              plot: 'Server synopsis',
              containerExtension: 'mkv',
            ),
          ),
          playerRouteBuilder: (args) {
            playerArgs = args;
            return Scaffold(body: Text('Player route: ${args.title}'));
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Play movie'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Player route: Fixture Movie'), findsOneWidget);
      expect(playerArgs?.streamUrl, 'http://example.com/movie/201.mp4');
      expect(playerArgs?.type, 'vod');
      expect(playerArgs?.metadata['container_extension'], 'mkv');
    });
  });
}

class _TestApp extends StatelessWidget {
  const _TestApp({required this.service, this.playerRouteBuilder});

  final XtreamService service;
  final Widget Function(PlayerArgs args)? playerRouteBuilder;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.dark(useMaterial3: true),
      onGenerateRoute: (settings) {
        if (settings.name == RouteNames.player &&
            settings.arguments is PlayerArgs) {
          final args = settings.arguments! as PlayerArgs;
          return MaterialPageRoute<void>(
            builder: (_) =>
                playerRouteBuilder?.call(args) ??
                Scaffold(body: Text('Player route: ${args.title}')),
          );
        }
        return MaterialPageRoute<void>(
          builder: (_) => VodDetailsScreen(
            item: const VodItem(
              id: 201,
              name: 'Fixture Movie',
              streamUrl: 'http://example.com/movie/201.mp4',
              containerExtension: 'mp4',
              rating: 3.5,
            ),
            xtreamService: service,
          ),
        );
      },
    );
  }
}

class _VodDetailsXtreamService extends XtreamService {
  _VodDetailsXtreamService({required this.info});

  final VodInfo info;

  @override
  Future<VodInfo> getVodInfo(int vodId) async => info;
}
