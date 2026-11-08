import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:song_lyrics/main.dart';

void main() {
  final testArtists = [
    const Artist(
      name: 'Океан Ельзи',
      songs: [
        Song(name: 'Без бою', text: 'Я не здамся без бою...'),
        Song(name: "В'юн над водою", text: 'В’юн над водою стелиться...'),
      ],
    ),
    const Artist(
      name: 'Бумбокс',
      songs: [
        Song(name: 'Вахтерам', text: 'Тебе так любив я...'),
      ],
    ),
  ];

  Widget buildTestApp({Future<List<Artist>> Function()? loader}) {
    return MaterialApp(
      theme: ThemeData.dark().copyWith(
        splashFactory: InkRipple.splashFactory,
      ),
      home: ArtistListPage(
        title: 'Список виконавців',
        loader: loader ?? (() async => testArtists),
      ),
    );
  }

  testWidgets('Navigation flow: list -> artist -> song', (WidgetTester tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    // Перевіряємо відображення списку виконавців
    expect(find.text('Список виконавців'), findsOneWidget);
    expect(find.text('Океан Ельзи'), findsOneWidget);
    expect(find.text('Бумбокс'), findsOneWidget);
    expect(find.text('Пісень: 2'), findsOneWidget);
    expect(find.text('Пісень: 1'), findsOneWidget);

    // Перехід до списку пісень "Океан Ельзи"
    await tester.tap(find.text('Океан Ельзи'));
    await tester.pumpAndSettle();

    // Заголовок має ім'я виконавця і підзаголовок з кількістю пісень
    expect(find.text('Океан Ельзи'), findsOneWidget);
    expect(find.text('2 пісні'), findsOneWidget);
    expect(find.text('Без бою'), findsOneWidget);
    expect(find.text("В'юн над водою"), findsOneWidget);

    // Перехід до тексту пісні "Без бою"
    await tester.tap(find.text('Без бою'));
    await tester.pumpAndSettle();

    expect(find.text('Я не здамся без бою...'), findsOneWidget);

    // Повернення назад до списку пісень
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Океан Ельзи'), findsOneWidget);
    expect(find.text('2 пісні'), findsOneWidget);

    // Повернення назад до списку виконавців
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Список виконавців'), findsOneWidget);
  });

  testWidgets('Search filters artists list and clears properly', (WidgetTester tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    // Відкриваємо модалку пошуку
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();

    // Вводимо запит у TextField
    final textField = find.byType(TextField);
    expect(textField, findsOneWidget);
    await tester.enterText(textField, 'бум');
    await tester.pumpAndSettle();

    // Закриваємо модалку
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    // Перевіряємо, що залишився тільки "Бумбокс"
    expect(find.text('Бумбокс'), findsOneWidget);
    expect(find.text('Океан Ельзи'), findsNothing);

    // Очищаємо пошук через кнопку очищення в AppBar
    final clearButton = find.byIcon(Icons.clear);
    expect(clearButton, findsOneWidget);
    await tester.tap(clearButton);
    await tester.pumpAndSettle();

    // Обидва виконавці знову у списку
    expect(find.text('Океан Ельзи'), findsOneWidget);
    expect(find.text('Бумбокс'), findsOneWidget);
  });

  testWidgets('Search matches songs with different apostrophe characters', (WidgetTester tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    // Шукаємо за піснею з модифікатором апострофа: вʼюн (U+02BC)
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'вʼюн');
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(find.text('Океан Ельзи'), findsOneWidget);
    expect(find.text('Бумбокс'), findsNothing);
  });

  testWidgets('Debounce and LinearProgressIndicator during search', (WidgetTester tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    // Відкриваємо пошук
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();

    // Вводимо текст у TextField
    final textField = find.byType(TextField);
    await tester.enterText(textField, 'бум');

    // Перевіряємо стан під час debounce (100 мс після вводу)
    await tester.pump(const Duration(milliseconds: 100));

    // LinearProgressIndicator відображається під час очікування пошуку
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    // Дочікуємося завершення debounce та пошуку
    await tester.pumpAndSettle();

    // Індикатор зникає, відображаються результати
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.text('Бумбокс'), findsOneWidget);
    expect(find.text('Океан Ельзи'), findsNothing);
  });

  testWidgets('Search field keeps its state and focus while the progress bar toggles', (WidgetTester tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();

    final editableBefore = tester.state<EditableTextState>(find.byType(EditableText));
    expect(editableBefore.widget.focusNode.hasFocus, isTrue);

    // Перша літера вмикає індикатор під AppBar: поле не повинно перебудуватися,
    // інакше втрачається фокус і наступні літери з клавіатури губляться.
    await tester.enterText(find.byType(TextField), 'б');
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    final editableDuring = tester.state<EditableTextState>(find.byType(EditableText));
    expect(identical(editableBefore, editableDuring), isTrue);
    expect(editableDuring.widget.focusNode.hasFocus, isTrue);

    await tester.pumpAndSettle();
    final editableAfter = tester.state<EditableTextState>(find.byType(EditableText));
    expect(identical(editableBefore, editableAfter), isTrue);
    expect(editableAfter.widget.focusNode.hasFocus, isTrue);
  });

  testWidgets('SongPage displays SelectableText and empty state when text is blank', (WidgetTester tester) async {
    const emptySong = Song(name: 'Порожня пісня', text: '');
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark().copyWith(
          splashFactory: InkRipple.splashFactory,
        ),
        home: const SongPage(song: emptySong),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Текст відсутній'), findsOneWidget);
    expect(find.text('Порожня пісня'), findsOneWidget);
  });

  testWidgets('SongPage displays SelectableText for regular song lyrics', (WidgetTester tester) async {
    const song = Song(
      name: 'Без бою',
      text: 'Я не здамся без бою...',
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark().copyWith(
          splashFactory: InkRipple.splashFactory,
        ),
        home: const SongPage(song: song),
      ),
    );
    await tester.pumpAndSettle();

    final selectableText = tester.widget<SelectableText>(find.byType(SelectableText));
    expect(selectableText.data, 'Я не здамся без бою...');
    expect(selectableText.style?.fontFamily, isNot('monospace'));
  });

  testWidgets('SongPage displays monospace font for song with chords', (WidgetTester tester) async {
    const chordSong = Song(
      name: 'Пісня з акордами',
      text: 'Am  C  Dm  E7\nСлова пісні',
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark().copyWith(
          splashFactory: InkRipple.splashFactory,
        ),
        home: const SongPage(song: chordSong),
      ),
    );
    await tester.pumpAndSettle();

    final selectableText = tester.widget<SelectableText>(find.byType(SelectableText));
    expect(selectableText.style?.fontFamily, 'monospace');
  });

  testWidgets('Error state shows retry button and Ukrainian error text', (WidgetTester tester) async {
    int attempts = 0;
    await tester.pumpWidget(
      buildTestApp(
        loader: () async {
          attempts++;
          if (attempts == 1) {
            throw Exception('Помилка мережі');
          }
          return testArtists;
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Не вдалося прочитати базу пісень'), findsOneWidget);
    final retryBtn = find.widgetWithText(ElevatedButton, 'Повторити');
    expect(retryBtn, findsOneWidget);

    await tester.tap(retryBtn);
    await tester.pumpAndSettle();

    expect(find.text('Список виконавців'), findsOneWidget);
    expect(find.text('Океан Ельзи'), findsOneWidget);
  });

  testWidgets('MyApp configures system theme mode, title and Ukrainian localization', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.title, 'Співаник');
    expect(materialApp.themeMode, ThemeMode.system);
    expect(materialApp.supportedLocales, contains(const Locale('uk')));
    expect(materialApp.locale, const Locale('uk'));
    expect(materialApp.theme?.colorScheme.primary, isNotNull);
    expect(materialApp.darkTheme?.colorScheme.brightness, Brightness.dark);
  });
}
