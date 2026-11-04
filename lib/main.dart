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

import 'package:flutter/material.dart';
import 'songbook.dart';

export 'songbook.dart' show Song, Artist, SongbookLoader;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Список виконавців',
      theme: ThemeData.dark().copyWith(
        primaryColor: const Color(0xFF2BA0DA),
        scaffoldBackgroundColor: Colors.black,
        splashFactory: InkRipple.splashFactory,
        textTheme: const TextTheme(
          bodyMedium: TextStyle(
            color: Colors.white,
          ),
        ),
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
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _reloadArtists();
  }

  void _reloadArtists() {
    setState(() {
      _artistsFuture = widget.loader != null
          ? widget.loader!()
          : SongbookLoader.loadArtists();
    });
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
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
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
            onPressed: () => _showSearchModal(context),
          ),
        ],
      ),
      body: FutureBuilder<List<Artist>>(
        future: _artistsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      'Помилка завантаження: ${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.redAccent),
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
          final filteredArtists = filterArtists(_allArtists, _searchQuery);

          if (filteredArtists.isEmpty) {
            return const Center(child: Text('Нічого не знайдено'));
          }

          return ListView.separated(
            separatorBuilder: (context, index) => Divider(
              color: Colors.grey[800],
            ),
            itemCount: filteredArtists.length,
            itemBuilder: (context, index) {
              final artist = filteredArtists[index];
              return ListTile(
                title: Text(artist.name),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                subtitle: Text(
                  'Пісень: ${artist.songs.length}',
                  style: const TextStyle(
                    color: Colors.grey,
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
          );
        },
      ),
    );
  }

  void _showSearchModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext modalContext) {
        return Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(modalContext).viewInsets.bottom,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Пошук виконавців та пісень',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        tooltip: 'Очистити',
                        onPressed: () {
                          _clearSearch();
                        },
                      )
                    : null,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
        );
      },
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

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.artist.name),
            Text(
              '${widget.artist.songs.length} пісень',
              style: Theme.of(context).textTheme.bodySmall,
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
            onPressed: () => _showSearchModal(context),
          ),
        ],
      ),
      body: filteredSongs.isEmpty
          ? const Center(child: Text('Нічого не знайдено'))
          : ListView.separated(
              separatorBuilder: (context, index) => Divider(
                color: Colors.grey[800],
              ),
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
    );
  }

  void _showSearchModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext modalContext) {
        return Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(modalContext).viewInsets.bottom,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Пошук пісень',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        tooltip: 'Очистити',
                        onPressed: _clearSearch,
                      )
                    : null,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
        );
      },
    );
  }
}

class SongPage extends StatelessWidget {
  final Song song;

  const SongPage({super.key, required this.song});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final bool withChords = hasChords(song.text);

    final textStyle = (withChords
            ? const TextStyle(fontFamily: 'monospace', fontSize: 14.0)
            : const TextStyle(fontSize: 16.0))
        .copyWith(color: colorScheme.onSurface);

    Widget content;
    if (song.text.trim().isEmpty) {
      content = Center(
        child: Text(
          'Текст відсутній',
          style: textTheme.bodyLarge?.copyWith(
            color: colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      );
    } else if (withChords) {
      content = SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SelectableText(
            song.text,
            style: textStyle,
          ),
        ),
      );
    } else {
      content = SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: SelectableText(
          song.text,
          style: textStyle,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(song.name),
      ),
      body: content,
    );
  }
}
