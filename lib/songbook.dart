/*
 * This file is part of the Flutter Song Lyrics App.
 *
 * Flutter Song Lyrics App is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * Flutter Song Lyrics App is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with Flutter Song Lyrics App.  If not, see <http://www.gnu.org/licenses/>.
 */

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show AssetBundle, rootBundle;

/// Модель пісні.
@immutable
class Song {
  final String name;
  final String text;

  const Song({
    required this.name,
    required this.text,
  });

  factory Song.fromJson(Map<String, dynamic> json) {
    final dynamic rawName = json['name'];
    final dynamic rawText = json['text'];
    if (rawName == null || rawText == null) {
      throw const FormatException('Song JSON must contain "name" and "text"');
    }
    final nameStr = rawName.toString();
    final textStr = rawText.toString();
    return Song(name: nameStr, text: textStr);
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'text': text,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Song &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          text == other.text;

  @override
  int get hashCode => Object.hash(name, text);

  @override
  String toString() => 'Song(name: $name)';
}

/// Модель виконавця.
@immutable
class Artist {
  final String name;
  final List<Song> songs;

  const Artist({
    required this.name,
    required this.songs,
  });

  factory Artist.fromJson(Map<String, dynamic> json) {
    final dynamic rawName = json['name'];
    final dynamic rawSongs = json['songs'];
    if (rawName == null) {
      throw const FormatException('Artist JSON must contain "name"');
    }
    final songsList = <Song>[];
    if (rawSongs is Iterable) {
      for (final songJson in rawSongs) {
        if (songJson is Map<String, dynamic>) {
          songsList.add(Song.fromJson(songJson));
        } else if (songJson is Map) {
          songsList.add(Song.fromJson(Map<String, dynamic>.from(songJson)));
        }
      }
    }
    final nameStr = rawName.toString();
    return Artist(name: nameStr, songs: List.unmodifiable(songsList));
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'songs': songs.map((s) => s.toJson()).toList(),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Artist &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          listEquals(songs, other.songs);

  @override
  int get hashCode => Object.hash(name, Object.hashAll(songs));

  @override
  String toString() => 'Artist(name: $name, songsCount: ${songs.length})';
}

/// Регулярний вираз для перевірки окремого акорду.
final RegExp _chordRegex = RegExp(r'^[A-H](#|b)?(m|maj|min|dim|aug|sus)?\d*(/[A-H](#|b)?)?$');

/// Перевіряє, чи складається рядок виключно з акордів та роздільників.
bool isChordLine(String line) {
  final trimmed = line.trim();
  if (trimmed.isEmpty) return false;

  final tokens = trimmed.split(RegExp(r'\s+'));
  int chordCount = 0;

  for (final rawToken in tokens) {
    final token = rawToken.replaceAll(RegExp(r'[\[\]():|]'), '');
    if (token.isEmpty) continue;

    if (_chordRegex.hasMatch(token)) {
      chordCount++;
    } else {
      return false;
    }
  }

  return chordCount > 0;
}

/// Перевіряє, чи містить текст пісні хоча б один рядок з акордами.
bool hasChords(String text) {
  if (text.isEmpty) return false;
  return text.split('\n').any(isChordLine);
}

/// Повертає відмінювану форму кількості пісень українською мовою:
/// "1 пісня", "2 пісні", "5 пісень".
String formatSongsCount(int count) {
  final absCount = count.abs();
  final mod10 = absCount % 10;
  final mod100 = absCount % 100;
  if (mod10 == 1 && mod100 != 11) {
    return '$count пісня';
  } else if (mod10 >= 2 && mod10 <= 4 && (mod100 < 10 || mod100 >= 20)) {
    return '$count пісні';
  } else {
    return '$count пісень';
  }
}


/// 33 літери українського алфавіту в канонічному порядку.
const String _ukrainianAlphabet = 'абвгґдеєжзиіїйклмнопрстуфхцчшщьюя';

final Map<int, int> _ukrainianLetterRanks = () {
  final map = <int, int>{};
  for (int i = 0; i < _ukrainianAlphabet.length; i++) {
    map[_ukrainianAlphabet.codeUnitAt(i)] = i;
  }
  return map;
}();

/// Порівняння символів з пріоритетом українського алфавіту.
int _charRank(int codeUnit) {
  // Апострофи зводимо до єдиного рангу
  if (codeUnit == 0x0027 || // '
      codeUnit == 0x2019 || // ’
      codeUnit == 0x02BC || // ʼ
      codeUnit == 0x02BB || // ʻ
      codeUnit == 0x0060 || // `
      codeUnit == 0x00B4) { // ´
    return 33;
  }

  // Українські літери
  final ukrRank = _ukrainianLetterRanks[codeUnit];
  if (ukrRank != null) {
    return ukrRank; // 0..32
  }

  // Латиниця a-z
  if (codeUnit >= 0x61 && codeUnit <= 0x7a) {
    return 100 + (codeUnit - 0x61);
  }

  // Цифри 0-9 (ранжуються перед літерами)
  if (codeUnit >= 0x30 && codeUnit <= 0x39) {
    return -100 + (codeUnit - 0x30);
  }

  // Інші символи
  return 1000 + codeUnit;
}

/// Сортування за українським алфавітом (case-insensitive з тай-брейком за оригіналом).
int compareUkrainian(String a, String b) {
  if (identical(a, b)) return 0;

  final aLower = a.toLowerCase();
  final bLower = b.toLowerCase();

  final minLen = aLower.length < bLower.length ? aLower.length : bLower.length;
  for (int i = 0; i < minLen; i++) {
    final charA = aLower.codeUnitAt(i);
    final charB = bLower.codeUnitAt(i);
    if (charA != charB) {
      final rankA = _charRank(charA);
      final rankB = _charRank(charB);
      if (rankA != rankB) {
        return rankA.compareTo(rankB);
      }
      // Якщо ранги однакові (наприклад, різні апострофи), продовжуємо порівняння наступних символів
    }
  }

  if (aLower.length != bLower.length) {
    return aLower.length.compareTo(bLower.length);
  }

  // Тай-брейк за оригінальним текстом (з нормалізацією апострофів)
  final normA = a.replaceAll(RegExp(r"[’ʼʻ`´']"), "'");
  final normB = b.replaceAll(RegExp(r"[’ʼʻ`´']"), "'");
  return normA.compareTo(normB);
}

/// Лічильник викликів normalizeSearchText (для тестування та бенчмарків).
@visibleForTesting
int normalizeSearchTextCalls = 0;

/// Скидання лічильника викликів normalizeSearchText.
@visibleForTesting
void resetNormalizeSearchTextCalls() {
  normalizeSearchTextCalls = 0;
}

/// Нормалізація рядка для нечутливого до апострофів, латинської 'i' та регістру пошуку.
String normalizeSearchText(String text) {
  normalizeSearchTextCalls++;
  if (text.isEmpty) return '';
  return text
      .toLowerCase()
      .replaceAll('i', 'і') // нормалізація латинської 'i' до кириличної 'і'
      .replaceAll(RegExp(r"[’ʼʻ`´']"), "'")
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// Шаблон пошуку, що збігається з тими самими рядками, що й порівняння
/// нормалізованих текстів (регістр, латинська 'i' ≡ 'і', будь-який апостроф,
/// послідовність пробілів), але без зберігання нормалізованих копій текстів у
/// пам'яті: регулярний вираз будується один раз на запит і йде по оригіналах.
/// Повертає null для порожнього запиту.
RegExp? buildSearchPattern(String query) {
  final normalizedQuery = normalizeSearchText(query);
  if (normalizedQuery.isEmpty) return null;
  final buffer = StringBuffer();
  for (final rune in normalizedQuery.runes) {
    final char = String.fromCharCode(rune);
    if (char == 'і') {
      buffer.write('[iі]');
    } else if (char == "'") {
      buffer.write("[’ʼʻ`´']");
    } else if (char == ' ') {
      buffer.write(r'\s+');
    } else {
      buffer.write(RegExp.escape(char));
    }
  }
  return RegExp(buffer.toString(), caseSensitive: false, unicode: true);
}

/// Перевірка входження підрядка пошуку в текст з нормалізацією.
bool matchesSearch(String target, String query) {
  final pattern = buildSearchPattern(query);
  if (pattern == null) return true;
  return pattern.hasMatch(target);
}

bool _songMatches(Song song, RegExp pattern) =>
    pattern.hasMatch(song.name) || pattern.hasMatch(song.text);

/// Фільтрація виконавців за пошуковим запитом (за назвою артиста, назвами його пісень або рядками тексту пісень).
List<Artist> filterArtists(List<Artist> artists, String query) {
  final pattern = buildSearchPattern(query);
  if (pattern == null) return artists;

  return artists
      .where((artist) =>
          pattern.hasMatch(artist.name) ||
          artist.songs.any((song) => _songMatches(song, pattern)))
      .toList();
}

/// Фільтрація пісень виконавця за пошуковим запитом (за назвою пісні або текстом).
List<Song> filterSongs(List<Song> songs, String query) {
  final pattern = buildSearchPattern(query);
  if (pattern == null) return songs;

  return songs.where((song) => _songMatches(song, pattern)).toList();
}

/// Пошук виконавців (асинхронно, щоб UI встиг показати індикатор).
Future<List<Artist>> searchArtists(List<Artist> artists, String query) {
  final trimmed = query.trim();
  if (trimmed.isEmpty) {
    return Future.value(artists);
  }
  // Не compute(): копіювання всього каталогу (десятки МБ текстів) в ізолят на кожен
  // запит дорожче за сам пошук. Один регулярний вираз по оригіналах — десятки
  // мілісекунд у релізній збірці; debounce в UI не дає запускати його на кожну літеру.
  return Future<void>.delayed(Duration.zero)
      .then((_) => filterArtists(artists, query));
}

/// Парсинг структури даних пісенника з валідацією, сортуванням та відсіюванням битих записів.
List<Artist> parseSongbookData(
  Map<String, dynamic> jsonData, {
  bool includeEmptyArtists = false,
}) {
  final dynamic artistsRaw = jsonData['artists'];
  final dynamic songsRaw = jsonData['songs'];

  if (artistsRaw == null || artistsRaw is! Map) {
    throw const FormatException('Invalid or missing "artists" map in JSON data');
  }
  if (songsRaw == null || songsRaw is! Map) {
    throw const FormatException('Invalid or missing "songs" map in JSON data');
  }

  final Map<dynamic, dynamic> artistsMap = artistsRaw;
  final Map<dynamic, dynamic> songsMap = songsRaw;

  final Map<String, Song> songUrlCache = {};
  final List<Artist> artists = [];

  artistsMap.forEach((dynamic artistKey, dynamic songUrls) {
    final String artistName = artistKey?.toString() ?? '';
    final trimmedArtistName = artistName.trim();
    if (trimmedArtistName.isEmpty) return;

    final List<Song> artistSongs = [];
    if (songUrls is Iterable) {
      for (final dynamic url in songUrls) {
        if (url == null) continue;
        final urlStr = url.toString();
        final cached = songUrlCache[urlStr];
        if (cached != null) {
          artistSongs.add(cached);
          continue;
        }

        final dynamic songEntry = songsMap[urlStr];
        if (songEntry is Map) {
          final dynamic rawName = songEntry['name'];
          final dynamic rawText = songEntry['text'];
          if (rawName is String && rawText is String && rawName.trim().isNotEmpty) {
            final trimmedSongName = rawName.trim();
            final song = Song(
              name: trimmedSongName,
              text: rawText,
            );
            songUrlCache[urlStr] = song;
            artistSongs.add(song);
          }
        }
      }
    }

    if (artistSongs.isNotEmpty || includeEmptyArtists) {
      artistSongs.sort((a, b) => compareUkrainian(a.name, b.name));
      artists.add(Artist(
        name: trimmedArtistName,
        songs: List.unmodifiable(artistSongs),
      ));
    }
  });

  artists.sort((a, b) => compareUkrainian(a.name, b.name));
  return List.unmodifiable(artists);
}

/// Чистий парсер рядка JSON пісенника. Підходить для виклику через compute().
List<Artist> parseSongbookJson(String jsonString) {
  final dynamic decoded = json.decode(jsonString);
  if (decoded is! Map) {
    throw const FormatException('Root of songbook JSON must be an object');
  }
  return parseSongbookData(Map<String, dynamic>.from(decoded));
}

/// Сервіс завантаження збірки пісень.
class SongbookLoader {
  static Future<List<Artist>> loadArtists({
    String assetPath = 'assets/progress.json',
    AssetBundle? bundle,
  }) async {
    final actualBundle = bundle ?? rootBundle;
    final String jsonString = await actualBundle.loadString(assetPath);
    return compute(parseSongbookJson, jsonString);
  }
}
