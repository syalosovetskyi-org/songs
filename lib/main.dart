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

import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'crash_reporter.dart';
import 'songbook.dart';

export 'songbook.dart'
    show
        Song,
        Artist,
        SongbookLoader,
        formatSongsCount,
        searchArtists,
        filterArtists,
        filterSongs,
        normalizeSearchText;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const flavor = String.fromEnvironment('FLAVOR', defaultValue: 'personal');
  if (flavor == 'play') {
    final reporter = CrashReporter.instance;
    await reporter.initialize();
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      reporter.recordError(error, stack, fatal: true);
      return true;
    };
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seedColor = Color(0xFF2BA0DA);

    return MaterialApp(
      title: 'Співаник',
      themeMode: ThemeMode.system,
      locale: const Locale('uk'),
      supportedLocales: const [
        Locale('uk'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.light,
        ),
        splashFactory: InkRipple.splashFactory,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.dark,
        ),
        splashFactory: InkRipple.splashFactory,
      ),
      home: const ArtistListPage(title: 'Список виконавців'),
    );
  }
}

class ArtistListPage extends StatefulWidget {
  const ArtistListPage({
    super.key,
    required this.title,
    this.loader,
  });

  final String title;
  final Future<List<Artist>> Function()? loader;

  @override
  State<ArtistListPage> createState() => _ArtistListPageState();
}

