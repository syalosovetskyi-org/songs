import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:song_lyrics/songbook.dart';

void main() {
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
    test('Normalizes case, whitespace and diverse apostrophe characters', () {
      expect(normalizeSearchText("  М'ЯТА  "), equals("м'ята"));
      expect(normalizeSearchText('п’ять'), equals("п'ять")); // U+2019
      expect(normalizeSearchText('сімʼя'), equals("сім'я")); // U+02BC
      expect(normalizeSearchText('з`явитися'), equals("з'явитися")); // U+0060
    });

    test('matchesSearch matches regardless of apostrophe style and casing', () {
      const target = "В'юн над водою";
      expect(matchesSearch(target, "в'юн"), isTrue);
      expect(matchesSearch(target, 'в’юн'), isTrue); // типографський апостроф
      expect(matchesSearch(target, 'вʼюн'), isTrue); // український модифікатор
      expect(matchesSearch(target, '  ВОДОЮ  '), isTrue);
      expect(matchesSearch(target, 'немає'), isFalse);
    });

    test('filterArtists filters by artist name and song name', () {
      final artists = [
        const Artist(name: 'Океан Ельзи', songs: [
          Song(name: 'Без бою', text: '...'),
          Song(name: "В'юн над водою", text: '...'),
        ]),
        const Artist(name: 'Бумбокс', songs: [
          Song(name: 'Вахтерам', text: '...'),
        ]),
      ];

      // Пошук за назвою артиста
      expect(filterArtists(artists, 'океан').map((a) => a.name), ['Океан Ельзи']);

      // Пошук за назвою пісні
      expect(filterArtists(artists, 'вахтерам').map((a) => a.name), ['Бумбокс']);

      // Пошук з апострофом у назві пісні
      expect(filterArtists(artists, 'вʼюн').map((a) => a.name), ['Океан Ельзи']);

      // Порожній запит повертає всіх
      expect(filterArtists(artists, '   ').length, 2);
    });

    test('filterSongs filters songs by name with apostrophe support', () {
      const songs = [
        Song(name: "В'юн над водою", text: '...'),
        Song(name: 'Без бою', text: '...'),
      ];

      expect(filterSongs(songs, 'в’юн').map((s) => s.name), ["В'юн над водою"]);
      expect(filterSongs(songs, 'бою').map((s) => s.name), ['Без бою']);
      expect(filterSongs(songs, '').length, 2);
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
}
