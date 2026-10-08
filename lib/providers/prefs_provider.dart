// SharedPreferences provider — overridden with the real instance in main().

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final Provider<SharedPreferences> sharedPrefsProvider = Provider<SharedPreferences>(
  (Ref ref) => throw UnimplementedError(
      'sharedPrefsProvider must be overridden in ProviderScope (see main.dart)'),
);
