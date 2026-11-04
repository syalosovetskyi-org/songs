import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:song_lyrics/crash_reporter.dart';

void main() {
  group('CrashReporter tests', () {
    test('PersonalCrashReporter is created by default (FLAVOR=personal)', () {
      final reporter = CrashReporter.create('personal');
      expect(reporter, isA<PersonalCrashReporter>());
    });

    test('PlayCrashReporter is created when FLAVOR=play', () {
      final reporter = CrashReporter.create('play');
      expect(reporter, isA<PlayCrashReporter>());
    });

    test('PersonalCrashReporter initialize does not throw and handles errors locally', () async {
      final reporter = PersonalCrashReporter();
      await expectLater(reporter.initialize(), completes);

      reporter.recordError(
        Exception('Test error'),
        StackTrace.current,
        fatal: false,
      );
      expect(reporter.errorLogs, hasLength(1));
      expect(reporter.errorLogs.first, contains('PersonalCrashReporter [ERROR]: Exception: Test error'));

      reporter.recordFlutterFatalError(
        FlutterErrorDetails(
          exception: Exception('Fatal framework error'),
          library: 'test',
        ),
      );
      expect(reporter.errorLogs, hasLength(2));
      expect(reporter.errorLogs.last, contains('PersonalCrashReporter [FATAL]: Exception: Fatal framework error'));
    });

    test('CrashReporter instance can be customized for testing', () {
      final customReporter = PersonalCrashReporter();
      CrashReporter.instance = customReporter;
      expect(CrashReporter.instance, same(customReporter));

      // Reset
      CrashReporter.instance = null;
    });
  });
}
