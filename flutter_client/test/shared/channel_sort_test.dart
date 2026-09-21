import 'package:flutter_test/flutter_test.dart';
import 'package:m3u_tv/services/domain_models.dart';
import 'package:m3u_tv/services/view_settings_service.dart';
import 'package:m3u_tv/shared/channel_sort.dart';
import 'package:m3u_tv/shared/natural_sort.dart';

Channel _channel({
  required int id,
  required String name,
  int? channelNumber,
}) => Channel(
  id: id,
  name: name,
  streamUrl: 'http://example.com/$id',
  channelNumber: channelNumber,
);

void main() {
  group('compareNatural', () {
    test('sorts symbols before digits before letters', () {
      final names = ['Zebra', '&TV', '00s Replay']..sort(compareNatural);
      expect(names, ['&TV', '00s Replay', 'Zebra']);
    });

    test('compares numeric runs by value, not lexically', () {
      final names = ['Channel 10', 'Channel 2']..sort(compareNatural);
      expect(names, ['Channel 2', 'Channel 10']);
    });

    test('is case-insensitive', () {
      final names = ['bbc', 'ABC']..sort(compareNatural);
      expect(names, ['ABC', 'bbc']);
    });
  });

  group('sortChannels', () {
    final channels = [
      _channel(id: 1, name: 'Zebra News', channelNumber: 30),
      _channel(id: 2, name: '&TV'),
      _channel(id: 3, name: '00s Replay', channelNumber: 10),
    ];

    test('playlistOrder returns the list unchanged', () {
      final sorted = sortChannels(channels, ChannelSortOption.playlistOrder);
      expect(sorted.map((c) => c.id), [1, 2, 3]);
    });

    test('alphabeticalAsc applies natural sort to names', () {
      final sorted = sortChannels(
        channels,
        ChannelSortOption.alphabeticalAsc,
      );
      expect(sorted.map((c) => c.name), ['&TV', '00s Replay', 'Zebra News']);
    });

    test('alphabeticalDesc reverses the natural sort order', () {
      final sorted = sortChannels(
        channels,
        ChannelSortOption.alphabeticalDesc,
      );
      expect(sorted.map((c) => c.name), ['Zebra News', '00s Replay', '&TV']);
    });

    test(
      'channelNumber sorts ascending, sinking unnumbered channels last',
      () {
        final sorted = sortChannels(channels, ChannelSortOption.channelNumber);
        expect(sorted.map((c) => c.id), [3, 1, 2]);
      },
    );
  });
}
