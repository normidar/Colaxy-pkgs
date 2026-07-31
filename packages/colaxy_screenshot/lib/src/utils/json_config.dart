import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

/// Get config file as json
Future<Map<String, String>> getJsonConfig() async {
  final configString = await rootBundle.loadString('assets/config.json');
  final jsonConfig = jsonDecode(configString) as Map<String, dynamic>;
  // `cast` is lazy: a non-String value used to surface as a CastError from some
  // unrelated line much later. Convert eagerly and name the offending key.
  return <String, String>{
    for (final entry in jsonConfig.entries)
      entry.key: entry.value is String
          ? entry.value as String
          : throw StateError(
              'assets/config.json: "${entry.key}" must be a string, '
              'got ${entry.value.runtimeType}.',
            ),
  };
}

/// Reset config file
Future<void> resetJsonConfig() async {
  final jsonConfig = await getJsonConfig();
  final configPath = '${jsonConfig['app_path']!}/assets/config.json';

  jsonConfig['launch_mode'] = '_${jsonConfig['launch_mode']}';
  const encoder = JsonEncoder.withIndent('  ');
  final jsonString = encoder.convert(jsonConfig);
  File(configPath).writeAsStringSync(jsonString);
}
