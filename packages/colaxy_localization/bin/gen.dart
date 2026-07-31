import 'dart:io';

import 'package:colaxy_localization/colaxy_localization.dart';
import 'package:colaxy_localization/src/cli_logger.dart';

/// Generates Fastlane metadata and native app-name resources from the app's
/// `assets/localizations/*.json` files.
void main(List<String> args) {
  final options = _parseArgs(args);
  if (options == null) return;

  final app = LocaleApp(rootPath: options.rootPath);
  final units = app.getLocaleUnits(mainLocale: options.mainLocale);
  for (final unit in units) {
    unit.fitAllToFastlane();
    CliLogger.info('generated ${unit.locale}');
  }
  CliLogger.info('done (${units.length} locales)');
}

class _Options {
  const _Options({required this.rootPath, required this.mainLocale});

  final String rootPath;
  final String mainLocale;
}

/// Returns null when the process should stop (help shown or bad usage).
_Options? _parseArgs(List<String> args) {
  var rootPath = '.';
  var mainLocale = defaultMainLocale;

  for (var i = 0; i < args.length; i++) {
    final arg = args[i];

    if (arg == '-h' || arg == '--help') {
      _printUsage();
      return null;
    }

    String? valueFor(String name) {
      if (arg == name) {
        if (i + 1 >= args.length) return null;
        return args[++i];
      }
      if (arg.startsWith('$name=')) return arg.substring(name.length + 1);
      return null;
    }

    final root = valueFor('--root');
    if (root != null) {
      rootPath = root;
      continue;
    }
    final main = valueFor('--main-locale');
    if (main != null) {
      mainLocale = main;
      continue;
    }

    CliLogger.error('Unknown argument: $arg');
    _printUsage();
    exitCode = 64; // EX_USAGE
    return null;
  }

  return _Options(rootPath: rootPath, mainLocale: mainLocale);
}

void _printUsage() {
  CliLogger.info('''
Usage: dart run colaxy_localization:gen [options]

  --root <dir>           App project directory (default: .)
  --main-locale <code>   Locale written to the platform default slots
                         (default: $defaultMainLocale)
  -h, --help             Show this message
''');
}
