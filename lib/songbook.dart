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
import 'dart:math' as math;
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

/// Регулярний вираз для перевірки префіксу табулатури (назва струни та роздільник |).
final RegExp _tabPrefixRegex = RegExp(r'^[A-Ha-h][#b]?\|');

/// Перевіряє, чи є рядок табулатурою.
bool isTabLine(String line) {
  final trimmed = line.trimLeft();
  if (trimmed.isEmpty) return false;
  return _tabPrefixRegex.hasMatch(trimmed) ||
      (line.contains('---') && line.contains('|'));
}

/// Модель рядка для відображення у пісеннику з акордами або табулатурою.
class ChordDisplayLine {
  final String text;
  final bool isChord;
  final bool isTab;

  const ChordDisplayLine(
    this.text, {
    this.isChord = false,
    this.isTab = false,
  });

  const ChordDisplayLine.named({
    required this.text,
    this.isChord = false,
    this.isTab = false,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChordDisplayLine &&
          runtimeType == other.runtimeType &&
          text == other.text &&
          isChord == other.isChord &&
          isTab == other.isTab;

  @override
  int get hashCode => Object.hash(text, isChord, isTab);

  @override
  String toString() =>
      'ChordDisplayLine(text: $text, isChord: $isChord, isTab: $isTab)';
}

class _TokenSpan {
  final int start;
  final int end;

  const _TokenSpan(this.start, this.end);
}

List<_TokenSpan> _findChordTokens(String line) {
  final tokens = <_TokenSpan>[];
  int i = 0;
  while (i < line.length) {
    if (line[i] != ' ') {
      final start = i;
      while (i < line.length && line[i] != ' ') {
        i++;
      }
      tokens.add(_TokenSpan(start, i));
    } else {
      i++;
    }
  }
  return tokens;
}

_TokenSpan? _getTokenCutting(int pos, List<_TokenSpan> tokens) {
  for (final tok in tokens) {
    if (tok.start < pos && pos < tok.end) {
      return tok;
    }
  }
  return null;
}

String _expandTabs(String line) {
  if (!line.contains('\t')) return line;
  final buffer = StringBuffer();
  int col = 0;
  for (int i = 0; i < line.length; i++) {
    final char = line[i];
    if (char == '\t') {
      final spaces = 4 - (col % 4);
      buffer.write(' ' * spaces);
      col += spaces;
    } else {
      buffer.write(char);
      col++;
    }
  }
  return buffer.toString();
}

int _countLeadingSpaces(String s) {
  int count = 0;
  while (count < s.length && s[count] == ' ') {
    count++;
  }
  return count;
}

int _choosePairSplit({
  required String lyric,
  required String chords,
  required int s,
  required int maxCols,
  required int length,
  required List<_TokenSpan> chordTokens,
}) {
  final limit = s + maxCols;
  if (limit >= length) {
    return length;
  }

  // 1. Шукаємо пробіл у рядку тексту в діапазоні (s, limit]
  int? breakPt;
  for (int p = limit; p > s; p--) {
    if (lyric[p] == ' ') {
      breakPt = p;
      break;
    }
  }

  // 2. Якщо знайдено, перевіряємо, чи не розрізає він токен акорду
  if (breakPt != null) {
    while (true) {
      final tok = _getTokenCutting(breakPt!, chordTokens);
      if (tok == null) break;

      final sTok = tok.start;
      int? shifted;
      for (int p = sTok - 1; p > s; p--) {
        if (lyric[p] == ' ') {
          shifted = p;
          break;
        }
      }

      if (shifted != null && shifted > s) {
        breakPt = shifted;
      } else if (sTok > s) {
        breakPt = sTok;
        break;
      } else {
        breakPt = limit;
        break;
      }
    }
  } else {
    // Немає пробілу в тексті: якщо є акорд, розриваємо прямо перед ним
    int? cand;
    for (final tok in chordTokens) {
      if (tok.start > s && tok.start <= limit) {
        cand = tok.start;
        break;
      }
    }
    if (cand != null) {
      breakPt = cand;
    } else {
      breakPt = limit;
    }
  }

  if (breakPt <= s) {
    breakPt = limit;
  }
  return breakPt;
}

void _layoutPair({
  required String chordLine,
  required String lyricLine,
  required int maxCols,
  required List<ChordDisplayLine> result,
}) {
  final len = math.max(chordLine.length, lyricLine.length);
  if (len <= maxCols) {
    result.add(ChordDisplayLine(chordLine, isChord: true));
    result.add(ChordDisplayLine(lyricLine, isChord: false));
    return;
  }

  final paddedChords = chordLine.padRight(len);
  final paddedLyric = lyricLine.padRight(len);
  final chordTokens = _findChordTokens(paddedChords);

  int s = 0;
  bool isContinuation = false;

  while (s < len) {
    final e = _choosePairSplit(
      lyric: paddedLyric,
      chords: paddedChords,
      s: s,
      maxCols: maxCols,
      length: len,
      chordTokens: chordTokens,
    );

    String chordPart = paddedChords.substring(s, e).trimRight();
    String lyricPart = paddedLyric.substring(s, e).trimRight();

    if (isContinuation) {
      final chordLead =
          chordPart.isNotEmpty ? _countLeadingSpaces(chordPart) : null;
      final lyricLead =
          lyricPart.isNotEmpty ? _countLeadingSpaces(lyricPart) : null;

      int stripCount = 0;
      if (chordLead != null && lyricLead != null) {
        stripCount = math.min(chordLead, lyricLead);
      } else if (chordLead != null) {
        stripCount = chordLead;
      } else if (lyricLead != null) {
        stripCount = lyricLead;
      }

      if (stripCount > 0) {
        if (chordPart.isNotEmpty) {
          chordPart = chordPart.substring(stripCount);
        }
        if (lyricPart.isNotEmpty) {
          lyricPart = lyricPart.substring(stripCount);
        }
      }
    }

    if (chordPart.isNotEmpty) {
      result.add(ChordDisplayLine(chordPart, isChord: true));
    }
    result.add(ChordDisplayLine(lyricPart, isChord: false));

    isContinuation = true;
    s = e;
  }
}

void _layoutSingleChordLine({
  required String line,
  required int maxCols,
  required List<ChordDisplayLine> result,
}) {
  if (line.length <= maxCols) {
    result.add(ChordDisplayLine(line, isChord: true));
    return;
  }

  final tokens = _findChordTokens(line);
  if (tokens.isEmpty) {
    result.add(ChordDisplayLine(line, isChord: true));
    return;
  }

  int s = 0;
  while (s < line.length) {
    final remaining = line.substring(s).trimRight();
    if (remaining.length <= maxCols) {
      if (remaining.isNotEmpty) {
        result.add(ChordDisplayLine(remaining, isChord: true));
      }
      break;
    }

    final limit = s + maxCols;
    int? breakPt;
    for (int p = limit; p > s; p--) {
      final tok = _getTokenCutting(p, tokens);
      if (tok == null) {
        breakPt = p;
        break;
      }
    }

    breakPt ??= limit;

    final chunk = line.substring(s, breakPt).trimRight();
    if (chunk.isNotEmpty) {
      result.add(ChordDisplayLine(chunk, isChord: true));
    }

    int nextS = breakPt;
    while (nextS < line.length && line[nextS] == ' ') {
      nextS++;
    }
    if (nextS <= s) {
      nextS = breakPt;
    }
    s = nextS;
  }
}

void _layoutSingleLyricLine({
  required String line,
  required int maxCols,
  required List<ChordDisplayLine> result,
}) {
  if (line.length <= maxCols) {
    result.add(ChordDisplayLine(line, isChord: false));
    return;
  }

  final words = line.trim().split(RegExp(r'\s+'));
  if (words.isEmpty || (words.length == 1 && words[0].isEmpty)) {
    result.add(ChordDisplayLine(line, isChord: false));
    return;
  }

  String currentLine = '';
  bool isFirst = true;
  int wIdx = 0;

  while (wIdx < words.length) {
    final word = words[wIdx];
    final limit = isFirst ? maxCols : (maxCols > 2 ? maxCols - 2 : maxCols);
    final prefix = isFirst ? '' : '  ';

    if (currentLine.isEmpty) {
      if (word.length <= limit) {
        currentLine = word;
        wIdx++;
      } else {
        final part = word.substring(0, limit);
        words[wIdx] = word.substring(limit);
        result.add(ChordDisplayLine('$prefix$part', isChord: false));
        isFirst = false;
        currentLine = '';
      }
    } else {
      if (currentLine.length + 1 + word.length <= limit) {
        currentLine = '$currentLine $word';
        wIdx++;
      } else {
        result.add(ChordDisplayLine('$prefix$currentLine', isChord: false));
        isFirst = false;
        currentLine = '';
      }
    }
  }

  if (currentLine.isNotEmpty) {
    final prefix = isFirst ? '' : '  ';
    result.add(ChordDisplayLine('$prefix$currentLine', isChord: false));
  }
}

/// Розбиває текст пісні на рядки з урахуванням акордових пар, табулатур та максимальної ширини.
List<ChordDisplayLine> layoutChordText(String text, int maxCols) {
  if (text.isEmpty || maxCols <= 0) return const [];

  final normalized = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  final rawLines = normalized.split('\n');
  final lines = rawLines.map(_expandTabs).toList();

  final result = <ChordDisplayLine>[];
  int i = 0;
  while (i < lines.length) {
    final line = lines[i];

    if (line.isEmpty) {
      result.add(const ChordDisplayLine(''));
      i++;
      continue;
    }

    if (isTabLine(line)) {
      result.add(ChordDisplayLine(line, isTab: true));
      i++;
      continue;
    }

    if (isChordLine(line)) {
      final hasNext = i + 1 < lines.length;
      final nextLine = hasNext ? lines[i + 1] : null;
      final isPair = nextLine != null &&
          nextLine.trim().isNotEmpty &&
          !isChordLine(nextLine) &&
          !isTabLine(nextLine);

      if (isPair) {
        _layoutPair(
          chordLine: line,
          lyricLine: nextLine,
          maxCols: maxCols,
          result: result,
        );
        i += 2;
      } else {
        _layoutSingleChordLine(
          line: line,
          maxCols: maxCols,
          result: result,
        );
        i++;
      }
      continue;
    }

    _layoutSingleLyricLine(
      line: line,
      maxCols: maxCols,
      result: result,
    );
    i++;
  }

  return List.unmodifiable(result);
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
