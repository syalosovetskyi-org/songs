import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:song_lyrics/songbook.dart';

void main() {
  group('Chord detection tests', () {
    test('isChordLine correctly detects lines with chords', () {
      expect(isChordLine('Am  C  Dm  E7'), isTrue);
      expect(isChordLine('G   D/F#   Em'), isTrue);
      expect(isChordLine('| Am | C | Dm | E |'), isTrue);
      expect(isChordLine('[H7] [F#m] [Bb]'), isTrue);
      expect(isChordLine('Csus4 Aaug Bbdim'), isTrue);

      expect(isChordLine(''), isFalse);
      expect(isChordLine('   '), isFalse);
      expect(isChordLine('Я не здамся без бою'), isFalse);
      expect(isChordLine('Am ідемо гуляти'), isFalse);
    });

    test('hasChords detects whether song lyrics have chord lines', () {
      const songWithChords = '''
Am          Dm
Я не здамся без бою
E7          Am
Я не здамся ніколи
''';
      expect(hasChords(songWithChords), isTrue);

      const songWithoutChords = '''
Там, де ми є, там де ми є
Немає болю і нема печалі
''';
      expect(hasChords(songWithoutChords), isFalse);
      expect(hasChords(''), isFalse);
    });
  });

  group('Ukrainian collation & sorting tests', () {
    test('Ukrainian alphabet order is respected', () {
      final letters = [
        'Я', 'Ю', 'Ь', 'Щ', 'Ш', 'Ч', 'Ц', 'Х', 'Ф', 'У', 'Т', 'С', 'Р', 'П', 'О',
        'Н', 'М', 'Л', 'К', 'Й', 'Ї', 'І', 'И', 'З', 'Ж', 'Є', 'Е', 'Д', 'Ґ', 'Г',
        'В', 'Б', 'А',
      ];
      letters.sort(compareUkrainian);

      final expected = [
        'А', 'Б', 'В', 'Г', 'Ґ', 'Д', 'Е', 'Є', 'Ж', 'З', 'И', 'І', 'Ї', 'Й', 'К',
        'Л', 'М', 'Н', 'О', 'П', 'Р', 'С', 'Т', 'У', 'Ф', 'Х', 'Ц', 'Ч', 'Ш', 'Щ',
        'Ь', 'Ю', 'Я',
      ];
      expect(letters, equals(expected));
    });

    test('Special Ukrainian letters order: ґ, є, і, ї', () {
      expect(compareUkrainian('Гайдамаки', 'Ґринджоли'), lessThan(0));
      expect(compareUkrainian('Ґринджоли', 'Данило'), lessThan(0));

      expect(compareUkrainian('Еней', 'Євген'), lessThan(0));
      expect(compareUkrainian('Євген', 'Журба'), lessThan(0));

      expect(compareUkrainian('Ирій', 'Іво Бобул'), lessThan(0));
      expect(compareUkrainian('Іво Бобул', 'Їжак'), lessThan(0));
      expect(compareUkrainian('Їжак', 'Йосип'), lessThan(0));
    });

    test('Case-insensitivity with deterministic tie-break', () {
      expect(compareUkrainian('іван', 'Іван'), isNot(0));
      expect(compareUkrainian('іван', 'Йосип'), lessThan(0));
      expect(compareUkrainian('Іван', 'йосип'), lessThan(0));
    });

    test('Apostrophes normalization in sorting', () {
      // Різні типи апострофів ранжуються однаково
      expect(compareUkrainian("м'ята", 'мʼята'), equals(0));
      expect(compareUkrainian('м’ята', "м'ята"), equals(0));
    });
  });

  group('Search normalization tests', () {
    test('Normalizes case, whitespace, latin i and diverse apostrophe characters', () {
      expect(normalizeSearchText("  М'ЯТА  "), equals("м'ята"));
      expect(normalizeSearchText('п’ять'), equals("п'ять")); // U+2019
      expect(normalizeSearchText('сімʼя'), equals("сім'я")); // U+02BC
      expect(normalizeSearchText('з`явитися'), equals("з'явитися")); // U+0060
      expect(normalizeSearchText('ivan'), equals('іvan')); // латинська i -> кирилична і
      expect(normalizeSearchText('Iво Бобул'), equals('іво бобул'));
    });

    test('matchesSearch matches regardless of apostrophe style, casing and latin i', () {
      const target = "В'юн над водою";
      expect(matchesSearch(target, "в'юн"), isTrue);
      expect(matchesSearch(target, 'в’юн'), isTrue); // типографський апостроф
      expect(matchesSearch(target, 'вʼюн'), isTrue); // український модифікатор
      expect(matchesSearch(target, '  ВОДОЮ  '), isTrue);
      expect(matchesSearch(target, 'немає'), isFalse);
      expect(matchesSearch('Іво Бобул', 'iво'), isTrue); // пошук з латинською 'i'
    });

    test('filterArtists filters by artist name, song name and song text', () {
      final artists = [
        Artist(name: 'Океан Ельзи', songs: [
          Song(name: 'Без бою', text: 'Я не здамся без бою...'),
          Song(name: "В'юн над водою", text: 'В’юн над водою стелиться...'),
        ]),
        Artist(name: 'Бумбокс', songs: [
          Song(name: 'Вахтерам', text: 'Тебе так любив я...'),
        ]),
        Artist(name: 'Антитіла', songs: [
          Song(name: 'TDME', text: 'Там де ми є...'),
        ]),
      ];

      // Пошук за назвою артиста
      expect(filterArtists(artists, 'океан').map((a) => a.name), ['Океан Ельзи']);

      // Пошук за назвою пісні
      expect(filterArtists(artists, 'вахтерам').map((a) => a.name), ['Бумбокс']);

      // Пошук за фрагментом тексту пісні
      expect(filterArtists(artists, 'не здамся').map((a) => a.name), ['Океан Ельзи']);

      // Пошук з апострофом у назві або тексті пісні
      expect(filterArtists(artists, 'вʼюн').map((a) => a.name), ['Океан Ельзи']);

      // Пошук латинською 'i' у назві артиста
      expect(filterArtists(artists, 'антитiла').map((a) => a.name), ['Антитіла']);

      // Порожній запит повертає всіх
      expect(filterArtists(artists, '   ').length, 3);
    });

    test('filterSongs filters songs by name and text with apostrophe and latin i support', () {
      final songs = [
        Song(name: "В'юн над водою", text: 'Стелиться туман...'),
        Song(name: 'Без бою', text: 'Я не здамся без бою...'),
      ];

      expect(filterSongs(songs, 'в’юн').map((s) => s.name), ["В'юн над водою"]);
      expect(filterSongs(songs, 'бою').map((s) => s.name), ['Без бою']);
      expect(filterSongs(songs, 'туман').map((s) => s.name), ["В'юн над водою"]); // пошук за текстом
      expect(filterSongs(songs, '').length, 2);
    });

    test('filterSongs uses precomputed fields without re-normalizing song texts', () {
      final songs = [
        Song(
          name: "В'юн над водою",
          text: 'Стелиться туман...',
          normalizedName: normalizeSearchText("В'юн над водою"),
          normalizedText: normalizeSearchText('Стелиться туман...'),
        ),
        Song(
          name: 'Без бою',
          text: 'Я не здамся без бою...',
          normalizedName: normalizeSearchText('Без бою'),
          normalizedText: normalizeSearchText('Я не здамся без бою...'),
        ),
      ];

      resetNormalizeSearchTextCalls();
      final filtered = filterSongs(songs, 'бою');
      expect(filtered.map((s) => s.name), ['Без бою']);
      expect(normalizeSearchTextCalls, equals(1));
    });
  });

  group('JSON parsing & error handling tests', () {
    late String fixtureJson;

    setUpAll(() {
      final fixtureFile = File('test/fixtures/sample_songbook.json');
      fixtureJson = fixtureFile.readAsStringSync();
    });

    test('Parses fixture JSON correctly with Ukrainian sorting applied', () {
      final artists = parseSongbookJson(fixtureJson);

      // Має містити валідних артистів (з піснями)
      final names = artists.map((a) => a.name).toList();

      expect(names, contains('Антитіла'));
      expect(names, contains('Бумбокс'));
      expect(names, contains('Гайдамаки'));
      expect(names, contains('Ґринджоли'));
      expect(names, contains('Еней'));
      expect(names, contains('Євген'));
      expect(names, contains('Іво Бобул'));
      expect(names, contains('Їжак'));
      expect(names, contains('Океан Ельзи'));

      // Перевірка порядку сортування артистів
      final antIndex = names.indexOf('Антитіла');
      final hayIndex = names.indexOf('Гайдамаки');
      final gryndzIndex = names.indexOf('Ґринджоли');
      final eneyIndex = names.indexOf('Еней');
      final yevgenIndex = names.indexOf('Євген');
      final ivoIndex = names.indexOf('Іво Бобул');
      final yizhakIndex = names.indexOf('Їжак');

      expect(antIndex, lessThan(hayIndex));
      expect(hayIndex, lessThan(gryndzIndex));
      expect(gryndzIndex, lessThan(eneyIndex));
      expect(eneyIndex, lessThan(yevgenIndex));
      expect(yevgenIndex, lessThan(ivoIndex));
      expect(ivoIndex, lessThan(yizhakIndex));
    });

    test('Filters out artists with no valid songs by default', () {
      final artists = parseSongbookJson(fixtureJson);
      final names = artists.map((a) => a.name).toSet();

      // "Артист Без Пісень" та "Артист З Невідомими URL" не повинні потрапити у фінальний список
      expect(names.contains('Артист Без Пісень'), isFalse);
      expect(names.contains('Артист З Невідомими URL'), isFalse);
    });

    test('Handles broken entries gracefully without crashing', () {
      final artists = parseSongbookJson(fixtureJson);
      final brokenArtist = artists.firstWhere(
        (a) => a.name == 'Артист З Битими Піснями',
        orElse: () => throw Exception('Artist not found'),
      );

      // З трьох пісень одна валідна ('Вціліла пісня'), інші дві биті
      expect(brokenArtist.songs.length, 1);
      expect(brokenArtist.songs.first.name, 'Вціліла пісня');
    });

    test('Throws explicit FormatException on corrupted JSON structure', () {
      // Корінь не є JSON-об'єктом
      expect(() => parseSongbookJson('["not an object"]'), throwsFormatException);

      // Відсутній ключ 'artists'
      expect(
        () => parseSongbookJson('{"songs": {}}'),
        throwsA(isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('artists'),
        )),
      );

      // Відсутній ключ 'songs'
      expect(
        () => parseSongbookJson('{"artists": {}}'),
        throwsA(isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('songs'),
        )),
      );
    });
  });

  group('Ukrainian pluralization tests', () {
    test('formatSongsCount correctly handles Ukrainian noun declension', () {
      expect(formatSongsCount(1), '1 пісня');
      expect(formatSongsCount(21), '21 пісня');
      expect(formatSongsCount(101), '101 пісня');

      expect(formatSongsCount(2), '2 пісні');
      expect(formatSongsCount(3), '3 пісні');
      expect(formatSongsCount(4), '4 пісні');
      expect(formatSongsCount(22), '22 пісні');
      expect(formatSongsCount(104), '104 пісні');

      expect(formatSongsCount(0), '0 пісень');
      expect(formatSongsCount(5), '5 пісень');
      expect(formatSongsCount(11), '11 пісень');
      expect(formatSongsCount(12), '12 пісень');
      expect(formatSongsCount(14), '14 пісень');
      expect(formatSongsCount(20), '20 пісень');
      expect(formatSongsCount(25), '25 пісень');
      expect(formatSongsCount(100), '100 пісень');
      expect(formatSongsCount(111), '111 пісень');
    });
  });

  group('Synthetic benchmark & index verification', () {
    test(
        'Synthetic dataset of 3000 songs x 15 KB text searches quickly without re-normalizing song texts',
        () async {
      // 15 KB chunk of Ukrainian lyrics (~15,580 characters)
      final chunk =
          'Ой у лузі червона калина похилилася, чогось наша славна Україна зажурилася. ' *
              200;
      expect(chunk.length, greaterThanOrEqualTo(15000));

      // Construct synthetic dataset: 100 artists x 30 songs = 3000 songs
      final List<Artist> syntheticArtists = [];
      for (int a = 0; a < 100; a++) {
        final List<Song> songs = [];
        for (int s = 0; s < 30; s++) {
          final songName = 'Пісня $a-$s';
          final text = (a == 42 && s == 15)
              ? '$chunk УнікальнийТекстДляПошуку'
              : chunk;
          songs.add(Song(
            name: songName,
            text: text,
            normalizedName: normalizeSearchText(songName),
            normalizedText: normalizeSearchText(text),
          ));
        }
        final artistName = 'Виконавець $a';
        syntheticArtists.add(Artist(
          name: artistName,
          songs: List.unmodifiable(songs),
          normalizedName: normalizeSearchText(artistName),
        ));
      }

      expect(syntheticArtists.length, 100);
      expect(
          syntheticArtists.fold<int>(0, (sum, a) => sum + a.songs.length), 3000);

      // Reset call counter before searching
      resetNormalizeSearchTextCalls();

      // Search for nonexistent query (worst case: scan across all 3000 songs and texts)
      final stopwatch = Stopwatch()..start();
      final noResults = filterArtists(syntheticArtists, 'qwxzy');
      stopwatch.stop();

      expect(noResults, isEmpty);
      // Reasonable time: on 3000 precomputed items, String.contains takes ~10-40 ms, well below 500 ms
      expect(stopwatch.elapsedMilliseconds, lessThan(500));
      // Verifies that normalizeSearchText was called ONLY once for query 'qwxzy',
      // and NOT repeated for any of the 3000 songs' texts!
      expect(normalizeSearchTextCalls, equals(1));

      // Search for a matching query in song text
      resetNormalizeSearchTextCalls();
      final matchStopwatch = Stopwatch()..start();
      final matchResults =
          filterArtists(syntheticArtists, 'УнікальнийТекстДляПошуку');
      matchStopwatch.stop();

      expect(matchResults.length, 1);
      expect(matchResults.first.name, 'Виконавець 42');
      expect(matchStopwatch.elapsedMilliseconds, lessThan(500));
      expect(normalizeSearchTextCalls, equals(1));

      // Test async background search (searchArtists)
      resetNormalizeSearchTextCalls();
      final asyncResults = await searchArtists(syntheticArtists, 'qwxzy');
      expect(asyncResults, isEmpty);
    });
  });
}
