import 'package:flutter_test/flutter_test.dart';
import 'package:m3u_tv/services/domain_models.dart';

void main() {
  group('PersonDetails.fromXtream', () {
    test('parses a full person entry', () {
      final result = PersonDetails.fromXtream(<String, Object?>{
        'name': 'Idris Elba',
        'photo': 'https://image.tmdb.org/t/p/w185/abc.jpg',
        'bio': 'An actor.',
      });
      expect(result, isNotNull);
      expect(result!.name, 'Idris Elba');
      expect(result.photo, 'https://image.tmdb.org/t/p/w185/abc.jpg');
      expect(result.bio, 'An actor.');
    });

    test('drops entries with an empty name', () {
      expect(PersonDetails.fromXtream(<String, Object?>{'name': ''}), isNull);
      expect(PersonDetails.fromXtream(<String, Object?>{}), isNull);
    });

    test('returns null for non-Map input', () {
      expect(PersonDetails.fromXtream(null), isNull);
      expect(PersonDetails.fromXtream('Idris Elba'), isNull);
    });
  });

  group('FilmographyCredit.fromXtream', () {
    test('parses a full movie credit', () {
      final result = FilmographyCredit.fromXtream(<String, Object?>{
        'tmdb_id': 550,
        'title': 'Fight Club',
        'media_type': 'movie',
        'character': 'Tyler Durden',
        'year': '1999',
        'poster_url': 'https://image.tmdb.org/t/p/w500/fc.jpg',
        'in_library': true,
        'local_id': 42,
      });
      expect(result, isNotNull);
      expect(result!.tmdbId, 550);
      expect(result.title, 'Fight Club');
      expect(result.mediaType, 'movie');
      expect(result.isSeries, isFalse);
      expect(result.character, 'Tyler Durden');
      expect(result.year, '1999');
      expect(result.posterUrl, 'https://image.tmdb.org/t/p/w500/fc.jpg');
      expect(result.inLibrary, isTrue);
      expect(result.localId, 42);
    });

    test('defaults media_type to movie and in_library to false', () {
      final result = FilmographyCredit.fromXtream(<String, Object?>{
        'tmdb_id': 1399,
        'title': 'Game of Thrones',
      });
      expect(result, isNotNull);
      expect(result!.mediaType, 'movie');
      expect(result.isSeries, isFalse);
      expect(result.inLibrary, isFalse);
      expect(result.localId, isNull);
    });

    test('isSeries is true for tv media_type', () {
      final result = FilmographyCredit.fromXtream(<String, Object?>{
        'tmdb_id': 1399,
        'title': 'Game of Thrones',
        'media_type': 'tv',
      });
      expect(result!.isSeries, isTrue);
    });

    test('drops entries missing tmdb_id or title', () {
      expect(
        FilmographyCredit.fromXtream(<String, Object?>{'title': 'X'}),
        isNull,
      );
      expect(
        FilmographyCredit.fromXtream(<String, Object?>{'tmdb_id': 1}),
        isNull,
      );
      expect(
        FilmographyCredit.fromXtream(<String, Object?>{
          'tmdb_id': 1,
          'title': '',
        }),
        isNull,
      );
    });

    test('returns null for non-Map input', () {
      expect(FilmographyCredit.fromXtream(null), isNull);
      expect(FilmographyCredit.fromXtream('Fight Club'), isNull);
    });
  });

  group('ActorFilmography.fromXtream', () {
    test('parses person + credits together', () {
      final result = ActorFilmography.fromXtream(<String, Object?>{
        'person': <String, Object?>{'name': 'Idris Elba'},
        'credits': <Object?>[
          <String, Object?>{
            'tmdb_id': 550,
            'title': 'Fight Club',
            'media_type': 'movie',
          },
        ],
      });
      expect(result, isNotNull);
      expect(result!.person?.name, 'Idris Elba');
      expect(result.credits, hasLength(1));
      expect(result.credits.single.title, 'Fight Club');
    });

    test('tolerates a missing person and empty credits', () {
      final result = ActorFilmography.fromXtream(<String, Object?>{});
      expect(result, isNotNull);
      expect(result!.person, isNull);
      expect(result.credits, isEmpty);
    });

    test('drops malformed credit entries but keeps valid ones', () {
      final result = ActorFilmography.fromXtream(<String, Object?>{
        'credits': <Object?>[
          <String, Object?>{'tmdb_id': 550, 'title': 'Fight Club'},
          <String, Object?>{'title': 'Missing tmdb_id'},
          'not a map',
        ],
      });
      expect(result!.credits, hasLength(1));
      expect(result.credits.single.title, 'Fight Club');
    });

    test('returns null for non-Map input', () {
      expect(ActorFilmography.fromXtream(null), isNull);
      expect(ActorFilmography.fromXtream('Idris Elba'), isNull);
    });
  });
}
