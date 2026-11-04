import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:song_lyrics/main.dart';

void main() {
  const testArtists = [
    Artist(
      name: 'Океан Ельзи',
      songs: [
        Song(name: 'Без бою', text: 'Я не здамся без бою...'),
        Song(name: "В'юн над водою", text: 'В’юн над водою стелиться...'),
      ],
    ),
    Artist(
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

    expect(find.text('Пісні Океан Ельзи'), findsOneWidget);
    expect(find.text('Без бою'), findsOneWidget);
    expect(find.text("В'юн над водою"), findsOneWidget);

    // Перехід до тексту пісні "Без бою"
    await tester.tap(find.text('Без бою'));
    await tester.pumpAndSettle();

    expect(find.text('Я не здамся без бою...'), findsOneWidget);

    // Повернення назад до списку пісень
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Пісні Океан Ельзи'), findsOneWidget);

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

    // Має знайти "Океан Ельзи" (де пісня "В'юн над водою")
    expect(find.text('Океан Ельзи'), findsOneWidget);
    expect(find.text('Бумбокс'), findsNothing);
  });
}