class _ArtistListPageState extends State<ArtistListPage> {
  late Future<List<Artist>> _artistsFuture;
  late final TextEditingController _searchController;
  List<Artist> _allArtists = const [];
  List<Artist>? _filteredArtists;
  String _searchQuery = '';
  bool _isSearching = false;
  bool _isSearchLoading = false;
  int _activeSearchId = 0;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _reloadArtists();
  }

  void _reloadArtists() {
    _debounceTimer?.cancel();
    final searchId = ++_activeSearchId;
    setState(() {
      _isSearchLoading = false;
      _filteredArtists = null;
      _artistsFuture = (widget.loader != null
              ? widget.loader!()
              : SongbookLoader.loadArtists())
          .then((artists) {
        _allArtists = artists;
        if (_searchQuery.trim().isNotEmpty) {
          _runSearch(_searchQuery, expectedSearchId: searchId);
        } else {
          _filteredArtists = artists;
        }
        return artists;
      });
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _debounceTimer?.cancel();
    ++_activeSearchId;
    setState(() {
      _searchQuery = '';
      _searchController.clear();
      _filteredArtists = _allArtists;
      _isSearchLoading = false;
    });
  }

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    final searchId = ++_activeSearchId;
    final trimmed = value.trim();

    if (trimmed.isEmpty) {
      setState(() {
        _searchQuery = value;
        _filteredArtists = _allArtists;
        _isSearchLoading = false;
      });
      return;
    }

    setState(() {
      _searchQuery = value;
      _isSearchLoading = true;
    });

    _debounceTimer = Timer(const Duration(milliseconds: 250), () {
      _runSearch(value, expectedSearchId: searchId);
    });
  }

  Future<void> _runSearch(String query, {required int expectedSearchId}) async {
    final results = await searchArtists(_allArtists, query);
    if (!mounted || expectedSearchId != _activeSearchId) {
      return;
    }
    setState(() {
      _filteredArtists = results;
      _isSearchLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Смуга під AppBar є завжди, перемикається лише її вміст: якщо bottom
    // змінюється між null і віджетом, AppBar перебудовує дерево, поле пошуку
    // втрачає фокус і з'єднання з клавіатурою, і наступні літери губляться.
    final PreferredSizeWidget appBarBottom = PreferredSize(
      preferredSize: const Size.fromHeight(2.0),
      child: SizedBox(
        height: 2.0,
        child: _isSearchLoading
            ? const LinearProgressIndicator(minHeight: 2.0)
            : null,
      ),
    );

    final PreferredSizeWidget appBar = _isSearching
        ? AppBar(
            bottom: appBarBottom,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Назад',
              onPressed: () {
                setState(() {
                  _isSearching = false;
                });
              },
            ),
            title: TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Пошук виконавців та пісень',
                border: InputBorder.none,
                suffixIcon: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _searchController,
                  builder: (context, value, _) {
                    if (value.text.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return IconButton(
                      icon: const Icon(Icons.clear),
                      tooltip: 'Очистити',
                      onPressed: _clearSearch,
                    );
                  },
                ),
              ),
              onChanged: _onSearchChanged,
            ),
          )
        : AppBar(
            title: Text(widget.title),
            bottom: appBarBottom,
            actions: [
              if (_searchQuery.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear),
                  tooltip: 'Очистити',
                  onPressed: _clearSearch,
                ),
              IconButton(
                icon: const Icon(Icons.search),
                tooltip: 'Пошук',
                onPressed: () {
                  setState(() {
                    _isSearching = true;
                  });
                },
              ),
            ],
          );

    return Scaffold(
      appBar: appBar,
      body: FutureBuilder<List<Artist>>(
        future: _artistsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            CrashReporter.instance.recordError(
              snapshot.error!,
              snapshot.stackTrace,
              reason: 'Помилка завантаження бази пісень',
            );
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, color: colorScheme.error, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      'Не вдалося прочитати базу пісень. Перевстановіть застосунок',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colorScheme.error),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _reloadArtists,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Повторити'),
                    ),
                  ],
                ),
              ),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Немає даних'));
          }

          _allArtists = snapshot.data!;
          final filteredArtists = _filteredArtists ?? _allArtists;

          final searchFilterChip = _searchQuery.isNotEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Chip(
                      label: Text('Знайдено ${filteredArtists.length} за «$_searchQuery»'),
                      onDeleted: _clearSearch,
                      deleteIcon: const Icon(Icons.close, size: 18),
                    ),
                  ),
                )
              : null;

          if (filteredArtists.isEmpty) {
            return Column(
              children: [
                if (searchFilterChip != null) searchFilterChip,
                const Expanded(
                  child: Center(child: Text('Нічого не знайдено')),
                ),
              ],
            );
          }

          return Column(
            children: [
              if (searchFilterChip != null) searchFilterChip,
              Expanded(
                child: ListView.separated(
                  separatorBuilder: (context, index) => const Divider(),
                  itemCount: filteredArtists.length,
                  itemBuilder: (context, index) {
                    final artist = filteredArtists[index];
                    return ListTile(
                      title: Text(artist.name),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      subtitle: Text(
                        'Пісень: ${artist.songs.length}',
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      onTap: () {
                        final initialQuery = _searchQuery.isNotEmpty &&
                                !matchesSearch(artist.name, _searchQuery)
                            ? _searchQuery
                            : '';
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SongListPage(
                              artist: artist,
                              initialSearchQuery: initialQuery,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class SongListPage extends StatefulWidget {
  final Artist artist;
  final String initialSearchQuery;

  const SongListPage({
    super.key,
    required this.artist,
    this.initialSearchQuery = '',
  });

  @override
  State<SongListPage> createState() => _SongListPageState();
}

class _SongListPageState extends State<SongListPage> {
  late final TextEditingController _searchController;
  late String _searchQuery;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _searchQuery = widget.initialSearchQuery;
    _searchController = TextEditingController(text: _searchQuery);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _clearSearch() {
    setState(() {
      _searchQuery = '';
      _searchController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final filteredSongs = filterSongs(widget.artist.songs, _searchQuery);
    final textScaleFactor = MediaQuery.textScalerOf(context).scale(1.0);
    final toolbarHeight = textScaleFactor > 1.0
        ? kToolbarHeight * textScaleFactor
        : kToolbarHeight;

    final searchFilterChip = _searchQuery.isNotEmpty
        ? Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Chip(
                label: Text('Знайдено ${filteredSongs.length} за «$_searchQuery»'),
                onDeleted: _clearSearch,
                deleteIcon: const Icon(Icons.close, size: 18),
              ),
            ),
          )
        : null;

    final PreferredSizeWidget appBar = _isSearching
        ? AppBar(
            toolbarHeight: toolbarHeight,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Назад',
              onPressed: () {
                setState(() {
                  _isSearching = false;
                });
              },
            ),
            title: TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Пошук пісень',
                border: InputBorder.none,
                suffixIcon: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _searchController,
                  builder: (context, value, _) {
                    if (value.text.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return IconButton(
                      icon: const Icon(Icons.clear),
                      tooltip: 'Очистити',
                      onPressed: _clearSearch,
                    );
                  },
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          )
        : AppBar(
            toolbarHeight: toolbarHeight,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.artist.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  formatSongsCount(filteredSongs.length),
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            actions: [
              if (_searchQuery.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear),
                  tooltip: 'Очистити',
                  onPressed: _clearSearch,
                ),
              IconButton(
                icon: const Icon(Icons.search),
                tooltip: 'Пошук',
                onPressed: () {
                  setState(() {
                    _isSearching = true;
                  });
                },
              ),
            ],
          );

    return Scaffold(
      appBar: appBar,
      body: filteredSongs.isEmpty
          ? Column(
              children: [
                if (searchFilterChip != null) searchFilterChip,
                const Expanded(
                  child: Center(child: Text('Нічого не знайдено')),
                ),
              ],
            )
          : Column(
              children: [
                if (searchFilterChip != null) searchFilterChip,
                Expanded(
                  child: ListView.separated(
                    separatorBuilder: (context, index) => const Divider(),
                    itemCount: filteredSongs.length,
                    itemBuilder: (context, index) {
                      final song = filteredSongs[index];
                      return ListTile(
                        title: Text(
                          song.name,
                          style: const TextStyle(fontSize: 16),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SongPage(song: song),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

class SongPage extends StatelessWidget {
  final Song song;

  const SongPage({super.key, required this.song});

  double _measureTextWidth(String text, double fontSize, TextScaler scaler) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: fontSize,
          letterSpacing: 0,
        ),
      ),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
    )..layout();
    return textPainter.width;
  }

  Widget _buildSongTitle(BuildContext context) {
    return Text(
      song.name,
      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final bool withChords = hasChords(song.text);

    Widget content;
    if (song.text.trim().isEmpty) {
      content = Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSongTitle(context),
            Expanded(
              child: Center(
                child: Text(
                  'Текст відсутній',
                  style: textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    } else if (withChords) {
      content = LayoutBuilder(
        builder: (context, constraints) {
          final availableWidth = constraints.maxWidth - 32.0;

          final scaler = MediaQuery.textScalerOf(context);

          // Оцінка колонок за шириною латинських літер; кирилиця в моноширинному
          // шрифті буває трохи ширшою, і системний масштаб шрифту теж впливає.
          int estimateCols(double size) {
            final charWidth =
                _measureTextWidth('MMMMMMMMMM', size, scaler) / 10.0;
            return charWidth > 0 ? (availableWidth / charWidth).floor() : 40;
          }

          double fontSize = 14.0;
          int maxCols = estimateCols(fontSize);
          if (maxCols < 28) {
            fontSize = 12.0;
            maxCols = estimateCols(fontSize);
          }
          if (maxCols < 1) maxCols = 1;

          // Остаточна перевірка по готових рядках: якщо хоч один (крім табулатури)
          // не влазить у ширину, зменшуємо кількість колонок і перерозкладаємо.
          var displayLines = layoutChordText(song.text, maxCols);
          bool overflows(List<ChordDisplayLine> lines) => lines.any((line) =>
              !line.isTab &&
              _measureTextWidth(line.text, fontSize, scaler) > availableWidth);
          while (maxCols > 10 && overflows(displayLines)) {
            maxCols--;
            displayLines = layoutChordText(song.text, maxCols);
          }

          final spans = <TextSpan>[];
          for (int i = 0; i < displayLines.length; i++) {
            final displayLine = displayLines[i];
            spans.add(
              TextSpan(
                text: i < displayLines.length - 1
                    ? '${displayLine.text}\n'
                    : displayLine.text,
                style: TextStyle(
                  color: displayLine.isChord
                      ? colorScheme.primary
                      : colorScheme.onSurface,
                ),
              ),
            );
          }

          // letterSpacing явно 0: інакше успадковується з теми (bodyMedium у
          // Material 3 має 0.25), рядки стають ширшими за виміряні й обрізаються.
          final textStyle = TextStyle(
            fontFamily: 'monospace',
            fontSize: fontSize,
            letterSpacing: 0,
          );

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSongTitle(context),
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SelectableText.rich(
                    TextSpan(
                      style: textStyle,
                      children: spans,
                    ),
                    style: textStyle,
                  ),
                ),
              ],
            ),
          );
        },
      );
    } else {
      final textStyle = TextStyle(
        fontSize: 16.0,
        color: colorScheme.onSurface,
      );

      content = SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSongTitle(context),
            const SizedBox(height: 16),
            SelectableText(
              song.text,
              style: textStyle,
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(),
      body: content,
    );
  }
}
