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

import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// Інтерфейс репортера помилок для різних flavor-ів.
abstract class CrashReporter {
  static CrashReporter? _instance;

  /// Поточний екземпляр репортера відповідно до FLAVOR (dart-define).
  static CrashReporter get instance => _instance ??= create();

  @visibleForTesting
  static set instance(CrashReporter? custom) => _instance = custom;

  /// Фабрика для створення репортера з урахуванням переданого flavor.
  static CrashReporter create([String? flavor]) {
    final effectiveFlavor =
        flavor ?? const String.fromEnvironment('FLAVOR', defaultValue: 'personal');
    if (effectiveFlavor.toLowerCase() == 'play') {
      return PlayCrashReporter();
    }
    return PersonalCrashReporter();
  }

  /// Ініціалізація сервісу відправки помилок.
  Future<void> initialize();

  /// Реєстрація фатальної помилки Flutter framework.
  void recordFlutterFatalError(FlutterErrorDetails details);

  /// Реєстрація помилки/виключення.
  void recordError(
    Object error,
    StackTrace? stack, {
    String? reason,
    Iterable<Object> information = const [],
    bool fatal = false,
  });
}

/// Реалізація для personal-сборки:
/// Firebase не ініціалізується і не викликається.
/// Помилки виводяться в лог (або в локальний GlitchTip, якщо підключено).
class PersonalCrashReporter implements CrashReporter {
  final List<String> errorLogs = [];

  @override
  Future<void> initialize() async {
    // У personal-сборці Firebase не ініціалізується взагалі
  }

  @override
  void recordFlutterFatalError(FlutterErrorDetails details) {
    FlutterError.presentError(details);
    final message = 'PersonalCrashReporter [FATAL]: ${details.exceptionAsString()}';
    errorLogs.add(message);
    debugPrint(message);
  }

  @override
  void recordError(
    Object error,
    StackTrace? stack, {
    String? reason,
    Iterable<Object> information = const [],
    bool fatal = false,
  }) {
    final message = 'PersonalCrashReporter [${fatal ? "FATAL" : "ERROR"}]: $error';
    errorLogs.add(message);
    debugPrint(message);
    if (stack != null) {
      debugPrint(stack.toString());
    }
  }
}

/// Реалізація для play-сборки (Google Play):
/// Відправляє помилки у Firebase Crashlytics.
/// Збір увімкнено виключно в release-режимі.
class PlayCrashReporter implements CrashReporter {
  @override
  Future<void> initialize() async {
    await Firebase.initializeApp();
    // Включаємо збір лише у release-режимі (!kDebugMode)
    await FirebaseCrashlytics.instance
        .setCrashlyticsCollectionEnabled(!kDebugMode);
  }

  @override
  void recordFlutterFatalError(FlutterErrorDetails details) {
    FirebaseCrashlytics.instance.recordFlutterFatalError(details);
  }

  @override
  void recordError(
    Object error,
    StackTrace? stack, {
    String? reason,
    Iterable<Object> information = const [],
    bool fatal = false,
  }) {
    FirebaseCrashlytics.instance.recordError(
      error,
      stack,
      reason: reason,
      information: information,
      fatal: fatal,
    );
  }
}
