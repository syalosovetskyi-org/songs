import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:song_lyrics/crash_reporter.dart';
import 'package:song_lyrics/main.dart';

/// Репортер, у якого ініціалізація падає, як Firebase.initializeApp()
/// з битим google-services.json або без Play Services.
class _FailingInitReporter extends PersonalCrashReporter {
  @override
  Future<void> initialize() async {
    throw StateError('Firebase.initializeApp failed');
  }
}

void main() {
  tearDown(() {
    CrashReporter.instance = null;
  });

  group('initCrashReporting', () {
    test('збій initialize() не валить старт і перемикає на локальний репортер',
        () async {
      final originalFlutterOnError = FlutterError.onError;
      final originalPlatformOnError = PlatformDispatcher.instance.onError;
      addTearDown(() {
        FlutterError.onError = originalFlutterOnError;
        PlatformDispatcher.instance.onError = originalPlatformOnError;
      });

      CrashReporter.instance = _FailingInitReporter();

      await expectLater(initCrashReporting('play'), completes);

      final fallback = CrashReporter.instance;
      expect(fallback, isA<PersonalCrashReporter>());
      expect(fallback, isNot(isA<_FailingInitReporter>()));
      final logs = (fallback as PersonalCrashReporter).errorLogs;
      expect(logs, hasLength(1));
      expect(logs.single, contains('Firebase.initializeApp failed'));

      // Обробники ведуть у робочий репортер, а не в неініціалізований Firebase.
      FlutterError.onError!(
        FlutterErrorDetails(exception: Exception('framework'), library: 'test'),
      );
      expect(logs.last, contains('[FATAL]'));
      expect(
        PlatformDispatcher.instance.onError!(
            Exception('async'), StackTrace.current),
        isTrue,
      );
      expect(logs, hasLength(3));
    });
  });

  group('ArtistListPage', () {
    testWidgets('помилка завантаження надсилається один раз, а не на кожен build',
        (tester) async {
      final reporter = PersonalCrashReporter();
      CrashReporter.instance = reporter;

      await tester.pumpWidget(MaterialApp(
        home: ArtistListPage(
          title: 'Список виконавців',
          loader: () async => throw StateError('broken songs.json'),
        ),
      ));
      await tester.pumpAndSettle();

      expect(
        find.text('Не вдалося прочитати базу пісень. Перевстановіть застосунок'),
        findsOneWidget,
      );
      expect(reporter.errorLogs, hasLength(1));

      // Відкриття пошуку викликає setState -> build() з тим самим Future.
      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(reporter.errorLogs, hasLength(1));
    });
  });
}
